extends Node

## Generates all Phase 5 Biome Fish ItemData (.tres) and 5 Villager NpcData (.tres) resources
## using 100% real Sunnyside World V2.1 PNGs and tileset AtlasTextures (zero procedural images).

const AP := preload("res://scripts/core/asset_paths.gd")
const ItemDataScript := preload("res://resources/item_data.gd")
const NpcDataScript := preload("res://resources/npc_data.gd")

var _tileset_tex: Texture2D = null
var _fish_tex: Texture2D = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/items"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/npcs"))

	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	_fish_tex = load(AP.ITEM_FISH) as Texture2D
	assert(_tileset_tex != null, "Missing Sunnyside tileset PNG: %s" % AP.TILESET_16PX)
	assert(_fish_tex != null, "Missing Sunnyside fish PNG: %s" % AP.ITEM_FISH)

	_build_biome_fish_items()
	_build_npc_profiles()

	print("[BuildPhase5Res] Generated 8 biome fish items and 5 NpcData villager profiles cleanly.")
	get_tree().quit(0)


func _atlas_icon(coords: Vector2i) -> AtlasTexture:
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = _tileset_tex
	at.region = Rect2(coords.x * 16, coords.y * 16, 16, 16)
	return at


func _build_biome_fish_items() -> void:
	# [file_stem, item_id, display_name, desc, tint, overlay_tex, sell_price, vitality_restore]
	var specs: Array[Array] = [
		# Farm Pond & Central River
		[
			"item_fish_river_trout", &"fish_river_trout", "River Trout",
			"Speckled freshwater trout caught in the Farm Pond or Central Village River.",
			Color(0.84, 0.98, 0.90, 1.0), null, 45, 18.0,
		],
		[
			"item_fish_sun_perch", &"fish_sun_perch", "Sun Perch",
			"Warm amber-finned perch fond of sunny bends along Bramblebrook River.",
			Color(1.0, 0.88, 0.54, 1.0), null, 55, 20.0,
		],
		[
			"item_fish_golden_carp", &"fish_golden_carp", "Golden Carp",
			"A rare gleaming carp prized across the valley. Bram's favorite river catch!",
			Color(1.0, 0.84, 0.24, 1.0), _atlas_icon(AP.TILE_COIN_PILE), 140, 35.0,
		],
		# Highland Spring Pond
		[
			"item_fish_spring_koi", &"fish_spring_koi", "Spring Koi",
			"Vibrant vermilion koi raised in the crystal-clear waters of Highland Spring.",
			Color(1.0, 0.60, 0.48, 1.0), _atlas_icon(AP.TILE_FLOWER_WHITE_SINGLE), 85, 25.0,
		],
		[
			"item_fish_mountain_minnow", &"fish_mountain_minnow", "Mountain Minnow",
			"Nimble silver-blue minnow darting near the northern waterfall brink.",
			Color(0.76, 0.92, 1.0, 1.0), null, 50, 16.0,
		],
		# Eastern Ocean Beach & Fishing Piers
		[
			"item_fish_sea_bass", &"fish_sea_bass", "Sea Bass",
			"Hearty saltwater bass hooked off Bram's wooden coastal piers.",
			Color(0.64, 0.84, 1.0, 1.0), _atlas_icon(AP.TILE_SHELL_TAN), 65, 22.0,
		],
		[
			"item_fish_ocean_snapper", &"fish_ocean_snapper", "Ocean Snapper",
			"Ruby-scaled reef snapper from deep eastern waters. A delicacy in Bramblebrook!",
			Color(1.0, 0.52, 0.54, 1.0), _atlas_icon(AP.TILE_STARFISH), 95, 28.0,
		],
		[
			"item_fish_coral_flounder", &"fish_coral_flounder", "Coral Flounder",
			"Rare iridescent flatfish found only off the outer ocean piers.",
			Color(0.96, 0.68, 1.0, 1.0), _atlas_icon(AP.TILE_SHELL_PINK), 150, 36.0,
		],
	]

	for sp: Array in specs:
		var item: ItemData = ItemDataScript.new()
		item.id = sp[1] as StringName
		item.display_name = sp[2] as String
		item.description = sp[3] as String
		item.category = ItemData.Category.FORAGE
		item.icon = _fish_tex
		item.icon_tint = sp[4] as Color
		item.overlay_icon = sp[5] as Texture2D
		item.max_stack = 99
		item.buy_price = 0
		item.sell_price = sp[6] as int
		item.vitality_restore = sp[7] as float
		var err: Error = ResourceSaver.save(item, "res://resources/items/%s.tres" % (sp[0] as String))
		assert(err == OK, "Failed to save fish item %s" % (sp[0] as String))


func _build_npc_profiles() -> void:
	# 1. MAREN — Botanist & Seed Merchant
	var maren: NpcData = NpcDataScript.new()
	maren.npc_id = &"maren"
	maren.display_name = "Maren"
	maren.role_title = "Botanist & Seed Merchant"
	maren.bio = "Runs the green-roofed Seed Shop in Bramblebrook."
	maren.hair_style = &"curlyhair"
	maren.hair_tint = Color.WHITE
	maren.home_building_id = &"maren_cottage"
	maren.shop_id = &"maren_seeds"
	maren.loved_items = [&"crop_sunflower", &"crop_cauliflower"]
	maren.liked_items = [&"wild_berry"]
	maren.disliked_items = [&"stone", &"fiber"]
	maren.liked_categories = PackedInt32Array([ItemData.Category.CROP])
	maren.morning_lines = PackedStringArray([
		"Morning dew still clings to the clover! Fresh seed packets are sorted for your garden.",
		"Solstice Plateau catches the very first sunlight — parsnips and sunflowers adore it up there.",
	])
	maren.afternoon_lines = PackedStringArray([
		"Step right up to the stall whenever you need fresh seeds or want to sell your harvest!",
		"I've been sketching petal charts all afternoon. Nothing beats a crisp head of cauliflower.",
	])
	maren.evening_lines = PackedStringArray([
		"What a lovely evening in Bramblebrook Plaza! It's nice to rest my feet after market hours.",
		"The lanterns coming on around the square always remind me how cozy this little island is.",
	])
	maren.season_lines = PackedStringArray([
		"Bloom season is here! Parsnips, carrots, potatoes, and cauliflower are all thriving.",
		"Sun season makes my sunflowers stretch right toward the sky — keep your watering can topped up!",
		"Harvest brings rich orange pumpkins and crisp cabbages. The whole village smells of cider!",
		"Frost quietens the soil, so it's the finest time to gather timber, fish, and plan spring beds.",
	])
	maren.heart3_lines = PackedStringArray([
		"You've got a genuine green thumb, friend! Every time you pass my cottage, the garden looks brighter.",
		"I set aside my plumpest sunflower seeds whenever I spot you crossing the farm bridge!",
	])
	maren.heart6_lines = PackedStringArray([
		"Honestly, Solstice Farm hasn't bloomed like this in years. I'm so glad you made Pebblefern your home.",
		"Whenever you bring me fresh flowers or veggies, it feels like the whole island is thriving together.",
	])
	maren.gift_loved_line = "Oh!! A gleaming beauty — you remembered my absolute favorite! I'll press a petal in my journal!"
	maren.gift_liked_line = "Ooh, so fresh and vibrant! Thank you kindly — I can't wait to cook with this tonight!"
	maren.gift_neutral_line = "Oh, for me? How thoughtful of you to drop by!"
	maren.gift_disliked_line = "Oh... well, I suppose I can tuck this behind the potting shed. Thanks anyway."
	_save_npc(maren, "npc_maren")

	# 2. KAELEN — Blacksmith & Forgemaster
	var kaelen: NpcData = NpcDataScript.new()
	kaelen.npc_id = &"kaelen"
	kaelen.display_name = "Kaelen"
	kaelen.role_title = "Blacksmith & Forgemaster"
	kaelen.bio = "Forges Copper & Iron tools at South Road Forge."
	kaelen.hair_style = &"spikeyhair"
	kaelen.hair_tint = Color(0.84, 0.78, 0.76, 1.0)
	kaelen.home_building_id = &"kaelen_forge"
	kaelen.shop_id = &"kaelen_forge"
	kaelen.loved_items = [&"copper_bar", &"iron_bar"]
	kaelen.liked_items = [&"stone", &"wood", &"crop_potato"]
	kaelen.disliked_items = [&"fiber", &"wild_berry"]
	kaelen.liked_categories = PackedInt32Array()
	kaelen.morning_lines = PackedStringArray([
		"Coals are glowing bright already. Good steel starts with an early fire!",
		"Heading down to Pebblefern Quarry? Upgrade your Pickaxe and those copper boulders crack like walnuts.",
	])
	kaelen.afternoon_lines = PackedStringArray([
		"Ring of the anvil keeps the whole south lane awake. Need a Copper or Iron upgrade?",
		"Build yourself a Stone Furnace from your Craft tab — smelt Rock and Wood into clean bars!",
	])
	kaelen.evening_lines = PackedStringArray([
		"Quenched the hearth for the night. Nothing beats cool plaza breeze after ten hours by the coals.",
		"Even a blacksmith needs a quiet evening chat with neighbors.",
	])
	kaelen.season_lines = PackedStringArray([
		"Bloom rain keeps my quench trough full without me hauling a single bucket!",
		"Sun heat plus forge heat? Haha, keeps my shoulders loose!",
		"Harvest is when folks wear their hoes and scythes down — bring 'em by if the edge dulls.",
		"Frost nights are best spent right beside my furnace. Warmest corner on Pebblefern Island!",
	])
	kaelen.heart3_lines = PackedStringArray([
		"You swing a sturdy tool, farmer. I'd trust my finest tempered iron in your hands any day.",
		"Next time you roast potatoes, save one for me — best forge supper there is!",
	])
	kaelen.heart6_lines = PackedStringArray([
		"I've forged blades and plows for twenty years, and watching you rebuild Solstice Farm beats every commission.",
		"Consider my anvil yours anytime, friend. We're keeping this island strong together.",
	])
	kaelen.gift_loved_line = "Whoa — pure, clean-smelted metal! Look at that grain! You really know how to make a smith grin!"
	kaelen.gift_liked_line = "Solid and practical — just how I like it! Much appreciated!"
	kaelen.gift_neutral_line = "Heh, appreciate you bringing this over."
	kaelen.gift_disliked_line = "Er... not much use for this around hot coals, but thanks for the thought."
	_save_npc(kaelen, "npc_kaelen")

	# 3. MAYOR ALDRIC — Mayor of Bramblebrook
	var aldric: NpcData = NpcDataScript.new()
	aldric.npc_id = &"aldric"
	aldric.display_name = "Mayor Aldric"
	aldric.role_title = "Mayor of Bramblebrook"
	aldric.bio = "Curates the Community Board at Village Hall."
	aldric.hair_style = &"bowlhair"
	aldric.hair_tint = Color(1.25, 2.05, 2.35, 1.0)
	aldric.home_building_id = &"aldric_hall"
	aldric.shop_id = &""
	aldric.loved_items = [&"crop_pumpkin", &"crop_cabbage", &"crop_sunflower"]
	aldric.liked_items = [&"crop_carrot", &"crop_parsnip"]
	aldric.disliked_items = [&"fiber", &"stone"]
	aldric.liked_categories = PackedInt32Array()
	aldric.morning_lines = PackedStringArray([
		"A splendid morning across Bramblebrook! Have you checked the Community Board today?",
		"Every freshly tilled row on Solstice Plateau puts new spirit into our whole township.",
	])
	aldric.afternoon_lines = PackedStringArray([
		"Neighbors pin fresh requests on the Community Board every morning — great way to earn Sunbursts and goodwill!",
		"I do love watching everyone gather in the plaza as the afternoon light softens.",
	])
	aldric.evening_lines = PackedStringArray([
		"Good evening, my friend! Seeing all five lanterns aglow over the square warms an old mayor's heart.",
		"Don't forget to rest before midnight — Solstice Farm will be waiting fresh at dawn.",
	])
	aldric.season_lines = PackedStringArray([
		"Bloom brings fresh hope to Bramblebrook! Let's make this our finest season yet.",
		"Sun days are bright and generous — perfect weather for strolling out to Bram's piers.",
		"Ah, Harvest! Nothing rivals a prize pumpkin or crisp cabbage on the Village Hall table!",
		"Frost settles gently over our roofs. Keep warm and look out for your neighbors!",
	])
	aldric.heart3_lines = PackedStringArray([
		"Everyone in Bramblebrook speaks warmly of you! You've stitched our little community right back together.",
		"Stop by Village Hall anytime — the tea kettle is always on for a good friend.",
	])
	aldric.heart6_lines = PackedStringArray([
		"When I first handed you the deed to Solstice Plateau, I hoped for the best — you've surpassed every dream!",
		"Pebblefern Island is truly lucky to have you as a neighbor and dear friend.",
	])
	aldric.gift_loved_line = "Magnificent!! A prize-worthy specimen! Why, this deserves a place of honor in Village Hall!"
	aldric.gift_liked_line = "Splendid, truly splendid! Nothing better than homegrown island produce!"
	aldric.gift_neutral_line = "Why thank you kindly! Very neighborly of you."
	aldric.gift_disliked_line = "Hmm, quite an unconventional gift... I'll file it away politely."
	_save_npc(aldric, "npc_aldric")

	# 4. BRAM — Coastal Angler & Pier Keeper
	var bram: NpcData = NpcDataScript.new()
	bram.npc_id = &"bram"
	bram.display_name = "Bram"
	bram.role_title = "Coastal Angler & Pier Keeper"
	bram.bio = "Tends the wooden ocean piers on East Islet."
	bram.hair_style = &"mophair"
	bram.hair_tint = Color(0.86, 0.82, 0.75, 1.0)
	bram.home_building_id = &"bram_cabin"
	bram.shop_id = &""
	bram.loved_items = [&"fish_ocean_snapper", &"fish_golden_carp", &"fish", &"fish_river_trout", &"fish_sun_perch"]
	bram.liked_items = [&"wood", &"crop_carrot", &"fish_sea_bass", &"fish_coral_flounder", &"fish_spring_koi", &"fish_mountain_minnow"]
	bram.disliked_items = [&"stone", &"fiber"]
	bram.liked_categories = PackedInt32Array()
	bram.morning_lines = PackedStringArray([
		"Tide's rolling in clean over the sandbar! Ocean Snappers bite sharp right off the north pier.",
		"Try casting in the Highland Spring, the Village River, and my Ocean Piers — every water holds its own catch!",
	])
	bram.afternoon_lines = PackedStringArray([
		"Salt air and creaking pier planks — can't imagine a finer office than this islet!",
		"Watch for that exclamation splash when your line tugs, then reel quick!",
	])
	bram.evening_lines = PackedStringArray([
		"Strolled across the ocean bridge to swap tall tales in the plaza! Care for a fishing story?",
		"Once hooked a Golden Carp in the river so bright it lit up the bridge pilings — true story!",
	])
	bram.season_lines = PackedStringArray([
		"Bloom tides bring lively schools of Sea Bass right up against the pilings.",
		"Sun season turns the eastern channel pure turquoise — best pier-casting weather all year!",
		"Harvest swells push fat Ocean Snappers closer to shore. Bring your rod!",
		"Frost chill makes the water glass-clear — great for spotting Spring Koi up north!",
	])
	bram.heart3_lines = PackedStringArray([
		"You've got proper angler's patience! Save a spot on the north pier next time you head east.",
		"I patched an extra plank on the ocean bridge so your boots stay dry crossing over!",
	])
	bram.heart6_lines = PackedStringArray([
		"Best fishing buddy I've ever had on Pebblefern! Come sunrise or dusk, my pier's always open to you.",
		"Between your harvests and our catches, Bramblebrook eats like royalty!",
	])
	bram.gift_loved_line = "By the tide!! What a catch! Look at the shine on those scales — you're a natural angler!"
	bram.gift_liked_line = "Hey, right on! Always handy down by the piers — thanks a bunch!"
	bram.gift_neutral_line = "Much obliged, mate! Good seeing you."
	bram.gift_disliked_line = "Heh, can't use that as bait or plank patch, I'm afraid. Still, thanks!"
	_save_npc(bram, "npc_bram")

	# 5. LYRA — Highland Forager & Herbalist
	var lyra: NpcData = NpcDataScript.new()
	lyra.npc_id = &"lyra"
	lyra.display_name = "Lyra"
	lyra.role_title = "Highland Forager & Herbalist"
	lyra.bio = "Forages wild berries by the Highland Spring."
	lyra.hair_style = &"longhair"
	lyra.hair_tint = Color(0.95, 0.78, 0.65, 1.0)
	lyra.home_building_id = &"lyra_cabin"
	lyra.shop_id = &""
	lyra.loved_items = [&"wild_berry", &"crop_radish", &"crop_beetroot"]
	lyra.liked_items = [&"wood", &"crop_kale", &"crop_sunflower"]
	lyra.disliked_items = [&"copper_bar", &"iron_bar"]
	lyra.liked_categories = PackedInt32Array()
	lyra.morning_lines = PackedStringArray([
		"Pine needles smell sweetest just after dawn! Did you climb the cliff ladder all the way up?",
		"Check the bushes beneath the northern pines — fresh Wild Berries ripen every few days!",
	])
	lyra.afternoon_lines = PackedStringArray([
		"Listen to the Highland Waterfall spill down into the valley... the whole island drinks from this spring.",
		"Cast a line in the Highland Spring sometime — shy Spring Koi and Mountain Minnows glide right below the lilies.",
	])
	lyra.evening_lines = PackedStringArray([
		"I always climb down the wooden ladder at dusk to catch up with Maren and everyone in the plaza.",
		"Starlight over Bramblebrook Plaza feels almost as peaceful as my pine grove.",
	])
	lyra.season_lines = PackedStringArray([
		"Bloom wakes every fern and wild berry shoot across the northern ridge!",
		"Sun filters through the pine canopy like warm honey — crisp radishes taste heavenly in this weather.",
		"Harvest tints the highland moss gold and crimson. Best season for earthy beetroot tea!",
		"Frost hushes the woods until you can hear every single droplet of the waterfall.",
	])
	lyra.heart3_lines = PackedStringArray([
		"The woodland birds don't even scatter when you climb the ladder anymore — they recognize a friend!",
		"I dried a bundle of highland mint for your farmhouse next time you visit.",
	])
	lyra.heart6_lines = PackedStringArray([
		"I used to spend weeks alone in the pines, but sharing the island with you has made every season warmer.",
		"Whenever you need quiet air or sweet berries, my hearth in the highlands is always lit for you.",
	])
	lyra.gift_loved_line = "Oh, what a jewel of the earth! Crisp, fragrant, and my very favorite — thank you from the heart!"
	lyra.gift_liked_line = "Lovely! This fits right into my woodland pantry — thank you so much!"
	lyra.gift_neutral_line = "Thank you for bringing this all the way over!"
	lyra.gift_disliked_line = "Ooh, cold forged metal feels so heavy compared to forest herbs... thank you though."
	_save_npc(lyra, "npc_lyra")


func _save_npc(npc: NpcData, file_stem: String) -> void:
	var err: Error = ResourceSaver.save(npc, "res://resources/npcs/%s.tres" % file_stem)
	assert(err == OK, "Failed to save NpcData %s" % file_stem)
