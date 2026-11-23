extends Node2D

## Automated Phase 5 verification suite & 1280x720 screenshot capture.
## Tests SocialManager (5 NpcData profiles, talk +20/day, Loved/Liked/Disliked gifting, 1/day limit,
## discovered Loved gifts), NpcActor live daily schedules & 3-layer WALKING animations (both arms),
## DialogueModal, People Tab, Community Board quests (accept -> track -> turn-in -> gold + friendship),
## and expanded 3-biome fishing (Ocean Piers, Highland Spring, Farm Pond/River + selling/shipping).

const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const SHOT_DIALOGUE: String = "res://Screenshots/phase5_dialogue_box.png"
const SHOT_PEOPLE: String = "res://Screenshots/phase5_people_tab.png"
const SHOT_QUEST_BOARD: String = "res://Screenshots/phase5_quest_board.png"
const SHOT_PLAZA_EVENING: String = "res://Screenshots/phase5_plaza_evening.png"

const OCEAN_FISH: Array[StringName] = [&"fish_sea_bass", &"fish_ocean_snapper", &"fish_coral_flounder"]
const SPRING_FISH: Array[StringName] = [&"fish_spring_koi", &"fish_mountain_minnow"]
const RIVER_FISH: Array[StringName] = [&"fish_river_trout", &"fish_sun_perch", &"fish_golden_carp"]

var _farm: FarmSanctuary = null
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
	SocialManager.reset_social()
	QuestManager.reset_quests()
	TimeManager.set_paused(true)
	TimeManager.set_time(12, 0)

	# 1. Verify all 5 NpcData profiles & all 8 biome fish + legacy fish loaded cleanly
	var npcs: Array[NpcData] = SocialManager.get_all_npcs()
	assert(npcs.size() == 5, "Expected 5 NpcData villager profiles, got %d" % npcs.size())
	for nid: StringName in [&"maren", &"kaelen", &"aldric", &"bram", &"lyra"]:
		assert(SocialManager.get_npc(nid) != null, "Missing NpcData for %s" % String(nid))

	for fid: StringName in [
		&"fish", &"fish_river_trout", &"fish_sun_perch", &"fish_golden_carp",
		&"fish_spring_koi", &"fish_mountain_minnow",
		&"fish_sea_bass", &"fish_ocean_snapper", &"fish_coral_flounder",
	]:
		var fitem: ItemData = InventoryManager.get_item(fid)
		assert(fitem != null and fitem.sell_price > 0, "Missing or unpriced fish item: %s" % String(fid))
	print("[VerifyP5] PASS: All 5 NpcData profiles and all 8 biome fish (+ legacy fish) resources loaded.")

	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(farm_packed != null, "Missing farm_sanctuary.tscn")
	_farm = farm_packed.instantiate() as FarmSanctuary
	add_child(_farm)
	assert(_farm.dialogue_modal != null and _farm.quest_board_modal != null, "FarmSanctuary missing Phase 5 modals!")
	_farm.refresh_atmosphere()


func _physics_process(_delta: float) -> void:
	_wait_frames += 1
	match _step:
		0:
			if _wait_frames >= 6:
				_test_gift_tables_and_social()
				_test_npc_schedules_and_walking()
				_test_community_board_quests()
				_test_biome_fishing_and_sales()

				# Stage Shot 1: Daytime DialogueModal with Maren at Bramblebrook Village!
				TimeManager.set_time(13, 30)
				_snap_all_npcs_to_current_time()
				var maren: NpcActor = _farm.find_npc_actor(&"maren")
				assert(maren != null, "Missing Maren NpcActor!")
				_farm.player.global_position = maren.global_position + Vector2(0.0, 22.0)
				_farm.player.set_facing_cardinal(Vector2i(0, -1))
				_farm.refresh_atmosphere()
				# Give Maren +200 extra friendship so multiple bright red hearts shine in the 10-heart row!
				SocialManager.add_friendship(&"maren", 150)
				_farm.dialogue_modal.open_dialogue(
					&"maren",
					maren,
					"Oh!! A gleaming Sunflower — you remembered my absolute favorite! Solstice Farm is looking brighter every single day!",
					"LOVED! +80♥",
					DialogueModal.TEXT_GOLD,
					_farm.player
				)
				_farm.dialogue_modal.finish_typewriter()
				_step = 1
				_wait_frames = 0

		1:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_DIALOGUE)
				print("[VerifyP5] Captured %s" % SHOT_DIALOGUE)
				_farm.dialogue_modal.set_open(false)

				# Stage Shot 2: InventoryModal -> People Tab showing all 5 villagers, hearts & discovered Loved gifts!
				SocialManager.add_friendship(&"kaelen", 240)
				SocialManager.add_friendship(&"aldric", 120)
				SocialManager.add_friendship(&"bram", 310)
				SocialManager.add_friendship(&"lyra", 180)
				_farm.inventory_modal.set_open(true)
				_farm.inventory_modal.set_active_tab(InventoryModal.Tab.PEOPLE)
				_farm.inventory_modal.select_npc_index(0) # Maren (shows Loves: Sunflower!)
				_step = 2
				_wait_frames = 0

		2:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_PEOPLE)
				print("[VerifyP5] Captured %s" % SHOT_PEOPLE)
				_farm.inventory_modal.set_open(false)

				# Stage Shot 3: Community Board Quest Modal at Bramblebrook Plaza with posted & active requests!
				var board_pos: Vector2 = _farm.get_world_marker_position("CommunityBoard")
				_farm.player.global_position = board_pos + Vector2(0.0, 18.0)
				_farm.player.set_facing_cardinal(Vector2i(0, -1))
				TimeManager.set_time(11, 30)
				_snap_all_npcs_to_current_time()
				_farm.refresh_atmosphere()
				# Refresh Day 2 board so 3 crisp daily requests appear on left alongside Bram's active Ocean Fish quest on right!
				QuestManager.refresh_daily_board(2, TimeManager.current_season, TimeManager.current_year)
				_farm.quest_board_modal.set_open(true)
				_step = 3
				_wait_frames = 0

		3:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_QUEST_BOARD)
				print("[VerifyP5] Captured %s" % SHOT_QUEST_BOARD)
				_farm.quest_board_modal.set_open(false)

				# Stage Shot 4: Warm Evening Plaza Gathering (18:30) with ALL 5 villagers & glowing lanterns + HUD Quest Tracker!
				TimeManager.set_time(18, 30)
				_snap_all_npcs_to_current_time()
				var plaza_pos: Vector2 = _farm.get_world_marker_position("FestivalPlazaCenter")
				_farm.player.global_position = plaza_pos + Vector2(-26.0, 26.0)
				_farm.player.set_facing_cardinal(Vector2i(0, -1))
				_farm.refresh_atmosphere()
				_step = 4
				_wait_frames = 0

		4:
			if _wait_frames >= 10:
				_save_viewport_png(SHOT_PLAZA_EVENING)
				print("[VerifyP5] Captured %s" % SHOT_PLAZA_EVENING)
				print("[VerifyP5] ALL PHASE 5 LIVING TOWN, QUEST BOARD, SCHEDULE & BIOME FISHING CHECKS PASSED!")
				get_tree().quit(0)


func _test_gift_tables_and_social() -> void:
	# 0. Verify EVERY item ID referenced in NpcData gift tables & QuestManager catalog exists in InventoryManager!
	for prof: NpcData in SocialManager.get_all_npcs():
		for iid: StringName in prof.loved_items:
			assert(InventoryManager.get_item(iid) != null, "NpcData %s unknown loved_item: %s" % [String(prof.npc_id), String(iid)])
		for iid: StringName in prof.liked_items:
			assert(InventoryManager.get_item(iid) != null, "NpcData %s unknown liked_item: %s" % [String(prof.npc_id), String(iid)])
		for iid: StringName in prof.disliked_items:
			assert(InventoryManager.get_item(iid) != null, "NpcData %s unknown disliked_item: %s" % [String(prof.npc_id), String(iid)])
	for q: QuestData in QuestManager.get_board_quests():
		if q.required_item_id != &"":
			assert(InventoryManager.get_item(q.required_item_id) != null, "Quest %s unknown required_item_id: %s" % [String(q.quest_id), String(q.required_item_id)])
		assert(InventoryManager.get_item(q.preview_item_id) != null, "Quest %s unknown preview_item_id: %s" % [String(q.quest_id), String(q.preview_item_id)])

	# 1. Verify exact Loved / Liked / Disliked evaluation across all 5 NPCs
	assert(SocialManager.evaluate_gift(&"maren", &"crop_sunflower") == &"loved", "Maren must Love Sunflower")
	assert(SocialManager.evaluate_gift(&"maren", &"crop_cauliflower") == &"loved", "Maren must Love Cauliflower")
	assert(SocialManager.evaluate_gift(&"maren", &"crop_parsnip") == &"liked", "Maren must Like all crops")
	assert(SocialManager.evaluate_gift(&"maren", &"wild_berry") == &"liked", "Maren must Like Wild Berry")

	assert(SocialManager.evaluate_gift(&"kaelen", &"copper_bar") == &"loved", "Kaelen must Love Copper Bar")
	assert(SocialManager.evaluate_gift(&"kaelen", &"iron_bar") == &"loved", "Kaelen must Love Iron Bar")
	assert(SocialManager.evaluate_gift(&"kaelen", &"stone") == &"liked", "Kaelen must Like Rock")
	assert(SocialManager.evaluate_gift(&"kaelen", &"crop_potato") == &"liked", "Kaelen must Like Potato")

	assert(SocialManager.evaluate_gift(&"aldric", &"crop_pumpkin") == &"loved", "Aldric must Love Pumpkin")
	assert(SocialManager.evaluate_gift(&"aldric", &"crop_cabbage") == &"loved", "Aldric must Love Cabbage")
	assert(SocialManager.evaluate_gift(&"aldric", &"crop_carrot") == &"liked", "Aldric must Like Carrot")

	assert(SocialManager.evaluate_gift(&"bram", &"fish_ocean_snapper") == &"loved", "Bram must Love Ocean Snapper")
	assert(SocialManager.evaluate_gift(&"bram", &"fish_golden_carp") == &"loved", "Bram must Love Golden Carp")
	assert(SocialManager.evaluate_gift(&"bram", &"fish") == &"loved", "Bram must Love River Fish")
	assert(SocialManager.evaluate_gift(&"bram", &"wood") == &"liked", "Bram must Like Wood")

	assert(SocialManager.evaluate_gift(&"lyra", &"wild_berry") == &"loved", "Lyra must Love Wild Berry")
	assert(SocialManager.evaluate_gift(&"lyra", &"crop_radish") == &"loved", "Lyra must Love Radish")
	assert(SocialManager.evaluate_gift(&"lyra", &"crop_beetroot") == &"loved", "Lyra must Love Beetroot")
	assert(SocialManager.evaluate_gift(&"lyra", &"crop_kale") == &"liked", "Lyra must Like Kale")

	# Tools & seeds must NEVER be giftable
	assert(not SocialManager.is_giftable_item(&"tool_hoe"), "Tools must not be giftable")
	assert(not SocialManager.is_giftable_item(&"seed_parsnip"), "Seeds must not be giftable")
	assert(SocialManager.is_giftable_item(&"crop_sunflower"), "Sunflower crop must be giftable")

	# 2. First talk awards +20 pts & opens DialogueModal; 2nd talk same day awards +0
	var maren: NpcActor = _farm.find_npc_actor(&"maren")
	assert(maren != null, "Missing Maren NpcActor")
	InventoryManager.select_hotbar_slot(0) # Holding Hoe -> normal conversation
	_farm.interact_with_npc(&"maren", maren)
	assert(_farm.dialogue_modal.is_open(), "Talking to Maren must open DialogueModal")
	assert(SocialManager.get_points(&"maren") == 20, "First talk/day must award +20 pts, got %d" % SocialManager.get_points(&"maren"))
	assert(SocialManager.has_talked_today(&"maren"), "talked_today flag must be set")
	_farm.dialogue_modal.set_open(false)

	_farm.interact_with_npc(&"maren", maren)
	assert(SocialManager.get_points(&"maren") == 20, "Second talk same day must NOT award extra pts")
	_farm.dialogue_modal.set_open(false)

	# 3. Direct Gifting Loved Sunflower to Maren -> +80 pts (total 100 = 1 Heart!), discovered Loved, 1/day cap!
	InventoryManager.add_item(&"crop_sunflower", 2)
	var sf_slot: int = _find_slot_with(&"crop_sunflower")
	assert(sf_slot >= 0, "Failed to place Sunflower in inventory")
	if sf_slot >= InventoryManager.HOTBAR_SIZE:
		InventoryManager.swap_slots(6, sf_slot)
		sf_slot = 6
	InventoryManager.select_hotbar_slot(sf_slot)

	_farm.interact_with_npc(&"maren", maren)
	assert(_farm.dialogue_modal.is_open(), "Direct gifting must open DialogueModal with tailored reaction")
	assert(SocialManager.get_points(&"maren") == 100, "Loved gift (+80) after talk (+20) must equal 100 pts, got %d" % SocialManager.get_points(&"maren"))
	assert(SocialManager.get_hearts(&"maren") == 1, "100 pts must equal 1 full Heart")
	assert(&"crop_sunflower" in SocialManager.get_discovered_loved(&"maren"), "Sunflower must be recorded in discovered Loved gifts")
	assert(InventoryManager.count_item(&"crop_sunflower") == 1, "Gifting must consume exactly 1 Sunflower")
	assert(not SocialManager.can_gift_today(&"maren"), "1-gift-per-day cap must block second gift today")
	_farm.dialogue_modal.set_open(false)

	# Attempt 2nd gift same day -> must NOT consume 2nd Sunflower or add points!
	_farm.interact_with_npc(&"maren", maren)
	assert(InventoryManager.count_item(&"crop_sunflower") == 1, "Blocked 2nd gift same day must NOT consume item")
	assert(SocialManager.get_points(&"maren") == 100, "Blocked 2nd gift same day must NOT add points")
	_farm.dialogue_modal.set_open(false)

	print("[VerifyP5] PASS: SocialManager gift tables, daily talk (+20), Loved gifting (+80 -> 1 Heart), discovery & 1/day cap verified.")


func _test_npc_schedules_and_walking() -> void:
	# Snap all 5 NPCs to Morning (07:00 -> HomeDoor)
	TimeManager.set_time(7, 0)
	_snap_all_npcs_to_current_time()

	var bram: NpcActor = _farm.find_npc_actor(&"bram")
	var lyra: NpcActor = _farm.find_npc_actor(&"lyra")
	var maren: NpcActor = _farm.find_npc_actor(&"maren")
	assert(bram != null and lyra != null and maren != null, "Missing villager actors")
	var bram_home: Vector2 = bram.global_position
	var lyra_home: Vector2 = lyra.global_position

	# Move player out of NPC proximity so villagers don't politely pause for the player
	_farm.player.global_position = _farm.get_world_marker_position("OpenMeadowSpot")

	# Advance to Work Hours (09:00) and step live walking frames
	TimeManager.set_time(9, 0)
	var walked_frame_seen: bool = false
	for _i: int in range(180):
		for n: Node in get_tree().get_nodes_in_group(&"npcs"):
			var actor: NpcActor = n as NpcActor
			if actor != null:
				actor.step_schedule(0.05, true)
		if bram.is_walking():
			walked_frame_seen = true
			assert(bram.get_current_anim_name() == &"walk", "Walking NPC must report walk animation")
			assert(bram._body_spr.hframes == 8 and bram._tool_spr.visible and bram._tool_spr.hframes == 8, "Walking NPC must use 8-frame WALKING strips with tools_walk_strip8 visible!")
	assert(walked_frame_seen, "Bram must enter active WALKING state transitioning from HomeDoor to WorkPost!")
	assert(bram.global_position.distance_to(bram_home) > 16.0, "Bram must physically travel away from HomeDoor at 09:00!")

	# Advance to Evening Plaza Gathering (18:30) and step everyone all the way into Bramblebrook Plaza!
	TimeManager.set_time(18, 30)
	for _i: int in range(600):
		for n: Node in get_tree().get_nodes_in_group(&"npcs"):
			var actor: NpcActor = n as NpcActor
			if actor != null:
				actor.step_schedule(0.05, true)

	var plaza_center: Vector2 = _farm.get_world_marker_position("FestivalPlazaCenter")
	for nid: StringName in [&"maren", &"kaelen", &"aldric", &"bram", &"lyra"]:
		var a: NpcActor = _farm.find_npc_actor(nid)
		assert(a != null, "Missing actor %s" % String(nid))
		assert(a.global_position.distance_to(plaza_center) < 96.0, "NPC %s failed to reach Evening Plaza! pos=%s plaza=%s" % [String(nid), str(a.global_position), str(plaza_center)])
		assert(not a.is_walking(), "NPC %s should settle into IDLE upon reaching PlazaSpot" % String(nid))
		assert(a._body_spr.hframes == 9 and a._tool_spr.visible and a._tool_spr.hframes == 9, "Idle NPC must render 9-frame IDLE strip with both arms visible!")
	assert(lyra.global_position.distance_to(lyra_home) > 150.0, "Lyra must descend Highland ladder into Bramblebrook Plaza at 18:30!")

	print("[VerifyP5] PASS: All 5 NPCs walk road/bridge/ladder schedules (8-frame WALKING w/ both arms) and gather in Evening Plaza.")


func _test_community_board_quests() -> void:
	# 1. Interact with CommunityBoard -> opens QuestBoardModal with 3 daily requests
	var board: WorldInteractable = _farm.get_node_or_null("WorldEntities/CommunityBoard") as WorldInteractable
	assert(board != null, "Missing WorldEntities/CommunityBoard")
	board.trigger_interact()
	assert(_farm.quest_board_modal.is_open(), "CommunityBoard must open QuestBoardModal")
	assert(QuestManager.get_board_quests().size() == 3, "Expected 3 daily quests on Community Board, got %d" % QuestManager.get_board_quests().size())

	# 2. Accept Maren's Carrot Bundle (index 0) and Bram's Ocean Pier Catch (now index 1)
	assert(_farm.quest_board_modal.accept_board_quest_by_index(0), "Accepting Maren's Carrot quest must succeed")
	assert(_farm.quest_board_modal.accept_board_quest_by_index(1), "Accepting Bram's Ocean Fish quest must succeed")
	assert(QuestManager.get_active_quests().size() == 2, "Expected 2 active quests after accepting")
	_farm.quest_board_modal.set_open(false)

	# Verify compact HUD Quest Tracker became visible automatically!
	assert(_farm.hud._quest_tracker_panel.visible, "HUD Quest Tracker must become visible when active quests exist")

	# 3. Gather 3 Carrots -> verify Maren quest ready -> talk to Maren -> Turn In Quest!
	InventoryManager.add_item(&"crop_carrot", 3)
	var ready_q: QuestData = QuestManager.find_ready_quest_for_npc(&"maren")
	assert(ready_q != null and ready_q.quest_id == &"q_maren_carrots", "Maren's Carrot quest must be ready to turn in")

	var gold_before: int = EconomyManager.get_sunbursts()
	var pts_before: int = SocialManager.get_points(&"maren")
	var maren: NpcActor = _farm.find_npc_actor(&"maren")
	_farm.interact_with_npc(&"maren", maren)
	assert(_farm.dialogue_modal.is_open(), "Talking to Maren with ready quest must open DialogueModal")
	assert(_farm.dialogue_modal.trigger_turn_in_quest(), "Turning in Maren's quest must succeed")
	assert(EconomyManager.get_sunbursts() == gold_before + 180, "Turning in Maren's quest must credit +180 G")
	assert(SocialManager.get_points(&"maren") == pts_before + 150, "Turning in Maren's quest must award +150 Friendship")
	assert(InventoryManager.count_item(&"crop_carrot") == 0, "Turning in Maren's quest must consume 3 Carrots")
	assert(&"q_maren_carrots" in QuestManager.get_completed_quest_ids(), "Completed quest ID must be recorded")
	_farm.dialogue_modal.set_open(false)

	print("[VerifyP5] PASS: Community Board quest accept, HUD tracker, and NPC turn-in (+180 G & +150 Friendship) verified.")


func _test_biome_fishing_and_sales() -> void:
	var p: Player = _farm.player
	InventoryManager.select_hotbar_slot(5) # Fishing Rod

	# A. Ocean Pier North -> Ocean Biome Fish!
	var pier_pos: Vector2 = _farm.get_world_marker_position("OceanPierNorth")
	var pier_cell: Vector2i = _world_to_cell(pier_pos)
	p.global_position = pier_pos
	p.set_facing_cardinal(Vector2i(0, -1))
	assert(_farm.get_water_biome(pier_cell + Vector2i(0, -1)) == &"ocean", "Water north of OceanPierNorth must classify as &'ocean'")
	var cast_ocean: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(cast_ocean.valid and cast_ocean.kind == ActionValidator.ActionKind.CAST_FISHING, "Ocean pier cast must succeed")
	var caught_ocean: StringName = p.force_complete_fishing_catch()
	assert(caught_ocean in OCEAN_FISH, "Ocean pier must yield an ocean species, got %s" % String(caught_ocean))
	p.cancel_fishing()

	# B. Highland Spring Pond -> Highland Spring Biome Fish!
	var spring_bank: Vector2i = Vector2i(47, 12) # Directly south of Highland Spring Pond (47, 11)!
	# Stand at (52, 9) facing west into Highland Spring Pond (51, 9)
	p.global_position = Vector2(52.0 * 16.0 + 8.0, 9.0 * 16.0 + 8.0)
	p.set_facing_cardinal(Vector2i(-1, 0))
	var spring_water: Vector2i = Vector2i(51, 9)
	assert(_farm.is_water_cell(spring_water), "Highland Spring cell %s must be fishable water" % str(spring_water))
	assert(_farm.get_water_biome(spring_water) == &"highland_spring", "Highland Spring cell must classify as &'highland_spring'")
	var cast_spring: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(cast_spring.valid and cast_spring.kind == ActionValidator.ActionKind.CAST_FISHING, "Highland Spring cast must succeed")
	var caught_spring: StringName = p.force_complete_fishing_catch()
	assert(caught_spring in SPRING_FISH, "Highland Spring must yield Spring Koi or Mountain Minnow, got %s" % String(caught_spring))
	p.cancel_fishing()

	# C. Farm Pond / Central River -> River Biome Fish!
	var river_bank: Vector2 = _farm.get_world_marker_position("RiverBankSpot")
	var river_water: Vector2i = _world_to_cell(river_bank) + Vector2i(-1, 0)
	p.global_position = river_bank
	p.set_facing_cardinal(Vector2i(-1, 0))
	assert(_farm.get_water_biome(river_water) == &"river", "Farm Pond must classify as &'river'")
	var cast_river: ActionValidator.ActionResult = p.use_selected_item(true, true)
	assert(cast_river.valid and cast_river.kind == ActionValidator.ActionKind.CAST_FISHING, "Farm Pond cast must succeed")
	var caught_river: StringName = p.force_complete_fishing_catch()
	assert(caught_river in RIVER_FISH, "Farm Pond must yield River Trout, Sun Perch, or Golden Carp, got %s" % String(caught_river))
	p.cancel_fishing()

	# D. Verify Biome Fish sell cleanly at Maren's Shop AND ship cleanly via Shipping Chest!
	var ocean_slot: int = _find_slot_with(caught_ocean)
	var river_slot: int = _find_slot_with(caught_river)
	assert(ocean_slot >= 0 and river_slot >= 0, "Caught biome fish must be in player inventory")
	var ocean_price: int = InventoryManager.get_item(caught_ocean).sell_price
	var gold_before: int = EconomyManager.get_sunbursts()
	assert(EconomyManager.sell_from_inventory_slot(ocean_slot, 1), "Selling ocean fish at Shop must succeed")
	assert(EconomyManager.get_sunbursts() == gold_before + ocean_price, "Selling ocean fish must credit exact Sunbursts")
	assert(EconomyManager.ship_from_inventory_slot(river_slot, 1), "Shipping river fish via Shipping Chest must succeed")

	# Catch 1 fresh ocean fish back so Bram's active Ocean Pier Catch quest shows 1/2 live progress on Quest Board & HUD!
	InventoryManager.add_item(&"fish_ocean_snapper", 1)
	assert(spring_bank != Vector2i.ZERO)
	print("[VerifyP5] PASS: 3-biome fishing (Ocean=%s, Spring=%s, River=%s) & Shop/Shipping sales verified." % [String(caught_ocean), String(caught_spring), String(caught_river)])


func _snap_all_npcs_to_current_time() -> void:
	var h: float = TimeManager.get_hour_float()
	for n: Node in get_tree().get_nodes_in_group(&"npcs"):
		var actor: NpcActor = n as NpcActor
		if actor != null:
			actor.snap_to_schedule(h)


func _find_slot_with(item_id: StringName) -> int:
	for i: int in range(InventoryManager.SLOT_COUNT):
		if InventoryManager.get_slot_item_id(i) == item_id:
			return i
	return -1


func _save_viewport_png(res_path: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	assert(img != null, "Failed to capture viewport image")
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var err: Error = img.save_png(abs_path)
	assert(err == OK, "Failed to save screenshot: %s" % abs_path)
