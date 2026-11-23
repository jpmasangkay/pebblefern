extends Node2D

## Automated Phase 4 verification suite & full 1280x720 screenshot capture.
## Tests EconomyManager, ShippingBin + Undo + DaySummaryModal overnight settlement,
## Maren's Seed Shop (buy/sell), Kaelen's Blacksmith tool upgrades (Basic -> Copper -> Iron,
## Watering Can 40->60->80, Hoe Vitality 2->1, Copper boulder/stump breaking), Furnace smelting,
## Crafting all 6 RecipeData recipes, ActionValidator placement validation, and persistence of
## PlacedChest (with stored items) & Outdoor Torch across FarmhouseInterior round-trip & sleep!

const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const INTERIOR_SCENE_PATH: String = "res://scenes/world/farmhouse_interior.tscn"
const SHOT_SHOP: String = "res://Screenshots/phase4_shop_modal.png"
const SHOT_FORGE: String = "res://Screenshots/phase4_forge_modal.png"
const SHOT_CRAFTING: String = "res://Screenshots/phase4_crafting_placed.png"
const SHOT_CRAFT_TAB: String = "res://Screenshots/phase4_craft_tab.png"
const SHOT_SUMMARY: String = "res://Screenshots/phase4_day_summary.png"

var _farm: FarmSanctuary = null
var _chest_cell: Vector2i = Vector2i.ZERO
var _torch_cell: Vector2i = Vector2i.ZERO
var _step: int = 0
var _wait_frames: int = 0


func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0))


func _ready() -> void:
	GridStateManager.clear_all()
	InventoryManager.reset_to_starter_loadout()
	EconomyManager.reset_economy()
	VitalitySystem.restore_full()
	TimeManager.reset_to_day_one()
	TimeManager.set_paused(true)
	TimeManager.set_time(12, 0)

	# 1. Verify all Phase 4 items & 6 recipes loaded cleanly into InventoryManager
	for iid: StringName in [
		&"copper_bar", &"iron_bar", &"fish",
		&"place_chest", &"place_fence", &"place_torch",
		&"place_stone_path", &"place_scarecrow", &"place_furnace",
	]:
		assert(InventoryManager.get_item(iid) != null, "Missing Phase 4 ItemData: %s" % String(iid))
	assert(InventoryManager.get_all_recipes().size() == 6, "Expected 6 crafting recipes, got %d" % InventoryManager.get_all_recipes().size())
	print("[VerifyP4] PASS: All Phase 4 items (bars, fish, 6 placeables) & 6 RecipeData resources loaded.")

	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(farm_packed != null, "Missing farm_sanctuary.tscn")
	_farm = farm_packed.instantiate() as FarmSanctuary
	add_child(_farm)
	assert(_farm.market_stall != null, "FarmSanctuary must include MarketStall on east sanctuary road!")
	assert(_farm.shop_modal != null and _farm.shipping_modal != null and _farm.chest_modal != null and _farm.furnace_modal != null, "Missing Phase 4 modals.")
	_farm.refresh_atmosphere()


func _physics_process(_delta: float) -> void:
	_wait_frames += 1
	match _step:
		0:
			if _wait_frames >= 6:
				_test_shop_and_tool_upgrades()
				_test_crafting_placement_and_furnace()
				_test_shipping_and_persistence()
				# Stage Shot 1: Maren's Seed Shop open by the east-road MarketStall inspecting Sunflower!
				_farm.player.global_position = _farm.market_stall.global_position + Vector2(0.0, 22.0)
				_farm.player.set_facing_cardinal(Vector2i(0, -1))
				TimeManager.set_time(12, 0)
				_farm.refresh_atmosphere()
				_farm.shop_modal.set_open(true, ShopModal.Tab.SEEDS)
				_farm.shop_modal.select_seed_index(6) # Sunflower (3-stage preview!)
				_farm.shop_modal.adjust_qty(4)        # Qty 5 -> 300 G preview
				_step = 1
				_wait_frames = 0
		1:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_SHOP)
				print("[VerifyP4] Captured %s" % SHOT_SHOP)
				# Stage Shot 1b: Kaelen's Forge tab
				_farm.shop_modal.set_active_tab(ShopModal.Tab.FORGE)
				_farm.shop_modal.select_tool_index(1) # Watering Can
				_step = 2
				_wait_frames = 0
		2:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_FORGE)
				print("[VerifyP4] Captured %s" % SHOT_FORGE)
				_farm.shop_modal.set_open(false)

				# Stage Shot 2: Dusk courtyard showing crafted & placed Storage Chest, glowing Torch, Fence,
				# Stone Path, Scarecrow, glowing Stone Furnace & Market Stall + Anvil, with green placement preview
				# and Copper/Iron upgraded tools visible on the HUD hotbar!
				InventoryManager.upgrade_tool_tier(&"tool_pickaxe", ToolData.ToolTier.COPPER)
				InventoryManager.upgrade_tool_tier(&"tool_watering_can", ToolData.ToolTier.IRON)
				InventoryManager.add_item(&"place_fence", 2)
				var f_slot: int = _find_slot_with(&"place_fence")
				if f_slot >= 0:
					InventoryManager.swap_slots(6, f_slot)
					InventoryManager.select_hotbar_slot(6)
				_farm.player.global_position = Vector2(float(_chest_cell.x + 2) * 16.0 + 8.0, float(_chest_cell.y + 1) * 16.0 + 8.0)
				_farm.player.set_facing_cardinal(Vector2i(1, 0))
				TimeManager.set_time(18, 45)
				_farm.refresh_atmosphere()
				_step = 3
				_wait_frames = 0
		3:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_CRAFTING)
				print("[VerifyP4] Captured %s" % SHOT_CRAFTING)

				# Stage Shot 2b: Inventory Modal -> Craft Tab open showing all 6 Sunnyside recipes!
				InventoryManager.add_item(&"wood", 25)
				InventoryManager.add_item(&"stone", 20)
				InventoryManager.add_item(&"fiber", 10)
				_farm.inventory_modal.set_open(true)
				_farm.inventory_modal.set_active_tab(InventoryModal.Tab.CRAFT)
				_farm.inventory_modal.select_recipe(5) # Stone Furnace
				_step = 4
				_wait_frames = 0
		4:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_CRAFT_TAB)
				print("[VerifyP4] Captured %s" % SHOT_CRAFT_TAB)
				_farm.inventory_modal.set_open(false)

				# Stage Shot 3: Overnight DaySummaryModal with itemized shipped crops & River Fish (HUD cleanly hidden!)
				EconomyManager.reset_economy()
				EconomyManager.ship_item_direct(&"crop_parsnip", 4)   # 4 x 35 = 140 G
				EconomyManager.ship_item_direct(&"crop_sunflower", 3) # 3 x 120 = 360 G
				EconomyManager.ship_item_direct(&"crop_carrot", 5)    # 5 x 45 = 225 G
				EconomyManager.ship_item_direct(&"fish", 2)           # 2 x 45 = 90 G
				var ledger: Dictionary = EconomyManager.build_pending_ledger(1, 0, 1)
				assert(int(ledger["total_earned"]) == 815, "Expected 815 G ledger total, got %d" % int(ledger["total_earned"]))
				var summary: DaySummaryModal = _farm.sleep_dialog.get_day_summary_modal()
				assert(summary != null, "SleepDialog missing DaySummaryModal!")
				summary.open_summary(ledger, true)
				_step = 5
				_wait_frames = 0
		5:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_SUMMARY)
				print("[VerifyP4] Captured %s" % SHOT_SUMMARY)
				var bal_before_cont: int = EconomyManager.get_sunbursts()
				var summary: DaySummaryModal = _farm.sleep_dialog.get_day_summary_modal()
				summary.confirm_continue()
				assert(EconomyManager.get_sunbursts() == bal_before_cont + 815, "Continue must credit exact 815 Sunbursts!")
				assert(not EconomyManager.has_pending_shipments(), "Committed shipments must clear queue.")
				print("[VerifyP4] PASS: DaySummaryModal itemized revenue ledger & exact Sunbursts credit verified (+815 G).")
				print("[VerifyP4] ALL PHASE 4 AUTOMATED CHECKS PASSED!")
				get_tree().quit(0)


func _test_shop_and_tool_upgrades() -> void:
	# A. Maren's Seed Shop: Buy 3 Sunflower Seeds (3 x 60 = 180 G) & Direct Sell 2 Carrots (2 x 45 = 90 G)
	assert(EconomyManager.get_sunbursts() == 500, "Must start with 500 Sunbursts.")
	var sf_before: int = InventoryManager.count_item(&"seed_sunflower")
	assert(EconomyManager.buy_item(&"seed_sunflower", 3), "Buying 3 Sunflower Seeds should succeed.")
	assert(EconomyManager.get_sunbursts() == 320, "Balance should drop 500 -> 320 G (got %d)." % EconomyManager.get_sunbursts())
	assert(InventoryManager.count_item(&"seed_sunflower") == sf_before + 3, "Backpack should receive +3 Sunflower Seeds.")

	InventoryManager.add_item(&"crop_carrot", 2)
	var carrot_slot: int = _find_slot_with(&"crop_carrot")
	assert(carrot_slot >= 0, "Expected carrot slot.")
	var earned: int = EconomyManager.sell_from_inventory_slot(carrot_slot, 2)
	assert(earned == 90 and EconomyManager.get_sunbursts() == 410, "Selling 2 Carrots must earn +90 G -> 410 G.")
	assert(InventoryManager.count_item(&"crop_carrot") == 0, "Sold carrots must be removed from pack.")
	print("[VerifyP4] PASS: Maren's Shop buy & direct backpack sell verified (500 -> 320 -> 410 G).")

	# B. Kaelen's Blacksmith Tool Upgrades (Basic -> Copper -> Iron) + Real Gameplay Upgrades!
	# Verify Basic Pickaxe is blocked on Copper-tier BOULDER_LARGE
	var large_boulder: ResourceNode = null
	for n: Node in get_tree().get_nodes_in_group(&"resource_nodes"):
		var rn: ResourceNode = n as ResourceNode
		if rn != null and rn.node_kind == ResourceNode.NodeKind.BOULDER_LARGE:
			large_boulder = rn
			break
	assert(large_boulder != null, "Expected Copper-tier BOULDER_LARGE in quarry.")

	var b_cell: Vector2i = large_boulder.get_grid_cell()
	_farm.player.global_position = Vector2(float(b_cell.x) * 16.0 + 8.0, float(b_cell.y + 1) * 16.0 + 8.0)
	_farm.player.set_facing_cardinal(Vector2i(0, -1))
	InventoryManager.select_hotbar_slot(3) # Pickaxe
	var blocked_res: ActionValidator.ActionResult = _farm.player.use_selected_item(false, true)
	assert(not blocked_res.valid and blocked_res.required_tier_blocked == int(ToolData.ToolTier.COPPER), "Basic Pickaxe must be blocked on Copper boulder!")

	# Upgrade Pickaxe to Copper (250 G + 10 Wood + 10 Rock)
	InventoryManager.add_item(&"wood", 30)
	InventoryManager.add_item(&"stone", 30)
	EconomyManager.set_sunbursts(1500)
	assert(EconomyManager.upgrade_tool(&"tool_pickaxe"), "Upgrading Pickaxe to Copper must succeed.")
	var pick: ToolData = InventoryManager.get_tool(&"tool_pickaxe")
	assert(pick.tier == ToolData.ToolTier.COPPER and pick.power == 2, "Copper Pickaxe must have tier=COPPER & power=2.")
	# Copper Pickaxe now validates & breaks BOULDER_LARGE in 3 hits (6 HP / power 2)!
	for _h: int in range(3):
		var hit_res: ActionValidator.ActionResult = _farm.player.use_selected_item(true, true)
		assert(hit_res.valid and hit_res.kind == ActionValidator.ActionKind.HIT_RESOURCE, "Copper Pickaxe must hit BOULDER_LARGE!")
		_farm.player.set_controls_locked(true)
		_farm.player.set_controls_locked(false)
	assert(large_boulder.is_destroyed(), "Copper Pickaxe must break BOULDER_LARGE in 3 hits!")

	# Upgrade Hoe to Copper -> Vitality cost drops 2.0 -> 1.0!
	assert(EconomyManager.upgrade_tool(&"tool_hoe"), "Upgrading Hoe to Copper must succeed.")
	assert(is_equal_approx(InventoryManager.get_tool(&"tool_hoe").vitality_cost, 1.0), "Copper Hoe must reduce Vitality cost to 1.0!")

	# Upgrade Watering Can Basic (40) -> Copper (60) -> Iron (80) using smelted Copper & Iron Bars!
	assert(EconomyManager.upgrade_tool(&"tool_watering_can"), "Watering Can Basic -> Copper must succeed.")
	assert(InventoryManager.get_tool(&"tool_watering_can").max_charges == 60, "Copper Watering Can max charges must be 60!")
	assert(InventoryManager.get_slot_charges(1) == 60, "Upgrading Watering Can must refill charges to 60!")

	InventoryManager.add_item(&"stone", 30)
	InventoryManager.add_item(&"wood", 20)
	assert(_farm.furnace_modal.smelt_bar(&"copper_bar"), "Furnace must smelt Copper Bar from 5 Rock + 2 Wood.")
	assert(_farm.furnace_modal.smelt_bar(&"copper_bar"), "Furnace must smelt 2nd Copper Bar.")
	assert(_farm.furnace_modal.smelt_bar(&"iron_bar"), "Furnace must smelt Iron Bar from 8 Rock + 3 Wood.")
	assert(_farm.furnace_modal.smelt_bar(&"iron_bar"), "Furnace must smelt 2nd Iron Bar.")
	assert(EconomyManager.upgrade_tool(&"tool_watering_can"), "Watering Can Copper -> Iron must succeed with smelted bars!")
	assert(InventoryManager.get_tool(&"tool_watering_can").max_charges == 80, "Iron Watering Can max charges must be 80!")
	assert(InventoryManager.get_slot_charges(1) == 80, "Iron Watering Can must refill to 80/80!")
	print("[VerifyP4] PASS: Kaelen's upgrades (Copper Pickaxe breaks boulder, Hoe Vit 2->1, Watering Can 40->60->80 + Furnace smelting) verified.")


func _test_crafting_placement_and_furnace() -> void:
	InventoryManager.reset_to_starter_loadout()
	InventoryManager.add_item(&"wood", 50)
	InventoryManager.add_item(&"stone", 40)
	InventoryManager.add_item(&"fiber", 20)

	# Craft ALL 6 recipes cleanly!
	for rid: StringName in [&"recipe_chest", &"recipe_fence", &"recipe_torch", &"recipe_stone_path", &"recipe_scarecrow", &"recipe_furnace"]:
		assert(InventoryManager.can_craft_recipe(rid), "Should be able to craft %s" % String(rid))
		assert(InventoryManager.craft_recipe(rid), "Failed crafting %s" % String(rid))

	# Verify ActionValidator strictly blocks placing objects on water and roads (dynamically via WorldMarkers!)
	var chest_slot: int = _find_slot_with(&"place_chest")
	assert(chest_slot >= 0, "Crafted Storage Chest missing from pack.")
	InventoryManager.swap_slots(6, chest_slot)
	InventoryManager.select_hotbar_slot(6)

	var river_bank: Vector2i = _world_to_cell(_farm.get_world_marker_position("RiverBankSpot"))
	_farm.player.global_position = Vector2(float(river_bank.x) * 16.0 + 8.0, float(river_bank.y) * 16.0 + 8.0)
	_farm.player.set_facing_cardinal(Vector2i(-1, 0))
	var bad_water: ActionValidator.ActionResult = _farm.player.use_selected_item(false, true)
	assert(not bad_water.valid and bad_water.reason == "Can't place on water", "Placing chest on water must be blocked!")

	var door_cell: Vector2i = _world_to_cell(_farm.get_world_marker_position("FarmhouseDoor"))
	_farm.player.global_position = Vector2(float(door_cell.x) * 16.0 + 8.0, float(door_cell.y + 1) * 16.0 + 8.0)
	_farm.player.set_facing_cardinal(Vector2i(0, 1))
	var bad_road: ActionValidator.ActionResult = _farm.player.use_selected_item(false, true)
	assert(not bad_road.valid and bad_road.reason == "Can't place on roads", "Placing chest on road must be blocked!")

	# Place Storage Chest via Player ActionValidator on valid open farm meadow cell (dynamic OpenMeadowSpot)!
	var meadow_origin: Vector2i = _world_to_cell(_farm.get_world_marker_position("OpenMeadowSpot"))
	_chest_cell = meadow_origin
	_torch_cell = meadow_origin + Vector2i(2, 0)
	_farm.player.global_position = Vector2(float(_chest_cell.x) * 16.0 + 8.0, float(_chest_cell.y + 1) * 16.0 + 8.0)
	_farm.player.set_facing_cardinal(Vector2i(0, -1))
	var ok_place: ActionValidator.ActionResult = _farm.player.use_selected_item(true, true)
	assert(ok_place.valid and ok_place.kind == ActionValidator.ActionKind.PLACE_OBJECT, "Placing Storage Chest on clear meadow must succeed (reason=%s)!" % ok_place.reason)
	_farm.player.set_controls_locked(true)
	_farm.player.set_controls_locked(false)
	assert(_farm.get_placed_object_node(_chest_cell) is PlacedChest, "PlacedChest node must spawn at %s!" % str(_chest_cell))

	# Store 5 Parsnips inside the placed Storage Chest!
	InventoryManager.add_item(&"crop_parsnip", 5)
	var p_slot: int = _find_slot_with(&"crop_parsnip")
	assert(PlacedChest.deposit_from_inventory_slot(_farm.scene_id, _chest_cell, p_slot), "Must deposit 5 Parsnips into PlacedChest!")
	assert(InventoryManager.count_item(&"crop_parsnip") == 0, "Deposited parsnips must move out of backpack.")

	# Place Outdoor Torch, Wooden Fence, Stone Path, Scarecrow, and Stone Furnace neatly in the open farm yard!
	assert(GridStateManager.place_object(_farm.scene_id, _torch_cell, &"torch"), "Place Outdoor Torch failed.")
	assert(GridStateManager.place_object(_farm.scene_id, meadow_origin + Vector2i(-1, 0), &"fence"), "Place Wooden Fence failed.")
	assert(GridStateManager.place_object(_farm.scene_id, meadow_origin + Vector2i(-1, 1), &"fence"), "Place Wooden Fence 2 failed.")
	assert(GridStateManager.place_object(_farm.scene_id, meadow_origin + Vector2i(0, 1), &"stone_path"), "Place Stone Path failed.")
	assert(GridStateManager.place_object(_farm.scene_id, meadow_origin + Vector2i(1, 1), &"stone_path"), "Place Stone Path 2 failed.")
	assert(GridStateManager.place_object(_farm.scene_id, meadow_origin + Vector2i(1, -1), &"scarecrow"), "Place Scarecrow failed.")
	assert(GridStateManager.place_object(_farm.scene_id, meadow_origin + Vector2i(3, 0), &"furnace"), "Place Stone Furnace failed.")
	assert(GridStateManager.is_cell_protected_by_scarecrow(_farm.scene_id, meadow_origin + Vector2i(0, 2)), "Scarecrow must protect crops within 5 tiles!")
	print("[VerifyP4] PASS: Crafted & placed Chest (16-slot), Torch, Fence, Stone Path, Scarecrow & Furnace + placement blocking verified.")


func _test_shipping_and_persistence() -> void:
	# A. Verify ShippingBin deposit + Undo Last + Re-ship + Bed Sleep inside FarmhouseInterior!
	EconomyManager.reset_economy()
	InventoryManager.add_item(&"crop_parsnip", 3)
	InventoryManager.add_item(&"fish", 2)
	var p_slot: int = _find_slot_with(&"crop_parsnip")
	var f_slot: int = _find_slot_with(&"fish")
	assert(EconomyManager.ship_from_inventory_slot(p_slot, 3), "Ship 3 Parsnips failed.")
	assert(EconomyManager.ship_from_inventory_slot(f_slot, 2), "Ship 2 Fish failed.")
	assert(EconomyManager.get_pending_shipped_total() == 195, "Expected 3*35 + 2*45 = 195 G pending.")

	var undone: Dictionary = EconomyManager.undo_last_shipped()
	assert(not undone.is_empty() and (undone["item_id"] as StringName) == &"fish", "Undo Last must return 2 Fish!")
	assert(InventoryManager.count_item(&"fish") == 2, "Undone Fish must return to InventoryManager!")
	var f_slot2: int = _find_slot_with(&"fish")
	assert(EconomyManager.ship_from_inventory_slot(f_slot2, 2), "Re-shipping 2 Fish must succeed.")

	# Enter FarmhouseInterior, sleep in the Red Bed (immediate=true), verify +195 G credited & Day 2!
	var int_packed: PackedScene = load(INTERIOR_SCENE_PATH) as PackedScene
	var interior: FarmhouseInterior = int_packed.instantiate() as FarmhouseInterior
	add_child(interior)
	# Also confirm placeable items are blocked indoors via ActionValidator!
	InventoryManager.add_item(&"place_torch", 1)
	var t_slot: int = _find_slot_with(&"place_torch")
	InventoryManager.swap_slots(7, t_slot)
	InventoryManager.select_hotbar_slot(7)
	var indoor_place: ActionValidator.ActionResult = interior.player.use_selected_item(false, true)
	assert(not indoor_place.valid and indoor_place.reason == "Can't place objects indoors", "Placing objects indoors must be blocked!")

	interior.sleep_dialog.begin_sleep_transition(Callable(), TimeManager.WEATHER_SUNNY, true)
	assert(TimeManager.current_day == 2, "Sleeping in FarmhouseInterior bed must advance to Day 2.")
	assert(EconomyManager.get_sunbursts() == 695, "Bed sleep must settle +195 G -> 695 G (got %d)." % EconomyManager.get_sunbursts())
	interior.queue_free()

	# Exit back to fresh FarmSanctuary instance -> assert PlacedChest (+ 5 Parsnips!) & Outdoor Torch persisted cleanly!
	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	var farm_reloaded: FarmSanctuary = farm_packed.instantiate() as FarmSanctuary
	add_child(farm_reloaded)
	var chest_node: PlacedChest = farm_reloaded.get_placed_object_node(_chest_cell) as PlacedChest
	assert(chest_node != null, "PlacedChest MUST persist across FarmhouseInterior round-trip & overnight sleep!")
	var stored_slots: Array[Dictionary] = PlacedChest.get_chest_slots(farm_reloaded.scene_id, _chest_cell)
	assert(String(stored_slots[0]["id"]) == "crop_parsnip" and int(stored_slots[0]["count"]) == 5, "Stored 5 Parsnips inside PlacedChest MUST persist!")
	assert(farm_reloaded.get_placed_object_node(_torch_cell) != null, "Outdoor Torch MUST persist across door transition & sleep!")
	farm_reloaded.queue_free()
	print("[VerifyP4] PASS: ShippingBin + Undo + Bed Sleep settlement + Chest contents & Torch persistence across house/sleep verified.")


func _find_slot_with(item_id: StringName) -> int:
	for i: int in range(InventoryManager.SLOT_COUNT):
		if InventoryManager.get_slot_item_id(i) == item_id:
			return i
	return -1


func _save_viewport_png(res_path: String) -> void:
	var out_path: String = ProjectSettings.globalize_path(res_path)
	var img: Image = get_viewport().get_texture().get_image()
	assert(img != null, "Failed to read viewport texture.")
	assert(img.get_width() >= 1280 and img.get_height() >= 720, "Expected 1280x720 capture, got %dx%d" % [img.get_width(), img.get_height()])
	var err: Error = img.save_png(out_path)
	assert(err == OK, "Failed to save %s (err=%d)" % [out_path, err])
