class_name FarmhouseInterior
extends Node2D

## Dedicated Stardew-style Farmhouse Interior room (res://scenes/world/farmhouse_interior.tscn).
## Features straight timber walls, cozy dining area, corner fireplace, interactive Red Bed ([E] Sleep),
## Exit Doormat portal back to FarmSanctuary, and strict indoor tool blocking via ActionValidator.

const AP := preload("res://scripts/core/asset_paths.gd")
const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"
const INVENTORY_MODAL_SCENE_PATH: String = "res://scenes/ui/inventory_modal.tscn"
const SLEEP_DIALOG_SCENE_PATH: String = "res://scenes/ui/sleep_dialog.tscn"
const PAUSE_MODAL_SCENE_PATH: String = "res://scenes/ui/pause_modal.tscn"
const MOBILE_CONTROLS_SCENE_PATH: String = "res://scenes/ui/mobile_controls.tscn"
const PauseModalScript := preload("res://scripts/ui/pause_modal.gd")
const MobileControlsScript := preload("res://scripts/ui/mobile_controls.gd")

@export var room_bounds_px: Rect2i = Rect2i(-48, -16, 320, 212)

@onready var player: Player = $WorldEntities/Player
@onready var exit_portal: Area2D = $ExitDoorPortal
@onready var bed_trigger: Area2D = $BedSleepTrigger
@onready var hearth_light: PointLight2D = get_node_or_null("HearthLight") as PointLight2D
@onready var room_modulate: CanvasModulate = get_node_or_null("InteriorModulate") as CanvasModulate

var hud: GameplayHUD = null
var inventory_modal: InventoryModal = null
var sleep_dialog: SleepDialog = null
var pause_modal: PauseModalScript = null
var mobile_controls: MobileControlsScript = null

var _is_player_at_bed: bool = false
var _is_player_at_exit: bool = false
var _flicker_time: float = 0.0
var _hud_user_visible: bool = true


func _ready() -> void:
	assert(player != null, "FarmhouseInterior requires WorldEntities/Player.")
	assert(exit_portal != null, "FarmhouseInterior requires ExitDoorPortal Area2D.")
	assert(bed_trigger != null, "FarmhouseInterior requires BedSleepTrigger Area2D.")

	player.set_camera_bounds(room_bounds_px)
	player.camera.position = Vector2.ZERO
	player.set_action_handlers(_validate_indoor_action, _execute_indoor_action)

	# Position player cleanly according to saved state OR spawn tag (from front door vs waking up in bed)
	var loaded_state: Dictionary = SaveManager.consume_loaded_player_state()
	var spawn_tag: StringName = SceneTransition.consume_spawn_tag()
	if bool(loaded_state.get("valid", false)):
		player.global_position = loaded_state["position"] as Vector2
		player.set_facing_cardinal(Vector2i(0, 1))
	elif spawn_tag == &"bed_wake":
		player.global_position = get_bed_wake_world_position()
		player.set_facing_cardinal(Vector2i(1, 0))
	else:
		player.global_position = get_entry_spawn_world_position()
		player.set_facing_cardinal(Vector2i(0, -1))

	exit_portal.body_entered.connect(_on_exit_entered)
	exit_portal.body_exited.connect(_on_exit_exited)
	bed_trigger.body_entered.connect(_on_bed_entered)
	bed_trigger.body_exited.connect(_on_bed_exited)

	_setup_ui()

	EventBus.player_interacted.connect(_on_player_interacted)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	EventBus.pass_out_triggered.connect(_on_pass_out_triggered)
	EventBus.interior_entered.emit(&"farmhouse")
	_refresh_interior_lighting()


func _exit_tree() -> void:
	if EventBus.player_interacted.is_connected(_on_player_interacted):
		EventBus.player_interacted.disconnect(_on_player_interacted)
	if EventBus.sleep_requested.is_connected(_on_sleep_requested):
		EventBus.sleep_requested.disconnect(_on_sleep_requested)
	if EventBus.pass_out_triggered.is_connected(_on_pass_out_triggered):
		EventBus.pass_out_triggered.disconnect(_on_pass_out_triggered)
	EventBus.interact_prompt_changed.emit("")
	EventBus.interior_exited.emit(&"farmhouse")


func _setup_ui() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var inv_scene: PackedScene = load(INVENTORY_MODAL_SCENE_PATH) as PackedScene
	var sleep_scene: PackedScene = load(SLEEP_DIALOG_SCENE_PATH) as PackedScene
	assert(hud_scene != null and inv_scene != null and sleep_scene != null, "Missing UI scenes in FarmhouseInterior.")

	hud = hud_scene.instantiate() as GameplayHUD
	add_child(hud)

	inventory_modal = inv_scene.instantiate() as InventoryModal
	add_child(inventory_modal)
	inventory_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	sleep_dialog = sleep_scene.instantiate() as SleepDialog
	add_child(sleep_dialog)
	sleep_dialog.set_wake_callback(_on_morning_wake_up)
	sleep_dialog.dialog_visibility_changed.connect(_on_ui_modal_state_changed)
	sleep_dialog.sleep_flow_started.connect(_update_ui_pause_state)
	sleep_dialog.sleep_flow_completed.connect(_update_ui_pause_state)

	var pause_scene: PackedScene = load(PAUSE_MODAL_SCENE_PATH) as PackedScene
	if pause_scene != null:
		pause_modal = pause_scene.instantiate() as PauseModalScript
		add_child(pause_modal)
		pause_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	var mob_scene: PackedScene = load(MOBILE_CONTROLS_SCENE_PATH) as PackedScene
	if mob_scene != null:
		mobile_controls = mob_scene.instantiate() as MobileControlsScript
		add_child(mobile_controls)
		mobile_controls.bind_scene(
			player,
			func() -> void:
				if sleep_dialog != null and (sleep_dialog.is_dialog_open() or sleep_dialog.is_transitioning()):
					return
				if pause_modal != null and pause_modal.is_open():
					return
				if inventory_modal != null:
					inventory_modal.toggle(),
			func() -> void:
				if sleep_dialog != null and (sleep_dialog.is_dialog_open() or sleep_dialog.is_transitioning()):
					return
				if inventory_modal != null and inventory_modal.is_open():
					return
				if pause_modal != null:
					pause_modal.toggle()
		)


func _process(delta: float) -> void:
	_flicker_time += minf(delta, 0.1)
	_refresh_interior_lighting()


func _physics_process(_delta: float) -> void:
	if not _is_player_at_exit:
		return
	if SceneTransition.is_portal_on_cooldown():
		return
	if TimeManager.is_paused():
		return
	# Stardew-style walk-down exit onto the doormat returns smoothly to the farm doorstep!
	if Input.is_action_pressed(&"move_down") or InputModeManager.virtual_move_vector.y > 0.35:
		exit_to_farm()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_menu") or event.is_action_pressed(&"ui_cancel"):
		if sleep_dialog != null and (sleep_dialog.is_dialog_open() or sleep_dialog.is_transitioning()):
			return
		if inventory_modal != null and inventory_modal.is_open():
			inventory_modal.set_open(false)
			get_viewport().set_input_as_handled()
			return
		if pause_modal != null:
			pause_modal.toggle()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_inventory"):
		if sleep_dialog != null and (sleep_dialog.is_dialog_open() or sleep_dialog.is_transitioning()):
			return
		if pause_modal != null and pause_modal.is_open():
			return
		if inventory_modal != null:
			inventory_modal.toggle()
			get_viewport().set_input_as_handled()


func get_entry_spawn_world_position() -> Vector2:
	# Stands neatly inside the cabin just north of the bottom Exit Doormat (cols 6..7, row 6.4)
	return Vector2(112.0, 108.0)


func get_bed_wake_world_position() -> Vector2:
	# Stands cleanly on the bedroom rug directly beside the Red Bed (col 2.5, row 3.4)
	return Vector2(44.0, 56.0)


func is_player_at_bed() -> bool:
	return _is_player_at_bed


func is_player_at_exit() -> bool:
	return _is_player_at_exit


func set_hud_visible(show_hud: bool) -> void:
	_hud_user_visible = show_hud
	if hud != null:
		var inv_open: bool = inventory_modal != null and inventory_modal.is_open()
		hud.visible = _hud_user_visible and not inv_open
	if mobile_controls != null:
		mobile_controls.set_force_hidden(not _hud_user_visible)


func exit_to_farm(immediate: bool = false) -> bool:
	if SceneTransition.is_transitioning():
		return false
	EventBus.door_transition_requested.emit(FARM_SCENE_PATH, &"from_house")
	return SceneTransition.exit_interior(&"from_house", immediate)


func _validate_indoor_action(item: ItemData, target_cell: Vector2i) -> ActionValidator.ActionResult:
	var ctx: ActionValidator.ValidationContext = ActionValidator.ValidationContext.new()
	ctx.is_indoors = true
	ctx.target_cell = target_cell
	return ActionValidator.validate_use(item, ctx)


func _execute_indoor_action(action: ActionValidator.ActionResult) -> void:
	if action.kind == ActionValidator.ActionKind.EAT_ITEM and action.item != null:
		if InventoryManager.remove_from_slot(InventoryManager.selected_hotbar_index, 1):
			VitalitySystem.restore(action.item.vitality_restore)


func _on_player_interacted(_target_cell: Vector2i) -> void:
	if _is_player_at_bed:
		EventBus.sleep_requested.emit()
	elif _is_player_at_exit:
		exit_to_farm()


func _on_sleep_requested() -> void:
	if inventory_modal != null and inventory_modal.is_open():
		return
	if sleep_dialog != null:
		sleep_dialog.open_dialog()


func _on_pass_out_triggered() -> void:
	if inventory_modal != null and inventory_modal.is_open():
		inventory_modal.set_open(false)
	if sleep_dialog != null and not sleep_dialog.is_transitioning():
		sleep_dialog.begin_sleep_transition(_on_morning_wake_up)


func _on_morning_wake_up() -> void:
	if player != null:
		player.global_position = get_bed_wake_world_position()
		player.set_facing_cardinal(Vector2i(1, 0))
	_refresh_interior_lighting()


func _refresh_interior_lighting() -> void:
	var hour_f: float = TimeManager.get_hour_float()
	var night_factor: float = clampf((hour_f - 17.5) / 3.0, 0.0, 1.0)
	if room_modulate != null:
		# Cozy bright warm cabin during the day; snug firelit amber-indigo at night (always readable!)
		room_modulate.color = Color(1.0, 0.98, 0.95, 1.0).lerp(Color(0.56, 0.50, 0.58, 1.0), night_factor)
	if hearth_light != null:
		var base_e: float = lerpf(0.42, 1.15, night_factor)
		hearth_light.energy = base_e * (0.94 + 0.06 * sin(_flicker_time * 9.2))


func _on_bed_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_player_at_bed = true
		EventBus.interact_prompt_changed.emit("[E] Sleep in Bed")


func _on_bed_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_player_at_bed = false
		if _is_player_at_exit:
			EventBus.interact_prompt_changed.emit("[E] Exit to Sanctuary")
		else:
			EventBus.interact_prompt_changed.emit("")


func _on_exit_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_player_at_exit = true
		EventBus.interact_prompt_changed.emit("[E] Exit to Sanctuary")


func _on_exit_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_player_at_exit = false
		if _is_player_at_bed:
			EventBus.interact_prompt_changed.emit("[E] Sleep in Bed")
		else:
			EventBus.interact_prompt_changed.emit("")


func _on_ui_modal_state_changed(_open_state: bool) -> void:
	_update_ui_pause_state()


func _update_ui_pause_state() -> void:
	var inv_open: bool = inventory_modal != null and inventory_modal.is_open()
	var sleep_open: bool = sleep_dialog != null and (sleep_dialog.is_dialog_open() or sleep_dialog.is_transitioning())
	var pause_open: bool = pause_modal != null and pause_modal.is_open()
	var modal_blocking: bool = inv_open or sleep_open or pause_open
	TimeManager.set_paused(modal_blocking)
	if player != null:
		player.set_controls_locked(modal_blocking)
	if hud != null:
		hud.visible = not (inv_open or pause_open) and _hud_user_visible
	if mobile_controls != null:
		mobile_controls.set_modal_hidden(modal_blocking)
