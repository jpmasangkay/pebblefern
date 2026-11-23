class_name Player
extends CharacterBody2D

## 3-layer synchronized Sunnyside World player controller (96x64 horizontal strips).
## Features brisk RUN locomotion (12 FPS, 88 px/s), 100% frame-locked Body/Hair sprites,
## strict pre-action validation via ActionValidator, mid-swing strike-frame execution + micro shake,
## full 4-state Sunnyside fishing loop (CASTING -> WAITING -> REELING -> CAUGHT),
## hold-to-chain swings, 3x3 reach mouse targeting, contextual TargetCursor visibility, and footstep SFX.

const AP := preload("res://scripts/core/asset_paths.gd")

enum AnimState {
	IDLE = 0,
	WALK = 1,
	RUN = 2,
	HOE = 3,
	WATER = 4,
	AXE = 5,
	MINE = 6,
	ATTACK = 7,
	FISH = 8,
	DOING = 9,
	WAIT_FISH = 10,
	REEL_FISH = 11,
	CAUGHT_FISH = 12,
}

enum FishPhase {
	NONE = 0,
	CASTING = 1,
	WAITING = 2,
	BITE_WINDOW = 3,
	REELING = 4,
	CAUGHT = 5,
}

const TILE_SIZE: float = 16.0
const WALK_SPEED: float = 88.0
const RUN_SPEED: float = 112.0
const MAX_NAV_POINTS: int = 256
const NAV_ARRIVAL_DIST_SQ: float = 9.0
const ERROR_FEEDBACK_COOLDOWN: float = 0.35
const FISH_WAIT_MIN_SEC: float = 1.5
const FISH_WAIT_MAX_SEC: float = 3.0
const FISH_BITE_WINDOW_SEC: float = 1.2

@export var hairstyle: StringName = &"shorthair"
@export var hair_tint: Color = Color.WHITE

@onready var visuals: Node2D = $Visuals
@onready var body_sprite: Sprite2D = $Visuals/BodySprite
@onready var hair_sprite: Sprite2D = $Visuals/HairSprite
@onready var tool_sprite: Sprite2D = $Visuals/ToolSprite
@onready var camera: Camera2D = $Camera2D
@onready var target_cursor: Node2D = $TargetCursor

# Preloaded animation tables indexed by AnimState (zero per-frame heap allocations)
var _body_textures: Array[Texture2D] = []
var _hair_textures: Array[Texture2D] = []
var _tool_textures: Array[Texture2D] = []
var _frame_counts: PackedInt32Array = PackedInt32Array()
var _frame_rates: PackedFloat32Array = PackedFloat32Array()
var _strike_frames: PackedInt32Array = PackedInt32Array()
var _state_loops: Array[bool] = []

var _state: int = AnimState.IDLE
var _anim_frame: int = 0
var _anim_elapsed: float = 0.0
var _facing_left: bool = false
var _facing_cardinal: Vector2i = Vector2i(0, 1)
var _target_cell: Vector2i = Vector2i.ZERO
var _mouse_active: bool = false
var _last_mouse_world: Vector2 = Vector2.ZERO
var _controls_locked: bool = false
var _hold_use_active: bool = false
var _error_cooldown: float = 0.0

# 4-State Fishing state machine (CASTING -> WAITING -> BITE_WINDOW -> REELING -> CAUGHT)
var _fish_phase: int = FishPhase.NONE
var _fish_timer: float = 0.0
var _fish_target_cell: Vector2i = Vector2i.ZERO
var _fish_catch_cb: Callable = Callable()
var _fish_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fish_alert_sprite: Sprite2D = null
var _alert_tween: Tween = null

# Pre-validated mid-swing action callbacks supplied by active world scene (FarmSanctuary / FarmhouseInterior)
var _validator_cb: Callable = Callable()
var _executor_cb: Callable = Callable()
var _pending_action: ActionValidator.ActionResult = null
var _pending_action_fired: bool = false

# Micro camera strike-frame shake (decays cleanly back to Vector2.ZERO)
var _shake_amp: float = 0.0
var _shake_phase: float = 0.0

# Phase 6 cave combat knockback & brief invulnerability frames
const HURT_INVULN_SEC: float = 0.85
var _hurt_invuln_timer: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO
var _hurt_flash_tween: Tween = null

# External Tap-to-Move queue (Phase 6); keyboard/gamepad ALWAYS cancels & overrides it
var _nav_path: PackedVector2Array = PackedVector2Array()
var _nav_index: int = 0


func _ready() -> void:
	add_to_group(&"player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_fish_rng.seed = 20260407
	assert(body_sprite != null and hair_sprite != null and tool_sprite != null, "Player requires 3-layer Visuals sprites.")
	assert(target_cursor != null, "Player requires TargetCursor node.")

	# Ensure default unlit neutral rendering (prevents white-blob washout)
	body_sprite.modulate = Color.WHITE
	hair_sprite.modulate = hair_tint
	tool_sprite.modulate = Color.WHITE

	# Real Sunnyside '!' alert icon (expression_alerted.png) displayed overhead on fish bite
	var alert_tex: Texture2D = load(AP.UI_EXPRESSION_ALERTED) as Texture2D
	assert(alert_tex != null, "Missing Sunnyside expression_alerted.png")
	_fish_alert_sprite = Sprite2D.new()
	_fish_alert_sprite.name = "FishAlertIcon"
	_fish_alert_sprite.texture = alert_tex
	_fish_alert_sprite.position = Vector2(0.0, -24.0)
	_fish_alert_sprite.z_index = 8
	_fish_alert_sprite.visible = false
	visuals.add_child(_fish_alert_sprite)

	_preload_animation_tables()
	_apply_state(AnimState.IDLE)
	_update_target_cursor()
	EventBus.hotbar_selection_changed.connect(_on_cursor_context_changed_int)
	EventBus.inventory_changed.connect(_update_target_cursor)
	EventBus.grid_cell_changed.connect(_on_cursor_grid_changed)


func _exit_tree() -> void:
	if EventBus.hotbar_selection_changed.is_connected(_on_cursor_context_changed_int):
		EventBus.hotbar_selection_changed.disconnect(_on_cursor_context_changed_int)
	if EventBus.inventory_changed.is_connected(_update_target_cursor):
		EventBus.inventory_changed.disconnect(_update_target_cursor)
	if EventBus.grid_cell_changed.is_connected(_on_cursor_grid_changed):
		EventBus.grid_cell_changed.disconnect(_on_cursor_grid_changed)


func _on_cursor_context_changed_int(_idx: int) -> void:
	_update_target_cursor()


func _on_cursor_grid_changed(_scene_id: StringName, _cell: Vector2i) -> void:
	_update_target_cursor()


func set_action_handlers(validator_cb: Callable, executor_cb: Callable) -> void:
	_validator_cb = validator_cb
	_executor_cb = executor_cb
	_update_target_cursor()


func set_fish_catch_handler(catch_cb: Callable) -> void:
	_fish_catch_cb = catch_cb


func get_fish_target_cell() -> Vector2i:
	return _fish_target_cell


## Deterministic helper for automated fishing verification: advances an active cast straight to CAUGHT
## using the exact biome catch callback bound by FarmSanctuary.
func force_complete_fishing_catch() -> StringName:
	if _fish_phase == FishPhase.NONE:
		return &""
	_hide_fish_alert()
	_fish_phase = FishPhase.CAUGHT
	_fish_timer = 0.0
	_apply_state(AnimState.CAUGHT_FISH, false)
	return _complete_fish_catch()


func is_fishing() -> bool:
	return _fish_phase != FishPhase.NONE


func is_busy() -> bool:
	return _is_action_state(_state)


func is_controls_locked() -> bool:
	return _controls_locked


func get_fish_phase() -> int:
	return _fish_phase


func _preload_animation_tables() -> void:
	# [folder, file_stem, frame_count, fps, loops, strike_frame]
	# ToolSprite stays visible in ALL states because tools_idle/walk/run draw the player's near arm & hand!
	var specs: Array[Array] = [
		["IDLE", "idle", 9, 8.0, true, 0],            # IDLE (tools_idle_strip9.png)
		["WALKING", "walk", 8, 10.0, true, 0],        # WALK (tools_walk_strip8.png)
		["RUN", "run", 8, 12.0, true, 0],             # RUN (tools_run_strip8.png — brisk default movement!)
		["DIG", "dig", 13, 22.0, false, 7],           # HOE (strike frame 7)
		["WATERING", "watering", 5, 18.0, false, 2],  # WATER (strike frame 2)
		["AXE", "axe", 10, 20.0, false, 5],           # AXE (strike frame 5)
		["MINING", "mining", 10, 20.0, false, 5],     # MINE (strike frame 5)
		["ATTACK", "attack", 10, 22.0, false, 4],     # ATTACK / SCYTHE (strike frame 4)
		["CASTING", "casting", 15, 18.0, false, 8],   # FISH (cast splash frame 8 -> WAITING)
		["DOING", "doing", 8, 20.0, false, 3],        # DOING (plant/harvest/eat frame 3)
		["WAITING", "waiting", 9, 8.0, true, 0],      # WAIT_FISH (steady rod loop facing water)
		["REELING", "reeling", 13, 18.0, false, 0],   # REEL_FISH (reeling in fish -> CAUGHT)
		["CAUGHT", "caught", 10, 14.0, false, 0],     # CAUGHT_FISH (victory hold -> IDLE)
	]

	var hair_prefix: String = String(hairstyle)
	_body_textures.resize(specs.size())
	_hair_textures.resize(specs.size())
	_tool_textures.resize(specs.size())
	_frame_counts.resize(specs.size())
	_frame_rates.resize(specs.size())
	_strike_frames.resize(specs.size())
	_state_loops.resize(specs.size())

	for i: int in range(specs.size()):
		var spec: Array = specs[i]
		var folder: String = spec[0]
		var stem: String = spec[1]
		var count: int = spec[2]
		var base_path: String = "%s/%s/base_%s_strip%d.png" % [AP.HUMAN_ROOT, folder, stem, count]
		var hair_path: String = "%s/%s/%s_%s_strip%d.png" % [AP.HUMAN_ROOT, folder, hair_prefix, stem, count]
		var tool_path: String = "%s/%s/tools_%s_strip%d.png" % [AP.HUMAN_ROOT, folder, stem, count]

		var b_tex: Texture2D = load(base_path) as Texture2D
		var h_tex: Texture2D = load(hair_path) as Texture2D
		var t_tex: Texture2D = load(tool_path) as Texture2D
		assert(b_tex != null, "Missing player base strip: %s" % base_path)
		assert(h_tex != null, "Missing player hair strip: %s" % hair_path)
		assert(t_tex != null, "Missing player tools strip: %s" % tool_path)

		_body_textures[i] = b_tex
		_hair_textures[i] = h_tex
		_tool_textures[i] = t_tex
		_frame_counts[i] = count
		_frame_rates[i] = spec[3]
		_state_loops[i] = spec[4]
		_strike_frames[i] = spec[5]


func _unhandled_input(event: InputEvent) -> void:
	if _controls_locked:
		_hold_use_active = false
		return

	if event is InputEventMouseMotion:
		_last_mouse_world = get_global_mouse_position()
		_mouse_active = true
		if _fish_phase == FishPhase.NONE:
			_update_target_cursor()
		return

	# Active Fishing State Input Handling (Bite catch, early reel, or WASD/Esc cancel!)
	if _fish_phase != FishPhase.NONE:
		if event.is_action_released(&"use_tool"):
			_hold_use_active = false
			return
		if _fish_phase == FishPhase.WAITING or _fish_phase == FishPhase.BITE_WINDOW:
			if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_inventory"):
				cancel_fishing()
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down") or event.is_action_pressed(&"move_left") or event.is_action_pressed(&"move_right"):
				cancel_fishing()
				return
			if event.is_action_pressed(&"use_tool") or event.is_action_pressed(&"interact"):
				handle_fishing_action_input()
				get_viewport().set_input_as_handled()
				return
		return

	# Hotbar selection via Keys 1..8, Mouse Wheel, and Gamepad LB/RB
	if event.is_action_pressed(&"hotbar_next"):
		InventoryManager.cycle_hotbar(1)
		_update_target_cursor()
		return
	if event.is_action_pressed(&"hotbar_prev"):
		InventoryManager.cycle_hotbar(-1)
		_update_target_cursor()
		return
	for slot_num: int in range(1, InventoryManager.HOTBAR_SIZE + 1):
		var action_name: StringName = StringName("hotbar_%d" % slot_num)
		if event.is_action_pressed(action_name):
			InventoryManager.select_hotbar_slot(slot_num - 1)
			_update_target_cursor()
			return

	if event.is_action_released(&"use_tool"):
		_hold_use_active = false
		return

	if event.is_action_pressed(&"use_tool"):
		if event is InputEventMouseButton:
			_last_mouse_world = get_global_mouse_position()
			_mouse_active = true
			_update_target_cursor()
		_hold_use_active = true
		if not _is_action_state(_state):
			use_selected_item(true, false)
	elif event.is_action_pressed(&"interact") and not _is_action_state(_state):
		EventBus.player_interacted.emit(_target_cell)


## Handles LMB / E during WAITING or BITE_WINDOW (also callable directly by automated tests).
func handle_fishing_action_input() -> void:
	if _fish_phase == FishPhase.BITE_WINDOW:
		_hide_fish_alert()
		_fish_phase = FishPhase.REELING
		_fish_timer = 0.0
		_hold_use_active = false
		AudioManager.play_sfx(&"water", -4.0, 0.04)
		trigger_camera_shake(1.0)
		_apply_state(AnimState.REEL_FISH, false)
	elif _fish_phase == FishPhase.WAITING:
		cancel_fishing("Nothing bit yet.")


func cancel_fishing(toast_msg: String = "") -> void:
	_hide_fish_alert()
	_fish_phase = FishPhase.NONE
	_fish_timer = 0.0
	_hold_use_active = false
	_pending_action = null
	_pending_action_fired = false
	_apply_state(AnimState.IDLE, false)
	if not toast_msg.is_empty():
		EventBus.toast_requested.emit(toast_msg)
	_update_target_cursor()


func _show_fish_alert() -> void:
	if _fish_alert_sprite == null:
		return
	_fish_alert_sprite.visible = true
	_fish_alert_sprite.scale = Vector2(0.5, 0.5)
	if _alert_tween != null and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert_tween = create_tween()
	_alert_tween.set_trans(Tween.TRANS_BACK)
	_alert_tween.set_ease(Tween.EASE_OUT)
	_alert_tween.tween_property(_fish_alert_sprite, "scale", Vector2.ONE, 0.14)


func _hide_fish_alert() -> void:
	if _alert_tween != null and _alert_tween.is_valid():
		_alert_tween.kill()
	if _fish_alert_sprite != null:
		_fish_alert_sprite.visible = false


## Validates the selected item BEFORE playing any animation, spawning particles, or draining Vitality.
## When immediate_execute is false (live gameplay), executes gameplay effect on the mid-swing strike frame!
func use_selected_item(allow_feedback: bool = true, immediate_execute: bool = false) -> ActionValidator.ActionResult:
	var item: ItemData = InventoryManager.get_selected_item_data()

	if _validator_cb.is_valid():
		var res: ActionValidator.ActionResult = _validator_cb.call(item, _target_cell) as ActionValidator.ActionResult
		assert(res != null, "ActionValidator callback must return ActionValidator.ActionResult.")
		if not res.valid:
			if res.required_tier_blocked > 0:
				EventBus.tool_tier_insufficient.emit(res.required_tier_blocked, _target_cell)
			if allow_feedback and _error_cooldown <= 0.0 and not res.reason.is_empty():
				_error_cooldown = ERROR_FEEDBACK_COOLDOWN
				AudioManager.play_sfx(&"error", -8.0, 0.03)
				EventBus.toast_requested.emit(res.reason)
			return res

		_pending_action = res
		_pending_action_fired = false
		if res.kind == ActionValidator.ActionKind.CAST_FISHING:
			_fish_phase = FishPhase.CASTING
			_fish_timer = 0.0
			_fish_target_cell = res.target_cell
			_hold_use_active = false
		trigger_tool_animation(res.anim_state)
		if immediate_execute:
			_fire_pending_action()
		return res

	var fallback: ActionValidator.ActionResult = ActionValidator.ActionResult.new()
	fallback.valid = false
	return fallback


func _fire_pending_action() -> void:
	if _pending_action == null or _pending_action_fired:
		return
	_pending_action_fired = true
	var action: ActionValidator.ActionResult = _pending_action
	if _executor_cb.is_valid():
		_executor_cb.call(action)
	if action.sfx_id != &"":
		AudioManager.play_sfx(action.sfx_id, -6.0, 0.05)
	match action.kind:
		ActionValidator.ActionKind.HIT_RESOURCE:
			trigger_camera_shake(1.5)
		ActionValidator.ActionKind.SWING_SWORD:
			trigger_camera_shake(0.75)
		ActionValidator.ActionKind.TILL:
			trigger_camera_shake(0.9)
		ActionValidator.ActionKind.HARVEST_CROP, ActionValidator.ActionKind.HARVEST_BERRY:
			trigger_camera_shake(0.6)
	_update_target_cursor()


func apply_damage_and_knockback(amount: float, from_world_pos: Vector2) -> bool:
	assert(amount > 0.0, "Player damage must be positive.")
	if _hurt_invuln_timer > 0.0 or _controls_locked:
		return false
	_hurt_invuln_timer = HURT_INVULN_SEC
	var push_dir: Vector2 = global_position - from_world_pos
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2(0.0, 1.0)
	_knockback_vel = push_dir.normalized() * 145.0
	AudioManager.play_sfx(&"player_hurt", -4.0, 0.05)
	trigger_camera_shake(2.2)

	if _hurt_flash_tween != null and _hurt_flash_tween.is_valid():
		_hurt_flash_tween.kill()
	visuals.modulate = Color(1.65, 0.52, 0.52, 1.0)
	_hurt_flash_tween = create_tween()
	_hurt_flash_tween.tween_property(visuals, "modulate", Color.WHITE, 0.24)

	VitalitySystem.consume(amount)
	if VitalitySystem.current_vitality <= 0.0:
		EventBus.pass_out_triggered.emit()
	return true


func is_hurt_invulnerable() -> bool:
	return _hurt_invuln_timer > 0.0


func trigger_camera_shake(amplitude: float) -> void:
	_shake_amp = maxf(_shake_amp, clampf(amplitude, 0.0, 3.0))
	_shake_phase = 0.0


func _physics_process(delta: float) -> void:
	var clamped_dt: float = minf(delta, 0.1)
	if _error_cooldown > 0.0:
		_error_cooldown = maxf(0.0, _error_cooldown - clamped_dt)
	if _hurt_invuln_timer > 0.0:
		_hurt_invuln_timer = maxf(0.0, _hurt_invuln_timer - clamped_dt)

	_update_camera_shake(clamped_dt)

	if _controls_locked:
		velocity = Vector2.ZERO
		_knockback_vel = Vector2.ZERO
		_hold_use_active = false
		target_cursor.visible = false
		if _fish_phase != FishPhase.NONE:
			cancel_fishing()
		_step_animation(clamped_dt)
		return

	if _mouse_active:
		_last_mouse_world = get_global_mouse_position()

	# Active 4-state Fishing tick (WAITING bite timer & 1.2s BITE_WINDOW)
	if _fish_phase != FishPhase.NONE:
		velocity = Vector2.ZERO
		target_cursor.visible = false
		_step_fishing_timers(clamped_dt)
		_step_animation(clamped_dt)
		return

	if _is_action_state(_state):
		velocity = _knockback_vel
		if _knockback_vel.length_squared() > 1.0:
			move_and_slide()
			_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 680.0 * clamped_dt)
		else:
			_knockback_vel = Vector2.ZERO
		_step_animation(clamped_dt)
		_update_target_cursor()
		return

	# Hold LMB / C to smoothly chain consecutive swings!
	if _hold_use_active and Input.is_action_pressed(&"use_tool"):
		_update_target_cursor()
		var chain_res: ActionValidator.ActionResult = use_selected_item(false, false)
		if chain_res.valid:
			return
	elif _hold_use_active and not Input.is_action_pressed(&"use_tool"):
		_hold_use_active = false

	var speed_mult: float = VitalitySystem.get_speed_multiplier()

	# PC / Gamepad directional input ALWAYS takes immediate priority over mobile virtual stick & tap-to-move
	var move_vec: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if move_vec.length_squared() <= 0.001 and InputModeManager.virtual_move_vector.length_squared() > 0.001:
		move_vec = InputModeManager.virtual_move_vector
	if move_vec.length_squared() > 0.001:
		cancel_navigation_path()
		var normalized: Vector2 = move_vec.normalized() if move_vec.length_squared() > 1.0 else move_vec
		var sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and not VitalitySystem.is_exhausted
		var base_speed: float = RUN_SPEED if sprinting else WALK_SPEED
		velocity = normalized * (base_speed * speed_mult)
		_update_facing(normalized)
		# Use brisk RUN strip (12 FPS) for normal movement, WALK strip when exhausted
		var desired_state: int = AnimState.WALK if VitalitySystem.is_exhausted else AnimState.RUN
		if _state != desired_state:
			var preserve: bool = _is_locomotion_state(_state)
			_apply_state(desired_state, preserve)
	elif _has_active_nav_path():
		_follow_nav_path(speed_mult)
	else:
		velocity = Vector2.ZERO
		if _state != AnimState.IDLE:
			_apply_state(AnimState.IDLE)

	if _knockback_vel.length_squared() > 1.0:
		velocity += _knockback_vel
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 680.0 * clamped_dt)
	else:
		_knockback_vel = Vector2.ZERO

	move_and_slide()
	var anim_mult: float = 1.2 if (Input.is_key_pressed(KEY_SHIFT) and not VitalitySystem.is_exhausted and _state == AnimState.RUN) else (0.72 if VitalitySystem.is_exhausted and _is_locomotion_state(_state) else 1.0)
	_step_animation(clamped_dt * anim_mult)
	_update_target_cursor()


func _step_fishing_timers(dt: float) -> void:
	if _fish_phase == FishPhase.WAITING:
		# Pressing directional movement during WAITING cancels fishing smoothly!
		var move_vec: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if move_vec.length_squared() <= 0.05 and InputModeManager.virtual_move_vector.length_squared() > 0.20:
			move_vec = InputModeManager.virtual_move_vector
		if move_vec.length_squared() > 0.05:
			cancel_fishing()
			return
		_fish_timer -= dt
		if _fish_timer <= 0.0:
			_fish_phase = FishPhase.BITE_WINDOW
			_fish_timer = FISH_BITE_WINDOW_SEC
			_show_fish_alert()
			AudioManager.play_sfx(&"water", -3.0, 0.03)
			AudioManager.play_sfx(&"pickup", -5.0, 0.02)
			trigger_camera_shake(1.1)
			EventBus.toast_requested.emit("Bite! Reel in now!")
	elif _fish_phase == FishPhase.BITE_WINDOW:
		_fish_timer -= dt
		if _fish_timer <= 0.0:
			_hide_fish_alert()
			_fish_phase = FishPhase.NONE
			_fish_timer = 0.0
			AudioManager.play_sfx(&"error", -7.0, 0.02)
			EventBus.toast_requested.emit("It got away!")
			_apply_state(AnimState.IDLE, false)
			_update_target_cursor()


func _update_camera_shake(dt: float) -> void:
	if _shake_amp <= 0.05:
		_shake_amp = 0.0
		if camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
		return
	_shake_phase += dt * 62.0
	_shake_amp = maxf(0.0, _shake_amp - dt * 11.5)
	camera.offset = Vector2(
		roundf(cos(_shake_phase) * _shake_amp),
		roundf(sin(_shake_phase * 1.3) * _shake_amp)
	)


func get_effective_walk_speed() -> float:
	return WALK_SPEED * VitalitySystem.get_speed_multiplier()


func set_camera_bounds(world_rect_px: Rect2i) -> void:
	assert(world_rect_px.size.x > 0 and world_rect_px.size.y > 0, "Invalid world camera bounds.")
	camera.limit_left = world_rect_px.position.x
	camera.limit_top = world_rect_px.position.y
	camera.limit_right = world_rect_px.end.x
	camera.limit_bottom = world_rect_px.end.y


func set_controls_locked(locked: bool) -> void:
	_controls_locked = locked
	if locked:
		velocity = Vector2.ZERO
		_hold_use_active = false
		_pending_action = null
		_pending_action_fired = false
		if _fish_phase != FishPhase.NONE:
			cancel_fishing()
		target_cursor.visible = false
		cancel_navigation_path()
		if _state != AnimState.IDLE:
			_apply_state(AnimState.IDLE)


func set_facing_cardinal(dir: Vector2i) -> void:
	assert(dir != Vector2i.ZERO, "Facing cardinal cannot be zero.")
	_facing_cardinal = dir
	if dir.x < 0:
		_facing_left = true
	elif dir.x > 0:
		_facing_left = false
	body_sprite.flip_h = _facing_left
	hair_sprite.flip_h = _facing_left
	tool_sprite.flip_h = _facing_left
	_mouse_active = false
	_update_target_cursor()


func trigger_tool_animation(tool_anim: int) -> void:
	assert(_is_action_state(tool_anim), "Tool animation must be an active action state.")
	cancel_navigation_path()
	velocity = Vector2.ZERO
	var player_cell: Vector2i = get_grid_cell()
	var dx: int = _target_cell.x - player_cell.x
	if dx < 0:
		_facing_left = true
	elif dx > 0:
		_facing_left = false
	_apply_state(tool_anim, false)


func set_navigation_path(points: PackedVector2Array) -> void:
	var count: int = mini(points.size(), MAX_NAV_POINTS)
	_nav_path = points.slice(0, count)
	_nav_index = 0


func cancel_navigation_path() -> void:
	if _nav_path.size() > 0:
		_nav_path = PackedVector2Array()
		_nav_index = 0


func get_grid_cell() -> Vector2i:
	return Vector2i(floori(global_position.x / TILE_SIZE), floori(global_position.y / TILE_SIZE))


func get_target_cell() -> Vector2i:
	return _target_cell


func get_facing_cardinal() -> Vector2i:
	return _facing_cardinal


func get_current_anim_state() -> int:
	return _state


func is_idle() -> bool:
	return _state == AnimState.IDLE


func is_target_cursor_visible() -> bool:
	return target_cursor.visible


func _has_active_nav_path() -> bool:
	return _nav_path.size() > 0 and _nav_index < _nav_path.size()


func _follow_nav_path(speed_mult: float) -> void:
	var target_pt: Vector2 = _nav_path[_nav_index]
	var to_target: Vector2 = target_pt - global_position
	if to_target.length_squared() <= NAV_ARRIVAL_DIST_SQ:
		_nav_index += 1
		if _nav_index >= _nav_path.size():
			cancel_navigation_path()
			velocity = Vector2.ZERO
			if _state != AnimState.IDLE:
				_apply_state(AnimState.IDLE)
			return
		target_pt = _nav_path[_nav_index]
		to_target = target_pt - global_position
	var dir: Vector2 = to_target.normalized()
	velocity = dir * (WALK_SPEED * speed_mult)
	_update_facing(dir)
	if _state != AnimState.WALK:
		_apply_state(AnimState.WALK, _is_locomotion_state(_state))


func _update_facing(dir: Vector2) -> void:
	if dir.x < -0.05:
		_facing_left = true
	elif dir.x > 0.05:
		_facing_left = false

	if absf(dir.x) >= absf(dir.y):
		_facing_cardinal = Vector2i(-1, 0) if dir.x < 0.0 else Vector2i(1, 0)
	else:
		_facing_cardinal = Vector2i(0, -1) if dir.y < 0.0 else Vector2i(0, 1)

	body_sprite.flip_h = _facing_left
	hair_sprite.flip_h = _facing_left
	tool_sprite.flip_h = _facing_left


func _apply_state(new_state: int, preserve_frame: bool = false) -> void:
	assert(new_state >= 0 and new_state < _body_textures.size(), "Invalid AnimState: %d" % new_state)
	var frames: int = _frame_counts[new_state]
	_state = new_state

	if preserve_frame and frames > 0:
		_anim_frame = _anim_frame % frames
	else:
		_anim_frame = 0
		_anim_elapsed = 0.0

	body_sprite.texture = _body_textures[new_state]
	body_sprite.hframes = frames
	body_sprite.vframes = 1
	body_sprite.frame = _anim_frame
	body_sprite.flip_h = _facing_left

	hair_sprite.texture = _hair_textures[new_state]
	hair_sprite.hframes = frames
	hair_sprite.vframes = 1
	hair_sprite.frame = _anim_frame
	hair_sprite.flip_h = _facing_left

	# ToolSprite draws the player's foreground arm & hand in IDLE/WALK/RUN as well as active tools — ALWAYS visible & frame-locked!
	tool_sprite.visible = true
	tool_sprite.texture = _tool_textures[new_state]
	tool_sprite.hframes = frames
	tool_sprite.vframes = 1
	tool_sprite.frame = _anim_frame
	tool_sprite.flip_h = _facing_left


func _step_animation(dt: float) -> void:
	var fps: float = _frame_rates[_state]
	var count: int = _frame_counts[_state]
	var frame_dur: float = 1.0 / fps
	_anim_elapsed += dt
	if _anim_elapsed < frame_dur:
		return

	var prev_frame: int = _anim_frame
	var steps: int = int(_anim_elapsed / frame_dur)
	_anim_elapsed -= float(steps) * frame_dur
	var next_frame: int = _anim_frame + steps

	if next_frame >= count:
		if _state_loops[_state]:
			_anim_frame = next_frame % count
		else:
			# Ensure mid-swing action fired before exiting swing even on lag spike
			if _pending_action != null and not _pending_action_fired:
				_fire_pending_action()
			_pending_action = null
			_pending_action_fired = false

			# 4-State Fishing transitions: CASTING -> WAITING, REELING -> CAUGHT (+1 Fish!), CAUGHT -> IDLE
			if _fish_phase == FishPhase.CASTING:
				_fish_phase = FishPhase.WAITING
				_fish_timer = _fish_rng.randf_range(FISH_WAIT_MIN_SEC, FISH_WAIT_MAX_SEC)
				_apply_state(AnimState.WAIT_FISH, false)
				return
			elif _fish_phase == FishPhase.REELING:
				_fish_phase = FishPhase.CAUGHT
				_apply_state(AnimState.CAUGHT_FISH, false)
				_complete_fish_catch()
				return
			elif _fish_phase == FishPhase.CAUGHT:
				_fish_phase = FishPhase.NONE
				_fish_timer = 0.0
				_apply_state(AnimState.IDLE, false)
				_update_target_cursor()
				return

			_apply_state(AnimState.IDLE, false)
			return
	else:
		_anim_frame = next_frame

	# 100% frame-locked BodySprite, HairSprite, and ToolSprite
	body_sprite.frame = _anim_frame
	hair_sprite.frame = _anim_frame
	tool_sprite.frame = _anim_frame

	# Mid-swing strike-frame gameplay trigger
	if _is_action_state(_state) and _pending_action != null and not _pending_action_fired:
		if _anim_frame >= _strike_frames[_state]:
			_fire_pending_action()

	# Footstep SFX right on foot-plant frames (1 & 5) of the 8-frame RUN cycle
	if _is_locomotion_state(_state) and _anim_frame != prev_frame:
		if _anim_frame == 1 or _anim_frame == 5:
			AudioManager.play_sfx(&"footstep", -14.0, 0.08)


func _update_target_cursor() -> void:
	var player_cell: Vector2i = get_grid_cell()
	var chosen: Vector2i = player_cell + _facing_cardinal
	if _mouse_active:
		var mouse_cell: Vector2i = Vector2i(floori(_last_mouse_world.x / TILE_SIZE), floori(_last_mouse_world.y / TILE_SIZE))
		var dist_x: int = absi(mouse_cell.x - player_cell.x)
		var dist_y: int = absi(mouse_cell.y - player_cell.y)
		if dist_x <= 1 and dist_y <= 1:
			chosen = mouse_cell
	_target_cell = chosen
	target_cursor.global_position = Vector2(float(chosen.x) * TILE_SIZE + 8.0, float(chosen.y) * TILE_SIZE + 8.0)

	# Hide 4-corner TargetCursor on non-actionable roads/grass/indoors or while actively fishing.
	# When holding a crafted placeable outdoors, show green (valid) or red (blocked) placement preview!
	if _controls_locked or _fish_phase != FishPhase.NONE:
		target_cursor.visible = false
		target_cursor.modulate = Color.WHITE
	elif _validator_cb.is_valid():
		var held: ItemData = InventoryManager.get_selected_item_data()
		var check: ActionValidator.ActionResult = _validator_cb.call(held, _target_cell) as ActionValidator.ActionResult
		if held != null and held.is_placeable():
			var is_indoor_block: bool = (check != null and not check.valid and check.reason == "Can't place objects indoors")
			if is_indoor_block:
				target_cursor.visible = false
				target_cursor.modulate = Color.WHITE
			else:
				target_cursor.visible = true
				target_cursor.modulate = Color(0.55, 1.0, 0.55, 1.0) if (check != null and check.valid) else Color(1.0, 0.42, 0.42, 1.0)
		else:
			target_cursor.modulate = Color.WHITE
			target_cursor.visible = (check != null and check.valid and check.kind != ActionValidator.ActionKind.EAT_ITEM and check.kind != ActionValidator.ActionKind.SWING_SWORD)
	else:
		target_cursor.visible = false
		target_cursor.modulate = Color.WHITE


func _complete_fish_catch() -> StringName:
	if _fish_catch_cb.is_valid():
		var caught_id: Variant = _fish_catch_cb.call(_fish_target_cell)
		if caught_id is StringName:
			return caught_id as StringName
	var leftover: int = InventoryManager.add_item(&"fish", 1)
	AudioManager.play_sfx(&"harvest", -4.0, 0.03)
	if leftover == 0:
		EventBus.toast_requested.emit("+1 Fish!")
	else:
		EventBus.toast_requested.emit("Backpack full!")
	return &"fish"


func _is_locomotion_state(st: int) -> bool:
	return st == AnimState.WALK or st == AnimState.RUN


func _is_action_state(st: int) -> bool:
	return st >= AnimState.HOE
