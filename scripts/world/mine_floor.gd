class_name MineFloor
extends Node2D

## Playable 3-floor Pebblefern Mine Cave (res://scenes/world/mine_floor.tscn).
## Features subterranean Sunnyside cavern walls & rails, flickering PointLight2D wall torches,
## soft player lantern aura, depth-scaled ore/crystal veins, hidden descending ladder,
## active directional Sword combat against Sunnyside Skeleton enemies with knockback & hitstop,
## strict underground tool rules via ActionValidator, and safe farmhouse rescue on 0 Vitality.

const AP := preload("res://scripts/core/asset_paths.gd")
const MineEnemyScript := preload("res://scripts/entities/mine_enemy.gd")
const RESOURCE_NODE_SCENE_PATH: String = "res://scenes/entities/resource_node.tscn"
const FARMHOUSE_INTERIOR_PATH: String = "res://scenes/world/farmhouse_interior.tscn"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"
const INVENTORY_MODAL_SCENE_PATH: String = "res://scenes/ui/inventory_modal.tscn"
const MOBILE_CONTROLS_SCENE_PATH: String = "res://scenes/ui/mobile_controls.tscn"
const MobileControlsScript := preload("res://scripts/ui/mobile_controls.gd")

const MAX_FLOORS: int = 3
const TILE_SIZE: float = 16.0
const SWORD_REACH_PX: float = 34.0
const SWORD_OVERLAP_PX: float = 18.0
const HITSTOP_DURATION_SEC: float = 0.045
const MINE_HIT_RADIUS_SQ: float = 20.0 * 20.0

@export var room_bounds_px: Rect2i = Rect2i(-32, -16, 448, 288)

@onready var world_entities: Node2D = $WorldEntities
@onready var player: Player = $WorldEntities/Player
@onready var exit_ladder_area: Area2D = $ExitLadderArea
@onready var cave_modulate: CanvasModulate = get_node_or_null("CaveModulate") as CanvasModulate
@onready var wall_lights_root: Node2D = get_node_or_null("WallLights") as Node2D
@onready var floor_content_root: Node2D = $WorldEntities/FloorContent

var current_floor: int = 1
var drop_pool: DroppedItemPool = null
var hud: GameplayHUD = null
var inventory_modal: InventoryModal = null
var pause_modal: CanvasLayer = null
var mobile_controls: MobileControlsScript = null
var _floor_banner_pill: SunnysideBox = null

var _resource_node_scene: PackedScene = null
var _tileset_tex: Texture2D = null
var _player_lantern: PointLight2D = null
var _floor_banner_layer: CanvasLayer = null
var _floor_banner_label: Label = null
var _descend_ladder_node: Node2D = null
var _descend_ladder_area: Area2D = null
var _descend_ladder_cell: Vector2i = Vector2i(-1, -1)
var _descend_ladder_revealed: bool = false
var _is_at_exit_ladder: bool = false
var _is_at_descend_ladder: bool = false
var _flicker_time: float = 0.0
var _hitstop_timer: float = 0.0
var _rescue_in_progress: bool = false
var _hud_user_visible: bool = true
var _sword_fx_particles: CPUParticles2D = null
var _mine_rocks: Array[ResourceNode] = []
var _mine_enemies: Array[MineEnemyScript] = []


func _ready() -> void:
	assert(player != null, "MineFloor requires WorldEntities/Player.")
	assert(exit_ladder_area != null, "MineFloor requires ExitLadderArea.")
	assert(floor_content_root != null, "MineFloor requires WorldEntities/FloorContent.")

	_resource_node_scene = load(RESOURCE_NODE_SCENE_PATH) as PackedScene
	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	assert(_resource_node_scene != null and _tileset_tex != null, "MineFloor missing core resources.")

	player.set_camera_bounds(room_bounds_px)
	player.camera.position = Vector2.ZERO
	player.set_action_handlers(_validate_mine_action, _execute_mine_action)

	# Attach warm player cave lantern aura
	_attach_player_lantern()

	# Pre-allocate magnetic DroppedItemPool for mined ores, gems, and skeleton drops
	drop_pool = DroppedItemPool.new()
	drop_pool.name = "MineDropPool"
	world_entities.add_child(drop_pool)

	# Crisp Sunnyside rock/crystal spark FX for sword impacts
	_sword_fx_particles = CPUParticles2D.new()
	_sword_fx_particles.name = "SwordFXParticles"
	_sword_fx_particles.texture = load(AP.ITEM_ROCK) as Texture2D
	_sword_fx_particles.emitting = false
	_sword_fx_particles.one_shot = true
	_sword_fx_particles.explosiveness = 0.92
	_sword_fx_particles.amount = 6
	_sword_fx_particles.lifetime = 0.24
	_sword_fx_particles.direction = Vector2(0.0, -1.0)
	_sword_fx_particles.spread = 95.0
	_sword_fx_particles.gravity = Vector2(0.0, 180.0)
	_sword_fx_particles.initial_velocity_min = 28.0
	_sword_fx_particles.initial_velocity_max = 64.0
	_sword_fx_particles.scale_amount_min = 0.20
	_sword_fx_particles.scale_amount_max = 0.34
	_sword_fx_particles.z_index = 6
	add_child(_sword_fx_particles)

	exit_ladder_area.body_entered.connect(_on_exit_ladder_entered)
	exit_ladder_area.body_exited.connect(_on_exit_ladder_exited)

	_setup_ui()
	_build_floor_banner()

	var incoming_id: StringName = SceneTransition.consume_interior_id()
	var start_floor: int = 1
	if incoming_id == &"mine_floor_2":
		start_floor = 2
	elif incoming_id == &"mine_floor_3":
		start_floor = 3

	load_floor(start_floor)

	# Restore exact saved coordinates if loaded directly from SaveManager
	if Engine.has_singleton("SaveManager") or get_node_or_null("/root/SaveManager") != null:
		var sm: Node = get_node_or_null("/root/SaveManager")
		if sm != null and sm.has_method("consume_loaded_player_state"):
			var loaded: Dictionary = sm.call("consume_loaded_player_state") as Dictionary
			if bool(loaded.get("valid", false)):
				var saved_floor: int = clampi(int(loaded.get("mine_floor", start_floor)), 1, MAX_FLOORS)
				if saved_floor != current_floor:
					load_floor(saved_floor)
				player.global_position = loaded["position"] as Vector2

	EventBus.player_interacted.connect(_on_player_interacted)
	EventBus.pass_out_triggered.connect(_on_pass_out_triggered)
	EventBus.input_mode_changed.connect(_on_mine_input_mode_changed)
	EventBus.touch_controls_preference_changed.connect(_on_mine_touch_pref_changed)
	EventBus.interior_entered.emit(&"pebblefern_mine")


func _exit_tree() -> void:
	if EventBus.player_interacted.is_connected(_on_player_interacted):
		EventBus.player_interacted.disconnect(_on_player_interacted)
	if EventBus.pass_out_triggered.is_connected(_on_pass_out_triggered):
		EventBus.pass_out_triggered.disconnect(_on_pass_out_triggered)
	if EventBus.input_mode_changed.is_connected(_on_mine_input_mode_changed):
		EventBus.input_mode_changed.disconnect(_on_mine_input_mode_changed)
	if EventBus.touch_controls_preference_changed.is_connected(_on_mine_touch_pref_changed):
		EventBus.touch_controls_preference_changed.disconnect(_on_mine_touch_pref_changed)
	EventBus.interact_prompt_changed.emit("")
	EventBus.interior_exited.emit(&"pebblefern_mine")


func _attach_player_lantern() -> void:
	var grad: Gradient = Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.90, 0.68, 0.45), Color(1.0, 0.78, 0.44, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128

	_player_lantern = PointLight2D.new()
	_player_lantern.name = "PlayerLanternLight"
	_player_lantern.position = Vector2(0.0, -6.0)
	_player_lantern.color = Color(1.0, 0.88, 0.66, 1.0)
	_player_lantern.texture = tex
	_player_lantern.texture_scale = 1.25
	_player_lantern.energy = 0.58
	_player_lantern.blend_mode = Light2D.BLEND_MODE_ADD
	player.add_child(_player_lantern)


func _setup_ui() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var inv_scene: PackedScene = load(INVENTORY_MODAL_SCENE_PATH) as PackedScene
	assert(hud_scene != null and inv_scene != null, "MineFloor missing HUD or InventoryModal scenes.")

	hud = hud_scene.instantiate() as GameplayHUD
	add_child(hud)

	inventory_modal = inv_scene.instantiate() as InventoryModal
	add_child(inventory_modal)
	inventory_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	if ResourceLoader.exists("res://scenes/ui/pause_modal.tscn"):
		var pause_scene: PackedScene = load("res://scenes/ui/pause_modal.tscn") as PackedScene
		if pause_scene != null:
			pause_modal = pause_scene.instantiate() as CanvasLayer
			add_child(pause_modal)
			if pause_modal.has_signal("modal_visibility_changed"):
				pause_modal.connect("modal_visibility_changed", _on_ui_modal_state_changed)

	var mob_scene: PackedScene = load(MOBILE_CONTROLS_SCENE_PATH) as PackedScene
	if mob_scene != null:
		mobile_controls = mob_scene.instantiate() as MobileControlsScript
		add_child(mobile_controls)
		mobile_controls.bind_scene(
			player,
			func() -> void:
				if pause_modal != null and pause_modal.has_method("is_open") and bool(pause_modal.call("is_open")):
					return
				if inventory_modal != null:
					inventory_modal.toggle(),
			func() -> void:
				if inventory_modal != null and inventory_modal.is_open():
					return
				if pause_modal != null and pause_modal.has_method("toggle"):
					pause_modal.call("toggle")
		)


func _build_floor_banner() -> void:
	_floor_banner_layer = CanvasLayer.new()
	_floor_banner_layer.name = "MineFloorBannerLayer"
	_floor_banner_layer.layer = 11
	add_child(_floor_banner_layer)

	var root_ctrl: Control = Control.new()
	root_ctrl.anchor_left = 0.0
	root_ctrl.anchor_top = 0.0
	root_ctrl.anchor_right = 2.0
	root_ctrl.anchor_bottom = 2.0
	root_ctrl.scale = Vector2(0.5, 0.5)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_floor_banner_layer.add_child(root_ctrl)

	var pill: SunnysideBox = SunnysideBox.new()
	pill.name = "FloorBannerPill"
	pill.set_box_style(SunnysideBox.Style.DARK_TAN)
	pill.anchor_left = 0.0
	pill.anchor_top = 0.0
	pill.anchor_right = 0.0
	pill.anchor_bottom = 0.0
	pill.offset_left = 8.0
	pill.offset_top = 8.0
	pill.offset_right = 172.0
	pill.offset_bottom = 26.0
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(pill)

	_floor_banner_label = Label.new()
	_floor_banner_label.name = "FloorBannerLabel"
	_floor_banner_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_floor_banner_label.add_theme_font_size_override(&"font_size", 9)
	_floor_banner_label.add_theme_color_override(&"font_color", Color(1.0, 0.92, 0.58, 1.0))
	_floor_banner_label.add_theme_color_override(&"font_outline_color", Color(0.16, 0.10, 0.08, 1.0))
	_floor_banner_label.add_theme_constant_override(&"outline_size", 2)
	pill.add_child(_floor_banner_label)
	_floor_banner_pill = pill
	_refresh_floor_banner_position()


func _on_mine_input_mode_changed(_mode: int, _family: int) -> void:
	_refresh_floor_banner_position()


func _on_mine_touch_pref_changed(_pref: int) -> void:
	_refresh_floor_banner_position()


func _refresh_floor_banner_position() -> void:
	if _floor_banner_pill == null:
		return
	var x0: float = 70.0 if InputModeManager.should_show_touch_controls() else 8.0
	_floor_banner_pill.offset_left = x0
	_floor_banner_pill.offset_right = x0 + 164.0


func load_floor(floor_num: int) -> void:
	current_floor = clampi(floor_num, 1, MAX_FLOORS)
	_descend_ladder_revealed = false
	_descend_ladder_cell = Vector2i(-1, -1)
	_is_at_descend_ladder = false
	_descend_ladder_node = null
	_descend_ladder_area = null
	_mine_rocks.clear()
	_mine_enemies.clear()

	# Clear previous floor entities & drops cleanly
	for c: Node in floor_content_root.get_children():
		c.queue_free()
	if drop_pool != null:
		drop_pool.clear_all_drops()

	# Place player cleanly at foot of the upper Exit Ladder
	player.global_position = get_entry_spawn_world_position()
	player.set_facing_cardinal(Vector2i(0, 1))

	if _floor_banner_label != null:
		_floor_banner_label.text = "Pebblefern Mine • Floor %d / %d" % [current_floor, MAX_FLOORS]

	# Slightly deeper moody slate-violet tint as player descends deeper!
	if cave_modulate != null:
		match current_floor:
			1:
				cave_modulate.color = Color(0.58, 0.60, 0.70, 1.0)
			2:
				cave_modulate.color = Color(0.52, 0.55, 0.68, 1.0)
			_:
				cave_modulate.color = Color(0.46, 0.52, 0.68, 1.0)

	_populate_floor_entities(current_floor)
	EventBus.mine_floor_changed.emit(current_floor)
	EventBus.interact_prompt_changed.emit("")


func _populate_floor_entities(p_floor: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260600 + p_floor * 131 + TimeManager.current_day * 17

	# Deterministic curated interior slots spaced cleanly apart on playable cavern floor (x=3..20, y=5..12)
	var rock_slots: Array[Vector2i] = [
		Vector2i(5, 6), Vector2i(7, 8), Vector2i(10, 8), Vector2i(14, 7), Vector2i(17, 6),
		Vector2i(4, 10), Vector2i(8, 11), Vector2i(12, 10), Vector2i(16, 10), Vector2i(19, 9),
		Vector2i(6, 12), Vector2i(14, 12), Vector2i(18, 12),
	]
	var enemy_slots: Array[Vector2i] = [
		Vector2i(6, 9),
		Vector2i(15, 9),
		Vector2i(11, 12),
	]

	# Build depth-scaled ore/crystal table
	var kinds: Array[int] = []
	match p_floor:
		1:
			kinds = [
				ResourceNode.NodeKind.MINE_ROCK,
				ResourceNode.NodeKind.ORE_COPPER,
				ResourceNode.NodeKind.MINE_ROCK,
				ResourceNode.NodeKind.ORE_COPPER,
				ResourceNode.NodeKind.MINE_ROCK,
				ResourceNode.NodeKind.ORE_COPPER,
				ResourceNode.NodeKind.CRYSTAL_VEIN,
				ResourceNode.NodeKind.MINE_ROCK,
				ResourceNode.NodeKind.ORE_COPPER,
				ResourceNode.NodeKind.MINE_ROCK,
			]
		2:
			kinds = [
				ResourceNode.NodeKind.MINE_ROCK,
				ResourceNode.NodeKind.ORE_COPPER,
				ResourceNode.NodeKind.ORE_IRON,
				ResourceNode.NodeKind.ORE_IRON,
				ResourceNode.NodeKind.CRYSTAL_VEIN,
				ResourceNode.NodeKind.MINE_ROCK,
				ResourceNode.NodeKind.ORE_COPPER,
				ResourceNode.NodeKind.ORE_IRON,
				ResourceNode.NodeKind.CRYSTAL_VEIN,
				ResourceNode.NodeKind.ORE_IRON,
				ResourceNode.NodeKind.MINE_ROCK,
			]
		_:
			kinds = [
				ResourceNode.NodeKind.ORE_IRON,
				ResourceNode.NodeKind.CRYSTAL_VEIN,
				ResourceNode.NodeKind.ORE_IRON,
				ResourceNode.NodeKind.CRYSTAL_VEIN,
				ResourceNode.NodeKind.ORE_COPPER,
				ResourceNode.NodeKind.ORE_IRON,
				ResourceNode.NodeKind.CRYSTAL_VEIN,
				ResourceNode.NodeKind.MINE_ROCK,
				ResourceNode.NodeKind.ORE_IRON,
				ResourceNode.NodeKind.MINE_ROCK,
				ResourceNode.NodeKind.CRYSTAL_VEIN,
			]

	var ladder_rock_idx: int = 2 if p_floor < MAX_FLOORS else -1
	var count_nodes: int = mini(kinds.size(), rock_slots.size())
	for i: int in range(count_nodes):
		var cell: Vector2i = rock_slots[i]
		var rn: ResourceNode = _resource_node_scene.instantiate() as ResourceNode
		rn.name = "MineNode_%d_%d" % [cell.x, cell.y]
		rn.persist_scene_id = &"" # Mine floors regenerate cleanly on each delve!
		rn.node_kind = kinds[i] as ResourceNode.NodeKind
		rn.position = _cell_center(cell) + Vector2(0.0, 2.0)
		if i == ladder_rock_idx:
			rn.hides_ladder = true
		if p_floor == 3 and kinds[i] == ResourceNode.NodeKind.CRYSTAL_VEIN and (i == 1 or i == 6):
			rn.override_drop_item_id = &"cave_ruby"
		rn.node_depleted.connect(_on_mine_rock_depleted)
		floor_content_root.add_child(rn)
		_mine_rocks.append(rn)

	# Spawn 2-3 Sunnyside Skeleton cave enemies per floor
	var enemy_count: int = 2 if p_floor == 1 else 3
	for e: int in range(enemy_count):
		var e_cell: Vector2i = enemy_slots[e % enemy_slots.size()]
		var enemy: MineEnemyScript = MineEnemyScript.new()
		enemy.name = "CaveSkeleton_%d" % e
		enemy.position = _cell_center(e_cell)
		floor_content_root.add_child(enemy)
		enemy.configure_for_floor(p_floor, rng.randi(), player)
		_mine_enemies.append(enemy)


func _on_mine_rock_depleted(node: ResourceNode) -> void:
	if node == null or not node.hides_ladder or _descend_ladder_revealed or current_floor >= MAX_FLOORS:
		return
	_reveal_descending_ladder(node.get_grid_cell())


func _reveal_descending_ladder(cell: Vector2i) -> void:
	_descend_ladder_revealed = true
	_descend_ladder_cell = cell

	var ladder_root: Node2D = Node2D.new()
	ladder_root.name = "DescendLadder"
	ladder_root.position = _cell_center(cell)
	ladder_root.z_index = -1
	floor_content_root.add_child(ladder_root)
	_descend_ladder_node = ladder_root

	# Authentic Sunnyside wooden ladder descending into rocky hole
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "LadderSprite"
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = _tileset_tex
	at.region = Rect2(AP.TILE_LADDER_MID.x * 16, AP.TILE_LADDER_MID.y * 16, 16, 16)
	spr.texture = at
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ladder_root.add_child(spr)

	var area: Area2D = Area2D.new()
	area.name = "DescendLadderArea"
	area.collision_layer = 8
	area.collision_mask = 4
	area.monitoring = true
	area.monitorable = true
	ladder_root.add_child(area)
	var cs: CollisionShape2D = CollisionShape2D.new()
	var circ: CircleShape2D = CircleShape2D.new()
	circ.radius = 16.0
	cs.shape = circ
	area.add_child(cs)
	area.body_entered.connect(_on_descend_ladder_entered)
	area.body_exited.connect(_on_descend_ladder_exited)
	_descend_ladder_area = area

	AudioManager.play_sfx(&"harvest", -4.0, 0.04)
	EventBus.toast_requested.emit("Ladder uncovered! Interact to descend to Floor %d!" % (current_floor + 1))


func get_entry_spawn_world_position() -> Vector2:
	# Stands directly at the base of the upper center Exit Ladder (col 11.5, row 4.2)
	return Vector2(11.5 * TILE_SIZE, 4.2 * TILE_SIZE)


func get_mine_rocks() -> Array[ResourceNode]:
	var alive: Array[ResourceNode] = []
	for rn: ResourceNode in _mine_rocks:
		if rn != null and is_instance_valid(rn) and not rn.is_destroyed():
			alive.append(rn)
	return alive


func get_alive_enemies() -> Array[MineEnemyScript]:
	var alive: Array[MineEnemyScript] = []
	for en: MineEnemyScript in _mine_enemies:
		if en != null and is_instance_valid(en) and en.is_alive():
			alive.append(en)
	return alive


func get_ladder_rock() -> ResourceNode:
	for rn: ResourceNode in _mine_rocks:
		if rn != null and is_instance_valid(rn) and rn.hides_ladder and not rn.is_destroyed():
			return rn
	return null


func is_descend_ladder_revealed() -> bool:
	return _descend_ladder_revealed


func set_hud_visible(show_hud: bool) -> void:
	_hud_user_visible = show_hud
	if hud != null:
		hud.visible = _hud_user_visible and not _is_any_modal_open()


func exit_to_quarry(immediate: bool = false) -> bool:
	if SceneTransition.is_transitioning():
		return false
	return SceneTransition.exit_interior(&"from_mine", immediate)


func descend_to_next_floor() -> bool:
	if current_floor >= MAX_FLOORS:
		return false
	AudioManager.play_sfx(&"door", -5.0, 0.04)
	load_floor(current_floor + 1)
	if current_floor == MAX_FLOORS:
		EventBus.toast_requested.emit("Floor 3 — Deep Crystal Chamber!")
	else:
		EventBus.toast_requested.emit("Descended to Floor %d!" % current_floor)
	return true


func _find_mine_rock_at(cell: Vector2i) -> ResourceNode:
	var target_center: Vector2 = _cell_center(cell)
	var best: ResourceNode = null
	var best_d2: float = MINE_HIT_RADIUS_SQ
	for rn: ResourceNode in _mine_rocks:
		if rn == null or not is_instance_valid(rn) or rn.is_destroyed():
			continue
		if rn.get_grid_cell() == cell:
			return rn
		var d2: float = rn.global_position.distance_squared_to(target_center)
		if d2 < best_d2:
			best_d2 = d2
			best = rn
	return best


func _validate_mine_action(item: ItemData, target_cell: Vector2i) -> ActionValidator.ActionResult:
	var ctx: ActionValidator.ValidationContext = ActionValidator.ValidationContext.new()
	ctx.is_indoors = false
	ctx.is_mine = true
	ctx.target_cell = target_cell
	ctx.resource_node = _find_mine_rock_at(target_cell)
	ctx.slot_charges = InventoryManager.get_selected_slot_charges()
	return ActionValidator.validate_use(item, ctx)


func _execute_mine_action(action: ActionValidator.ActionResult) -> void:
	match action.kind:
		ActionValidator.ActionKind.HIT_RESOURCE:
			var pick: ToolData = action.item as ToolData
			if pick != null:
				VitalitySystem.consume(pick.vitality_cost)
				if action.target_resource != null and is_instance_valid(action.target_resource):
					action.target_resource.apply_tool_hit(pick, drop_pool, player)
				EventBus.player_tool_used.emit(pick.id, action.target_cell)
				if VitalitySystem.current_vitality <= 0.0:
					EventBus.pass_out_triggered.emit()

		ActionValidator.ActionKind.SWING_SWORD:
			var sword: ToolData = action.item as ToolData
			var dmg: int = maxi(1, sword.power) if sword != null else 1
			VitalitySystem.consume(1.0)
			var hit_count: int = perform_sword_strike(dmg)
			if hit_count > 0:
				_trigger_hitstop(HITSTOP_DURATION_SEC)
				player.trigger_camera_shake(1.8)
			EventBus.player_tool_used.emit(&"tool_scythe", action.target_cell)
			if VitalitySystem.current_vitality <= 0.0:
				EventBus.pass_out_triggered.emit()

		ActionValidator.ActionKind.EAT_ITEM:
			if action.item != null and InventoryManager.remove_from_slot(InventoryManager.selected_hotbar_index, 1):
				VitalitySystem.restore(action.item.vitality_restore)
				EventBus.toast_requested.emit("Restored +%d Vitality!" % int(action.item.vitality_restore))


## Directional Sword arc hit detection against all alive cave skeletons on the current floor.
func perform_sword_strike(damage: int = 1) -> int:
	assert(damage > 0, "Sword strike damage must be positive.")
	var facing_v: Vector2 = Vector2(player.get_facing_cardinal()).normalized()
	if facing_v.length_squared() < 0.01:
		facing_v = Vector2(0.0, 1.0)

	var hits: int = 0
	for enemy: MineEnemyScript in _mine_enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var to_e: Vector2 = enemy.global_position - player.global_position
		var dist: float = to_e.length()
		if dist > SWORD_REACH_PX:
			continue
		var in_arc: bool = (dist <= SWORD_OVERLAP_PX) or (to_e.normalized().dot(facing_v) >= -0.15)
		if in_arc:
			if enemy.take_sword_hit(damage, player.global_position, drop_pool, player):
				hits += 1
				if _sword_fx_particles != null:
					_sword_fx_particles.global_position = enemy.global_position + Vector2(0.0, -4.0)
					_sword_fx_particles.restart()
					_sword_fx_particles.emitting = true
	return hits


func _trigger_hitstop(duration: float) -> void:
	_hitstop_timer = maxf(_hitstop_timer, duration)
	for en: MineEnemyScript in _mine_enemies:
		if en != null and is_instance_valid(en):
			en.set_ai_paused(true)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	_flicker_time += dt

	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - dt)
		if _hitstop_timer <= 0.0:
			var modal_open: bool = _is_any_modal_open()
			for en: MineEnemyScript in _mine_enemies:
				if en != null and is_instance_valid(en):
					en.set_ai_paused(modal_open)

	# Flicker subterranean wall torches & player lantern gently
	if wall_lights_root != null:
		var idx: int = 0
		for c: Node in wall_lights_root.get_children():
			var pl: PointLight2D = c as PointLight2D
			if pl != null:
				pl.energy = 0.72 * (0.93 + 0.07 * sin(_flicker_time * 8.4 + float(idx) * 1.9))
				idx += 1
	if _player_lantern != null:
		_player_lantern.energy = 0.56 * (0.96 + 0.04 * sin(_flicker_time * 6.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_menu") or event.is_action_pressed(&"ui_cancel"):
		if inventory_modal != null and inventory_modal.is_open():
			inventory_modal.set_open(false)
			get_viewport().set_input_as_handled()
			return
		if pause_modal != null and pause_modal.has_method("toggle"):
			pause_modal.call("toggle")
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed(&"toggle_inventory"):
		if pause_modal != null and pause_modal.has_method("is_open") and bool(pause_modal.call("is_open")):
			return
		if inventory_modal != null:
			inventory_modal.toggle()
			get_viewport().set_input_as_handled()


func _on_player_interacted(_target_cell: Vector2i) -> void:
	if _is_any_modal_open():
		return
	if _is_at_exit_ladder:
		exit_to_quarry()
	elif _is_at_descend_ladder and _descend_ladder_revealed:
		descend_to_next_floor()


func _on_pass_out_triggered() -> void:
	trigger_safe_mine_rescue(false)


## Safe rescue back to Farmhouse bed next morning with ZERO item loss when Vitality hits 0 underground!
func trigger_safe_mine_rescue(immediate: bool = false) -> void:
	if _rescue_in_progress:
		return
	_rescue_in_progress = true
	if inventory_modal != null and inventory_modal.is_open():
		inventory_modal.set_open(false)
	if pause_modal != null and pause_modal.has_method("set_open"):
		pause_modal.call("set_open", false)
	player.set_controls_locked(true)
	EventBus.toast_requested.emit("You grew faint in the mine and were carried home safely!")
	TimeManager.sleep_to_next_day()
	SceneTransition.transition_to_scene(FARMHOUSE_INTERIOR_PATH, &"bed_wake", immediate)


func _on_exit_ladder_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_at_exit_ladder = true
		EventBus.interact_prompt_changed.emit("[E] Exit Mine to Quarry")


func _on_exit_ladder_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_at_exit_ladder = false
		EventBus.interact_prompt_changed.emit("[E] Descend to Floor %d" % (current_floor + 1) if _is_at_descend_ladder else "")


func _on_descend_ladder_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_at_descend_ladder = true
		EventBus.interact_prompt_changed.emit("[E] Descend to Floor %d" % (current_floor + 1))


func _on_descend_ladder_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_at_descend_ladder = false
		EventBus.interact_prompt_changed.emit("[E] Exit Mine to Quarry" if _is_at_exit_ladder else "")


func _is_any_modal_open() -> bool:
	var inv_open: bool = inventory_modal != null and inventory_modal.is_open()
	var pause_open: bool = pause_modal != null and pause_modal.has_method("is_open") and bool(pause_modal.call("is_open"))
	return inv_open or pause_open


func _on_ui_modal_state_changed(_open_state: bool) -> void:
	var blocking: bool = _is_any_modal_open()
	TimeManager.set_paused(blocking)
	if player != null:
		player.set_controls_locked(blocking)
	for en: MineEnemyScript in _mine_enemies:
		if en != null and is_instance_valid(en):
			en.set_ai_paused(blocking)
	if hud != null:
		hud.visible = not blocking and _hud_user_visible
	if _floor_banner_layer != null:
		_floor_banner_layer.visible = not blocking and _hud_user_visible
	if mobile_controls != null:
		mobile_controls.set_modal_hidden(blocking)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * TILE_SIZE + 8.0, float(cell.y) * TILE_SIZE + 8.0)
