extends Node

## Manages Pebblefern Island resident profiles (NpcData), friendship points/hearts (0..10),
## daily talking & gifting limits (1/day, 2/week), discovered gift preferences, and contextual dialogue.

const MAX_HEARTS: int = 10
const POINTS_PER_HEART: int = 100
const MAX_POINTS: int = MAX_HEARTS * POINTS_PER_HEART
const TALK_DAILY_POINTS: int = 20
const MAX_GIFTS_PER_WEEK: int = 2

const GIFT_POINTS_LOVED: int = 80
const GIFT_POINTS_LIKED: int = 45
const GIFT_POINTS_NEUTRAL: int = 20
const GIFT_POINTS_DISLIKED: int = -20

const NPC_ORDER: Array[StringName] = [
	&"maren",
	&"kaelen",
	&"aldric",
	&"bram",
	&"lyra",
]

var _profiles: Dictionary = {} # StringName -> NpcData
var _points: Dictionary = {} # StringName -> int
var _talked_today: Dictionary = {} # StringName -> bool
var _gifted_today: Dictionary = {} # StringName -> bool
var _gifts_this_week: Dictionary = {} # StringName -> int
var _dialogue_cursor: Dictionary = {} # StringName -> int
var _discovered_loved: Dictionary = {} # StringName -> Array[StringName]
var _discovered_liked: Dictionary = {} # StringName -> Array[StringName]
var _discovered_disliked: Dictionary = {} # StringName -> Array[StringName]


func _ready() -> void:
	_load_npc_profiles()
	reset_social()
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func _load_npc_profiles() -> void:
	_profiles.clear()
	for nid: StringName in NPC_ORDER:
		var path: String = "res://resources/npcs/npc_%s.tres" % String(nid)
		if ResourceLoader.exists(path):
			var prof: NpcData = load(path) as NpcData
			if prof != null:
				_profiles[prof.npc_id] = prof


func reset_social() -> void:
	_points.clear()
	_talked_today.clear()
	_gifted_today.clear()
	_gifts_this_week.clear()
	_dialogue_cursor.clear()
	_discovered_loved.clear()
	_discovered_liked.clear()
	_discovered_disliked.clear()
	for nid: StringName in NPC_ORDER:
		_points[nid] = 0
		_talked_today[nid] = false
		_gifted_today[nid] = false
		_gifts_this_week[nid] = 0
		_dialogue_cursor[nid] = 0
		_discovered_loved[nid] = [] as Array[StringName]
		_discovered_liked[nid] = [] as Array[StringName]
		_discovered_disliked[nid] = [] as Array[StringName]


func _on_day_started(day: int, _season_idx: int, _year: int, _weather: StringName) -> void:
	var new_week: bool = (day > 0 and posmod(day - 1, 7) == 0)
	for nid: StringName in NPC_ORDER:
		_talked_today[nid] = false
		_gifted_today[nid] = false
		if new_week:
			_gifts_this_week[nid] = 0


func get_npc(npc_id: StringName) -> NpcData:
	return _profiles.get(npc_id, null) as NpcData


func get_all_npcs() -> Array[NpcData]:
	var out: Array[NpcData] = []
	for nid: StringName in NPC_ORDER:
		var prof: NpcData = get_npc(nid)
		if prof != null:
			out.append(prof)
	return out


func get_points(npc_id: StringName) -> int:
	return int(_points.get(npc_id, 0))


func get_hearts(npc_id: StringName) -> int:
	return clampi(int(get_points(npc_id) / POINTS_PER_HEART), 0, MAX_HEARTS)


func has_talked_today(npc_id: StringName) -> bool:
	return bool(_talked_today.get(npc_id, false))


func has_gifted_today(npc_id: StringName) -> bool:
	return bool(_gifted_today.get(npc_id, false))


func get_gifts_this_week(npc_id: StringName) -> int:
	return int(_gifts_this_week.get(npc_id, 0))


func can_gift_today(npc_id: StringName) -> bool:
	if not _profiles.has(npc_id):
		return false
	return (not has_gifted_today(npc_id)) and (get_gifts_this_week(npc_id) < MAX_GIFTS_PER_WEEK)


func get_gift_block_reason(npc_id: StringName) -> String:
	var prof: NpcData = get_npc(npc_id)
	var nm: String = prof.display_name if prof != null else String(npc_id)
	if has_gifted_today(npc_id):
		return "Already gave %s a gift today." % nm
	if get_gifts_this_week(npc_id) >= MAX_GIFTS_PER_WEEK:
		return "%s already received %d gifts this week." % [nm, MAX_GIFTS_PER_WEEK]
	return ""


func is_giftable_item(item_id: StringName) -> bool:
	if item_id == &"":
		return false
	var item: ItemData = InventoryManager.get_item(item_id)
	if item == null:
		return false
	match item.category:
		ItemData.Category.CROP, ItemData.Category.FORAGE, ItemData.Category.RESOURCE, ItemData.Category.CONSUMABLE:
			return true
		_:
			return false


func add_friendship(npc_id: StringName, delta: int) -> int:
	assert(npc_id != &"", "add_friendship requires non-empty npc_id")
	var prev: int = get_points(npc_id)
	var next_pts: int = clampi(prev + delta, 0, MAX_POINTS)
	_points[npc_id] = next_pts
	var hearts: int = get_hearts(npc_id)
	assert(next_pts >= 0 and next_pts <= MAX_POINTS, "Friendship points invariant violated")
	EventBus.friendship_changed.emit(npc_id, next_pts, hearts)
	return next_pts


## Awards +20 points on the first conversation of the day. Returns points gained (20 or 0).
func record_talk(npc_id: StringName) -> int:
	if not _profiles.has(npc_id):
		return 0
	if has_talked_today(npc_id):
		return 0
	_talked_today[npc_id] = true
	add_friendship(npc_id, TALK_DAILY_POINTS)
	return TALK_DAILY_POINTS


func evaluate_gift(npc_id: StringName, item_id: StringName) -> StringName:
	var prof: NpcData = get_npc(npc_id)
	if prof == null or item_id == &"":
		return &"neutral"
	if item_id in prof.loved_items:
		return &"loved"
	if item_id in prof.liked_items:
		return &"liked"
	if item_id in prof.disliked_items:
		return &"disliked"
	var item: ItemData = InventoryManager.get_item(item_id)
	if item != null:
		var cat_i: int = int(item.category)
		for allowed_cat: int in prof.liked_categories:
			if cat_i == allowed_cat:
				return &"liked"
	return &"neutral"


func get_points_for_tier(tier: StringName) -> int:
	match tier:
		&"loved":
			return GIFT_POINTS_LOVED
		&"liked":
			return GIFT_POINTS_LIKED
		&"disliked":
			return GIFT_POINTS_DISLIKED
		_:
			return GIFT_POINTS_NEUTRAL


func give_gift_from_slot(npc_id: StringName, slot_index: int) -> Dictionary:
	var prof: NpcData = get_npc(npc_id)
	if prof == null:
		return {"ok": false, "reason": "Unknown villager."}
	var item_id: StringName = InventoryManager.get_slot_item_id(slot_index)
	var item_cnt: int = InventoryManager.get_slot_count(slot_index)
	if item_id == &"" or item_cnt <= 0 or not is_giftable_item(item_id):
		return {"ok": false, "reason": "Hold a crop, fish, berry, or material to gift."}
	if not can_gift_today(npc_id):
		return {"ok": false, "reason": get_gift_block_reason(npc_id)}

	var item_data: ItemData = InventoryManager.get_item(item_id)
	var item_name: String = item_data.display_name if item_data != null else String(item_id)
	var removed: bool = InventoryManager.remove_from_slot(slot_index, 1)
	assert(removed, "Failed to consume gifted item from slot %d" % slot_index)

	var tier: StringName = evaluate_gift(npc_id, item_id)
	var delta: int = get_points_for_tier(tier)

	_gifted_today[npc_id] = true
	_gifts_this_week[npc_id] = get_gifts_this_week(npc_id) + 1
	_record_discovered_gift(npc_id, item_id, tier)
	add_friendship(npc_id, delta)

	var reaction_line: String = prof.gift_neutral_line
	match tier:
		&"loved":
			reaction_line = prof.gift_loved_line
		&"liked":
			reaction_line = prof.gift_liked_line
		&"disliked":
			reaction_line = prof.gift_disliked_line

	EventBus.gift_given.emit(npc_id, item_id, tier)
	return {
		"ok": true,
		"reason": "",
		"tier": tier,
		"delta": delta,
		"reaction_line": reaction_line,
		"item_id": item_id,
		"item_name": item_name,
	}


func _record_discovered_gift(npc_id: StringName, item_id: StringName, tier: StringName) -> void:
	if tier == &"loved":
		var arr: Array = _discovered_loved.get(npc_id, []) as Array
		if not (item_id in arr):
			arr.append(item_id)
			_discovered_loved[npc_id] = arr
	elif tier == &"liked":
		var arr: Array = _discovered_liked.get(npc_id, []) as Array
		if not (item_id in arr):
			arr.append(item_id)
			_discovered_liked[npc_id] = arr
	elif tier == &"disliked":
		var arr: Array = _discovered_disliked.get(npc_id, []) as Array
		if not (item_id in arr):
			arr.append(item_id)
			_discovered_disliked[npc_id] = arr


func get_discovered_loved(npc_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var src: Array = _discovered_loved.get(npc_id, []) as Array
	for v: Variant in src:
		out.append(v as StringName)
	return out


func get_discovered_liked(npc_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var src: Array = _discovered_liked.get(npc_id, []) as Array
	for v: Variant in src:
		out.append(v as StringName)
	return out


func get_contextual_dialogue(npc_id: StringName, advance_cursor: bool = true) -> String:
	var prof: NpcData = get_npc(npc_id)
	if prof == null:
		return "Lovely day on Pebblefern Island!"

	var pool: PackedStringArray = PackedStringArray()
	var hearts: int = get_hearts(npc_id)
	var hour_f: float = TimeManager.get_hour_float()
	var season_idx: int = clampi(TimeManager.current_season, 0, 3)

	# 1. Heart-tier special lines (prioritized first once unlocked!)
	if hearts >= 6:
		for line: String in prof.heart6_lines:
			pool.append(line)
	elif hearts >= 3:
		for line: String in prof.heart3_lines:
			pool.append(line)

	# 2. Time-of-day contextual lines
	var tod_lines: PackedStringArray = prof.afternoon_lines
	if hour_f < 12.0:
		tod_lines = prof.morning_lines
	elif hour_f >= 17.0:
		tod_lines = prof.evening_lines
	for line: String in tod_lines:
		pool.append(line)

	# 3. Season-aware flavor line
	if season_idx < prof.season_lines.size() and not prof.season_lines[season_idx].is_empty():
		pool.append(prof.season_lines[season_idx])

	if pool.is_empty():
		return "Good to see you around Bramblebrook!"

	var cursor: int = int(_dialogue_cursor.get(npc_id, 0))
	var chosen: String = pool[posmod(cursor, pool.size())]
	if advance_cursor:
		_dialogue_cursor[npc_id] = cursor + 1
	return chosen


func serialize() -> Dictionary:
	var out: Dictionary = {}
	for nid: StringName in NPC_ORDER:
		var loved_s: Array[String] = []
		for item_id: StringName in get_discovered_loved(nid):
			loved_s.append(String(item_id))
		var liked_s: Array[String] = []
		for item_id: StringName in get_discovered_liked(nid):
			liked_s.append(String(item_id))
		out[String(nid)] = {
			"points": get_points(nid),
			"talked_today": has_talked_today(nid),
			"gifted_today": has_gifted_today(nid),
			"gifts_this_week": get_gifts_this_week(nid),
			"discovered_loved": loved_s,
			"discovered_liked": liked_s,
		}
	return out


func deserialize(data: Dictionary) -> void:
	reset_social()
	for nid: StringName in NPC_ORDER:
		var key: String = String(nid)
		if not data.has(key):
			continue
		var entry: Dictionary = data[key] as Dictionary
		_points[nid] = clampi(int(entry.get("points", 0)), 0, MAX_POINTS)
		_talked_today[nid] = bool(entry.get("talked_today", false))
		_gifted_today[nid] = bool(entry.get("gifted_today", false))
		_gifts_this_week[nid] = clampi(int(entry.get("gifts_this_week", 0)), 0, MAX_GIFTS_PER_WEEK)
		var l_arr: Array[StringName] = []
		for s: Variant in (entry.get("discovered_loved", []) as Array):
			l_arr.append(StringName(String(s)))
		_discovered_loved[nid] = l_arr
		var lk_arr: Array[StringName] = []
		for s: Variant in (entry.get("discovered_liked", []) as Array):
			lk_arr.append(StringName(String(s)))
		_discovered_liked[nid] = lk_arr
