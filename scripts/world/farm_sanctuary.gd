class_name FarmSanctuary
extends Node2D

## Solstice Sanctuary Farm scene controller.
## Coordinates strict ActionValidator pre-validation, mid-swing gameplay execution,
## Smart Harvest (mature crops + ripe berry bushes), real Stardew DoorPortal transition,
## persistent farming grid, placed craftable objects (Chest, Torch, Fence, Path, Scarecrow, Furnace),
## Maren & Kaelen's MarketStall, Sanctuary Shipping Chest, pooled magnetic drops, and UI/atmosphere.

const AP := preload("res://scripts/core/asset_paths.gd")
const CROP_NODE_SCENE_PATH: String = "res://scenes/entities/crop_node.tscn"
const PLACED_CHEST_SCENE_PATH: String = "res://scenes/props/placed_chest.tscn"
const INTERIOR_SCENE_PATH: String = "res://scenes/world/farmhouse_interior.tscn"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"
const INVENTORY_MODAL_SCENE_PATH: String = "res://scenes/ui/inventory_modal.tscn"
const SLEEP_DIALOG_SCENE_PATH: String = "res://scenes/ui/sleep_dialog.tscn"
const SHIPPING_MODAL_SCENE_PATH: String = "res://scenes/ui/shipping_modal.tscn"
const SHOP_MODAL_SCENE_PATH: String = "res://scenes/ui/shop_modal.tscn"
const CHEST_MODAL_SCENE_PATH: String = "res://scenes/ui/chest_modal.tscn"
const FURNACE_MODAL_SCENE_PATH: String = "res://scenes/ui/furnace_modal.tscn"
const DIALOGUE_MODAL_SCENE_PATH: String = "res://scenes/ui/dialogue_modal.tscn"
const QUEST_BOARD_MODAL_SCENE_PATH: String = "res://scenes/ui/quest_board_modal.tscn"
const FESTIVAL_SHOWCASE_SCENE_PATH: String = "res://scenes/ui/festival_showcase_modal.tscn"
const PAUSE_MODAL_SCENE_PATH: String = "res://scenes/ui/pause_modal.tscn"
const MOBILE_CONTROLS_SCENE_PATH: String = "res://scenes/ui/mobile_controls.tscn"
const MINE_FLOOR_SCENE_PATH: String = "res://scenes/world/mine_floor.tscn"
const FestivalShowcaseScript := preload("res://scripts/ui/festival_showcase_modal.gd")
const PauseModalScript := preload("res://scripts/ui/pause_modal.gd")
const MobileControlsScript := preload("res://scripts/ui/mobile_controls.gd")

const TILE_SIZE: float = 16.0
const RESOURCE_HIT_RADIUS_SQ: float = 18.0 * 18.0
const BERRY_HIT_RADIUS_SQ: float = 18.0 * 18.0

@export var scene_id: StringName = &"farm_sanctuary"
@export var world_bounds_px: Rect2i = Rect2i(0, 0, 1536, 960)
@export var title_showcase_mode: bool = false

@onready var water_layer: TileMapLayer = $"00_Water"
@onready var ground_layer: TileMapLayer = $"01_Ground"
@onready var paths_layer: TileMapLayer = $"02_Paths"
@onready var soil_layer: TileMapLayer = $"03_SoilOverlay"
@onready var deco_layer: TileMapLayer = $"04_Decorations"
@onready var ladder_layer: TileMapLayer = get_node_or_null("01b_CliffLadders") as TileMapLayer
@onready var beach_layer: TileMapLayer = get_node_or_null("01c_BeachSand") as TileMapLayer
@onready var quarry_layer: TileMapLayer = get_node_or_null("01d_QuarryGround") as TileMapLayer
@onready var waterfall_layer: TileMapLayer = get_node_or_null("01e_Waterfalls") as TileMapLayer
@onready var garden_bed_layer: TileMapLayer = get_node_or_null("02b_GardenBed") as TileMapLayer
@onready var world_entities: Node2D = $WorldEntities
@onready var world_markers: Node2D = get_node_or_null("WorldMarkers") as Node2D
@onready var player: Player = $WorldEntities/Player
@onready var farmhouse: CutawayFarmhouse = $WorldEntities/CutawayFarmhouse
@onready var shipping_bin: ShippingBin = $WorldEntities/ShippingBin
@onready var market_stall: MarketStall = get_node_or_null("WorldEntities/MarketStall") as MarketStall

var drop_pool: DroppedItemPool = null
var atmosphere: WorldAtmosphere = null
var hud: GameplayHUD = null
var inventory_modal: InventoryModal = null
var sleep_dialog: SleepDialog = null
var shipping_modal: ShippingModal = null
var shop_modal: ShopModal = null
var chest_modal: ChestModal = null
var furnace_modal: FurnaceModal = null
var dialogue_modal: DialogueModal = null
var quest_board_modal: QuestBoardModal = null
var festival_showcase_modal: FestivalShowcaseScript = null
var pause_modal: PauseModalScript = null
var mobile_controls: MobileControlsScript = null
var _festival_overlay: Node2D = null

var _crop_node_scene: PackedScene = null
var _placed_chest_scene: PackedScene = null
var _crop_nodes: Dictionary = {} # Vector2i -> CropNode
var _placed_nodes: Dictionary = {} # Vector2i -> Node2D (PlacedChest or PlacedWorldObject)
var _fx_particles: CPUParticles2D = null
var _soil_chip_tex: Texture2D = null
var _water_chip_tex: Texture2D = null
var _hud_user_visible: bool = true
var _fish_loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	assert(player != null, "FarmSanctuary requires WorldEntities/Player.")
	assert(farmhouse != null, "FarmSanctuary requires WorldEntities/CutawayFarmhouse.")
	assert(soil_layer != null and water_layer != null and ground_layer != null, "FarmSanctuary missing TileMapLayers.")
	_crop_node_scene = load(CROP_NODE_SCENE_PATH) as PackedScene
	_placed_chest_scene = load(PLACED_CHEST_SCENE_PATH) as PackedScene
	assert(_crop_node_scene != null, "Missing crop_node.tscn")
	assert(_placed_chest_scene != null, "Missing placed_chest.tscn")

	player.set_camera_bounds(world_bounds_px)
	player.set_action_handlers(_validate_player_action, _execute_player_action)
	player.set_fish_catch_handler(_on_player_fish_caught)
	_fish_loot_rng.seed = 20260515

	# Honor exact saved coordinates (SaveManager) OR doorstep return position (Farmhouse / NPC Interior / Mine)!
	var loaded_state: Dictionary = SaveManager.consume_loaded_player_state()
	var ret: Dictionary = SceneTransition.consume_return_position()
	var spawn_tag: StringName = SceneTransition.consume_spawn_tag()
	if bool(loaded_state.get("valid", false)):
		player.global_position = loaded_state["position"] as Vector2
		player.set_facing_cardinal(Vector2i(0, 1))
	elif bool(ret.get("valid", false)):
		player.global_position = ret["position"] as Vector2
		player.set_facing_cardinal(Vector2i(0, 1))
	elif spawn_tag == &"from_house":
		player.global_position = farmhouse.get_door_spawn_world_position()
		player.set_facing_cardinal(Vector2i(0, 1))

	# Prune any ResourceNodes previously cleared before stepping indoors
	_prune_destroyed_resources()

	# Pre-allocate fixed-capacity magnetic DroppedItemPool inside WorldEntities
	drop_pool = DroppedItemPool.new()
	drop_pool.name = "DroppedItemPool"
	world_entities.add_child(drop_pool)

	# Reusable zero-procedural-art CPUParticles2D for hoe dirt / watering splash bursts
	_soil_chip_tex = load(AP.SOIL_DRY) as Texture2D
	_water_chip_tex = load(AP.ICON_WATERING_CAN) as Texture2D
	_fx_particles = CPUParticles2D.new()
	_fx_particles.name = "ActionFXParticles"
	_fx_particles.emitting = false
	_fx_particles.one_shot = true
	_fx_particles.explosiveness = 0.9
	_fx_particles.amount = 6
	_fx_particles.lifetime = 0.30
	_fx_particles.direction = Vector2(0.0, -1.0)
	_fx_particles.spread = 70.0
	_fx_particles.gravity = Vector2(0.0, 220.0)
	_fx_particles.initial_velocity_min = 28.0
	_fx_particles.initial_velocity_max = 60.0
	_fx_particles.scale_amount_min = 0.22
	_fx_particles.scale_amount_max = 0.36
	_fx_particles.z_index = 4
	add_child(_fx_particles)

	_sync_initial_grid_state()
	_setup_ui_and_atmosphere()

	if title_showcase_mode:
		_apply_title_showcase_mode()
		return

	EventBus.player_interacted.connect(_on_player_interacted)
	EventBus.grid_cell_changed.connect(_on_grid_cell_changed)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	EventBus.pass_out_triggered.connect(_on_pass_out_triggered)
	EventBus.shipping_bin_interacted.connect(_on_shipping_bin_interacted)
	EventBus.shop_requested.connect(_on_shop_requested)
	EventBus.chest_interacted.connect(_on_chest_interacted)
	EventBus.furnace_interacted.connect(_on_furnace_interacted)
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.quest_board_requested.connect(_on_quest_board_requested)
	EventBus.mine_entrance_requested.connect(_on_mine_entrance_requested)
	EventBus.festival_started.connect(_on_festival_started)
	EventBus.festival_ended.connect(_on_festival_ended)

	if FestivalManager.is_festival_active:
		_apply_festival_plaza_state(true)


func _exit_tree() -> void:
	if EventBus.player_interacted.is_connected(_on_player_interacted):
		EventBus.player_interacted.disconnect(_on_player_interacted)
	if EventBus.grid_cell_changed.is_connected(_on_grid_cell_changed):
		EventBus.grid_cell_changed.disconnect(_on_grid_cell_changed)
	if EventBus.sleep_requested.is_connected(_on_sleep_requested):
		EventBus.sleep_requested.disconnect(_on_sleep_requested)
	if EventBus.pass_out_triggered.is_connected(_on_pass_out_triggered):
		EventBus.pass_out_triggered.disconnect(_on_pass_out_triggered)
	if EventBus.shipping_bin_interacted.is_connected(_on_shipping_bin_interacted):
		EventBus.shipping_bin_interacted.disconnect(_on_shipping_bin_interacted)
	if EventBus.shop_requested.is_connected(_on_shop_requested):
		EventBus.shop_requested.disconnect(_on_shop_requested)
	if EventBus.chest_interacted.is_connected(_on_chest_interacted):
		EventBus.chest_interacted.disconnect(_on_chest_interacted)
	if EventBus.furnace_interacted.is_connected(_on_furnace_interacted):
		EventBus.furnace_interacted.disconnect(_on_furnace_interacted)
	if EventBus.dialogue_requested.is_connected(_on_dialogue_requested):
		EventBus.dialogue_requested.disconnect(_on_dialogue_requested)
	if EventBus.quest_board_requested.is_connected(_on_quest_board_requested):
		EventBus.quest_board_requested.disconnect(_on_quest_board_requested)
	if EventBus.mine_entrance_requested.is_connected(_on_mine_entrance_requested):
		EventBus.mine_entrance_requested.disconnect(_on_mine_entrance_requested)
	if EventBus.festival_started.is_connected(_on_festival_started):
		EventBus.festival_started.disconnect(_on_festival_started)
	if EventBus.festival_ended.is_connected(_on_festival_ended):
		EventBus.festival_ended.disconnect(_on_festival_ended)
	EventBus.interact_prompt_changed.emit("")


func _apply_title_showcase_mode() -> void:
	set_process_unhandled_input(false)
	set_hud_visible(false)
	if mobile_controls != null:
		mobile_controls.set_force_hidden(true)
	if player != null:
		player.set_controls_locked(true)
		player.visible = false
		if player.camera != null:
			player.camera.enabled = false


func _prune_destroyed_resources() -> void:
	for child: Node in world_entities.get_children():
		var rn: ResourceNode = child as ResourceNode
		if rn != null and GridStateManager.is_resource_destroyed(scene_id, rn.get_grid_cell()):
			rn.queue_free()


func _setup_ui_and_atmosphere() -> void:
	atmosphere = WorldAtmosphere.new()
	atmosphere.name = "WorldAtmosphere"
	add_child(atmosphere)
	atmosphere.setup(ground_layer, world_entities, farmhouse, player)

	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var inv_scene: PackedScene = load(INVENTORY_MODAL_SCENE_PATH) as PackedScene
	var sleep_scene: PackedScene = load(SLEEP_DIALOG_SCENE_PATH) as PackedScene
	var ship_scene: PackedScene = load(SHIPPING_MODAL_SCENE_PATH) as PackedScene
	var shop_scene: PackedScene = load(SHOP_MODAL_SCENE_PATH) as PackedScene
	var chest_scene: PackedScene = load(CHEST_MODAL_SCENE_PATH) as PackedScene
	var furnace_scene: PackedScene = load(FURNACE_MODAL_SCENE_PATH) as PackedScene
	var dialogue_scene: PackedScene = load(DIALOGUE_MODAL_SCENE_PATH) as PackedScene
	var quest_board_scene: PackedScene = load(QUEST_BOARD_MODAL_SCENE_PATH) as PackedScene
	assert(
		hud_scene != null and inv_scene != null and sleep_scene != null
		and ship_scene != null and shop_scene != null and chest_scene != null and furnace_scene != null
		and dialogue_scene != null and quest_board_scene != null,
		"Missing FarmSanctuary UI scenes."
	)

	hud = hud_scene.instantiate() as GameplayHUD
	add_child(hud)

	inventory_modal = inv_scene.instantiate() as InventoryModal
	add_child(inventory_modal)
	inventory_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	shipping_modal = ship_scene.instantiate() as ShippingModal
	add_child(shipping_modal)
	shipping_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	shop_modal = shop_scene.instantiate() as ShopModal
	add_child(shop_modal)
	shop_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	chest_modal = chest_scene.instantiate() as ChestModal
	add_child(chest_modal)
	chest_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	furnace_modal = furnace_scene.instantiate() as FurnaceModal
	add_child(furnace_modal)
	furnace_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	dialogue_modal = dialogue_scene.instantiate() as DialogueModal
	add_child(dialogue_modal)
	dialogue_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)
	dialogue_modal.festival_action_requested.connect(_on_dialogue_festival_action)

	quest_board_modal = quest_board_scene.instantiate() as QuestBoardModal
	add_child(quest_board_modal)
	quest_board_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	var fest_scene: PackedScene = load(FESTIVAL_SHOWCASE_SCENE_PATH) as PackedScene
	if fest_scene != null:
		festival_showcase_modal = fest_scene.instantiate() as FestivalShowcaseScript
		add_child(festival_showcase_modal)
		festival_showcase_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	var pause_scene: PackedScene = load(PAUSE_MODAL_SCENE_PATH) as PackedScene
	if pause_scene != null:
		pause_modal = pause_scene.instantiate() as PauseModalScript
		add_child(pause_modal)
		pause_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	sleep_dialog = sleep_scene.instantiate() as SleepDialog
	add_child(sleep_dialog)
	sleep_dialog.set_wake_callback(_on_morning_wake_up)
	sleep_dialog.dialog_visibility_changed.connect(_on_ui_modal_state_changed)
	sleep_dialog.sleep_flow_started.connect(_update_ui_pause_state)
	sleep_dialog.sleep_flow_completed.connect(_update_ui_pause_state)

	var mob_scene: PackedScene = load(MOBILE_CONTROLS_SCENE_PATH) as PackedScene
	if mob_scene != null:
		mobile_controls = mob_scene.instantiate() as MobileControlsScript
		add_child(mobile_controls)
		mobile_controls.bind_scene(
			player,
			func() -> void:
				if not _is_any_non_inventory_modal_open() and inventory_modal != null:
					inventory_modal.toggle(),
			func() -> void:
				if not _is_any_modal_open() and pause_modal != null:
					pause_modal.set_open(true)
		)


func _unhandled_input(event: InputEvent) -> void:
	if title_showcase_mode:
		return
	if event.is_action_pressed(&"pause_menu") or event.is_action_pressed(&"ui_cancel"):
		if _is_any_modal_open():
			if pause_modal != null and pause_modal.is_open():
				pause_modal.set_open(false)
				get_viewport().set_input_as_handled()
			return
		if pause_modal != null:
			pause_modal.set_open(true)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_inventory"):
		if _is_any_non_inventory_modal_open():
			return
		if inventory_modal != null:
			inventory_modal.toggle()
			get_viewport().set_input_as_handled()


func _is_any_non_inventory_modal_open() -> bool:
	if sleep_dialog != null and (sleep_dialog.is_dialog_open() or sleep_dialog.is_transitioning()):
		return true
	if shipping_modal != null and shipping_modal.is_open():
		return true
	if shop_modal != null and shop_modal.is_open():
		return true
	if chest_modal != null and chest_modal.is_open():
		return true
	if furnace_modal != null and furnace_modal.is_open():
		return true
	if dialogue_modal != null and dialogue_modal.is_open():
		return true
	if quest_board_modal != null and quest_board_modal.is_open():
		return true
	if festival_showcase_modal != null and festival_showcase_modal.is_open():
		return true
	if pause_modal != null and pause_modal.is_open():
		return true
	return false


func _is_any_modal_open() -> bool:
	return (inventory_modal != null and inventory_modal.is_open()) or _is_any_non_inventory_modal_open()


func set_hud_visible(show_hud: bool) -> void:
	_hud_user_visible = show_hud
	if hud != null:
		hud.visible = _hud_user_visible and not _is_any_modal_open()
	if mobile_controls != null:
		mobile_controls.set_force_hidden(title_showcase_mode or not _hud_user_visible)


func refresh_atmosphere() -> void:
	if atmosphere != null:
		atmosphere.refresh_lighting()


func _on_shipping_bin_interacted() -> void:
	if _is_any_modal_open():
		return
	if shipping_modal != null:
		shipping_modal.set_open(true)


func _on_shop_requested(shop_id: StringName) -> void:
	if _is_any_modal_open():
		return
	if shop_modal != null:
		var target_tab: int = ShopModal.Tab.FORGE if shop_id == &"kaelen_forge" else ShopModal.Tab.SEEDS
		shop_modal.set_open(true, target_tab)


func _on_chest_interacted(p_scene_id: StringName, p_cell: Vector2i) -> void:
	if p_scene_id != scene_id or _is_any_modal_open():
		return
	var chest_node: PlacedChest = _placed_nodes.get(p_cell, null) as PlacedChest
	if chest_modal != null:
		chest_modal.open_chest(p_scene_id, p_cell, chest_node)


func _on_furnace_interacted(p_scene_id: StringName, p_cell: Vector2i) -> void:
	if p_scene_id != scene_id or _is_any_modal_open():
		return
	var f_node: PlacedWorldObject = _placed_nodes.get(p_cell, null) as PlacedWorldObject
	if furnace_modal != null:
		furnace_modal.open_furnace(f_node)


func _on_dialogue_requested(npc_id: StringName) -> void:
	if _is_any_modal_open():
		return
	var actor: NpcActor = find_npc_actor(npc_id)
	interact_with_npc(npc_id, actor)


func _on_quest_board_requested() -> void:
	if _is_any_modal_open():
		return
	if quest_board_modal != null:
		quest_board_modal.set_open(true)


func find_npc_actor(npc_id: StringName) -> NpcActor:
	for npc_node: Node in get_tree().get_nodes_in_group(&"npcs"):
		var actor: NpcActor = npc_node as NpcActor
		if actor != null and actor.npc_id == npc_id:
			return actor
	return null


## Handles Phase 5 direct gifting, quest turn-in prompt, and contextual dialogue for any villager.
func interact_with_npc(npc_id: StringName, actor: NpcActor = null) -> void:
	if dialogue_modal == null or _is_any_modal_open():
		return
	if actor == null:
		actor = find_npc_actor(npc_id)

	var ready_q: QuestData = QuestManager.find_ready_quest_for_npc(npc_id)
	var held_id: StringName = InventoryManager.get_selected_item_id()

	# Priority 1: Ready-to-turn-in quest opens dialogue with prominent Turn In button!
	if ready_q != null:
		if actor != null:
			actor.show_emote(&"chat")
		var invite: String = "Hey! Did you bring the %d %s from the Community Board? Click [Turn In] whenever you're ready!" % [ready_q.required_count, ready_q.required_label]
		dialogue_modal.open_dialogue(npc_id, actor, invite, "QUEST READY!", DialogueModal.TEXT_GOLD, player)
		return

	# Priority 2: Direct Gifting when holding any giftable crop/fish/berry/bar/resource!
	if held_id != &"" and SocialManager.is_giftable_item(held_id):
		if SocialManager.can_gift_today(npc_id):
			var gres: Dictionary = SocialManager.give_gift_from_slot(npc_id, InventoryManager.selected_hotbar_index)
			if bool(gres.get("ok", false)):
				var tier: StringName = gres["tier"] as StringName
				var delta: int = int(gres["delta"])
				var react_line: String = String(gres["reaction_line"])
				var badge_str: String = "GIFT +%d♥" % delta
				var badge_col: Color = DialogueModal.TEXT_CREAM
				match tier:
					&"loved":
						AudioManager.play_sfx(&"coin", -4.0, 0.04)
						AudioManager.play_sfx(&"harvest", -6.0, 0.03)
						badge_str = "LOVED! +%d♥" % delta
						badge_col = DialogueModal.TEXT_GOLD
					&"liked":
						AudioManager.play_sfx(&"harvest", -5.0, 0.04)
						badge_str = "LIKED! +%d♥" % delta
						badge_col = DialogueModal.TEXT_GOLD
					&"disliked":
						AudioManager.play_sfx(&"error", -8.0, 0.03)
						badge_str = "DISLIKED %d" % delta
						badge_col = DialogueModal.TEXT_ROSE
					_:
						AudioManager.play_sfx(&"pickup", -6.0, 0.04)
				if actor != null:
					actor.show_emote(tier)
				dialogue_modal.open_dialogue(npc_id, actor, react_line, badge_str, badge_col, player)
				return
		else:
			EventBus.toast_requested.emit(SocialManager.get_gift_block_reason(npc_id))

	# Priority 3: Bloom Blossom Festival unique dialogue & Mayor Aldric Showcase trigger!
	if FestivalManager.is_festival_active:
		var fest_line: String = FestivalManager.get_festival_dialogue(npc_id)
		var f_pts: int = SocialManager.record_talk(npc_id)
		var f_badge: String = "FESTIVAL! +%d♥" % f_pts if f_pts > 0 else "BLOOM FESTIVAL!"
		dialogue_modal.open_dialogue(npc_id, actor, fest_line, f_badge, DialogueModal.TEXT_GOLD, player)
		if actor != null:
			actor.show_emote(&"happy")
		return

	# Priority 4: Standard contextual conversation (+20 pts first talk/day)
	var talked_before: bool = SocialManager.has_talked_today(npc_id)
	dialogue_modal.open_dialogue(npc_id, actor, "", "", DialogueModal.TEXT_GOLD, player)
	if not talked_before and actor != null:
		actor.show_emote(&"chat")


func _on_dialogue_festival_action(action_id: StringName) -> void:
	if action_id == &"start_festival":
		FestivalManager.start_festival(false)
	elif action_id == &"open_showcase":
		if festival_showcase_modal != null:
			festival_showcase_modal.set_open(true)


func _on_mine_entrance_requested() -> void:
	if _is_any_modal_open() or SceneTransition.is_transitioning():
		return
	var doorstep: Vector2 = _resolve_mine_doorstep_position()
	SceneTransition.enter_interior(MINE_FLOOR_SCENE_PATH, &"mine_floor_1", "res://scenes/world/farm_sanctuary.tscn", doorstep, &"from_quarry", false)


func _resolve_mine_doorstep_position() -> Vector2:
	for wi_node: Node in get_tree().get_nodes_in_group(&"world_interactables"):
		var wi: WorldInteractable = wi_node as WorldInteractable
		if wi != null and wi.interactable_id == &"mine_entrance":
			return wi.global_position + Vector2(0.0, 22.0)
	if world_markers != null:
		var m: Marker2D = world_markers.get_node_or_null("MineEntrance") as Marker2D
		if m != null:
			return m.global_position + Vector2(0.0, 20.0)
	return player.global_position


func _on_festival_started(_festival_id: StringName) -> void:
	_apply_festival_plaza_state(true)


func _on_festival_ended(_festival_id: StringName) -> void:
	_apply_festival_plaza_state(false)


func has_festival_overlay() -> bool:
	return _festival_overlay != null and is_instance_valid(_festival_overlay)


## Non-destructive Bloom Blossom Festival overlay over Bramblebrook Plaza (removed cleanly on end_festival!).
func _apply_festival_plaza_state(active: bool) -> void:
	if _festival_overlay != null and is_instance_valid(_festival_overlay):
		_festival_overlay.queue_free()
		_festival_overlay = null

	for npc_node: Node in get_tree().get_nodes_in_group(&"npcs"):
		var actor: NpcActor = npc_node as NpcActor
		if actor != null:
			actor.set_festival_mode(active)

	if not active:
		return

	var overlay: Node2D = Node2D.new()
	overlay.name = "BloomFestivalOverlay"
	overlay.y_sort_enabled = true
	world_entities.add_child(overlay)
	_festival_overlay = overlay

	var ts_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	var fire_tex: Texture2D = load(AP.FIRE_01_STRIP4) as Texture2D
	var strip_script: Script = load("res://scripts/world/strip_sprite_2d.gd") as Script
	var sun_tex: Texture2D = load(AP.CROPS_ROOT + "/sunflower_05.png") as Texture2D
	var pump_tex: Texture2D = load(AP.CROPS_ROOT + "/pumpkin_05.png") as Texture2D
	var crate_base_tex: Texture2D = load(AP.CRATE_BASE) as Texture2D
	var crate_top_tex: Texture2D = load(AP.CRATE_TOP) as Texture2D

	var light_grad: Gradient = Gradient.new()
	light_grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	light_grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.88, 0.58, 0.45), Color(1.0, 0.72, 0.32, 0.0)])
	light_grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var light_tex: GradientTexture2D = GradientTexture2D.new()
	light_tex.gradient = light_grad
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(0.5, 0.0)
	light_tex.width = 96
	light_tex.height = 96

	# 1. Four warm glowing Festival Lantern Posts framing Bramblebrook Plaza (cols 51..60, rows 26..33)
	var lantern_cells: Array[Vector2i] = [
		Vector2i(51, 27),
		Vector2i(60, 27),
		Vector2i(51, 33),
		Vector2i(60, 33),
	]
	for idx: int in range(lantern_cells.size()):
		var lpos: Vector2 = _cell_center(lantern_cells[idx])
		var post: Sprite2D = Sprite2D.new()
		var pat: AtlasTexture = AtlasTexture.new()
		pat.atlas = ts_tex
		pat.region = Rect2(AP.TILE_FENCE_POST_SINGLE.x * 16, AP.TILE_FENCE_POST_SINGLE.y * 16, 16, 16)
		post.texture = pat
		post.position = lpos + Vector2(0.0, -4.0)
		overlay.add_child(post)

		var fl: Sprite2D = Sprite2D.new()
		fl.script = strip_script
		fl.texture = fire_tex
		fl.hframes = 4
		fl.vframes = 1
		fl.scale = Vector2(0.75, 0.75)
		fl.set("frame_rate", 8.0)
		fl.position = lpos + Vector2(0.0, -12.0)
		fl.z_index = 2
		overlay.add_child(fl)

		var pl: PointLight2D = PointLight2D.new()
		pl.position = lpos + Vector2(0.0, -10.0)
		pl.color = Color(1.0, 0.78, 0.40, 1.0)
		pl.texture = light_tex
		pl.texture_scale = 1.25
		pl.energy = 0.62
		pl.blend_mode = Light2D.BLEND_MODE_ADD
		overlay.add_child(pl)

	# 2. Blooming Flower Garlands lining the plaza square perimeter
	var flower_specs: Array[Array] = [
		[Vector2i(52, 26), AP.TILE_FLOWER_RED_BIG],
		[Vector2i(53, 26), AP.TILE_FLOWER_WHITE_BIG],
		[Vector2i(58, 26), AP.TILE_FLOWER_BLUE_BIG],
		[Vector2i(59, 26), AP.TILE_FLOWER_RED_BIG],
		[Vector2i(52, 33), AP.TILE_FLOWER_BLUE_BIG],
		[Vector2i(54, 33), AP.TILE_FLOWER_RED_BIG],
		[Vector2i(57, 33), AP.TILE_FLOWER_WHITE_BIG],
		[Vector2i(59, 33), AP.TILE_FLOWER_BLUE_BIG],
	]
	for fs: Array in flower_specs:
		var fpos: Vector2 = _cell_center(fs[0] as Vector2i)
		var fcoords: Vector2i = fs[1] as Vector2i
		var fspr: Sprite2D = Sprite2D.new()
		var fat: AtlasTexture = AtlasTexture.new()
		fat.atlas = ts_tex
		fat.region = Rect2(fcoords.x * 16, fcoords.y * 16, 16, 16)
		fspr.texture = fat
		fspr.position = fpos
		fspr.z_index = -1
		overlay.add_child(fspr)

	# 3. Festive Harvest Showcase Judging Table at north-center Plaza (cols 55..56, row 27)
	var table_pos: Vector2 = Vector2(55.5 * TILE_SIZE, 27.2 * TILE_SIZE)
	for dx: float in [-8.0, 8.0]:
		var cb: Sprite2D = Sprite2D.new()
		cb.texture = crate_base_tex
		cb.position = table_pos + Vector2(dx, 2.0)
		overlay.add_child(cb)
		var ct: Sprite2D = Sprite2D.new()
		ct.texture = crate_top_tex
		ct.position = table_pos + Vector2(dx, -2.0)
		overlay.add_child(ct)

	var disp_sun: Sprite2D = Sprite2D.new()
	disp_sun.texture = sun_tex
	disp_sun.position = table_pos + Vector2(-8.0, -7.0)
	disp_sun.z_index = 2
	overlay.add_child(disp_sun)

	var disp_pump: Sprite2D = Sprite2D.new()
	disp_pump.texture = pump_tex
	disp_pump.position = table_pos + Vector2(8.0, -6.0)
	disp_pump.z_index = 2
	overlay.add_child(disp_pump)

	var disp_gem: Sprite2D = Sprite2D.new()
	var gem_at: AtlasTexture = AtlasTexture.new()
	gem_at.atlas = ts_tex
	gem_at.region = Rect2(AP.TILE_CAVE_CRYSTAL.x * 16, AP.TILE_CAVE_CRYSTAL.y * 16, 16, 16)
	disp_gem.texture = gem_at
	disp_gem.position = table_pos + Vector2(0.0, -9.0)
	disp_gem.z_index = 2
	overlay.add_child(disp_gem)


func _on_sleep_requested() -> void:
	if _is_any_modal_open():
		return
	if sleep_dialog != null:
		sleep_dialog.open_dialog()


func _on_pass_out_triggered() -> void:
	_close_all_modals()
	if sleep_dialog != null and not sleep_dialog.is_transitioning():
		sleep_dialog.begin_sleep_transition(_on_pass_out_wake_up)


func _close_all_modals() -> void:
	if inventory_modal != null and inventory_modal.is_open():
		inventory_modal.set_open(false)
	if shipping_modal != null and shipping_modal.is_open():
		shipping_modal.set_open(false)
	if shop_modal != null and shop_modal.is_open():
		shop_modal.set_open(false)
	if chest_modal != null and chest_modal.is_open():
		chest_modal.close_chest()
	if furnace_modal != null and furnace_modal.is_open():
		furnace_modal.close_furnace()
	if dialogue_modal != null and dialogue_modal.is_open():
		dialogue_modal.set_open(false)
	if quest_board_modal != null and quest_board_modal.is_open():
		quest_board_modal.set_open(false)
	if festival_showcase_modal != null and festival_showcase_modal.is_open():
		festival_showcase_modal.set_open(false)
	if pause_modal != null and pause_modal.is_open():
		pause_modal.set_open(false)


func _on_pass_out_wake_up() -> void:
	SceneTransition.transition_to_scene(INTERIOR_SCENE_PATH, &"bed_wake", true)


func _on_morning_wake_up() -> void:
	if player != null and farmhouse != null:
		player.global_position = farmhouse.get_door_spawn_world_position()
		player.set_facing_cardinal(Vector2i(0, 1))
	refresh_atmosphere()


func _on_ui_modal_state_changed(_open_state: bool) -> void:
	_update_ui_pause_state()


func _update_ui_pause_state() -> void:
	var modal_blocking: bool = _is_any_modal_open()
	TimeManager.set_paused(modal_blocking)
	if player != null:
		player.set_controls_locked(modal_blocking)
	if hud != null:
		hud.visible = not modal_blocking and _hud_user_visible
	if mobile_controls != null:
		mobile_controls.set_modal_hidden(modal_blocking)


func _sync_initial_grid_state() -> void:
	var existing_cells: Dictionary = GridStateManager.get_scene_cells(scene_id)
	if existing_cells.is_empty():
		# First boot: import pre-compiled starter 03_SoilOverlay tiles into GridStateManager
		for cell: Vector2i in soil_layer.get_used_cells():
			var src_id: int = soil_layer.get_cell_source_id(cell)
			if src_id == AP.SOURCE_SOIL_DRY:
				GridStateManager.till_cell(scene_id, cell)
			elif src_id == AP.SOURCE_SOIL_WATERED:
				GridStateManager.till_cell(scene_id, cell)
				GridStateManager.water_cell(scene_id, cell)
	else:
		# Returning from house or loading save: rebuild soil, crops & placed objects from GridStateManager!
		soil_layer.clear()
		for cell_key: Variant in existing_cells.keys():
			_refresh_cell_visual(cell_key as Vector2i, false)


func _on_grid_cell_changed(changed_scene: StringName, cell: Vector2i) -> void:
	if changed_scene != scene_id:
		return
	_refresh_cell_visual(cell, true)


func _refresh_cell_visual(cell: Vector2i, play_pop: bool) -> void:
	var st: GridCellState = GridStateManager.get_cell(scene_id, cell)
	if st == null or not st.is_tilled:
		soil_layer.erase_cell(cell)
	else:
		var src_id: int = AP.SOURCE_SOIL_WATERED if st.is_watered else AP.SOURCE_SOIL_DRY
		soil_layer.set_cell(cell, src_id, Vector2i(0, 0))

	# 1. Sync CropNode visual
	if st == null or st.crop_id == &"":
		if _crop_nodes.has(cell):
			var old_node: CropNode = _crop_nodes[cell] as CropNode
			_crop_nodes.erase(cell)
			if is_instance_valid(old_node):
				old_node.queue_free()
	else:
		var crop_data: CropData = InventoryManager.get_crop(st.crop_id)
		assert(crop_data != null, "Unknown crop_id in GridStateManager: %s" % String(st.crop_id))
		var stage: int = crop_data.get_stage_for_days(st.days_grown)
		var crop_node: CropNode = _crop_nodes.get(cell, null) as CropNode
		if crop_node == null or not is_instance_valid(crop_node):
			crop_node = _crop_node_scene.instantiate() as CropNode
			crop_node.name = "Crop_%d_%d" % [cell.x, cell.y]
			crop_node.position = _cell_center(cell)
			world_entities.add_child(crop_node)
			_crop_nodes[cell] = crop_node
		crop_node.configure(crop_data, stage, st.is_withered, play_pop)

	# 2. Sync Persistent Placed Object visual (PlacedChest or PlacedWorldObject)
	var obj_id: StringName = st.placed_object_id if st != null else &""
	if obj_id == &"":
		if _placed_nodes.has(cell):
			var old_obj: Node2D = _placed_nodes[cell] as Node2D
			_placed_nodes.erase(cell)
			if is_instance_valid(old_obj):
				old_obj.queue_free()
	else:
		if not _placed_nodes.has(cell) or not is_instance_valid(_placed_nodes[cell] as Node2D):
			var spawned: Node2D = null
			if obj_id == &"chest":
				var chest: PlacedChest = _placed_chest_scene.instantiate() as PlacedChest
				chest.name = "PlacedChest_%d_%d" % [cell.x, cell.y]
				chest.position = _cell_center(cell) + Vector2(0.0, 2.0)
				world_entities.add_child(chest)
				chest.bind_cell(scene_id, cell)
				spawned = chest
			else:
				var pobj: PlacedWorldObject = PlacedWorldObject.new()
				pobj.name = "Placed_%s_%d_%d" % [String(obj_id), cell.x, cell.y]
				pobj.position = _cell_center(cell) + (Vector2.ZERO if obj_id == &"stone_path" else Vector2(0.0, 2.0))
				world_entities.add_child(pobj)
				pobj.configure(scene_id, cell, obj_id)
				spawned = pobj
			_placed_nodes[cell] = spawned


func get_placed_object_node(cell: Vector2i) -> Node2D:
	return _placed_nodes.get(cell, null) as Node2D


## Strict side-effect-free pre-validation invoked by Player BEFORE animation, particles, or stamina drain.
func _validate_player_action(item: ItemData, target_cell: Vector2i) -> ActionValidator.ActionResult:
	var ctx: ActionValidator.ValidationContext = ActionValidator.ValidationContext.new()
	ctx.is_indoors = false
	ctx.target_cell = target_cell
	ctx.is_real_water = is_water_cell(target_cell)
	ctx.cell_state = GridStateManager.get_cell(scene_id, target_cell)
	ctx.is_crop_mature = GridStateManager.is_crop_mature(scene_id, target_cell)
	ctx.resource_node = find_resource_node_at(target_cell)
	ctx.berry_bush = find_berry_bush_at(target_cell)
	ctx.slot_charges = InventoryManager.get_selected_slot_charges()
	if item is ToolData and (item as ToolData).tool_kind == ToolData.ToolKind.HOE:
		ctx.is_tillable = is_cell_tillable(target_cell)
	elif item != null and item.is_placeable():
		var block_reason: String = get_placement_block_reason(target_cell)
		ctx.can_place_object = block_reason.is_empty()
		ctx.place_block_reason = block_reason
	return ActionValidator.validate_use(item, ctx)


## Executes a pre-validated action on the exact mid-swing strike frame.
func _execute_player_action(action: ActionValidator.ActionResult) -> void:
	var target_cell: Vector2i = action.target_cell
	match action.kind:
		ActionValidator.ActionKind.HARVEST_CROP:
			_try_harvest_crop_at(target_cell)

		ActionValidator.ActionKind.HARVEST_BERRY:
			if action.target_bush != null and is_instance_valid(action.target_bush):
				action.target_bush.harvest_berries(drop_pool, player, scene_id)
				_burst_fx(action.target_bush.global_position, load(AP.ICON_PLANT) as Texture2D)

		ActionValidator.ActionKind.TILL:
			var hoe: ToolData = action.item as ToolData
			if hoe != null:
				VitalitySystem.consume(hoe.vitality_cost)
			if GridStateManager.till_cell(scene_id, target_cell):
				if deco_layer.get_cell_source_id(target_cell) != -1:
					deco_layer.erase_cell(target_cell)
				_burst_fx(_cell_center(target_cell), _soil_chip_tex)
			EventBus.player_tool_used.emit(&"tool_hoe", target_cell)

		ActionValidator.ActionKind.REFILL_WATER:
			InventoryManager.refill_watering_can()
			_burst_fx(_cell_center(target_cell), _water_chip_tex)
			EventBus.player_tool_used.emit(&"tool_watering_can", target_cell)

		ActionValidator.ActionKind.WATER_SOIL:
			var can: ToolData = action.item as ToolData
			if can != null:
				VitalitySystem.consume(can.vitality_cost)
			if InventoryManager.consume_watering_can_charge():
				GridStateManager.water_cell(scene_id, target_cell)
				_burst_fx(_cell_center(target_cell), _water_chip_tex)
			EventBus.player_tool_used.emit(&"tool_watering_can", target_cell)

		ActionValidator.ActionKind.PLANT_SEED:
			if action.item != null and GridStateManager.plant_crop(scene_id, target_cell, action.item.crop_id):
				InventoryManager.remove_from_slot(InventoryManager.selected_hotbar_index, 1)
				_burst_fx(_cell_center(target_cell), _soil_chip_tex)
				EventBus.player_seed_used.emit(action.item.id, target_cell)

		ActionValidator.ActionKind.PLACE_OBJECT:
			if action.item != null and action.item.is_placeable():
				if GridStateManager.place_object(scene_id, target_cell, action.item.placeable_object_id):
					InventoryManager.remove_from_slot(InventoryManager.selected_hotbar_index, 1)
					if deco_layer.get_cell_source_id(target_cell) != -1:
						deco_layer.erase_cell(target_cell)
					_burst_fx(_cell_center(target_cell), _soil_chip_tex)

		ActionValidator.ActionKind.HIT_RESOURCE:
			var tool: ToolData = action.item as ToolData
			if tool != null:
				VitalitySystem.consume(tool.vitality_cost)
				if action.target_resource != null and is_instance_valid(action.target_resource):
					action.target_resource.apply_tool_hit(tool, drop_pool, player)
				EventBus.player_tool_used.emit(tool.id, target_cell)

		ActionValidator.ActionKind.CLEAR_WITHERED:
			var scythe: ToolData = action.item as ToolData
			if scythe != null:
				VitalitySystem.consume(scythe.vitality_cost)
			GridStateManager.clear_crop(scene_id, target_cell)
			_burst_fx(_cell_center(target_cell), _soil_chip_tex)
			EventBus.player_tool_used.emit(&"tool_scythe", target_cell)

		ActionValidator.ActionKind.CAST_FISHING:
			var rod: ToolData = action.item as ToolData
			if rod != null:
				VitalitySystem.consume(rod.vitality_cost)
			_burst_fx(_cell_center(target_cell), _water_chip_tex)
			EventBus.player_tool_used.emit(&"tool_fishing_rod", target_cell)

		ActionValidator.ActionKind.EAT_ITEM:
			if action.item != null and InventoryManager.remove_from_slot(InventoryManager.selected_hotbar_index, 1):
				VitalitySystem.restore(action.item.vitality_restore)


func _on_player_interacted(target_cell: Vector2i) -> void:
	if _is_any_modal_open() or player.is_fishing():
		return

	# Priority 1: Smart Harvest mature Stage-5 crop at target cell or under player's feet
	if _try_harvest_crop_at(target_cell):
		AudioManager.play_sfx(&"harvest", -6.0, 0.04)
		player.trigger_tool_animation(Player.AnimState.DOING)
		return
	var player_cell: Vector2i = player.get_grid_cell()
	if player_cell != target_cell and _try_harvest_crop_at(player_cell):
		AudioManager.play_sfx(&"harvest", -6.0, 0.04)
		player.trigger_tool_animation(Player.AnimState.DOING)
		return

	# Priority 2: Smart Harvest ripe Berry Bush at target cell
	var bush: BerryBush = find_berry_bush_at(target_cell)
	if bush != null and bush.is_ripe():
		if bush.harvest_berries(drop_pool, player, scene_id):
			AudioManager.play_sfx(&"harvest", -6.0, 0.04)
			_burst_fx(bush.global_position, load(AP.ICON_PLANT) as Texture2D)
			player.trigger_tool_animation(Player.AnimState.DOING)
			return

	# Priority 3: Farmhouse DoorPortal transition into dedicated farmhouse_interior.tscn
	if farmhouse != null and farmhouse.is_player_at_door():
		farmhouse.enter_farmhouse()
		return

	# Priority 3b: Any NPC House DoorPortal transition into themed npc_interior.tscn!
	for house_node: Node in get_tree().get_nodes_in_group(&"npc_houses"):
		var nh: NpcHouse = house_node as NpcHouse
		if nh != null and nh.is_player_at_door():
			nh.enter_house()
			return

	# Priority 4: Maren's Seed Shop Market Stall
	# (If player holds a giftable item or has a ready quest for Maren while she's behind the counter, gift/turn-in cleanly!)
	if market_stall != null and market_stall.is_player_nearby():
		var maren_actor: NpcActor = find_npc_actor(&"maren")
		var held_at_stall: StringName = InventoryManager.get_selected_item_id()
		var maren_at_post: bool = (maren_actor != null and maren_actor.get_current_slot() == NpcActor.ScheduleSlot.WORK_POST and not maren_actor.is_walking())
		if maren_at_post and (QuestManager.find_ready_quest_for_npc(&"maren") != null or (held_at_stall != &"" and SocialManager.is_giftable_item(held_at_stall) and SocialManager.can_gift_today(&"maren"))):
			interact_with_npc(&"maren", maren_actor)
			return
		market_stall.trigger_interact()
		return

	# Priority 4b: WorldInteractables (Kaelen's Forge Apron, Community Board, Mine Entrance)
	for wi_node: Node in get_tree().get_nodes_in_group(&"world_interactables"):
		var wi: WorldInteractable = wi_node as WorldInteractable
		if wi != null and wi.is_player_nearby():
			wi.trigger_interact()
			return

	# Priority 4c: Villager NPCs ([E] Talk, Direct Gift, or Turn In Quest)
	for npc_node: Node in get_tree().get_nodes_in_group(&"npcs"):
		var npc: NpcActor = npc_node as NpcActor
		if npc != null and npc.is_player_nearby():
			interact_with_npc(npc.npc_id, npc)
			return

	# Priority 5: Placed Storage Chest (target cell or nearby InteractArea)
	var target_chest: PlacedChest = _placed_nodes.get(target_cell, null) as PlacedChest
	if target_chest != null and is_instance_valid(target_chest):
		target_chest.trigger_interact()
		return
	for ch_node: Node in get_tree().get_nodes_in_group(&"placed_chests"):
		var pc: PlacedChest = ch_node as PlacedChest
		if pc != null and pc.is_player_nearby():
			pc.trigger_interact()
			return

	# Priority 6: Placed Furnace or Scarecrow (target cell or nearby InteractArea)
	var target_pobj: PlacedWorldObject = _placed_nodes.get(target_cell, null) as PlacedWorldObject
	if target_pobj != null and is_instance_valid(target_pobj) and (target_pobj.object_id == &"furnace" or target_pobj.object_id == &"scarecrow"):
		target_pobj.trigger_interact()
		return
	for po_node: Node in get_tree().get_nodes_in_group(&"placed_objects"):
		var po: PlacedWorldObject = po_node as PlacedWorldObject
		if po != null and po.is_player_nearby():
			po.trigger_interact()
			return

	# Priority 7: Sanctuary Shipping Chest
	if shipping_bin != null and shipping_bin.is_player_nearby():
		shipping_bin.trigger_interact()
		return

	# Priority 8: Holding seeds or placeable + pressing [E] / Right-Click acts cleanly!
	var held: ItemData = InventoryManager.get_selected_item_data()
	if held != null and (held.category == ItemData.Category.SEED or held.is_placeable()):
		player.use_selected_item(true, false)


func _try_harvest_crop_at(cell: Vector2i) -> bool:
	if not GridStateManager.is_crop_mature(scene_id, cell):
		return false
	var harvested: Dictionary = GridStateManager.harvest_cell(scene_id, cell)
	if harvested.is_empty():
		return false
	var produce_id: StringName = harvested["item_id"] as StringName
	var count: int = int(harvested["count"])
	drop_pool.spawn_scatter_drops(_cell_center(cell), produce_id, count, player)
	return true


## Returns true ONLY for real open 00_Water ocean/river/pond/waterfall tiles (NEVER bridge or pier decks!).
func is_water_cell(cell: Vector2i) -> bool:
	var src_id: int = water_layer.get_cell_source_id(cell)
	if src_id == -1:
		return false
	return water_layer.get_cell_alternative_tile(cell) == 0


## Classifies any fishable 00_Water cell into &"highland_spring", &"ocean", or &"river".
func get_water_biome(cell: Vector2i) -> StringName:
	if cell.y <= 15 and cell.x >= 40 and cell.x <= 55:
		return &"highland_spring"
	if water_layer.get_cell_source_id(cell) == AP.SOURCE_MAIN_16PX:
		var atlas: Vector2i = water_layer.get_cell_atlas_coords(cell)
		var is_ocean_tile: bool = (atlas.x >= 11 and atlas.x <= 14 and atlas.y >= 18 and atlas.y <= 21)
		if is_ocean_tile or cell.x >= 72:
			return &"ocean"
	return &"river"


func roll_fish_for_biome(biome_id: StringName) -> StringName:
	var roll: float = _fish_loot_rng.randf()
	match biome_id:
		&"ocean":
			if roll < 0.45:
				return &"fish_sea_bass"
			elif roll < 0.85:
				return &"fish_ocean_snapper"
			return &"fish_coral_flounder"
		&"highland_spring":
			if roll < 0.55:
				return &"fish_mountain_minnow"
			return &"fish_spring_koi"
		_:
			if roll < 0.50:
				return &"fish_river_trout"
			elif roll < 0.88:
				return &"fish_sun_perch"
			return &"fish_golden_carp"


func _on_player_fish_caught(target_cell: Vector2i) -> StringName:
	var biome: StringName = get_water_biome(target_cell)
	var fish_id: StringName = roll_fish_for_biome(biome)
	if InventoryManager.get_item(fish_id) == null:
		fish_id = &"fish"
	var item_data: ItemData = InventoryManager.get_item(fish_id)
	var leftover: int = InventoryManager.add_item(fish_id, 1)
	AudioManager.play_sfx(&"harvest", -4.0, 0.03)
	EventBus.fish_caught.emit(fish_id, biome)
	if leftover == 0:
		var nm: String = item_data.display_name if item_data != null else "Fish"
		EventBus.toast_requested.emit("Caught %s!" % nm)
	else:
		EventBus.toast_requested.emit("Backpack full!")
	return fish_id


func get_world_marker_position(marker_name: String) -> Vector2:
	if world_markers != null:
		var m: Marker2D = world_markers.get_node_or_null(marker_name) as Marker2D
		if m != null:
			return m.global_position
	return Vector2.ZERO


func get_npc_house(building_id: StringName) -> NpcHouse:
	for house_node: Node in get_tree().get_nodes_in_group(&"npc_houses"):
		var nh: NpcHouse = house_node as NpcHouse
		if nh != null and nh.building_id == building_id:
			return nh
	return null


func _is_cliff_ground_cell(cell: Vector2i) -> bool:
	var g_td: TileData = ground_layer.get_cell_tile_data(cell)
	if g_td != null and g_td.terrain_set == AP.TERRAIN_SET_CLIFF:
		return true
	if ground_layer.get_cell_source_id(cell) == AP.SOURCE_MAIN_16PX:
		var atlas: Vector2i = ground_layer.get_cell_atlas_coords(cell)
		if atlas in [
			AP.TILE_CLIFF_LIP_M, AP.TILE_CLIFF_LIP_L, AP.TILE_CLIFF_LIP_R,
			AP.TILE_CLIFF_FACE_TL, AP.TILE_CLIFF_FACE_TM, AP.TILE_CLIFF_FACE_TR,
			AP.TILE_CLIFF_FACE_ML, AP.TILE_CLIFF_FACE_MM, AP.TILE_CLIFF_FACE_MR,
			AP.TILE_CLIFF_BASE_L, AP.TILE_CLIFF_BASE_R,
			Vector2i(10, 5), Vector2i(12, 5), AP.TILE_CLIFF_WATERFALL_SIDE,
			AP.TILE_CAVE_ARCH_L, AP.TILE_CAVE_ARCH_R,
		]:
			return true
	return false


func _is_beach_sand_cell(cell: Vector2i) -> bool:
	if beach_layer != null and beach_layer.get_cell_source_id(cell) != -1:
		return true
	if ground_layer.get_cell_source_id(cell) == AP.SOURCE_MAIN_16PX:
		var atlas: Vector2i = ground_layer.get_cell_atlas_coords(cell)
		if atlas in [AP.TILE_SAND_SOLID, AP.TILE_SAND_ALT_A, AP.TILE_SAND_ALT_B, AP.TILE_SAND_ALT_C]:
			return true
	return false


func _is_inside_any_building_footprint(world_pt: Vector2) -> bool:
	var fh_rect: Rect2 = Rect2(farmhouse.global_position + Vector2(-12.0, -96.0), Vector2(124.0, 100.0))
	if fh_rect.has_point(world_pt):
		return true
	for house_node: Node in get_tree().get_nodes_in_group(&"npc_houses"):
		var nh: NpcHouse = house_node as NpcHouse
		if nh != null and nh.get_world_footprint_rect().has_point(world_pt):
			return true
	return false


## Returns empty string if cell is valid for placing a crafted object, or a clear toast reason why blocked.
func get_placement_block_reason(cell: Vector2i) -> String:
	var world_pt: Vector2 = _cell_center(cell)
	if not world_bounds_px.has_point(Vector2i(int(world_pt.x), int(world_pt.y))):
		return "Out of bounds"
	if water_layer.get_cell_source_id(cell) != -1 or is_water_cell(cell):
		return "Can't place on water"
	if waterfall_layer != null and waterfall_layer.get_cell_source_id(cell) != -1:
		return "Can't place on water"
	if ladder_layer != null and ladder_layer.get_cell_source_id(cell) != -1:
		return "Can't place on ladders"
	if _is_cliff_ground_cell(cell):
		return "Can't place on cliffs"
	if _is_beach_sand_cell(cell):
		return "Can't place on beach sand"
	if quarry_layer != null and quarry_layer.get_cell_source_id(cell) != -1:
		return "Can't place on quarry stone"
	var in_garden_bed: bool = garden_bed_layer != null and garden_bed_layer.get_cell_source_id(cell) != -1
	var p_td: TileData = paths_layer.get_cell_tile_data(cell)
	if not in_garden_bed and p_td != null and p_td.terrain_set == AP.TERRAIN_SET_PATHS:
		return "Can't place on roads"
	if _is_inside_any_building_footprint(world_pt):
		return "Tile is occupied"
	var st: GridCellState = GridStateManager.get_cell(scene_id, cell)
	if st != null:
		if st.placed_object_id != &"":
			return "Tile is occupied"
		if st.is_tilled or st.crop_id != &"":
			return "Can't place on tilled soil or crops"
	if find_resource_node_at(cell) != null or find_berry_bush_at(cell) != null:
		return "Tile is occupied"
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = world_pt
	query.collision_mask = 3
	if space.intersect_point(query, 4).size() > 0:
		return "Tile is occupied"
	return ""


func is_cell_tillable(cell: Vector2i) -> bool:
	var world_pt: Vector2 = _cell_center(cell)
	if not world_bounds_px.has_point(Vector2i(int(world_pt.x), int(world_pt.y))):
		return false
	if water_layer.get_cell_source_id(cell) != -1 or is_water_cell(cell):
		return false
	if waterfall_layer != null and waterfall_layer.get_cell_source_id(cell) != -1:
		return false
	if ladder_layer != null and ladder_layer.get_cell_source_id(cell) != -1:
		return false
	if GridStateManager.get_placed_object_id(scene_id, cell) != &"":
		return false
	if _is_cliff_ground_cell(cell):
		return false
	if _is_beach_sand_cell(cell):
		return false
	if quarry_layer != null and quarry_layer.get_cell_source_id(cell) != -1:
		return false

	var in_garden_bed: bool = garden_bed_layer != null and garden_bed_layer.get_cell_source_id(cell) != -1
	var p_td: TileData = paths_layer.get_cell_tile_data(cell)
	if not in_garden_bed and p_td != null and p_td.terrain_set == AP.TERRAIN_SET_PATHS:
		return false

	if _is_inside_any_building_footprint(world_pt):
		return false
	if find_resource_node_at(cell) != null:
		return false
	if find_berry_bush_at(cell) != null:
		return false

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = world_pt
	query.collision_mask = 3
	var hits: Array[Dictionary] = space.intersect_point(query, 4)
	if hits.size() > 0:
		return false

	return true


func find_resource_node_at(cell: Vector2i) -> ResourceNode:
	var target_center: Vector2 = _cell_center(cell)
	var best: ResourceNode = null
	var best_dist_sq: float = RESOURCE_HIT_RADIUS_SQ
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"resource_nodes")
	for n: Node in nodes:
		var rn: ResourceNode = n as ResourceNode
		if rn == null or rn.is_destroyed():
			continue
		if rn.get_grid_cell() == cell:
			return rn
		var d_sq: float = rn.global_position.distance_squared_to(target_center)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = rn
	return best


func find_berry_bush_at(cell: Vector2i) -> BerryBush:
	var target_center: Vector2 = _cell_center(cell)
	var best: BerryBush = null
	var best_dist_sq: float = BERRY_HIT_RADIUS_SQ
	var bushes: Array[Node] = get_tree().get_nodes_in_group(&"berry_bushes")
	for n: Node in bushes:
		var bb: BerryBush = n as BerryBush
		if bb == null:
			continue
		if bb.get_grid_cell() == cell:
			return bb
		var d_sq: float = bb.global_position.distance_squared_to(target_center)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = bb
	return best


func get_crop_node(cell: Vector2i) -> CropNode:
	return _crop_nodes.get(cell, null) as CropNode


func _burst_fx(world_pos: Vector2, tex: Texture2D) -> void:
	if _fx_particles == null or tex == null:
		return
	_fx_particles.global_position = world_pos
	_fx_particles.texture = tex
	_fx_particles.restart()
	_fx_particles.emitting = true


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * TILE_SIZE + 8.0, float(cell.y) * TILE_SIZE + 8.0)
