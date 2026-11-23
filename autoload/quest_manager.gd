extends Node

## Manages Pebblefern Community Board daily rotating villager quests (Phase 5: Living Town).
## Tracks available board postings, active accepted quests, live inventory progress, and NPC turn-ins.

const QuestDataScript := preload("res://resources/quest_data.gd")

const DAILY_BOARD_SLOTS: int = 3
const MAX_ACTIVE_QUESTS: int = 6

const GROUP_OCEAN_FISH: Array[StringName] = [
	&"fish_sea_bass",
	&"fish_ocean_snapper",
	&"fish_coral_flounder",
]
const GROUP_RIVER_FISH: Array[StringName] = [
	&"fish_river_trout",
	&"fish_sun_perch",
	&"fish_golden_carp",
	&"fish",
]
const GROUP_SPRING_FISH: Array[StringName] = [
	&"fish_spring_koi",
	&"fish_mountain_minnow",
]

var _catalog: Array[QuestData] = []
var _board_quests: Array[QuestData] = []
var _active_quests: Array[QuestData] = []
var _completed_ids: Array[StringName] = []


func _ready() -> void:
	_build_catalog()
	reset_quests()
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func _build_catalog() -> void:
	_catalog.clear()
	# [id, npc_id, title, desc, req_item, req_group, req_label, preview_item, req_count, gold, friendship]
	var specs: Array[Array] = [
		[
			&"q_maren_carrots", &"maren", "Fresh Carrot Bundle",
			"Maren needs crisp Solstice carrots for her seasonal seed catalogue display.",
			&"crop_carrot", &"", "Carrots", &"crop_carrot", 3, 180, 150,
		],
		[
			&"q_kaelen_stone", &"kaelen", "Quarry Stone Supply",
			"Kaelen is relining his forge hearth and needs sturdy quarry stone.",
			&"stone", &"", "Rock", &"stone", 8, 150, 150,
		],
		[
			&"q_bram_ocean_fish", &"bram", "Ocean Pier Catch",
			"Bram is preparing a coastal chowder and wants fresh fish from the eastern piers.",
			&"", &"ocean_fish", "Ocean Fish", &"fish_ocean_snapper", 2, 220, 150,
		],
		[
			&"q_lyra_berries", &"lyra", "Highland Berry Basket",
			"Lyra is steeping woodland berry jam and could use extra ripe berries.",
			&"wild_berry", &"", "Wild Berries", &"wild_berry", 4, 140, 150,
		],
		[
			&"q_aldric_pumpkins", &"aldric", "Village Hall Pumpkins",
			"Mayor Aldric wants plump pumpkins to decorate Bramblebrook Village Hall.",
			&"crop_pumpkin", &"", "Pumpkins", &"crop_pumpkin", 2, 260, 150,
		],
		[
			&"q_maren_sunflowers", &"maren", "Golden Sunflower Study",
			"Maren is sketching golden sunflower petals for her botanical almanac.",
			&"crop_sunflower", &"", "Sunflowers", &"crop_sunflower", 2, 210, 150,
		],
		[
			&"q_kaelen_wood", &"kaelen", "Forge Timber Delivery",
			"Kaelen needs dry island timber to stoke the bellows through the week.",
			&"wood", &"", "Wood", &"wood", 6, 130, 120,
		],
		[
			&"q_bram_river_fish", &"bram", "River Angler Challenge",
			"Bram wants to compare freshwater catches from the Farm Pond and Village River.",
			&"", &"river_fish", "River Fish", &"fish_river_trout", 2, 190, 150,
		],
	]

	for sp: Array in specs:
		var q: QuestData = QuestDataScript.new()
		q.quest_id = sp[0] as StringName
		q.npc_id = sp[1] as StringName
		q.title = sp[2] as String
		q.description = sp[3] as String
		q.required_item_id = sp[4] as StringName
		q.required_item_group = sp[5] as StringName
		q.required_label = sp[6] as String
		q.preview_item_id = sp[7] as StringName
		q.required_count = sp[8] as int
		q.reward_gold = sp[9] as int
		q.reward_friendship = sp[10] as int
		q.day_issued = 1
		q.status = QuestData.Status.AVAILABLE
		_catalog.append(q)


func reset_quests() -> void:
	_board_quests.clear()
	_active_quests.clear()
	_completed_ids.clear()
	refresh_daily_board(TimeManager.current_day, TimeManager.current_season, TimeManager.current_year)


func _on_day_started(day: int, season_idx: int, year: int, _weather: StringName) -> void:
	refresh_daily_board(day, season_idx, year)


func refresh_daily_board(day: int, season_idx: int, year: int) -> void:
	_board_quests.clear()
	var total: int = _catalog.size()
	if total == 0:
		return

	# Day 1 always posts Maren (Carrots), Kaelen (Stone), and Bram (Ocean Fish);
	# later days rotate cleanly across all 8 villager requests without duplicating active quests.
	var start_idx: int = posmod((year - 1) * 112 + season_idx * 28 + (day - 1) * 3, total)
	var picked: int = 0
	for offset: int in range(total):
		if picked >= DAILY_BOARD_SLOTS:
			break
		var tpl: QuestData = _catalog[(start_idx + offset) % total]
		if _is_quest_active_by_id(tpl.quest_id):
			continue
		var inst: QuestData = tpl.duplicate() as QuestData
		inst.day_issued = day
		inst.status = QuestData.Status.AVAILABLE
		_board_quests.append(inst)
		picked += 1

	EventBus.quests_changed.emit()


func get_board_quests() -> Array[QuestData]:
	return _board_quests


func get_active_quests() -> Array[QuestData]:
	return _active_quests


func get_completed_quest_ids() -> Array[StringName]:
	return _completed_ids


func _is_quest_active_by_id(quest_id: StringName) -> bool:
	for q: QuestData in _active_quests:
		if q.quest_id == quest_id:
			return true
	return false


func accept_quest(quest_id: StringName) -> bool:
	if _active_quests.size() >= MAX_ACTIVE_QUESTS:
		return false
	if _is_quest_active_by_id(quest_id):
		return false
	for i: int in range(_board_quests.size()):
		var q: QuestData = _board_quests[i]
		if q.quest_id == quest_id and q.status == QuestData.Status.AVAILABLE:
			q.status = QuestData.Status.ACTIVE
			_active_quests.append(q)
			_board_quests.remove_at(i)
			EventBus.quests_changed.emit()
			return true
	return false


func get_group_item_ids(group_id: StringName) -> Array[StringName]:
	match group_id:
		&"ocean_fish":
			return GROUP_OCEAN_FISH
		&"river_fish":
			return GROUP_RIVER_FISH
		&"spring_fish":
			return GROUP_SPRING_FISH
		_:
			return [] as Array[StringName]


func get_quest_progress(q: QuestData) -> int:
	if q == null:
		return 0
	if q.required_item_id != &"":
		return InventoryManager.count_item(q.required_item_id)
	if q.required_item_group != &"":
		var total: int = 0
		for iid: StringName in get_group_item_ids(q.required_item_group):
			total += InventoryManager.count_item(iid)
		return total
	return 0


func is_quest_ready(q: QuestData) -> bool:
	if q == null or q.status != QuestData.Status.ACTIVE:
		return false
	return get_quest_progress(q) >= maxi(1, q.required_count)


func find_ready_quest_for_npc(npc_id: StringName) -> QuestData:
	for q: QuestData in _active_quests:
		if q.npc_id == npc_id and is_quest_ready(q):
			return q
	return null


func find_active_quest_for_npc(npc_id: StringName) -> QuestData:
	for q: QuestData in _active_quests:
		if q.npc_id == npc_id:
			return q
	return null


func turn_in_quest(quest_id: StringName) -> Dictionary:
	var idx: int = -1
	for i: int in range(_active_quests.size()):
		if _active_quests[i].quest_id == quest_id:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "Quest is not active."}

	var q: QuestData = _active_quests[idx]
	if not is_quest_ready(q):
		return {"ok": false, "reason": "You don't have enough %s yet." % q.required_label}

	# Consume exact required items (supporting both exact item_id and logical item groups!)
	var consumed_ok: bool = _consume_quest_items(q)
	assert(consumed_ok, "Quest item consumption mismatch for %s" % String(quest_id))

	q.status = QuestData.Status.COMPLETED
	_active_quests.remove_at(idx)
	_completed_ids.append(q.quest_id)

	EconomyManager.add_sunbursts(q.reward_gold)
	SocialManager.add_friendship(q.npc_id, q.reward_friendship)

	EventBus.quest_completed.emit(q.quest_id, q.npc_id, q.reward_gold, q.reward_friendship)
	EventBus.quests_changed.emit()
	return {
		"ok": true,
		"quest": q,
		"reward_gold": q.reward_gold,
		"reward_friendship": q.reward_friendship,
	}


func _consume_quest_items(q: QuestData) -> bool:
	if q.required_item_id != &"":
		return InventoryManager.remove_item(q.required_item_id, q.required_count)
	if q.required_item_group != &"":
		var remaining: int = q.required_count
		for iid: StringName in get_group_item_ids(q.required_item_group):
			if remaining <= 0:
				break
			var avail: int = InventoryManager.count_item(iid)
			if avail > 0:
				var take: int = mini(avail, remaining)
				var ok: bool = InventoryManager.remove_item(iid, take)
				assert(ok, "Failed to remove group item %s" % String(iid))
				remaining -= take
		return remaining == 0
	return false


func _find_catalog_template(quest_id: StringName) -> QuestData:
	for tpl: QuestData in _catalog:
		if tpl.quest_id == quest_id:
			return tpl
	return null


func serialize() -> Dictionary:
	var board_arr: Array[Dictionary] = []
	for q: QuestData in _board_quests:
		board_arr.append({"id": String(q.quest_id), "day_issued": q.day_issued})
	var active_arr: Array[Dictionary] = []
	for q: QuestData in _active_quests:
		active_arr.append({"id": String(q.quest_id), "day_issued": q.day_issued})
	var completed_arr: Array[String] = []
	for cid: StringName in _completed_ids:
		completed_arr.append(String(cid))
	return {
		"board_quests": board_arr,
		"active_quests": active_arr,
		"completed_ids": completed_arr,
	}


func deserialize(data: Dictionary) -> void:
	_board_quests.clear()
	_active_quests.clear()
	_completed_ids.clear()

	var board_src: Array = data.get("board_quests", []) as Array
	var b_lim: int = mini(board_src.size(), DAILY_BOARD_SLOTS)
	for i: int in range(b_lim):
		var entry: Dictionary = board_src[i] as Dictionary
		var qid: StringName = StringName(String(entry.get("id", "")))
		var tpl: QuestData = _find_catalog_template(qid)
		if tpl != null:
			var inst: QuestData = tpl.duplicate() as QuestData
			inst.day_issued = maxi(1, int(entry.get("day_issued", 1)))
			inst.status = QuestData.Status.AVAILABLE
			_board_quests.append(inst)

	var active_src: Array = data.get("active_quests", []) as Array
	var a_lim: int = mini(active_src.size(), MAX_ACTIVE_QUESTS)
	for i: int in range(a_lim):
		var entry: Dictionary = active_src[i] as Dictionary
		var qid: StringName = StringName(String(entry.get("id", "")))
		var tpl: QuestData = _find_catalog_template(qid)
		if tpl != null and not _is_quest_active_by_id(qid):
			var inst: QuestData = tpl.duplicate() as QuestData
			inst.day_issued = maxi(1, int(entry.get("day_issued", 1)))
			inst.status = QuestData.Status.ACTIVE
			_active_quests.append(inst)

	var comp_src: Array = data.get("completed_ids", []) as Array
	var c_lim: int = mini(comp_src.size(), 128)
	for i: int in range(c_lim):
		var cid: StringName = StringName(String(comp_src[i]))
		if cid != &"":
			_completed_ids.append(cid)

	EventBus.quests_changed.emit()
