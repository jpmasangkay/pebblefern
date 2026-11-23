extends Node

## Manages Pebblefern's economy: Sunbursts (G) currency, Sanctuary Shipping Chest overnight ledger
## with Undo-Last support, Maren's Seed Shop buy/sell, and Kaelen's Blacksmith tool upgrades.

const STARTING_SUNBURSTS: int = 500
const MAX_SHIPPED_STACKS: int = 128

const UPGRADEABLE_TOOLS: Array[StringName] = [
	&"tool_hoe",
	&"tool_watering_can",
	&"tool_axe",
	&"tool_pickaxe",
]

var sunbursts: int = STARTING_SUNBURSTS
var _shipped_queue: Array[Dictionary] = [] # [{ "item_id": StringName, "count": int, "unit_price": int }]
var _last_settled_ledger: Dictionary = {}


func _ready() -> void:
	reset_economy()


func reset_economy() -> void:
	sunbursts = STARTING_SUNBURSTS
	_shipped_queue.clear()
	_last_settled_ledger.clear()
	EventBus.currency_changed.emit(sunbursts, 0)
	EventBus.shipping_ledger_changed.emit()


func get_sunbursts() -> int:
	return sunbursts


func set_sunbursts(amount: int) -> void:
	var clamped: int = maxi(0, amount)
	var delta: int = clamped - sunbursts
	sunbursts = clamped
	EventBus.currency_changed.emit(sunbursts, delta)


func add_sunbursts(delta: int) -> int:
	assert(delta >= 0, "add_sunbursts expects non-negative delta; use spend_sunbursts to deduct.")
	sunbursts += delta
	EventBus.currency_changed.emit(sunbursts, delta)
	return sunbursts


func can_afford(amount: int) -> bool:
	return amount >= 0 and sunbursts >= amount


func spend_sunbursts(amount: int) -> bool:
	assert(amount >= 0, "spend_sunbursts requires non-negative amount.")
	if amount == 0:
		return true
	if sunbursts < amount:
		return false
	sunbursts -= amount
	EventBus.currency_changed.emit(sunbursts, -amount)
	return true


# ------------------------------------------------------------------------------
# SANCTUARY SHIPPING CHEST LEDGER
# ------------------------------------------------------------------------------
func ship_from_inventory_slot(slot_index: int, quantity: int) -> bool:
	assert(quantity > 0, "ship_from_inventory_slot requires quantity > 0.")
	if _shipped_queue.size() >= MAX_SHIPPED_STACKS:
		return false
	var item_id: StringName = InventoryManager.get_slot_item_id(slot_index)
	var avail: int = InventoryManager.get_slot_count(slot_index)
	if item_id == &"" or avail < quantity:
		return false
	var item: ItemData = InventoryManager.get_item(item_id)
	if item == null or not item.is_sellable():
		return false
	if not InventoryManager.remove_from_slot(slot_index, quantity):
		return false
	_shipped_queue.append({
		"item_id": item_id,
		"count": quantity,
		"unit_price": item.sell_price,
	})
	EventBus.shipping_ledger_changed.emit()
	return true


func ship_item_direct(item_id: StringName, quantity: int) -> bool:
	assert(quantity > 0, "ship_item_direct requires quantity > 0.")
	if _shipped_queue.size() >= MAX_SHIPPED_STACKS:
		return false
	var item: ItemData = InventoryManager.get_item(item_id)
	if item == null or not item.is_sellable():
		return false
	_shipped_queue.append({
		"item_id": item_id,
		"count": quantity,
		"unit_price": item.sell_price,
	})
	EventBus.shipping_ledger_changed.emit()
	return true


## Pops the most recently shipped stack and returns it cleanly to InventoryManager.
func undo_last_shipped() -> Dictionary:
	if _shipped_queue.is_empty():
		return {}
	var last_entry: Dictionary = _shipped_queue[_shipped_queue.size() - 1]
	var item_id: StringName = last_entry["item_id"] as StringName
	var count: int = int(last_entry["count"])
	if not InventoryManager.can_fit_item(item_id, count):
		return {}
	_shipped_queue.pop_back()
	InventoryManager.add_item(item_id, count)
	EventBus.shipping_ledger_changed.emit()
	return last_entry


func has_pending_shipments() -> bool:
	return not _shipped_queue.is_empty()


func get_pending_shipped_count() -> int:
	var total: int = 0
	for entry: Dictionary in _shipped_queue:
		total += int(entry["count"])
	return total


func get_pending_shipped_total() -> int:
	var total: int = 0
	for entry: Dictionary in _shipped_queue:
		total += int(entry["count"]) * int(entry["unit_price"])
	return total


func get_last_shipped_entry() -> Dictionary:
	if _shipped_queue.is_empty():
		return {}
	return (_shipped_queue[_shipped_queue.size() - 1] as Dictionary).duplicate()


## Builds a clean itemized revenue ledger from pending shipments WITHOUT clearing or crediting yet.
func build_pending_ledger(completed_day: int, completed_season: int, completed_year: int) -> Dictionary:
	var agg: Dictionary = {} # StringName -> Dictionary
	var order: Array[StringName] = []
	var grand_total: int = 0

	for entry: Dictionary in _shipped_queue:
		var iid: StringName = entry["item_id"] as StringName
		var cnt: int = int(entry["count"])
		var unit_p: int = int(entry["unit_price"])
		if not agg.has(iid):
			var item_data: ItemData = InventoryManager.get_item(iid)
			var dname: String = item_data.display_name if item_data != null else String(iid)
			agg[iid] = {
				"item_id": iid,
				"display_name": dname,
				"count": 0,
				"unit_price": unit_p,
				"subtotal": 0,
			}
			order.append(iid)
		var row: Dictionary = agg[iid] as Dictionary
		row["count"] = int(row["count"]) + cnt
		row["subtotal"] = int(row["count"]) * int(row["unit_price"])
		grand_total += cnt * unit_p

	var rows: Array[Dictionary] = []
	for iid: StringName in order:
		rows.append(agg[iid] as Dictionary)

	return {
		"day": completed_day,
		"season_index": completed_season,
		"year": completed_year,
		"rows": rows,
		"total_earned": grand_total,
		"balance_before": sunbursts,
		"balance_after": sunbursts + grand_total,
	}


## Commits pending overnight shipments, credits Sunbursts, clears queue, and returns finalized ledger.
func commit_overnight_shipping(completed_day: int, completed_season: int, completed_year: int) -> Dictionary:
	var ledger: Dictionary = build_pending_ledger(completed_day, completed_season, completed_year)
	var earned: int = int(ledger["total_earned"])
	_shipped_queue.clear()
	if earned > 0:
		add_sunbursts(earned)
	ledger["balance_after"] = sunbursts
	_last_settled_ledger = ledger
	EventBus.shipping_ledger_changed.emit()
	return ledger


func get_last_settled_ledger() -> Dictionary:
	return _last_settled_ledger


# ------------------------------------------------------------------------------
# MAREN'S SEED SHOP — BUY & DIRECT SELL
# ------------------------------------------------------------------------------
func buy_item(item_id: StringName, quantity: int) -> bool:
	assert(quantity > 0, "buy_item requires quantity > 0.")
	var item: ItemData = InventoryManager.get_item(item_id)
	if item == null or item.buy_price <= 0:
		return false
	var total_cost: int = item.buy_price * quantity
	if not can_afford(total_cost):
		return false
	if not InventoryManager.can_fit_item(item_id, quantity):
		return false
	if not spend_sunbursts(total_cost):
		return false
	var leftover: int = InventoryManager.add_item(item_id, quantity)
	assert(leftover == 0, "Inventory space check mismatch during buy_item.")
	return true


func sell_from_inventory_slot(slot_index: int, quantity: int) -> int:
	assert(quantity > 0, "sell_from_inventory_slot requires quantity > 0.")
	var item_id: StringName = InventoryManager.get_slot_item_id(slot_index)
	var avail: int = InventoryManager.get_slot_count(slot_index)
	if item_id == &"" or avail < quantity:
		return 0
	var item: ItemData = InventoryManager.get_item(item_id)
	if item == null or not item.is_sellable():
		return 0
	if not InventoryManager.remove_from_slot(slot_index, quantity):
		return 0
	var earned: int = item.sell_price * quantity
	add_sunbursts(earned)
	return earned


# ------------------------------------------------------------------------------
# KAELEN'S BLACKSMITH — TOOL UPGRADES (BASIC -> COPPER -> IRON)
# ------------------------------------------------------------------------------
func get_tool_upgrade_spec(tool_id: StringName) -> Dictionary:
	var tool: ToolData = InventoryManager.get_tool(tool_id)
	if tool == null:
		return {}
	var cur_tier: int = int(tool.tier)
	if cur_tier >= int(ToolData.ToolTier.IRON):
		return {
			"tool_id": tool_id,
			"maxed": true,
			"current_tier": cur_tier,
			"next_tier": cur_tier,
			"next_tier_name": "Max (Iron)",
			"cost_g": 0,
			"materials": [],
			"benefit": "Forged to maximum Iron grade.",
		}

	var next_tier: int = cur_tier + 1
	var next_name: String = "Copper" if next_tier == int(ToolData.ToolTier.COPPER) else "Iron"
	var cost_g: int = 250 if next_tier == int(ToolData.ToolTier.COPPER) else 500
	var materials: Array[Dictionary] = []
	if next_tier == int(ToolData.ToolTier.COPPER):
		materials = [
			{"id": &"wood", "count": 10},
			{"id": &"stone", "count": 10},
		]
	else:
		materials = [
			{"id": &"copper_bar", "count": 2},
			{"id": &"iron_bar", "count": 2},
		]

	var benefit: String = ""
	match tool.tool_kind:
		ToolData.ToolKind.WATERING_CAN:
			var next_cap: int = 40 + (next_tier - 1) * 20
			benefit = "Capacity %d -> %d & instant refill" % [tool.max_charges, next_cap]
		ToolData.ToolKind.PICKAXE:
			benefit = "Power %d -> %d · Breaks %s boulders" % [tool.power, next_tier, next_name]
		ToolData.ToolKind.AXE:
			benefit = "Power %d -> %d · Chops hardwood stumps" % [tool.power, next_tier]
		ToolData.ToolKind.HOE:
			benefit = "Vitality cost 2 -> 1 per till"
		_:
			benefit = "Power %d -> %d" % [tool.power, next_tier]

	return {
		"tool_id": tool_id,
		"maxed": false,
		"current_tier": cur_tier,
		"next_tier": next_tier,
		"next_tier_name": next_name,
		"cost_g": cost_g,
		"materials": materials,
		"benefit": benefit,
	}


func can_upgrade_tool(tool_id: StringName) -> bool:
	var spec: Dictionary = get_tool_upgrade_spec(tool_id)
	if spec.is_empty() or bool(spec.get("maxed", true)):
		return false
	if not can_afford(int(spec["cost_g"])):
		return false
	var mats: Array = spec["materials"] as Array
	for m: Variant in mats:
		var md: Dictionary = m as Dictionary
		if InventoryManager.count_item(md["id"] as StringName) < int(md["count"]):
			return false
	return true


func upgrade_tool(tool_id: StringName) -> bool:
	if not can_upgrade_tool(tool_id):
		return false
	var spec: Dictionary = get_tool_upgrade_spec(tool_id)
	var cost_g: int = int(spec["cost_g"])
	var mats: Array = spec["materials"] as Array
	if not spend_sunbursts(cost_g):
		return false
	for m: Variant in mats:
		var md: Dictionary = m as Dictionary
		var ok_rem: bool = InventoryManager.remove_item(md["id"] as StringName, int(md["count"]))
		assert(ok_rem, "Material count mismatch during upgrade_tool.")
	var next_tier: ToolData.ToolTier = int(spec["next_tier"]) as ToolData.ToolTier
	var upgraded: bool = InventoryManager.upgrade_tool_tier(tool_id, next_tier)
	assert(upgraded, "InventoryManager.upgrade_tool_tier failed unexpectedly.")
	AudioManager.play_sfx(&"craft", -4.0, 0.02)
	return true


# ------------------------------------------------------------------------------
# SERIALIZATION (PHASE 6 SAVE COMPATIBILITY)
# ------------------------------------------------------------------------------
func serialize() -> Dictionary:
	var q_arr: Array[Dictionary] = []
	for entry: Dictionary in _shipped_queue:
		q_arr.append({
			"item_id": String(entry["item_id"]),
			"count": int(entry["count"]),
			"unit_price": int(entry["unit_price"]),
		})
	return {
		"sunbursts": sunbursts,
		"shipped_queue": q_arr,
	}


func deserialize(data: Dictionary) -> void:
	sunbursts = maxi(0, int(data.get("sunbursts", STARTING_SUNBURSTS)))
	_shipped_queue.clear()
	var q_arr: Array = data.get("shipped_queue", []) as Array
	var limit: int = mini(q_arr.size(), MAX_SHIPPED_STACKS)
	for i: int in range(limit):
		var e: Dictionary = q_arr[i] as Dictionary
		var iid: StringName = StringName(String(e.get("item_id", "")))
		var cnt: int = maxi(0, int(e.get("count", 0)))
		var up: int = maxi(0, int(e.get("unit_price", 0)))
		if iid != &"" and cnt > 0:
			_shipped_queue.append({"item_id": iid, "count": cnt, "unit_price": up})
	EventBus.currency_changed.emit(sunbursts, 0)
	EventBus.shipping_ledger_changed.emit()
