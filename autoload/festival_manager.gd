extends Node

## Manages seasonal town festivals in Bramblebrook Plaza (Bloom Blossom Festival on Bloom Day 7).
## Coordinates morning announcements, festival lifecycle, villager plaza gatherings,
## unique festive dialogue, and Mayor Aldric's interactive Harvest Showcase judging.

const FESTIVAL_ID: StringName = &"bloom_blossom"
const FESTIVAL_SEASON: int = 0 # Bloom
const FESTIVAL_DAY: int = 7
const FESTIVAL_START_HOUR: float = 9.0
const FESTIVAL_END_HOUR: float = 16.0

const FIRST_PLACE_VALUE_THRESHOLD: int = 90
const FIRST_PLACE_GOLD: int = 300
const PARTICIPATION_GOLD: int = 150
const FESTIVAL_FRIENDSHIP_BONUS: int = 100

var is_festival_active: bool = false
var showcase_submitted_this_festival: bool = false
var last_celebrated_year: int = 0
var last_rank: StringName = &""
var last_submitted_item_name: String = ""


func _ready() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func reset_festivals() -> void:
	var was_active: bool = is_festival_active
	is_festival_active = false
	showcase_submitted_this_festival = false
	last_celebrated_year = 0
	last_rank = &""
	last_submitted_item_name = ""
	if was_active:
		EventBus.festival_ended.emit(FESTIVAL_ID)


func _on_day_started(day: int, season_idx: int, year: int, _weather: StringName) -> void:
	if is_festival_active:
		end_festival(false)
	if season_idx == FESTIVAL_SEASON and day == FESTIVAL_DAY and last_celebrated_year < year:
		EventBus.toast_requested.emit("Bloom Blossom Festival today in Bramblebrook Plaza (9 AM - 4 PM)!")


func is_festival_day() -> bool:
	return TimeManager.current_season == FESTIVAL_SEASON and TimeManager.current_day == FESTIVAL_DAY


func has_celebrated_this_year() -> bool:
	return last_celebrated_year >= TimeManager.current_year


func can_start_festival_now() -> bool:
	if is_festival_active or has_celebrated_this_year():
		return false
	if not is_festival_day():
		return false
	var hour_f: float = TimeManager.get_hour_float()
	return hour_f >= FESTIVAL_START_HOUR and hour_f <= FESTIVAL_END_HOUR


func start_festival(force: bool = false) -> bool:
	if is_festival_active:
		return true
	if not force and not can_start_festival_now():
		return false
	is_festival_active = true
	showcase_submitted_this_festival = false
	last_rank = &""
	last_submitted_item_name = ""
	AudioManager.play_sfx(&"festival", -4.0, 0.02)
	EventBus.festival_started.emit(FESTIVAL_ID)
	EventBus.toast_requested.emit("Bloom Blossom Festival begun! Speak with Mayor Aldric for the Showcase!")
	return true


func end_festival(show_toast: bool = true) -> void:
	if not is_festival_active:
		return
	is_festival_active = false
	last_celebrated_year = maxi(last_celebrated_year, TimeManager.current_year)
	EventBus.festival_ended.emit(FESTIVAL_ID)
	if show_toast:
		EventBus.toast_requested.emit("The Bloom Blossom Festival concludes! Thank you for celebrating!")


func is_showcase_eligible_item(item_id: StringName) -> bool:
	if item_id == &"":
		return false
	var item: ItemData = InventoryManager.get_item(item_id)
	if item == null or item.sell_price <= 0:
		return false
	return item.category == ItemData.Category.CROP or item.category == ItemData.Category.FORAGE


## Evaluates and consumes 1 showcase entry from backpack slot `slot_index`.
## Awards +300G (1st Place for >= 90G value/rarity) or +150G (Participation) + 100 Friendship with all 5 villagers!
func submit_showcase_item(slot_index: int) -> Dictionary:
	if not is_festival_active:
		return {"ok": false, "reason": "No festival is currently active."}
	if showcase_submitted_this_festival:
		return {"ok": false, "reason": "You already submitted an entry for this year's Showcase!"}
	if slot_index < 0 or slot_index >= InventoryManager.SLOT_COUNT:
		return {"ok": false, "reason": "Invalid backpack slot."}

	var item_id: StringName = InventoryManager.get_slot_item_id(slot_index)
	var cnt: int = InventoryManager.get_slot_count(slot_index)
	if item_id == &"" or cnt <= 0 or not is_showcase_eligible_item(item_id):
		return {"ok": false, "reason": "Choose a Crop, Fish, or Cave Gem for the Showcase."}

	var item: ItemData = InventoryManager.get_item(item_id)
	assert(item != null, "Missing ItemData for festival showcase submission: %s" % String(item_id))

	var removed: bool = InventoryManager.remove_from_slot(slot_index, 1)
	assert(removed, "Failed to consume festival showcase item from slot %d" % slot_index)

	var is_first: bool = item.sell_price >= FIRST_PLACE_VALUE_THRESHOLD
	var rank: StringName = &"first_place" if is_first else &"participation"
	var rank_title: String = "1st Place — Grand Blossom Ribbon!" if is_first else "Festival Honorable Mention!"
	var gold_reward: int = FIRST_PLACE_GOLD if is_first else PARTICIPATION_GOLD
	var judge_line: String = (
		"Marvelous!! Your %s outshines every blossom in the valley! First Place and %d G to Solstice Farm!"
		% [item.display_name, gold_reward]
	) if is_first else (
		"What a fine, heartfelt %s! Bramblebrook applauds your contribution — here is %d G!"
		% [item.display_name, gold_reward]
	)

	showcase_submitted_this_festival = true
	last_celebrated_year = maxi(last_celebrated_year, TimeManager.current_year)
	last_rank = rank
	last_submitted_item_name = item.display_name

	EconomyManager.add_sunbursts(gold_reward)
	for nid: StringName in SocialManager.NPC_ORDER:
		SocialManager.add_friendship(nid, FESTIVAL_FRIENDSHIP_BONUS)

	AudioManager.play_sfx(&"festival", -3.0, 0.02)
	AudioManager.play_sfx(&"coin", -4.0, 0.03)
	EventBus.festival_showcase_completed.emit(rank, item.id, gold_reward)
	EventBus.toast_requested.emit("%s +%d G & +100♥ All Villagers!" % ["1st Place!" if is_first else "Showcase Complete!", gold_reward])

	return {
		"ok": true,
		"rank": rank,
		"rank_title": rank_title,
		"item_id": item.id,
		"item_name": item.display_name,
		"gold_reward": gold_reward,
		"friendship_bonus": FESTIVAL_FRIENDSHIP_BONUS,
		"judge_line": judge_line,
	}


func get_festival_dialogue(npc_id: StringName) -> String:
	if showcase_submitted_this_festival:
		var trophy_note: String = "That %s stole the whole show!" % last_submitted_item_name if not last_submitted_item_name.is_empty() else "What a splendid Showcase!"
		match npc_id:
			&"maren":
				return "Bravo!! %s Look at all the petals drifting across Bramblebrook Plaza!" % trophy_note
			&"kaelen":
				return "Ha! %s You've got real craftsmanship in everything you do, neighbor!" % trophy_note
			&"aldric":
				return "A Bloom Blossom Festival for the history books! %s Speak to me anytime when you're ready to wrap up." % trophy_note
			&"bram":
				return "Cheers to Solstice Farm! %s Best gathering since the tall tide of '22!" % trophy_note
			&"lyra":
				return "The lantern glow and wildflowers feel downright magical tonight! %s" % trophy_note
			_:
				return "Happy Bloom Blossom Festival! %s" % trophy_note

	match npc_id:
		&"maren":
			return "Happy Bloom Blossom Festival! I wove fresh garlands from sunrise petals all around the square!"
		&"kaelen":
			return "Even I put the hammer down for Bloom Day 7! Bring your finest crop, catch, or cave gem to Mayor Aldric's judging table!"
		&"aldric":
			return "Welcome to the Bloom Blossom Festival! Step right up to submit your proudest crop, fish, or cave crystal for our Harvest Showcase!"
		&"bram":
			return "I crossed the ocean bridge early so I wouldn't miss the judging! A rare fish or gleaming gem is a sure crowd-pleaser!"
		&"lyra":
			return "Seeing all five of us gathered beneath the festival lanterns warms the whole highland ridge! Have you entered the Showcase yet?"
		_:
			return "Happy Bloom Blossom Festival!"


func serialize() -> Dictionary:
	return {
		"last_celebrated_year": last_celebrated_year,
		"last_rank": String(last_rank),
		"last_submitted_item_name": last_submitted_item_name,
	}


func deserialize(data: Dictionary) -> void:
	reset_festivals()
	last_celebrated_year = maxi(0, int(data.get("last_celebrated_year", 0)))
	last_rank = StringName(String(data.get("last_rank", "")))
	last_submitted_item_name = String(data.get("last_submitted_item_name", ""))
