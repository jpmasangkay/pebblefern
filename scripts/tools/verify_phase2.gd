extends Node2D

## Automated Phase 2 verification suite & screenshot capture.
## Tests all 11 crops, all 6 tools, Hoe tilling, Seed planting, Watering Can (40 charges + river refill),
## Stage-5 harvesting, VitalitySystem + Exhausted debuff, tiered ResourceNodes, and pooled magnetic DroppedItems.

const AP := preload("res://scripts/core/asset_paths.gd")
const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const PHASE2_SHOT: String = "res://Screenshots/phase2_farming_verified.png"
const QUARRY_SHOT: String = "res://Screenshots/phase2_quarry_nodes.png"

var _farm: FarmSanctuary = null
var _player: Player = null
var _step: int = 0
var _wait_frames: int = 0
var _tier_warning_received: bool = false
var _items_collected: int = 0


func _ready() -> void:
	GridStateManager.clear_all()
	InventoryManager.reset_to_starter_loadout()
	VitalitySystem.restore_full()

	var packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(packed != null, "Failed to load farm_sanctuary.tscn")
	_farm = packed.instantiate() as FarmSanctuary
	add_child(_farm)
	_farm.set_hud_visible(false)
	TimeManager.set_paused(true)
	TimeManager.set_time(12, 0)
	_farm.refresh_atmosphere()
	_player = _farm.player
	assert(_player != null, "FarmSanctuary missing player.")

	EventBus.tool_tier_insufficient.connect(_on_tier_insufficient)
	EventBus.item_picked_up.connect(_on_item_picked_up)

	_run_data_audit()


func _on_tier_insufficient(_req_tier: int, _cell: Vector2i) -> void:
	_tier_warning_received = true


func _on_item_picked_up(_item_id: StringName, count: int) -> void:
	_items_collected += count


func _run_data_audit() -> void:
	# 1. Verify all 11 Sunnyside crops + 5 stages + harvest icons + seeds + produce
	var crops: Array[CropData] = InventoryManager.get_all_crops()
	assert(crops.size() == 11, "Expected 11 Sunnyside crops, got %d" % crops.size())
	for c: CropData in crops:
		assert(c.stage_textures.size() == 5, "Crop %s missing 5 stages" % String(c.crop_id))
		for s: int in range(5):
			assert(c.stage_textures[s] != null, "Null stage texture on %s stage %d" % [String(c.crop_id), s])
		assert(c.harvest_icon != null, "Missing _05 harvest icon on %s" % String(c.crop_id))
		assert(InventoryManager.get_item(c.seed_item_id) != null, "Missing seed item %s" % String(c.seed_item_id))
		assert(InventoryManager.get_item(c.harvest_item_id) != null, "Missing harvest item %s" % String(c.harvest_item_id))

	# 2. Verify all 6 starter tools in Hotbar 0..5 + starter seeds in 6..7
	var expected_hotbar: Array[StringName] = [
		&"tool_hoe", &"tool_watering_can", &"tool_axe", &"tool_pickaxe",
		&"tool_scythe", &"tool_fishing_rod", &"seed_parsnip", &"seed_sunflower",
	]
	for i: int in range(expected_hotbar.size()):
		assert(InventoryManager.get_slot_item_id(i) == expected_hotbar[i], "Hotbar slot %d mismatch" % i)
	assert(InventoryManager.get_slot_charges(1) == 40, "Watering Can must start with 40 charges.")
	print("[VerifyP2] PASS: All 11 crops (5 stages + _05) & 6 starter tools + seeds verified.")


func _physics_process(_delta: float) -> void:
	_wait_frames += 1
	match _step:
		0:
			if _wait_frames >= 6:
				_test_farming_and_watering_refill()
				_step = 1
				_wait_frames = 0
		1:
			# Wait for magnetic pickup of harvested parsnip (~0.5s = 36 ticks)
			if _wait_frames >= 36:
				var parsnip_count: int = InventoryManager.count_item(&"crop_parsnip")
				assert(parsnip_count >= 1, "Harvested parsnip should have magnetized into InventoryManager (got %d)" % parsnip_count)
				print("[VerifyP2] PASS: Mature Stage-5 harvest & magnetic DroppedItem pickup collected (%d parsnip)." % parsnip_count)
				_test_vitality_exhaustion()
				_test_chop_tree_and_stump()
				_step = 2
				_wait_frames = 0
		2:
			# Wait beside felled tree & chopped stump so wood drops magnetize cleanly into player!
			if _wait_frames >= 42:
				var wood_cnt: int = InventoryManager.count_item(&"wood")
				assert(wood_cnt >= 4, "Expected >= 4 wood collected from tree+stump (got %d)" % wood_cnt)
				print("[VerifyP2] PASS: Tree fell -> stump conversion -> wood magnetized into inventory (%d wood)." % wood_cnt)
				_test_mine_rock_and_tiered_boulder()
				_step = 3
				_wait_frames = 0
		3:
			# Wait beside mined boulder so stone drops magnetize cleanly into player!
			if _wait_frames >= 42:
				var stone_cnt: int = InventoryManager.count_item(&"stone")
				assert(stone_cnt >= 8, "Expected >= 8 stone collected from Copper-mined boulder (got %d)" % stone_cnt)
				print("[VerifyP2] PASS: Small rock & Copper-tier boulder mining + magnetic stone drops verified (%d stone)." % stone_cnt)
				_setup_visual_showcase_garden()
				_step = 4
				_wait_frames = 0
		4:
			if _wait_frames >= 10:
				_save_viewport_png(PHASE2_SHOT)
				print("[VerifyP2] Captured %s" % PHASE2_SHOT)
				# Also capture quarry closeup showing boulders, stumps, and active stone/wood drops
				var q_pos: Vector2 = _farm.get_world_marker_position("QuarryCenter")
				_player.global_position = q_pos
				_farm.drop_pool.spawn_drop(q_pos + Vector2(16.0, -16.0), &"wood", 2, null)
				_farm.drop_pool.spawn_drop(q_pos + Vector2(-16.0, -16.0), &"stone", 2, null)
				_step = 5
				_wait_frames = 0
		5:
			if _wait_frames >= 10:
				_save_viewport_png(QUARRY_SHOT)
				print("[VerifyP2] Captured %s" % QUARRY_SHOT)
				print("[VerifyP2] ALL PHASE 2 AUTOMATED CHECKS PASSED!")
				get_tree().quit(0)


func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0))


func _test_farming_and_watering_refill() -> void:
	var garden_origin: Vector2i = _world_to_cell(_farm.get_world_marker_position("GardenOrigin"))
	var river_bank: Vector2i = _world_to_cell(_farm.get_world_marker_position("RiverBankSpot"))
	var water_cell: Vector2i = river_bank + Vector2i(-1, 0)
	var road_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("FarmhouseDoor")) + Vector2i(0, 2)
	var meadow_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("OpenMeadowSpot"))

	# Reject tilling on water and on scalloped road
	assert(not _farm.is_cell_tillable(water_cell), "Water cell must NOT be tillable!")
	assert(not _farm.is_cell_tillable(road_cell), "Road cell must NOT be tillable!")

	# 1. Till a fresh garden cell with Hoe (slot 0)
	var test_cell: Vector2i = garden_origin
	_player.global_position = Vector2(float(test_cell.x) * 16.0 + 8.0, float(test_cell.y + 1) * 16.0 + 8.0)
	_player.set_facing_cardinal(Vector2i(0, -1))
	InventoryManager.select_hotbar_slot(0) # Hoe
	var vit_before: float = VitalitySystem.current_vitality
	_player.use_selected_item(true, true)
	_player.set_controls_locked(true)
	_player.set_controls_locked(false)
	assert(is_equal_approx(VitalitySystem.current_vitality, vit_before - 2.0), "Hoe swing must cost 2.0 Vitality!")
	var st: GridCellState = GridStateManager.get_cell(_farm.scene_id, test_cell)
	assert(st != null and st.is_tilled and not st.is_watered, "Garden cell must be tilled and dry.")
	assert(_farm.soil_layer.get_cell_source_id(test_cell) == AP.SOURCE_SOIL_DRY, "03_SoilOverlay must show dry soil.")

	# Also verify open meadow tilling works cleanly
	assert(_farm.is_cell_tillable(meadow_cell), "Open meadow cell should be tillable!")
	assert(GridStateManager.till_cell(_farm.scene_id, meadow_cell), "Should till open meadow cell cleanly.")

	# 2. Plant Parsnip seed (slot 6) on test_cell
	InventoryManager.select_hotbar_slot(6)
	var seeds_before: int = InventoryManager.get_selected_slot_count()
	_player.use_selected_item(true, true)
	_player.set_controls_locked(true)
	_player.set_controls_locked(false)
	assert(InventoryManager.get_selected_slot_count() == seeds_before - 1, "Planting must consume 1 seed.")
	assert(GridStateManager.get_cell(_farm.scene_id, test_cell).crop_id == &"parsnip", "Crop must be planted.")
	assert(_farm.get_crop_node(test_cell) != null, "CropNode must spawn inside WorldEntities.")

	# 3. Water test_cell with Watering Can (slot 1) -> charges 40 -> 39, soil darkens!
	InventoryManager.select_hotbar_slot(1)
	_player.use_selected_item(true, true)
	_player.set_controls_locked(true)
	_player.set_controls_locked(false)
	assert(InventoryManager.get_selected_slot_charges() == 39, "Watering must spend 1 charge (40->39).")
	assert(GridStateManager.get_cell(_farm.scene_id, test_cell).is_watered, "Cell must be marked watered.")
	assert(_farm.soil_layer.get_cell_source_id(test_cell) == AP.SOURCE_SOIL_WATERED, "03_SoilOverlay must darken to watered soil.")

	# 4. Walk to Farm Pond bank facing 00_Water tile and refill Watering Can to 40/40!
	_player.global_position = Vector2(float(river_bank.x) * 16.0 + 8.0, float(river_bank.y) * 16.0 + 8.0)
	_player.set_facing_cardinal(Vector2i(-1, 0))
	assert(_farm.is_water_cell(_player.get_target_cell()), "Target cell %s must be recognized as water." % str(_player.get_target_cell()))
	_player.use_selected_item(true, true)
	_player.set_controls_locked(true)
	_player.set_controls_locked(false)
	assert(InventoryManager.get_selected_slot_charges() == 40, "Watering Can must refill to 40/40 at water!")
	print("[VerifyP2] PASS: Hoe till, seed plant, Watering Can (40 charges + watered soil + water refill) verified.")

	# 5. Simulate overnight growth (4 watered days -> Stage 4 / mature Stage-5) & harvest via interact!
	for _d: int in range(4):
		GridStateManager.water_cell(_farm.scene_id, test_cell)
		GridStateManager.advance_day(CropData.Season.BLOOM, false)
	assert(GridStateManager.is_crop_mature(_farm.scene_id, test_cell), "Parsnip must be mature after 4 watered days.")
	assert(_farm.get_crop_node(test_cell).current_stage == 4, "Mature CropNode must display stage 4 (_04.png).")

	_player.global_position = Vector2(float(test_cell.x) * 16.0 + 8.0, float(test_cell.y + 1) * 16.0 + 8.0)
	_player.set_facing_cardinal(Vector2i(0, -1))
	EventBus.player_interacted.emit(test_cell)
	assert(GridStateManager.get_cell(_farm.scene_id, test_cell).crop_id == &"", "Harvested cell must clear crop.")
	assert(_farm.drop_pool.get_active_count() >= 1, "Harvest must spawn magnetic DroppedItem from pool.")


func _test_vitality_exhaustion() -> void:
	VitalitySystem.restore_full()
	assert(not VitalitySystem.is_exhausted, "Fresh Vitality should not be exhausted.")
	var normal_speed: float = _player.get_effective_walk_speed()
	# 50 tool swings x 2.0 cost = 100.0 Vitality drained -> Exhausted!
	for _i: int in range(50):
		VitalitySystem.consume(2.0)
	assert(VitalitySystem.current_vitality == 0.0, "Vitality must clamp at 0.0.")
	assert(VitalitySystem.is_exhausted, "VitalitySystem must flag is_exhausted at 0 Vitality.")
	var exhausted_speed: float = _player.get_effective_walk_speed()
	assert(exhausted_speed < normal_speed * 0.6, "Exhausted player speed must suffer debuff (got %.1f vs %.1f)." % [exhausted_speed, normal_speed])

	# Restore full vitality before resource tests
	VitalitySystem.restore_full()
	assert(not VitalitySystem.is_exhausted and is_equal_approx(_player.get_effective_walk_speed(), normal_speed))
	print("[VerifyP2] PASS: VitalitySystem (100 max, 2/swing, Exhausted speed debuff %.1f -> %.1f) verified." % [normal_speed, exhausted_speed])


func _test_chop_tree_and_stump() -> void:
	var all_nodes: Array[Node] = get_tree().get_nodes_in_group(&"resource_nodes")
	var sample_tree: ResourceNode = null
	for n: Node in all_nodes:
		var rn: ResourceNode = n as ResourceNode
		if rn != null and rn.node_kind in [ResourceNode.NodeKind.TREE_DECIDUOUS, ResourceNode.NodeKind.TREE_PINE]:
			sample_tree = rn
			break
	assert(sample_tree != null, "Expected destructible tree ResourceNode on farm.")

	var axe: ToolData = InventoryManager.get_tool(&"tool_axe")
	# Stand right beside the tree so felled timber + stump timber both magnetize into player!
	_player.global_position = sample_tree.global_position + Vector2(0.0, 14.0)
	for _h: int in range(4):
		assert(sample_tree.apply_tool_hit(axe, _farm.drop_pool, _player), "Axe hit on tree must succeed.")
	assert(not sample_tree.is_destroyed() and sample_tree.node_kind in [ResourceNode.NodeKind.STUMP_SMALL, ResourceNode.NodeKind.STUMP_MEDIUM], "Felled tree must convert to choppable stump.")
	# Finish chopping the converted stump right in place!
	var stump_hits: int = sample_tree.max_hp
	for _h: int in range(stump_hits):
		sample_tree.apply_tool_hit(axe, _farm.drop_pool, _player)
	assert(sample_tree.is_destroyed(), "Converted stump must be destroyed after axe hits.")


func _test_mine_rock_and_tiered_boulder() -> void:
	var all_nodes: Array[Node] = get_tree().get_nodes_in_group(&"resource_nodes")
	var sample_rock: ResourceNode = null
	var sample_large_boulder: ResourceNode = null
	for n: Node in all_nodes:
		var rn: ResourceNode = n as ResourceNode
		if rn == null or rn.is_destroyed():
			continue
		if sample_rock == null and rn.node_kind == ResourceNode.NodeKind.ROCK_SMALL:
			sample_rock = rn
		elif sample_large_boulder == null and rn.node_kind == ResourceNode.NodeKind.BOULDER_LARGE:
			sample_large_boulder = rn

	assert(sample_rock != null, "Expected destructible small rock ResourceNode on farm.")
	assert(sample_large_boulder != null, "Expected tier-2 BOULDER_LARGE ResourceNode in quarry.")
	var pickaxe: ToolData = InventoryManager.get_tool(&"tool_pickaxe")

	# 1. Mine small rock (2 Basic Pickaxe hits -> drops 2 stone!)
	for _h: int in range(2):
		sample_rock.apply_tool_hit(pickaxe, _farm.drop_pool, _player)
	assert(sample_rock.is_destroyed(), "Small rock must be destroyed after 2 Basic Pickaxe hits.")

	# 2. Tiered tool gating: Basic Pickaxe must NOT damage Copper-tier BOULDER_LARGE!
	_tier_warning_received = false
	_player.global_position = sample_large_boulder.global_position + Vector2(0.0, 16.0)
	var hit_basic: bool = sample_large_boulder.apply_tool_hit(pickaxe, _farm.drop_pool, _player)
	assert(not hit_basic and _tier_warning_received, "Basic Pickaxe must emit tool_tier_insufficient on BOULDER_LARGE.")
	assert(sample_large_boulder.current_hp == sample_large_boulder.max_hp, "BOULDER_LARGE HP must remain untouched.")

	# Upgrade Pickaxe to Copper Tier 2 (power=2) -> breaks 6-HP boulder in 3 hits & drops 8 stone right beside player!
	InventoryManager.upgrade_tool_tier(&"tool_pickaxe", ToolData.ToolTier.COPPER)
	for _h: int in range(3):
		assert(sample_large_boulder.apply_tool_hit(pickaxe, _farm.drop_pool, _player), "Copper Pickaxe must damage BOULDER_LARGE.")
	assert(sample_large_boulder.is_destroyed(), "Copper Pickaxe must destroy BOULDER_LARGE in 3 hits.")
	InventoryManager.upgrade_tool_tier(&"tool_pickaxe", ToolData.ToolTier.BASIC)


func _setup_visual_showcase_garden() -> void:
	var g0: Vector2i = _world_to_cell(_farm.get_world_marker_position("GardenOrigin"))
	var crops: Array[CropData] = InventoryManager.get_all_crops()
	for i: int in range(11):
		var c: CropData = crops[i]
		var col: int = g0.x + i
		GridStateManager.set_crop_state(_farm.scene_id, Vector2i(col, g0.y), c.crop_id, 0 if i < 6 else 1, i >= 5)
		var mid_days: int = maxi(1, int(roundf(float(c.days_to_mature) * 0.55)))
		GridStateManager.set_crop_state(_farm.scene_id, Vector2i(col, g0.y + 1), c.crop_id, mid_days, true)
		var pre_days: int = maxi(1, c.days_to_mature - 1)
		GridStateManager.set_crop_state(_farm.scene_id, Vector2i(col, g0.y + 2), c.crop_id, pre_days, true)
		GridStateManager.set_crop_state(_farm.scene_id, Vector2i(col, g0.y + 3), c.crop_id, c.days_to_mature, true)

	for x: int in range(g0.x, g0.x + 6):
		GridStateManager.set_crop_state(_farm.scene_id, Vector2i(x, g0.y + 4), &"", 0, false)
	for x: int in range(g0.x + 6, g0.x + 11):
		GridStateManager.set_crop_state(_farm.scene_id, Vector2i(x, g0.y + 4), &"", 0, true)

	_player.global_position = Vector2(float(g0.x + 5) * 16.0 + 8.0, float(g0.y + 5) * 16.0 + 4.0)
	_player.set_facing_cardinal(Vector2i(0, -1))
	_farm.drop_pool.spawn_drop(Vector2(float(g0.x + 1) * 16.0 + 8.0, float(g0.y + 5) * 16.0 + 4.0), &"crop_parsnip", 1, null)
	_farm.drop_pool.spawn_drop(Vector2(float(g0.x + 2) * 16.0 + 8.0, float(g0.y + 5) * 16.0 + 8.0), &"crop_sunflower", 1, null)
	_farm.drop_pool.spawn_drop(Vector2(float(g0.x + 9) * 16.0 + 8.0, float(g0.y + 5) * 16.0 + 4.0), &"wood", 2, null)
	_farm.drop_pool.spawn_drop(Vector2(float(g0.x + 10) * 16.0 + 8.0, float(g0.y + 5) * 16.0 + 8.0), &"stone", 2, null)


func _save_viewport_png(res_or_abs_path: String) -> void:
	var out_path: String = ProjectSettings.globalize_path(res_or_abs_path) if res_or_abs_path.begins_with("res://") else res_or_abs_path
	var img: Image = get_viewport().get_texture().get_image()
	assert(img != null, "Failed to read viewport texture image.")
	var err: Error = img.save_png(out_path)
	assert(err == OK, "Failed to save screenshot to %s (err=%d)" % [out_path, err])
