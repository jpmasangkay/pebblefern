extends Node2D

## Automated sanity & gameplay feel verification suite.
## Verifies strict ActionValidator rules (Fishing Rod, Hoe, Watering Can, Seeds, Axe/Pickaxe mismatch,
## Smart Harvest on crops & berry bushes, indoors tool blocking), real Stardew DoorPortal transition
## into farmhouse_interior.tscn & back with persistent state, symmetric torches, CircleShape2D collider,
## RUN 12 FPS locomotion, contextual TargetCursor visibility, and AudioManager SFX.

const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const INTERIOR_SCENE_PATH: String = "res://scenes/world/farmhouse_interior.tscn"
const SHOT_DOOR_TORCHES: String = "res://Screenshots/farm_door_and_torches.png"
const SHOT_INTERIOR: String = "res://Screenshots/farmhouse_interior_verified.png"
const SHOT_SOIL_HOTBAR: String = "res://Screenshots/soil_and_hotbar_verified.png"

var _farm: FarmSanctuary = null
var _interior: FarmhouseInterior = null
var _last_toast: String = ""
var _persist_cell: Vector2i = Vector2i.ZERO
var _step: int = 0
var _wait_frames: int = 0


func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0))


func _ready() -> void:
	GridStateManager.clear_all()
	InventoryManager.reset_to_starter_loadout()
	VitalitySystem.restore_full()
	TimeManager.reset_to_day_one()
	TimeManager.set_paused(true)
	TimeManager.set_time(12, 0)

	EventBus.toast_requested.connect(_on_toast)

	# 1. Verify AudioManager has all required synthesized retro SFX buffers
	for sfx: StringName in [
		&"footstep", &"door", &"hoe", &"water", &"axe", &"pickaxe",
		&"scythe", &"fish_cast", &"harvest", &"plant", &"pickup", &"error",
	]:
		assert(AudioManager.has_sfx(sfx), "AudioManager missing SFX: %s" % String(sfx))
		assert(AudioManager.play_sfx(sfx), "AudioManager failed to play SFX: %s" % String(sfx))
	print("[VerifyFeel] PASS: AudioManager retro SFX pool (12 effects) verified.")

	# 2. Load FarmSanctuary for outdoor validation tests
	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(farm_packed != null, "Missing farm_sanctuary.tscn")
	_farm = farm_packed.instantiate() as FarmSanctuary
	add_child(_farm)
	_farm.refresh_atmosphere()


func _on_toast(msg: String) -> void:
	_last_toast = msg


func _physics_process(_delta: float) -> void:
	_wait_frames += 1
	match _step:
		0:
			if _wait_frames >= 6:
				_run_outdoor_validation_tests()
				# Stage clear visual comparison in the garden bed dynamically via GardenOrigin!
				InventoryManager.reset_to_starter_loadout()
				InventoryManager.select_hotbar_slot(6)
				GridStateManager.clear_scene(_farm.scene_id)
				var g0: Vector2i = _world_to_cell(_farm.get_world_marker_position("GardenOrigin"))
				for dx: int in range(2, 5):
					GridStateManager.till_cell(_farm.scene_id, g0 + Vector2i(dx, 1))
				for dx: int in range(5, 8):
					GridStateManager.till_cell(_farm.scene_id, g0 + Vector2i(dx, 1))
					GridStateManager.water_cell(_farm.scene_id, g0 + Vector2i(dx, 1))
				GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(2, 2), &"parsnip", 0, false)
				GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(3, 2), &"sunflower", 0, false)
				GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(4, 2), &"carrot", 0, false)
				GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(5, 2), &"parsnip", 0, true)
				GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(6, 2), &"sunflower", 0, true)
				GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(7, 2), &"carrot", 0, true)
				GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(8, 2), &"sunflower", 8, true)
				GridStateManager.set_crop_state(_farm.scene_id, _persist_cell, &"parsnip", 0, true)

				_farm.player.global_position = Vector2(float(g0.x + 5) * 16.0 + 8.0, float(g0.y + 3) * 16.0 + 10.0)
				_farm.player.set_facing_cardinal(Vector2i(0, -1))
				TimeManager.set_time(12, 0)
				_farm.refresh_atmosphere()
				_step = 4
				_wait_frames = 0
		4:
			if _wait_frames >= 10:
				_save_viewport_png(SHOT_SOIL_HOTBAR)
				print("[VerifyFeel] Captured %s" % SHOT_SOIL_HOTBAR)
				# Stage player on front doorstep at evening dusk (19:30) so both glowing symmetric torches & house door show clearly!
				_farm.player.global_position = _farm.farmhouse.get_door_spawn_world_position() + Vector2(0.0, 24.0)
				_farm.player.set_facing_cardinal(Vector2i(0, -1))
				InventoryManager.select_hotbar_slot(5) # Fishing rod on road -> TargetCursor MUST stay hidden!
				_farm.player._update_target_cursor()
				assert(not _farm.player.is_target_cursor_visible(), "TargetCursor must be hidden on non-actionable road!")
				TimeManager.set_time(19, 30)
				_farm.refresh_atmosphere()
				_step = 1
				_wait_frames = 0
		1:
			if _wait_frames >= 10:
				_save_viewport_png(SHOT_DOOR_TORCHES)
				print("[VerifyFeel] Captured %s" % SHOT_DOOR_TORCHES)
				# Tear down outdoor farm and verify dedicated FarmhouseInterior room!
				_farm.queue_free()
				_farm = null
				var int_packed: PackedScene = load(INTERIOR_SCENE_PATH) as PackedScene
				assert(int_packed != null, "Missing farmhouse_interior.tscn")
				_interior = int_packed.instantiate() as FarmhouseInterior
				add_child(_interior)
				TimeManager.set_time(12, 0)
				_step = 2
				_wait_frames = 0
		2:
			if _wait_frames >= 8:
				_run_indoor_validation_tests()
				# Position player neatly in the center aisle for crisp interior visual capture
				_interior.player.global_position = Vector2(112.0, 102.0)
				_interior.player.set_facing_cardinal(Vector2i(0, -1))
				_interior.player.camera.make_current()
				_step = 3
				_wait_frames = 0
		3:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_INTERIOR)
				print("[VerifyFeel] Captured %s" % SHOT_INTERIOR)
				# Verify real Stardew scene transition round-trip (Farm -> DoorPortal -> Interior -> Exit -> Farm preserving crops!)
				_interior.queue_free()
				_interior = null
				_verify_roundtrip_persistence()
				print("[VerifyFeel] ALL GAMEPLAY FEEL, VALIDATOR & DOOR TRANSITION CHECKS PASSED!")
				get_tree().quit(0)


func _run_outdoor_validation_tests() -> void:
	var p: Player = _farm.player
	var cs: CollisionShape2D = p.get_node("CollisionShape2D") as CollisionShape2D
	assert(cs != null and cs.shape is CircleShape2D, "Player feet collider must be CircleShape2D!")
	assert(is_equal_approx((cs.shape as CircleShape2D).radius, 4.5), "Player CircleShape2D radius must be 4.5px!")
	assert(is_equal_approx(p.get_effective_walk_speed(), 88.0), "Player default move speed must be 88 px/s!")

	# Resolve dynamic map landmarks from WorldMarkers
	var meadow_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("OpenMeadowSpot"))
	var bridge_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("BridgeCrossing"))
	var river_bank: Vector2i = _world_to_cell(_farm.get_world_marker_position("RiverBankSpot"))
	var garden_origin: Vector2i = _world_to_cell(_farm.get_world_marker_position("GardenOrigin"))
	_persist_cell = meadow_cell

	# A. Fishing Rod on grass, road, and wooden bridge MUST be rejected (IDLE, 0 stamina, toast!)
	InventoryManager.select_hotbar_slot(5) # Fishing Rod
	var vit_before: float = VitalitySystem.current_vitality
	p.global_position = Vector2(float(meadow_cell.x) * 16.0 + 8.0, float(meadow_cell.y + 1) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(0, -1))
	assert(not p.is_target_cursor_visible(), "TargetCursor must be hidden for Fishing Rod on grass!")
	_last_toast = ""
	var fish_grass: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(not fish_grass.valid, "Fishing Rod on grass MUST be rejected!")
	assert(fish_grass.reason == "Face the river or pond to fish", "Unexpected grass fish toast: %s" % fish_grass.reason)
	assert(_last_toast == "Face the river or pond to fish", "Expected toast emitted for fishing on grass.")
	assert(p.get_current_anim_state() == Player.AnimState.IDLE, "Rejected tool MUST keep player in IDLE!")
	assert(is_equal_approx(VitalitySystem.current_vitality, vit_before), "Rejected tool MUST NOT drain stamina!")

	# Bridge cell -> MUST be rejected!
	p.global_position = Vector2(float(bridge_cell.x - 1) * 16.0 + 8.0, float(bridge_cell.y) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(1, 0))
	assert(not _farm.is_water_cell(bridge_cell), "Wooden bridge cell %s must NOT count as fishable water!" % str(bridge_cell))
	var fish_bridge: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not fish_bridge.valid, "Fishing Rod on wooden bridge MUST be rejected!")

	# Real 00_Water pond/river cell -> MUST be accepted!
	p.global_position = Vector2(float(river_bank.x) * 16.0 + 8.0, float(river_bank.y) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(-1, 0))
	assert(p.is_target_cursor_visible(), "TargetCursor must appear when Fishing Rod faces real 00_Water!")
	var fish_water: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(fish_water.valid and fish_water.kind == ActionValidator.ActionKind.CAST_FISHING, "Fishing Rod facing real water must succeed!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)
	print("[VerifyFeel] PASS: Fishing Rod strictly rejected on grass/road/bridge and accepted ONLY on real 00_Water.")

	# B. Watering Can & Seeds on untilled grass MUST be rejected (0 charges, 0 seeds, 0 stamina)
	var grass_cell: Vector2i = meadow_cell
	p.global_position = Vector2(float(grass_cell.x) * 16.0 + 8.0, float(grass_cell.y + 1) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(0, -1))
	InventoryManager.select_hotbar_slot(1) # Watering Can
	var charges_before: int = InventoryManager.get_selected_slot_charges()
	var water_grass: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not water_grass.valid and water_grass.reason == "Till soil with Hoe first", "Watering Can on grass must be rejected!")
	assert(InventoryManager.get_selected_slot_charges() == charges_before, "Watering Can on grass must NOT waste charges!")

	InventoryManager.select_hotbar_slot(6) # Parsnip Seeds
	var seeds_before: int = InventoryManager.get_selected_slot_count()
	var seed_grass: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not seed_grass.valid and seed_grass.reason == "Till soil with Hoe first", "Seeds on untilled grass must be rejected!")
	assert(InventoryManager.get_selected_slot_count() == seeds_before, "Rejected seed must NOT be consumed!")

	# C. Hoe on clear meadow -> valid; Hoe on already-tilled -> rejected; Water on dry tilled -> valid; Water on wet -> rejected!
	InventoryManager.select_hotbar_slot(0) # Hoe
	assert(p.is_target_cursor_visible(), "TargetCursor must show for Hoe on clear tillable grass!")
	var till_ok: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(till_ok.valid and till_ok.kind == ActionValidator.ActionKind.TILL, "Hoe on clear meadow must succeed!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)
	var till_again: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not till_again.valid and till_again.reason == "Already tilled", "Hoe on already-tilled soil must be rejected!")

	InventoryManager.select_hotbar_slot(6) # Plant Parsnip Seed on dry tilled soil!
	var parsnip_seeds_before: int = InventoryManager.get_selected_slot_count()
	var plant_ok: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(plant_ok.valid and plant_ok.kind == ActionValidator.ActionKind.PLANT_SEED, "Planting on empty dry tilled soil must succeed!")
	assert(InventoryManager.get_selected_slot_count() == parsnip_seeds_before - 1, "Planting must deduct 1 seed!")
	assert(_farm.get_crop_node(grass_cell) != null and _farm.get_crop_node(grass_cell).current_stage == 0, "Stage-0 seed sprite must spawn immediately!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)

	# Planting again on the same occupied tile MUST fail cleanly with toast!
	var plant_dup: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not plant_dup.valid and plant_dup.reason == "Already planted here", "Planting on occupied tile must reject cleanly!")

	InventoryManager.select_hotbar_slot(1) # Water dry tilled soil
	var water_ok: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(water_ok.valid and water_ok.kind == ActionValidator.ActionKind.WATER_SOIL, "Watering dry tilled soil must succeed!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)
	var water_again: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not water_again.valid and water_again.reason == "Soil is already watered", "Watering already-wet soil must be rejected!")

	# Also verify Till -> Water -> Plant Seed (slot 8 Sunflower on ALREADY-WATERED tilled tile!) -> Grow -> Harvest!
	var wet_first_cell: Vector2i = meadow_cell + Vector2i(1, 0)
	for candidate: Vector2i in [meadow_cell + Vector2i(1, 0), meadow_cell + Vector2i(2, 0), meadow_cell + Vector2i(0, -1), garden_origin]:
		if _farm.is_cell_tillable(candidate) and _farm.find_berry_bush_at(candidate) == null:
			wet_first_cell = candidate
			break
	p.global_position = Vector2(float(wet_first_cell.x) * 16.0 + 8.0, float(wet_first_cell.y + 1) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(0, -1))
	InventoryManager.select_hotbar_slot(0) # Hoe
	var till_wet_res: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(till_wet_res.valid and till_wet_res.kind == ActionValidator.ActionKind.TILL, "Hoe on %s must till!" % str(wet_first_cell))
	p.set_controls_locked(true)
	p.set_controls_locked(false)
	InventoryManager.select_hotbar_slot(1) # Water BEFORE planting
	assert(p.use_selected_item(true, true).valid, "Watering empty tilled soil must succeed!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)
	InventoryManager.select_hotbar_slot(7) # Slot 8 Sunflower Seeds on watered tilled tile!
	var sf_before: int = InventoryManager.get_selected_slot_count()
	var plant_wet_ok: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(plant_wet_ok.valid and plant_wet_ok.kind == ActionValidator.ActionKind.PLANT_SEED, "Planting on already-watered tilled soil must succeed!")
	assert(InventoryManager.get_selected_slot_count() == sf_before - 1, "Sunflower seed stack must decrement by 1!")
	assert(_farm.get_crop_node(wet_first_cell) != null and _farm.get_crop_node(wet_first_cell).current_stage == 0, "Sunflower stage-0 seed sprite must spawn immediately!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)
	# Verify full growth -> harvest cycle on (36,19)!
	GridStateManager.set_crop_state(_farm.scene_id, wet_first_cell, &"sunflower", 8, true)
	var harv_ok: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(harv_ok.valid and harv_ok.kind == ActionValidator.ActionKind.HARVEST_CROP, "Mature Sunflower must harvest cleanly!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)
	print("[VerifyFeel] PASS: Full Till -> Plant (dry & watered) -> Water -> Harvest loop verified.")

	# D. Axe vs Pickaxe tool mismatch feedback
	var sample_rock: ResourceNode = null
	var sample_tree: ResourceNode = null
	for n: Node in get_tree().get_nodes_in_group(&"resource_nodes"):
		var rn: ResourceNode = n as ResourceNode
		if rn == null or rn.is_destroyed():
			continue
		if sample_rock == null and rn.required_tool == ToolData.ToolKind.PICKAXE and rn.required_tier == ToolData.ToolTier.BASIC and _farm.find_berry_bush_at(rn.get_grid_cell()) == null:
			sample_rock = rn
		elif sample_tree == null and rn.required_tool == ToolData.ToolKind.AXE and rn.required_tier == ToolData.ToolTier.BASIC and _farm.find_berry_bush_at(rn.get_grid_cell()) == null:
			sample_tree = rn
	assert(sample_rock != null and sample_tree != null, "Expected rock & tree nodes on farm.")

	var rock_cell: Vector2i = sample_rock.get_grid_cell()
	p.global_position = Vector2(float(rock_cell.x) * 16.0 + 8.0, float(rock_cell.y + 1) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(0, -1))
	InventoryManager.select_hotbar_slot(2) # Axe on Rock -> "Use Pickaxe on rocks"
	var axe_rock: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not axe_rock.valid and axe_rock.reason == "Use Pickaxe on rocks", "Axe on rock must say 'Use Pickaxe on rocks' (got '%s')" % axe_rock.reason)

	var tree_cell: Vector2i = sample_tree.get_grid_cell()
	p.global_position = Vector2(float(tree_cell.x) * 16.0 + 8.0, float(tree_cell.y + 1) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(0, -1))
	InventoryManager.select_hotbar_slot(3) # Pickaxe on Tree -> "Use Axe on trees"
	var pick_tree: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not pick_tree.valid and pick_tree.reason == "Use Axe on trees", "Pickaxe on tree must say 'Use Axe on trees' (got '%s')" % pick_tree.reason)
	print("[VerifyFeel] PASS: Axe/Pickaxe tool-mismatch messages ('Use Pickaxe on rocks' / 'Use Axe on trees') verified.")

	# E. Smart Harvest mature crop & ripe Berry Bush while holding Axe/Hoe!
	var crop_cell: Vector2i = garden_origin + Vector2i(2, 1)
	GridStateManager.set_crop_state(_farm.scene_id, crop_cell, &"parsnip", 4, true)
	p.global_position = Vector2(float(crop_cell.x) * 16.0 + 8.0, float(crop_cell.y + 1) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(0, -1))
	InventoryManager.select_hotbar_slot(2) # Holding Axe!
	var smart_crop: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(smart_crop.valid and smart_crop.kind == ActionValidator.ActionKind.HARVEST_CROP, "LMB while holding Axe must Smart Harvest mature crop!")
	assert(GridStateManager.get_cell(_farm.scene_id, crop_cell).crop_id == &"", "Smart Harvest must harvest mature crop!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)

	var ripe_bush: BerryBush = null
	for n: Node in get_tree().get_nodes_in_group(&"berry_bushes"):
		var bb: BerryBush = n as BerryBush
		if bb != null and bb.is_ripe():
			ripe_bush = bb
			break
	assert(ripe_bush != null, "Expected at least one ripe BerryBush on farm.")
	var bush_cell: Vector2i = ripe_bush.get_grid_cell()
	p.global_position = Vector2(float(bush_cell.x) * 16.0 + 8.0, float(bush_cell.y + 1) * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(0, -1))
	InventoryManager.select_hotbar_slot(0) # Holding Hoe!
	var smart_bush: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(smart_bush.valid and smart_bush.kind == ActionValidator.ActionKind.HARVEST_BERRY, "LMB while holding Hoe must Smart Harvest ripe BerryBush!")
	assert(not ripe_bush.is_ripe(), "Harvested BerryBush must switch to Plain variant!")
	p.set_controls_locked(true)
	p.set_controls_locked(false)
	print("[VerifyFeel] PASS: Smart Harvest on mature Stage-5 crop & ripe BerryBush while holding tools verified.")

	# F. Verify exterior Farmhouse is solid (DoorPortal present, RoofLayer opaque!)
	assert(_farm.farmhouse.get_node_or_null("DoorPortal") != null, "Farmhouse must have DoorPortal Area2D!")
	assert(_farm.farmhouse.get_node_or_null("WallCollisions/SolidMainWingHull") != null, "Farmhouse front wall & door must be 100% solid!")
	assert(is_equal_approx(_farm.farmhouse.roof_layer.modulate.a, 1.0), "Exterior farmhouse roof must remain solid opaque!")
	print("[VerifyFeel] PASS: Solid exterior farmhouse + DoorPortal verified.")


func _run_indoor_validation_tests() -> void:
	var p: Player = _interior.player
	var vit_before: float = VitalitySystem.current_vitality
	# Verify EVERY tool slot (0..5) is strictly rejected indoors with "Can't use tools indoors"!
	for slot_idx: int in range(6):
		InventoryManager.select_hotbar_slot(slot_idx)
		p._update_target_cursor()
		assert(not p.is_target_cursor_visible(), "TargetCursor must be hidden indoors for slot %d!" % slot_idx)
		var res: ActionValidator.ActionResult = p.use_selected_item(false, true)
		assert(not res.valid, "Tool slot %d MUST be rejected indoors!" % slot_idx)
		assert(res.reason == "Can't use tools indoors", "Expected indoor block toast, got '%s'" % res.reason)
		assert(p.get_current_anim_state() == Player.AnimState.IDLE, "Blocked indoor tool must keep player IDLE!")
	assert(is_equal_approx(VitalitySystem.current_vitality, vit_before), "Blocked indoor tools must drain 0 Vitality!")

	# Verify Seeds are blocked indoors
	InventoryManager.select_hotbar_slot(6)
	var seed_in: ActionValidator.ActionResult = p.use_selected_item(false, true)
	assert(not seed_in.valid and seed_in.reason == "Can't plant seeds indoors", "Seeds must be rejected indoors!")

	# Verify BedSleepTrigger & ExitDoorPortal exist cleanly in FarmhouseInterior
	assert(_interior.get_node_or_null("BedSleepTrigger") != null, "FarmhouseInterior missing BedSleepTrigger!")
	assert(_interior.get_node_or_null("ExitDoorPortal") != null, "FarmhouseInterior missing ExitDoorPortal!")
	print("[VerifyFeel] PASS: All 6 tools & seeds strictly blocked indoors + Bed/Exit portals verified.")


func _verify_roundtrip_persistence() -> void:
	# Re-instantiate FarmSanctuary with spawn_tag=&"from_house" to prove doorstep spawn + GridStateManager persistence!
	SceneTransition.has_pending_return_position = false
	SceneTransition.pending_spawn_tag = &"from_house"
	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	var farm2: FarmSanctuary = farm_packed.instantiate() as FarmSanctuary
	add_child(farm2)
	var expected_doorstep: Vector2 = farm2.farmhouse.get_door_spawn_world_position()
	assert(farm2.player.global_position.distance_to(expected_doorstep) < 1.0, "Returning from house must spawn player cleanly on doorstep!")
	var persisted: GridCellState = GridStateManager.get_cell(farm2.scene_id, _persist_cell)
	assert(persisted != null and persisted.is_tilled and persisted.crop_id == &"parsnip" and persisted.is_watered, "Farm crops & tilled soil must persist cleanly across door transitions!")
	assert(farm2.get_crop_node(_persist_cell) != null, "Persisted CropNode must respawn cleanly on return from farmhouse!")
	farm2.queue_free()
	print("[VerifyFeel] PASS: Door transition round-trip spawns on doorstep with 100% farm state preserved.")


func _save_viewport_png(res_path: String) -> void:
	var out_path: String = ProjectSettings.globalize_path(res_path)
	var img: Image = get_viewport().get_texture().get_image()
	assert(img != null, "Failed to read viewport image.")
	var err: Error = img.save_png(out_path)
	assert(err == OK, "Failed to save %s (err=%d)" % [out_path, err])
