extends Node

## Manages the 24-slot player backpack (slots 0..7 = Hotbar), stack merging,
## watering can charges, and pre-indexed O(1) lookups for all ItemData, ToolData, and CropData.

const AP := preload("res://scripts/core/asset_paths.gd")

const SLOT_COUNT: int = 24
const HOTBAR_SIZE: int = 8

# Structure-of-Arrays flat slot storage (zero per-frame allocations)
var _slot_ids: Array[StringName] = []
var _slot_counts: PackedInt32Array = PackedInt32Array()
var _slot_charges: PackedInt32Array = PackedInt32Array()

var selected_hotbar_index: int = 0

# Pre-indexed O(1) resource databases
var _items: Dictionary = {} # StringName -> ItemData
var _tools: Dictionary = {} # StringName -> ToolData
var _crops: Dictionary = {} # StringName -> CropData
var _recipes: Dictionary = {} # StringName -> RecipeData
var _recipe_order: Array[StringName] = []


func _ready() -> void:
	_load_databases()
	_init_empty_slots()
	reset_to_starter_loadout()


func _load_databases() -> void:
	var tool_ids: PackedStringArray = [
		"tool_hoe",
		"tool_watering_can",
		"tool_axe",
		"tool_pickaxe",
		"tool_scythe",
		"tool_fishing_rod",
	]
	for tid: String in tool_ids:
		var path: String = "res://resources/tools/%s.tres" % tid
		var tool_res: ToolData = load(path) as ToolData
		assert(tool_res != null, "Missing tool resource: %s" % path)
		# Duplicate so runtime tool tier upgrades do not mutate on-disk .tres cache
		var inst: ToolData = tool_res.duplicate() as ToolData
		_items[inst.id] = inst
		_tools[inst.id] = inst

	for stem: String in AP.CROP_STEMS:
		var crop_path: String = "res://resources/crops/crop_%s.tres" % stem
		var crop_res: CropData = load(crop_path) as CropData
		assert(crop_res != null, "Missing crop resource: %s" % crop_path)
		_crops[crop_res.crop_id] = crop_res

		var seed_path: String = "res://resources/items/seed_%s.tres" % stem
		var seed_res: ItemData = load(seed_path) as ItemData
		assert(seed_res != null, "Missing seed resource: %s" % seed_path)
		_items[seed_res.id] = seed_res

		var produce_path: String = "res://resources/items/item_%s.tres" % stem
		var produce_res: ItemData = load(produce_path) as ItemData
		assert(produce_res != null, "Missing produce resource: %s" % produce_path)
		_items[produce_res.id] = produce_res

	var core_items: PackedStringArray = [
		"item_wood",
		"item_stone",
		"item_fiber",
		"item_wild_berry",
		"item_fish",
	]
	for cname: String in core_items:
		var cpath: String = "res://resources/items/%s.tres" % cname
		var cres: ItemData = load(cpath) as ItemData
		assert(cres != null, "Missing core resource item: %s" % cpath)
		_items[cres.id] = cres

	# Phase 4 smelted bars & placeable craftable items (guarded for first-time resource generation)
	var phase4_items: PackedStringArray = [
		"item_copper_bar",
		"item_iron_bar",
		"item_placed_chest",
		"item_wooden_fence",
		"item_outdoor_torch",
		"item_stone_path",
		"item_scarecrow",
		"item_furnace",
	]
	for p4_name: String in phase4_items:
		var p4_path: String = "res://resources/items/%s.tres" % p4_name
		if ResourceLoader.exists(p4_path):
			var p4_res: ItemData = load(p4_path) as ItemData
			if p4_res != null:
				_items[p4_res.id] = p4_res

	# Phase 5 biome-specific fish species (guarded for first-time resource generation)
	var phase5_fish_items: PackedStringArray = [
		"item_fish_river_trout",
		"item_fish_sun_perch",
		"item_fish_golden_carp",
		"item_fish_spring_koi",
		"item_fish_mountain_minnow",
		"item_fish_sea_bass",
		"item_fish_ocean_snapper",
		"item_fish_coral_flounder",
	]
	for f_name: String in phase5_fish_items:
		var f_path: String = "res://resources/items/%s.tres" % f_name
		if ResourceLoader.exists(f_path):
			var f_res: ItemData = load(f_path) as ItemData
			if f_res != null:
				_items[f_res.id] = f_res

	# Phase 6 mine cave ores, gems & monster loot (guarded for first-time resource generation)
	var phase6_items: PackedStringArray = [
		"item_copper_ore",
		"item_iron_ore",
		"item_cave_crystal",
		"item_cave_ruby",
		"item_shadow_shard",
	]
	for p6_name: String in phase6_items:
		var p6_path: String = "res://resources/items/%s.tres" % p6_name
		if ResourceLoader.exists(p6_path):
			var p6_res: ItemData = load(p6_path) as ItemData
			if p6_res != null:
				_items[p6_res.id] = p6_res

	var recipe_files: PackedStringArray = [
		"recipe_chest",
		"recipe_fence",
		"recipe_torch",
		"recipe_stone_path",
		"recipe_scarecrow",
		"recipe_furnace",
	]
	_recipes.clear()
	_recipe_order.clear()
	for rname: String in recipe_files:
		var rpath: String = "res://resources/recipes/%s.tres" % rname
		if ResourceLoader.exists(rpath):
			var rres: RecipeData = load(rpath) as RecipeData
			if rres != null:
				_recipes[rres.id] = rres
				_recipe_order.append(rres.id)


func _init_empty_slots() -> void:
	_slot_ids.resize(SLOT_COUNT)
	_slot_counts.resize(SLOT_COUNT)
	_slot_charges.resize(SLOT_COUNT)
	for i: int in range(SLOT_COUNT):
		_slot_ids[i] = &""
		_slot_counts[i] = 0
		_slot_charges[i] = 0


func reset_to_starter_loadout() -> void:
	for i: int in range(SLOT_COUNT):
		_slot_ids[i] = &""
		_slot_counts[i] = 0
		_slot_charges[i] = 0

	# Hotbar slots 0..5 = all 6 starter tools; slots 6..7 = starter seeds
	_set_slot_raw(0, &"tool_hoe", 1, 0)
	_set_slot_raw(1, &"tool_watering_can", 1, 40)
	_set_slot_raw(2, &"tool_axe", 1, 0)
	_set_slot_raw(3, &"tool_pickaxe", 1, 0)
	_set_slot_raw(4, &"tool_scythe", 1, 0)
	_set_slot_raw(5, &"tool_fishing_rod", 1, 0)
	_set_slot_raw(6, &"seed_parsnip", 12, 0)
	_set_slot_raw(7, &"seed_sunflower", 6, 0)

	# Backpack starter variety seeds
	_set_slot_raw(8, &"seed_carrot", 6, 0)
	_set_slot_raw(9, &"seed_potato", 6, 0)
	_set_slot_raw(10, &"seed_radish", 6, 0)

	# Reset runtime tool tiers cleanly back to Basic
	for tid: Variant in _tools.keys():
		var t: ToolData = _tools[tid] as ToolData
		t.tier = ToolData.ToolTier.BASIC
		t.power = 1
		if t.tool_kind == ToolData.ToolKind.WATERING_CAN:
			t.max_charges = 40
		elif t.tool_kind == ToolData.ToolKind.HOE:
			t.vitality_cost = 2.0

	selected_hotbar_index = 0
	EventBus.inventory_changed.emit()
	EventBus.hotbar_selection_changed.emit(selected_hotbar_index)
	EventBus.watering_can_changed.emit(40, 40)


func get_recipe(recipe_id: StringName) -> RecipeData:
	return _recipes.get(recipe_id, null) as RecipeData


func get_all_recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for rid: StringName in _recipe_order:
		var r: RecipeData = _recipes.get(rid, null) as RecipeData
		if r != null:
			out.append(r)
	return out


func can_fit_item(item_id: StringName, amount: int) -> bool:
	assert(amount > 0, "can_fit_item requires amount > 0")
	var data: ItemData = get_item(item_id)
	if data == null:
		return false
	var max_stk: int = maxi(1, data.max_stack)
	var capacity: int = 0
	for i: int in range(SLOT_COUNT):
		if _slot_ids[i] == &"":
			capacity += max_stk
		elif _slot_ids[i] == item_id and max_stk > 1:
			capacity += maxi(0, max_stk - _slot_counts[i])
		if capacity >= amount:
			return true
	return false


func can_craft_recipe(recipe_id: StringName) -> bool:
	var r: RecipeData = get_recipe(recipe_id)
	if r == null:
		return false
	var ing_n: int = r.get_ingredient_count()
	for i: int in range(ing_n):
		if count_item(r.ingredient_ids[i]) < r.ingredient_counts[i]:
			return false
	return can_fit_item(r.output_item_id, r.output_count)


func craft_recipe(recipe_id: StringName) -> bool:
	if not can_craft_recipe(recipe_id):
		return false
	var r: RecipeData = get_recipe(recipe_id)
	var ing_n: int = r.get_ingredient_count()
	for i: int in range(ing_n):
		var ok: bool = remove_item(r.ingredient_ids[i], r.ingredient_counts[i])
		assert(ok, "Ingredient verification mismatch while crafting %s" % String(recipe_id))
	var leftover: int = add_item(r.output_item_id, r.output_count)
	assert(leftover == 0, "Space verification mismatch while crafting %s" % String(recipe_id))
	EventBus.item_crafted.emit(r.id, r.output_item_id, r.output_count)
	return true


func _set_slot_raw(index: int, item_id: StringName, count: int, charges: int) -> void:
	assert(index >= 0 and index < SLOT_COUNT, "Inventory slot out of bounds: %d" % index)
	assert(item_id == &"" or _items.has(item_id), "Unknown item_id: %s" % String(item_id))
	_slot_ids[index] = item_id
	_slot_counts[index] = count
	_slot_charges[index] = charges


func get_item(item_id: StringName) -> ItemData:
	return _items.get(item_id, null) as ItemData


func get_tool(tool_id: StringName) -> ToolData:
	return _tools.get(tool_id, null) as ToolData


func get_crop(crop_id: StringName) -> CropData:
	return _crops.get(crop_id, null) as CropData


func get_all_crops() -> Array[CropData]:
	var out: Array[CropData] = []
	for stem: String in AP.CROP_STEMS:
		var c: CropData = get_crop(StringName(stem))
		if c != null:
			out.append(c)
	return out


func get_slot_item_id(index: int) -> StringName:
	assert(index >= 0 and index < SLOT_COUNT, "Slot index out of bounds.")
	return _slot_ids[index]


func get_slot_count(index: int) -> int:
	assert(index >= 0 and index < SLOT_COUNT, "Slot index out of bounds.")
	return _slot_counts[index]


func get_slot_charges(index: int) -> int:
	assert(index >= 0 and index < SLOT_COUNT, "Slot index out of bounds.")
	return _slot_charges[index]


func select_hotbar_slot(index: int) -> void:
	var clamped: int = clampi(index, 0, HOTBAR_SIZE - 1)
	if clamped == selected_hotbar_index:
		return
	selected_hotbar_index = clamped
	EventBus.hotbar_selection_changed.emit(selected_hotbar_index)


func cycle_hotbar(delta: int) -> void:
	var next_idx: int = posmod(selected_hotbar_index + delta, HOTBAR_SIZE)
	select_hotbar_slot(next_idx)


func get_selected_item_id() -> StringName:
	return _slot_ids[selected_hotbar_index]


func get_selected_item_data() -> ItemData:
	var id: StringName = _slot_ids[selected_hotbar_index]
	return get_item(id) if id != &"" else null


func get_selected_tool_data() -> ToolData:
	var id: StringName = _slot_ids[selected_hotbar_index]
	return get_tool(id) if id != &"" else null


func get_selected_slot_count() -> int:
	return _slot_counts[selected_hotbar_index]


func get_selected_slot_charges() -> int:
	return _slot_charges[selected_hotbar_index]


## Adds up to `amount` of `item_id`, merging onto existing stacks first.
## Returns leftover count that did not fit (0 means all items were added).
func add_item(item_id: StringName, amount: int) -> int:
	assert(amount > 0, "add_item requires amount > 0")
	var data: ItemData = get_item(item_id)
	assert(data != null, "Attempted to add unknown item_id: %s" % String(item_id))

	var remaining: int = amount
	var max_stk: int = maxi(1, data.max_stack)

	# Pass 1: Merge into existing matching stacks
	if max_stk > 1:
		for i: int in range(SLOT_COUNT):
			if _slot_ids[i] == item_id and _slot_counts[i] < max_stk:
				var space: int = max_stk - _slot_counts[i]
				var to_add: int = mini(space, remaining)
				_slot_counts[i] += to_add
				remaining -= to_add
				if remaining == 0:
					break

	# Pass 2: Place into empty slots
	if remaining > 0:
		var init_charges: int = 0
		if data is ToolData:
			init_charges = (data as ToolData).max_charges
		for i: int in range(SLOT_COUNT):
			if _slot_ids[i] == &"":
				var to_add: int = mini(max_stk, remaining)
				_slot_ids[i] = item_id
				_slot_counts[i] = to_add
				_slot_charges[i] = init_charges
				remaining -= to_add
				if remaining == 0:
					break

	if remaining < amount:
		EventBus.inventory_changed.emit()
	return remaining


func remove_from_slot(slot_index: int, amount: int) -> bool:
	assert(slot_index >= 0 and slot_index < SLOT_COUNT, "Slot index out of bounds.")
	assert(amount > 0, "remove_from_slot requires amount > 0")
	if _slot_ids[slot_index] == &"" or _slot_counts[slot_index] < amount:
		return false
	_slot_counts[slot_index] -= amount
	if _slot_counts[slot_index] <= 0:
		_slot_ids[slot_index] = &""
		_slot_counts[slot_index] = 0
		_slot_charges[slot_index] = 0
	EventBus.inventory_changed.emit()
	return true


func remove_item(item_id: StringName, amount: int) -> bool:
	assert(amount > 0, "remove_item requires amount > 0")
	if count_item(item_id) < amount:
		return false
	var remaining: int = amount
	for i: int in range(SLOT_COUNT - 1, -1, -1):
		if _slot_ids[i] == item_id:
			var take: int = mini(_slot_counts[i], remaining)
			_slot_counts[i] -= take
			remaining -= take
			if _slot_counts[i] <= 0:
				_slot_ids[i] = &""
				_slot_counts[i] = 0
				_slot_charges[i] = 0
			if remaining == 0:
				break
	EventBus.inventory_changed.emit()
	return true


func count_item(item_id: StringName) -> int:
	var total: int = 0
	for i: int in range(SLOT_COUNT):
		if _slot_ids[i] == item_id:
			total += _slot_counts[i]
	return total


func find_tool_slot(tool_kind: ToolData.ToolKind) -> int:
	for i: int in range(SLOT_COUNT):
		var t: ToolData = get_tool(_slot_ids[i])
		if t != null and t.tool_kind == tool_kind:
			return i
	return -1


func consume_watering_can_charge() -> bool:
	var tool: ToolData = get_selected_tool_data()
	if tool == null or tool.tool_kind != ToolData.ToolKind.WATERING_CAN:
		return false
	if _slot_charges[selected_hotbar_index] <= 0:
		return false
	_slot_charges[selected_hotbar_index] -= 1
	EventBus.watering_can_changed.emit(_slot_charges[selected_hotbar_index], tool.max_charges)
	EventBus.inventory_changed.emit()
	return true


func refill_watering_can() -> bool:
	var tool: ToolData = get_selected_tool_data()
	if tool == null or tool.tool_kind != ToolData.ToolKind.WATERING_CAN:
		return false
	_slot_charges[selected_hotbar_index] = tool.max_charges
	EventBus.watering_can_changed.emit(_slot_charges[selected_hotbar_index], tool.max_charges)
	EventBus.inventory_changed.emit()
	return true


func upgrade_tool_tier(tool_id: StringName, new_tier: ToolData.ToolTier) -> bool:
	var tool: ToolData = get_tool(tool_id)
	if tool == null:
		return false
	tool.tier = new_tier
	tool.power = int(new_tier)
	if tool.tool_kind == ToolData.ToolKind.WATERING_CAN:
		tool.max_charges = 40 + (int(new_tier) - 1) * 20
		var can_slot: int = find_tool_slot(ToolData.ToolKind.WATERING_CAN)
		if can_slot >= 0:
			_slot_charges[can_slot] = tool.max_charges
			EventBus.watering_can_changed.emit(_slot_charges[can_slot], tool.max_charges)
	elif tool.tool_kind == ToolData.ToolKind.HOE:
		tool.vitality_cost = 1.0 if int(new_tier) >= int(ToolData.ToolTier.COPPER) else 2.0
	EventBus.tool_upgraded.emit(tool_id, int(new_tier))
	EventBus.inventory_changed.emit()
	return true


func swap_slots(index_a: int, index_b: int) -> void:
	assert(index_a >= 0 and index_a < SLOT_COUNT and index_b >= 0 and index_b < SLOT_COUNT, "Swap slot bounds error.")
	if index_a == index_b:
		return
	var tmp_id: StringName = _slot_ids[index_a]
	var tmp_cnt: int = _slot_counts[index_a]
	var tmp_chg: int = _slot_charges[index_a]
	_slot_ids[index_a] = _slot_ids[index_b]
	_slot_counts[index_a] = _slot_counts[index_b]
	_slot_charges[index_a] = _slot_charges[index_b]
	_slot_ids[index_b] = tmp_id
	_slot_counts[index_b] = tmp_cnt
	_slot_charges[index_b] = tmp_chg
	EventBus.inventory_changed.emit()


func serialize() -> Dictionary:
	var slots_arr: Array[Dictionary] = []
	for i: int in range(SLOT_COUNT):
		slots_arr.append({
			"id": String(_slot_ids[i]),
			"count": _slot_counts[i],
			"charges": _slot_charges[i],
		})
	var tool_tiers: Dictionary = {}
	for tid: Variant in _tools.keys():
		var t: ToolData = _tools[tid] as ToolData
		tool_tiers[String(tid)] = int(t.tier)
	return {
		"selected_hotbar_index": selected_hotbar_index,
		"slots": slots_arr,
		"tool_tiers": tool_tiers,
	}


func deserialize(data: Dictionary) -> void:
	_init_empty_slots()
	var tool_tiers: Dictionary = data.get("tool_tiers", {}) as Dictionary
	for tid_str: Variant in tool_tiers.keys():
		var tid: StringName = StringName(String(tid_str))
		var tier_val: int = clampi(int(tool_tiers[tid_str]), ToolData.ToolTier.BASIC, ToolData.ToolTier.IRON)
		upgrade_tool_tier(tid, tier_val as ToolData.ToolTier)
	var slots_arr: Array = data.get("slots", []) as Array
	var limit: int = mini(slots_arr.size(), SLOT_COUNT)
	for i: int in range(limit):
		var entry: Dictionary = slots_arr[i] as Dictionary
		var item_id: StringName = StringName(String(entry.get("id", "")))
		var cnt: int = maxi(0, int(entry.get("count", 0)))
		var chg: int = maxi(0, int(entry.get("charges", 0)))
		if item_id != &"" and _items.has(item_id) and cnt > 0:
			_set_slot_raw(i, item_id, cnt, chg)
	selected_hotbar_index = clampi(int(data.get("selected_hotbar_index", 0)), 0, HOTBAR_SIZE - 1)
	EventBus.inventory_changed.emit()
	EventBus.hotbar_selection_changed.emit(selected_hotbar_index)
