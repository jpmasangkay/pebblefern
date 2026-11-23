extends Node2D

## Automated World Expansion verification suite & 1280x720 5-shot gallery capture.
## Verifies the 96x60 5-district island, all 6 verbatim Room1.yy buildings, all 5 animated NPCs,
## Phase 5-6 Marker2D waypoints, walkable wooden cliff ladders, ocean pier fishing, strict terrain
## rules for Hoe/Placeables, Kaelen's direct Forge tab, indoor tool blocking inside NPC interiors,
## and exact doorstep return + GridStateManager persistence across Farmhouse, Maren, and Kaelen!

const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const FARMHOUSE_INTERIOR_PATH: String = "res://scenes/world/farmhouse_interior.tscn"
const NPC_INTERIOR_PATH: String = "res://scenes/world/npc_interior.tscn"

const SHOT_OVERVIEW: String = "res://Screenshots/world_full_overview.png"
const SHOT_FARM: String = "res://Screenshots/world_farm_plateau.png"
const SHOT_VILLAGE: String = "res://Screenshots/world_village_npcs.png"
const SHOT_BEACH_HIGHLANDS: String = "res://Screenshots/world_beach_highlands.png"
const SHOT_WATER_CLIFF: String = "res://Screenshots/water_cliff_check.png"
const SHOT_NPC_INTERIOR: String = "res://Screenshots/world_npc_interior.png"
const SHOT_BRIDGE_FIXED: String = "res://Screenshots/bridge_fixed_check.png"
const SHOT_VILLAGE_CLEAN: String = "res://Screenshots/village_paths_clean.png"
const SHOT_BRIDGE_PILINGS: String = "res://Screenshots/bridge_pilings_fixed.png"
const SHOT_LADDERS_PIER: String = "res://Screenshots/ladders_pier_fixed.png"

var _farm: FarmSanctuary = null
var _npc_interior: NpcInterior = null
var _cam: Camera2D = null
var _step: int = 0
var _wait_frames: int = 0
var _last_toast: String = ""
var _last_dialogue_npc: StringName = &""


func _ready() -> void:
	GridStateManager.clear_all()
	InventoryManager.reset_to_starter_loadout()
	EconomyManager.reset_economy()
	VitalitySystem.restore_full()
	TimeManager.reset_to_day_one()
	TimeManager.set_paused(true)
	TimeManager.set_time(12, 0)

	EventBus.toast_requested.connect(func(msg: String) -> void: _last_toast = msg)
	EventBus.dialogue_requested.connect(func(nid: StringName) -> void: _last_dialogue_npc = nid)

	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(farm_packed != null, "Missing farm_sanctuary.tscn")
	_farm = farm_packed.instantiate() as FarmSanctuary
	add_child(_farm)
	_farm.refresh_atmosphere()

	_cam = Camera2D.new()
	_cam.name = "GalleryCamera"
	_cam.enabled = false
	add_child(_cam)


func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0))


func _physics_process(_delta: float) -> void:
	_wait_frames += 1
	match _step:
		0:
			if _wait_frames >= 6:
				_verify_world_structure_and_markers()
				_verify_terrain_and_fishing_rules()
				_verify_npcs_and_interactables()
				_verify_ladder_walkability()
				_verify_door_roundtrips_and_npc_interiors()

				# Stage crisp midday showcase crops in Farm Garden for the visual gallery!
				_stage_gallery_crops()
				_farm.set_hud_visible(false)
				TimeManager.set_time(12, 0)
				_farm.refresh_atmosphere()
				_farm.player.camera.enabled = false
				_cam.enabled = true
				_cam.make_current()

				# Shot 1: Full 96x60 Island Overview (fills 1280x720 edge-to-edge with sparkling ocean!)
				_cam.position = Vector2(768.0, 480.0)
				_cam.zoom = Vector2(0.209, 0.209)
				_step = 1
				_wait_frames = 0
		1:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_OVERVIEW)
				print("[VerifyWorld] Captured %s" % SHOT_OVERVIEW)
				# Shot 2: Solstice Farm Plateau (Blue Farmhouse, Shipping Bin, Fenced Garden, Farm Pond, Bridge)
				_cam.position = Vector2(21.0 * 16.0, 21.5 * 16.0)
				_cam.zoom = Vector2(0.55, 0.55)
				_step = 2
				_wait_frames = 0
		2:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_FARM)
				print("[VerifyWorld] Captured %s" % SHOT_FARM)
				# Shot 3: Bramblebrook Village (Maren's Green Cottage + Shop, Aldric's Purple Hall + Natural Plaza, Kaelen's Orange Forge + Hearth Yard)
				_cam.position = Vector2(51.5 * 16.0, 31.0 * 16.0)
				_cam.zoom = Vector2(0.49, 0.49)
				_step = 3
				_wait_frames = 0
		3:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_VILLAGE)
				print("[VerifyWorld] Captured %s" % SHOT_VILLAGE)
				# Shot 4: Highland Woods, Seamless Pond->Waterfall, Ocean Channel Bridge & Bram's Bridged Pier Islet!
				_cam.position = Vector2(67.0 * 16.0, 20.5 * 16.0)
				_cam.zoom = Vector2(0.35, 0.35)
				_step = 4
				_wait_frames = 0
		4:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_BEACH_HIGHLANDS)
				print("[VerifyWorld] Captured %s" % SHOT_BEACH_HIGHLANDS)
				# Shot 4b: Dedicated Water & Cliff Check (North Highland Waterfall, Beach Channel Bridge Pilings & Flush South Cliffs/Waterfall!)
				_cam.position = Vector2(59.5 * 16.0, 32.0 * 16.0)
				_cam.zoom = Vector2(0.285, 0.285)
				_step = 45
				_wait_frames = 0
		45:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_WATER_CLIFF)
				print("[VerifyWorld] Captured %s" % SHOT_WATER_CLIFF)
				# Shot 4c: Close-up of fixed Farm-to-Village Bridge (zero floating torches, pilings in water, single-span Room1.yy deck, clean road exit!)
				_cam.position = Vector2(35.5 * 16.0, 21.5 * 16.0)
				_cam.zoom = Vector2(0.76, 0.76)
				_step = 46
				_wait_frames = 0
		46:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_BRIDGE_FIXED)
				_save_viewport_png(SHOT_BRIDGE_PILINGS)
				print("[VerifyWorld] Captured %s & %s" % [SHOT_BRIDGE_FIXED, SHOT_BRIDGE_PILINGS])
				# Shot 4d: Bramblebrook Village showing completely clean dirt roads with zero scattered debris & wide walkable clearances!
				_cam.position = Vector2(51.5 * 16.0, 31.0 * 16.0)
				_cam.zoom = Vector2(0.49, 0.49)
				_step = 47
				_wait_frames = 0
		47:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_VILLAGE_CLEAN)
				print("[VerifyWorld] Captured %s" % SHOT_VILLAGE_CLEAN)
				# Shot 4e: Zoomed view of both Highland Cliff Ladders (connected dirt paths, zero brown cliff wall under rungs),
				# Beach Island Bridge (flush pilings), and Bram's Verbatim Room1.yy Ocean Fishing Piers!
				_cam.position = Vector2(70.5 * 16.0, 24.5 * 16.0)
				_cam.zoom = Vector2(0.40, 0.40)
				_step = 48
				_wait_frames = 0
		48:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_LADDERS_PIER)
				print("[VerifyWorld] Captured %s" % SHOT_LADDERS_PIER)
				# Shot 5: Inside Maren's Themed Botanist Cottage (clean straight walls, plants on tables, bookshelves, seed crates, warm rug & HUD!)
				_farm.queue_free()
				_farm = null
				_cam.enabled = false
				SceneTransition.pending_interior_id = &"maren"
				var int_packed: PackedScene = load(NPC_INTERIOR_PATH) as PackedScene
				_npc_interior = int_packed.instantiate() as NpcInterior
				add_child(_npc_interior)
				_npc_interior.player.global_position = Vector2(112.0, 102.0)
				_npc_interior.player.set_facing_cardinal(Vector2i(0, -1))
				_npc_interior.player.camera.make_current()
				TimeManager.set_time(12, 0)
				_step = 5
				_wait_frames = 0
		5:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_NPC_INTERIOR)
				print("[VerifyWorld] Captured %s" % SHOT_NPC_INTERIOR)
				print("[VerifyWorld] ALL WORLD EXPANSION, NPC INTERIOR & OCEAN FISHING CHECKS PASSED!")
				get_tree().quit(0)


func _verify_world_structure_and_markers() -> void:
	# 1. Verify 96x60 (1536x960) world bounds & automatic Camera2D limit clamping
	assert(_farm.world_bounds_px == Rect2i(0, 0, 1536, 960), "Expected 96x60 (1536x960) bounds, got %s" % str(_farm.world_bounds_px))
	assert(_farm.player.camera.limit_right == 1536 and _farm.player.camera.limit_bottom == 960, "Player Camera2D must clamp to full 1536x960 island!")

	# 2. Verify all 6 distinct verbatim buildings exist
	assert(_farm.farmhouse != null, "Missing Blue Farmhouse!")
	var npc_houses: Array[Node] = get_tree().get_nodes_in_group(&"npc_houses")
	assert(npc_houses.size() == 5, "Expected 5 distinct NPC houses, got %d" % npc_houses.size())
	for bid: StringName in [&"maren_cottage", &"kaelen_forge", &"aldric_hall", &"bram_cabin", &"lyra_cabin"]:
		assert(_farm.get_npc_house(bid) != null, "Missing NpcHouse with building_id=%s" % String(bid))

	# 3. Verify all 5 animated 3-layer NPCs exist in group &"npcs"
	var npcs: Array[Node] = get_tree().get_nodes_in_group(&"npcs")
	var found_npcs: Dictionary = {}
	for n: Node in npcs:
		var actor: NpcActor = n as NpcActor
		if actor != null:
			found_npcs[actor.npc_id] = actor
	for nid: StringName in [&"maren", &"kaelen", &"aldric", &"lyra", &"bram"]:
		assert(found_npcs.has(nid), "Missing NpcActor for npc_id=%s" % String(nid))

	# 4. Verify Phase 5-6 Marker2D landmarks & NpcScheduleWaypoints
	for m_name: String in [
		"FarmhouseDoor", "ShippingBin", "MarketStall", "KaelenForge", "GardenOrigin",
		"CommunityBoard", "FestivalPlazaCenter", "MineEntrance", "OceanPierNorth", "OceanPierSouth",
	]:
		assert(_farm.get_world_marker_position(m_name) != Vector2.ZERO, "Missing WorldMarker: %s" % m_name)

	var wp_root: Node = _farm.get_node_or_null("NpcScheduleWaypoints")
	assert(wp_root != null, "Missing NpcScheduleWaypoints container!")
	for npc_folder: String in ["Maren", "Kaelen", "Aldric", "Lyra", "Bram"]:
		for wp: String in ["HomeDoor", "WorkPost", "PlazaSpot"]:
			assert(wp_root.get_node_or_null("%s/%s" % [npc_folder, wp]) is Marker2D, "Missing waypoint %s/%s" % [npc_folder, wp])

	print("[VerifyWorld] PASS: 96x60 bounds, Camera2D limits, all 6 buildings, all 5 NPCs, and all Phase 5-6 waypoints verified.")


func _verify_terrain_and_fishing_rules() -> void:
	var p: Player = _farm.player
	InventoryManager.select_hotbar_slot(5) # Fishing Rod

	# A. Ocean Beach Pier fishing -> MUST SUCCEED facing ocean water!
	var pier_pos: Vector2 = _farm.get_world_marker_position("OceanPierNorth")
	var pier_cell: Vector2i = _world_to_cell(pier_pos)
	p.global_position = pier_pos
	p.set_facing_cardinal(Vector2i(0, -1)) # Facing north off wooden pier into deep blue ocean!
	assert(_farm.is_water_cell(pier_cell + Vector2i(0, -1)), "Ocean tile north of FishingPierNorth must be fishable water!")
	var pier_fish: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(pier_fish.valid and pier_fish.kind == ActionValidator.ActionKind.CAST_FISHING, "Fishing Rod off ocean pier MUST succeed!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)

	# Pier deck itself -> MUST BE REJECTED!
	p.global_position = pier_pos
	p.set_facing_cardinal(Vector2i(-1, 0)) # Facing along pier deck!
	assert(not _farm.is_water_cell(pier_cell + Vector2i(-1, 0)), "Pier deck cell must NOT be fishable water!")
	var pier_deck_fish: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not pier_deck_fish.valid, "Fishing Rod on pier deck MUST be rejected!")

	# Inland beach sand -> MUST BE REJECTED for Fishing AND Hoe AND Placeables!
	var sand_pos: Vector2 = _farm.get_world_marker_position("BeachSandInland")
	var sand_cell: Vector2i = _world_to_cell(sand_pos)
	p.global_position = sand_pos + Vector2(0.0, 16.0)
	p.set_facing_cardinal(Vector2i(0, -1))
	var sand_fish: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not sand_fish.valid, "Fishing Rod on inland beach sand MUST be rejected!")

	InventoryManager.select_hotbar_slot(0) # Hoe
	assert(not _farm.is_cell_tillable(sand_cell), "Hoe MUST be blocked on beach sand!")
	assert(not _farm.get_placement_block_reason(sand_cell).is_empty(), "Placeables MUST be blocked on beach sand!")

	# Ladders, Cliffs, Roads, Quarry Stone, Bridges, Piers -> MUST block Hoe & Placeables!
	var ladder_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("HighlandLadderBottom")) + Vector2i(0, -1)
	var cliff_pos: Vector2 = _farm.get_world_marker_position("CliffCheck")
	var cliff_cell: Vector2i = _world_to_cell(cliff_pos) if cliff_pos != Vector2.ZERO else Vector2i(40, 15)
	var quarry_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("QuarryCenter"))
	var bridge_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("BridgeCrossing"))
	var road_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("FestivalPlazaCenter"))

	assert(not _farm.is_cell_tillable(ladder_cell), "Hoe must be blocked on wooden cliff ladders!")
	assert(not _farm.is_cell_tillable(cliff_cell), "Hoe must be blocked on cliffs!")
	assert(not _farm.is_cell_tillable(quarry_cell), "Hoe must be blocked on quarry stone!")
	assert(not _farm.is_cell_tillable(bridge_cell), "Hoe must be blocked on bridges!")
	assert(not _farm.is_cell_tillable(pier_cell), "Hoe must be blocked on ocean piers!")
	assert(not _farm.is_cell_tillable(road_cell), "Hoe must be blocked on village roads!")

	# Farm garden & open farm meadow -> MUST BE TILLABLE!
	var garden_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("GardenOrigin"))
	var meadow_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("OpenMeadowSpot"))
	assert(_farm.is_cell_tillable(garden_cell), "Farm garden cell MUST be tillable!")
	assert(_farm.is_cell_tillable(meadow_cell), "Open farm meadow MUST be tillable!")

	print("[VerifyWorld] PASS: Ocean pier fishing, inland sand/pier-deck rejection, and strict Hoe/Placeable terrain rules verified.")


func _verify_npcs_and_interactables() -> void:
	# 1. Verify Kaelen's Forge Apron opens ShopModal DIRECTLY on Tab.FORGE!
	var forge_apron: WorldInteractable = _farm.get_node_or_null("WorldEntities/KaelenForgeApron") as WorldInteractable
	assert(forge_apron != null, "Missing KaelenForgeApron!")
	forge_apron.trigger_interact()
	assert(_farm.shop_modal.is_open(), "KaelenForgeApron must open ShopModal!")
	assert(_farm.shop_modal._active_tab == ShopModal.Tab.FORGE, "KaelenForgeApron must open DIRECTLY on ShopModal.Tab.FORGE!")
	_farm.shop_modal.set_open(false)

	# 2. Verify Community Board opens QuestBoardModal (Phase 5) & Pebblefern Mine wires Phase 6 ENTER_MINE!
	var board: WorldInteractable = _farm.get_node_or_null("WorldEntities/CommunityBoard") as WorldInteractable
	var mine: WorldInteractable = _farm.get_node_or_null("WorldEntities/MineEntrance") as WorldInteractable
	assert(board != null and mine != null, "Missing CommunityBoard or MineEntrance!")
	board.trigger_interact()
	assert(_farm.quest_board_modal != null and _farm.quest_board_modal.is_open(), "Community Board must open Phase 5 QuestBoardModal.")
	_farm.quest_board_modal.set_open(false)
	assert(mine.action_kind == WorldInteractable.ActionKind.ENTER_MINE, "Mine Entrance must be wired to ActionKind.ENTER_MINE in Phase 6.")
	assert("Mine" in mine.prompt_text, "Mine Entrance prompt must indicate entering Pebblefern Mine.")

	# 3. Verify NPC Talk greetings, dialogue_requested signal & DialogueModal
	var aldric: NpcActor = _farm.get_node_or_null("WorldEntities/NpcAldric") as NpcActor
	assert(aldric != null, "Missing NpcAldric!")
	_last_dialogue_npc = &""
	aldric.trigger_interact()
	assert(_last_dialogue_npc == &"aldric", "Talking to Aldric must emit dialogue_requested(&'aldric')!")
	assert(_farm.dialogue_modal != null and _farm.dialogue_modal.is_open(), "Talking to Aldric must open DialogueModal!")
	_farm.dialogue_modal.set_open(false)
	print("[VerifyWorld] PASS: Kaelen direct Forge tab, Community Board / Mine hooks, and NPC DialogueModal verified.")


func _tc(x: float, y: float) -> Vector2:
	return Vector2(x * 16.0 + 8.0, y * 16.0 + 8.0)


func _walk_player_route(route_name: String, waypoints: Array[Vector2]) -> void:
	assert(waypoints.size() >= 2, "Walkability route %s requires >= 2 points." % route_name)
	var p: Player = _farm.player
	p.global_position = waypoints[0]
	p.velocity = Vector2.ZERO
	const MAX_TICKS_PER_LEG: int = 240
	const STEP_SPEED: float = 96.0
	for idx: int in range(1, waypoints.size()):
		var goal: Vector2 = waypoints[idx]
		var reached: bool = false
		for _tick: int in range(MAX_TICKS_PER_LEG):
			var diff: Vector2 = goal - p.global_position
			var dist: float = diff.length()
			if dist <= 5.0:
				reached = true
				break
			p.velocity = (diff / dist) * minf(STEP_SPEED, dist * 15.0)
			p.move_and_slide()
		p.velocity = Vector2.ZERO
		assert(
			reached or p.global_position.distance_to(goal) <= 6.0,
			"[WalkSweep] Route '%s' BLOCKED on leg %d -> %s! Stuck at %s (dist=%.1f)" % [
				route_name, idx, str(goal), str(p.global_position), p.global_position.distance_to(goal)
			]
		)
	print("[VerifyWorld] PASS Walkability Route: %s (%d waypoints reached cleanly)." % [route_name, waypoints.size()])


func _verify_ladder_walkability() -> void:
	# 0. Verify zero props/torches on 00_Water & zero scatter debris on 02_Paths (DirtRoad / VillagePlaza)
	for wc: Vector2i in _farm.water_layer.get_used_cells():
		var on_offshore_islet: bool = (wc.x <= 5 and wc.y <= 6) or (wc.x >= 79 and wc.x <= 82 and wc.y >= 7 and wc.y <= 10) or (wc.x >= 87 and wc.y >= 49)
		if not on_offshore_islet and _farm.deco_layer.get_cell_source_id(wc) != -1:
			var d_coords: Vector2i = _farm.deco_layer.get_cell_atlas_coords(wc)
			assert(d_coords == AssetPaths.TILE_WATER_GLINT_ANIM, "Illegal decoration tile %s on 00_Water at %s!" % [str(d_coords), str(wc)])
	for child: Node in _farm.world_entities.get_children():
		if child is Node2D and (child.name.begins_with("WalkwayTorch") or child.name.begins_with("CourtyardTorch")):
			var t_cell: Vector2i = _world_to_cell((child as Node2D).global_position)
			assert(_farm.water_layer.get_cell_source_id(t_cell) == -1, "Floating torch %s on 00_Water at %s!" % [child.name, str(t_cell)])
			assert(_farm.paths_layer.get_cell_source_id(t_cell) == -1, "Torch %s spawned on DirtRoad/VillagePlaza at %s!" % [child.name, str(t_cell)])
	for pc: Vector2i in _farm.paths_layer.get_used_cells():
		assert(_farm.deco_layer.get_cell_source_id(pc) == -1, "Scatter debris tile %s found on DirtRoad/VillagePlaza at %s!" % [str(_farm.deco_layer.get_cell_atlas_coords(pc)), str(pc)])

	var maren_door: Vector2 = _farm.get_npc_house(&"maren_cottage").get_door_spawn_world_position()
	var kaelen_door: Vector2 = _farm.get_npc_house(&"kaelen_forge").get_door_spawn_world_position()
	var aldric_door: Vector2 = _farm.get_npc_house(&"aldric_hall").get_door_spawn_world_position()
	var lyra_door: Vector2 = _farm.get_npc_house(&"lyra_cabin").get_door_spawn_world_position()
	var bram_door: Vector2 = _farm.get_npc_house(&"bram_cabin").get_door_spawn_world_position()
	var pier_north_tip: Vector2 = _farm.get_world_marker_position("OceanPierNorth")
	var pier_south_tip: Vector2 = _farm.get_world_marker_position("OceanPierSouth")

	# Route 1: Farm Plateau -> across Farm Bridge -> into Bramblebrook Plaza -> every NPC doorway (Maren, Aldric, Kaelen)
	_walk_player_route("1_Farm_Bridge_Village_Doors", [
		_farm.farmhouse.get_door_spawn_world_position(),
		_tc(16, 20.5),
		_tc(31, 21),
		_tc(38, 21),
		_tc(39, 25),
		_tc(43, 27.5),
		maren_door,
		_tc(43, 27.5),
		_tc(49, 27.5),
		_tc(55, 28),
		_tc(60, 27.5),
		aldric_door,
		_tc(60, 27.5),
		_tc(55.5, 31),
		_tc(56, 36),
		_tc(56, 41.5),
		_tc(45.5, 41.5),
		kaelen_door,
		_tc(45.5, 41.5),
		_tc(52, 41),
	])

	# Route 2A & 2B: Village -> up BOTH Highland Cliff Ladders -> to Lyra's Cabin
	_walk_player_route("2A_Village_WestHighlandLadder_LyraCabin", [
		_tc(53.5, 27),
		_tc(53.5, 17),
		_tc(53.5, 12),
		_tc(58, 11.5),
		lyra_door,
	])
	_walk_player_route("2B_Village_EastHighlandLadder_LyraCabin", [
		_tc(64.5, 27),
		_tc(64.5, 17),
		_tc(64.5, 12),
		_tc(58, 11.5),
		lyra_door,
	])

	# Route 3: Village -> across Beach Bridge -> to Bram's Cabin and out to the tip of BOTH Ocean Fishing Piers
	_walk_player_route("3_Village_BeachBridge_Bram_BothOceanPiers", [
		_tc(56, 31),
		_tc(66, 31),
		_tc(74, 31),
		_tc(79.5, 31),
		bram_door,
		_tc(79.5, 29),
		_tc(84, 28.5),
		pier_north_tip,
		_tc(82, 29),
		_tc(81, 35),
		_tc(81, 39.5),
		_tc(84, 39.5),
		pier_south_tip,
	])

	# Route 4: Farm Plateau -> down Quarry Cliff Ladder -> across Quarry Bridge back to Village
	_walk_player_route("4_Farm_QuarryLadder_QuarryBridge_Village", [
		_tc(21.5, 21),
		_tc(21.5, 26),
		_tc(21.5, 32),
		_tc(21.5, 38),
		_tc(21.5, 42),
		_tc(31, 42),
		_tc(37, 42),
		_tc(45, 42),
		_tc(56, 41.5),
		_tc(55.5, 31),
	])


func _verify_door_roundtrips_and_npc_interiors() -> void:
	# Plant a persistent test crop on farm meadow before entering interiors!
	var persist_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("OpenMeadowSpot"))
	GridStateManager.set_crop_state(_farm.scene_id, persist_cell, &"sunflower", 3, true)

	# 1. Test Farmhouse interior round-trip
	var fh_doorstep: Vector2 = _farm.farmhouse.get_door_spawn_world_position()
	SceneTransition.active_return_scene = FARM_SCENE_PATH
	SceneTransition.active_return_position = fh_doorstep
	SceneTransition.pending_return_position = fh_doorstep
	SceneTransition.has_pending_return_position = true
	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	var f_ret_fh: FarmSanctuary = farm_packed.instantiate() as FarmSanctuary
	add_child(f_ret_fh)
	assert(f_ret_fh.player.global_position.distance_to(fh_doorstep) < 1.0, "Farmhouse return must spawn at exact farmhouse doorstep!")
	assert(f_ret_fh.get_crop_node(persist_cell) != null, "Farm crops must persist across farmhouse round-trip!")
	f_ret_fh.queue_free()

	# 2. Test Maren's Cottage & Kaelen's Forge interiors: tool blocking + exact per-house doorstep return + persistence!
	var npc_int_packed: PackedScene = load(NPC_INTERIOR_PATH) as PackedScene
	for pair: Array in [
		[&"maren_cottage", &"maren"],
		[&"kaelen_forge", &"kaelen"],
		[&"aldric_hall", &"aldric"],
		[&"bram_cabin", &"bram"],
		[&"lyra_cabin", &"lyra"],
	]:
		var b_id: StringName = pair[0] as StringName
		var theme_id: StringName = pair[1] as StringName
		var house: NpcHouse = _farm.get_npc_house(b_id)
		assert(house != null, "Missing house %s" % String(b_id))
		var expected_doorstep: Vector2 = house.get_door_spawn_world_position()

		# Enter themed NPC interior
		SceneTransition.pending_interior_id = theme_id
		SceneTransition.active_return_scene = FARM_SCENE_PATH
		SceneTransition.active_return_position = expected_doorstep
		var interior: NpcInterior = npc_int_packed.instantiate() as NpcInterior
		add_child(interior)
		assert(interior.active_theme_id == theme_id, "NpcInterior must load theme %s" % String(theme_id))

		# Verify ALL 6 tools are strictly blocked indoors!
		for slot_idx: int in range(6):
			InventoryManager.select_hotbar_slot(slot_idx)
			var res: ActionValidator.ActionResult = interior.player.use_selected_item(false, true)
			assert(not res.valid and res.reason == "Can't use tools indoors", "Tools must be blocked inside %s!" % String(theme_id))
		interior.queue_free()

		# Simulate exit back to FarmSanctuary -> assert player lands at THAT EXACT house's doorstep facing south!
		SceneTransition.pending_return_position = expected_doorstep
		SceneTransition.has_pending_return_position = true
		var f_ret: FarmSanctuary = farm_packed.instantiate() as FarmSanctuary
		add_child(f_ret)
		assert(f_ret.player.global_position.distance_to(expected_doorstep) < 1.0, "Exiting %s must return to exact doorstep %s (got %s)!" % [String(b_id), str(expected_doorstep), str(f_ret.player.global_position)])
		assert(f_ret.player.get_facing_cardinal() == Vector2i(0, 1), "Exiting %s must face south!" % String(b_id))
		assert(GridStateManager.get_cell(f_ret.scene_id, persist_cell).crop_id == &"sunflower", "GridStateManager must persist across %s round-trip!" % String(b_id))
		assert(f_ret.get_crop_node(persist_cell) != null, "CropNode must respawn cleanly after %s round-trip!" % String(b_id))
		f_ret.queue_free()

	print("[VerifyWorld] PASS: Farmhouse + ALL 5 themed NPC interiors (tool blocking + exact doorstep return + GridStateManager persistence) verified.")


func _stage_gallery_crops() -> void:
	var persist_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("OpenMeadowSpot"))
	GridStateManager.clear_crop(_farm.scene_id, persist_cell)
	var st_p: GridCellState = GridStateManager.get_cell(_farm.scene_id, persist_cell)
	if st_p != null:
		st_p.is_tilled = false
		st_p.is_watered = false
		EventBus.grid_cell_changed.emit(_farm.scene_id, persist_cell)
	var g0: Vector2i = _world_to_cell(_farm.get_world_marker_position("GardenOrigin"))
	var crops: Array[CropData] = InventoryManager.get_all_crops()
	for i: int in range(mini(11, crops.size())):
		var c: CropData = crops[i]
		GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(1 + i, 1), c.crop_id, c.days_to_mature, true)
		GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(1 + i, 2), c.crop_id, maxi(1, c.days_to_mature - 2), true)
	for dx: int in range(1, 7):
		GridStateManager.till_cell(_farm.scene_id, g0 + Vector2i(dx, 4))
	for dx: int in range(7, 12):
		GridStateManager.till_cell(_farm.scene_id, g0 + Vector2i(dx, 4))
		GridStateManager.water_cell(_farm.scene_id, g0 + Vector2i(dx, 4))
	_farm.player.global_position = _farm.get_world_marker_position("FarmhouseDoor") + Vector2(0.0, 14.0)
	_farm.player.set_facing_cardinal(Vector2i(0, 1))


func _save_viewport_png(res_path: String) -> void:
	var out_path: String = ProjectSettings.globalize_path(res_path)
	var img: Image = get_viewport().get_texture().get_image()
	assert(img != null, "Failed to read viewport image.")
	assert(img.get_width() >= 1280 and img.get_height() >= 720, "Expected 1280x720 screenshot, got %dx%d" % [img.get_width(), img.get_height()])
	var err: Error = img.save_png(out_path)
	assert(err == OK, "Failed to save %s (err=%d)" % [out_path, err])
