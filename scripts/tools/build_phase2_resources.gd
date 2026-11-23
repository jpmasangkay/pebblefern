extends Node

## Generates verified .tres resource instances for all 6 Tools, 11 Crops, 11 Seeds,
## 11 Harvested Produce items, and core crafting/foraging resources using real Sunnyside PNGs.

const AP := preload("res://scripts/core/asset_paths.gd")
const ItemDataScript := preload("res://resources/item_data.gd")
const ToolDataScript := preload("res://resources/tool_data.gd")
const CropDataScript := preload("res://resources/crop_data.gd")


func _ready() -> void:
	_ensure_dir("res://resources/tools")
	_ensure_dir("res://resources/crops")
	_ensure_dir("res://resources/items")

	_build_tools()
	_build_crops_and_seeds()
	_build_core_resources()

	print("[BuildPhase2Res] All 6 tools, 11 crops, 11 seeds, 11 produce items, and 4 core resources saved.")
	get_tree().quit(0)


func _ensure_dir(res_path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	DirAccess.make_dir_recursive_absolute(abs_path)


func _save_res(res: Resource, path: String) -> void:
	var err: Error = ResourceSaver.save(res, path)
	assert(err == OK, "Failed to save %s (err=%d)" % [path, err])


func _build_tools() -> void:
	# [id, name, desc, kind, icon_path, max_charges, anim_state]
	# anim_state matches Player.AnimState: HOE=3, WATER=4, AXE=5, MINE=6, ATTACK=7, FISH=8
	var specs: Array[Array] = [
		[&"tool_hoe", "Rusty Hoe", "Tills meadow and garden earth for planting seeds.", ToolData.ToolKind.HOE, AP.ICON_HOE, 0, 3],
		[&"tool_watering_can", "Watering Can", "Waters tilled crops (40 charges). Refill at rivers or ponds.", ToolData.ToolKind.WATERING_CAN, AP.ICON_WATERING_CAN, 40, 4],
		[&"tool_axe", "Woodsman Axe", "Chops trees and stumps into sturdy timber.", ToolData.ToolKind.AXE, AP.ICON_AXE, 0, 5],
		[&"tool_pickaxe", "Miner Pickaxe", "Breaks rocks and quarry boulders into stone and ore.", ToolData.ToolKind.PICKAXE, AP.ICON_PICKAXE, 0, 6],
		[&"tool_scythe", "Sanctuary Scythe", "Clears weeds, withered stalks, and harvests mature crops.", ToolData.ToolKind.SCYTHE, AP.ICON_SCYTHE, 0, 7],
		[&"tool_fishing_rod", "Bamboo Rod", "Casts a line into rivers and ponds to reel in fresh fish.", ToolData.ToolKind.FISHING_ROD, AP.ICON_FISHING_ROD, 0, 8],
	]

	for s: Array in specs:
		var tool: ToolData = ToolDataScript.new()
		tool.id = s[0]
		tool.display_name = s[1]
		tool.description = s[2]
		tool.category = ItemData.Category.TOOL
		tool.tool_kind = s[3]
		tool.icon = load(s[4]) as Texture2D
		assert(tool.icon != null, "Missing tool icon: %s" % s[4])
		tool.max_stack = 1
		tool.tier = ToolData.ToolTier.BASIC
		tool.power = 1
		tool.vitality_cost = 2.0
		tool.max_charges = s[5]
		tool.player_anim_state = s[6]
		_save_res(tool, "res://resources/tools/%s.tres" % String(tool.id))


func _build_crops_and_seeds() -> void:
	var seed_pouch_tex: Texture2D = load(AP.ITEM_SEEDS_GENERIC) as Texture2D
	assert(seed_pouch_tex != null, "Missing seeds_generic.png")

	# [stem, display_name, botanical, seasons, days, seed_buy, crop_sell, vit_restore, min_y, max_y]
	var specs: Array[Array] = [
		["parsnip", "Parsnip", "Pastinaca sativa", PackedInt32Array([0]), 4, 20, 35, 18.0, 1, 1],
		["carrot", "Carrot", "Daucus carota", PackedInt32Array([0]), 4, 25, 45, 22.0, 1, 1],
		["potato", "Potato", "Solanum tuberosum", PackedInt32Array([0]), 6, 50, 80, 25.0, 1, 2],
		["cauliflower", "Cauliflower", "Brassica oleracea", PackedInt32Array([0]), 12, 80, 175, 40.0, 1, 1],
		["kale", "Kale", "Brassica sabellica", PackedInt32Array([0, 2]), 6, 70, 110, 28.0, 1, 1],
		["radish", "Radish", "Raphanus sativus", PackedInt32Array([1]), 6, 40, 90, 24.0, 1, 1],
		["sunflower", "Sunflower", "Helianthus annuus", PackedInt32Array([1, 2]), 8, 60, 120, 15.0, 1, 1],
		["wheat", "Wheat", "Triticum aestivum", PackedInt32Array([1, 2]), 4, 10, 30, 10.0, 1, 1],
		["cabbage", "Cabbage", "Brassica capitata", PackedInt32Array([1]), 9, 100, 210, 35.0, 1, 1],
		["beetroot", "Beetroot", "Beta vulgaris", PackedInt32Array([2]), 6, 50, 100, 26.0, 1, 1],
		["pumpkin", "Pumpkin", "Cucurbita pepo", PackedInt32Array([2]), 13, 100, 320, 45.0, 1, 1],
	]

	assert(specs.size() == 11, "Must define all 11 Sunnyside World crops.")
	for s: Array in specs:
		var stem: String = s[0]
		var crop_name: String = s[1]
		var seed_id: StringName = StringName("seed_" + stem)
		var harvest_id: StringName = StringName("crop_" + stem)

		var stages: Array[Texture2D] = []
		for stage_idx: int in range(5):
			var spath: String = "%s/%s_0%d.png" % [AP.CROPS_ROOT, stem, stage_idx]
			var stex: Texture2D = load(spath) as Texture2D
			assert(stex != null, "Missing crop stage PNG: %s" % spath)
			stages.append(stex)

		var harvest_path: String = "%s/%s_05.png" % [AP.CROPS_ROOT, stem]
		var harvest_tex: Texture2D = load(harvest_path) as Texture2D
		assert(harvest_tex != null, "Missing crop harvest icon PNG: %s" % harvest_path)

		# 1. CropData resource
		var crop: CropData = CropDataScript.new()
		crop.crop_id = StringName(stem)
		crop.display_name = crop_name
		crop.botanical_name = s[2]
		crop.seed_item_id = seed_id
		crop.harvest_item_id = harvest_id
		crop.seasons = s[3]
		crop.days_to_mature = s[4]
		crop.stage_textures = stages
		crop.harvest_icon = harvest_tex
		crop.harvest_min_yield = s[8]
		crop.harvest_max_yield = s[9]
		_save_res(crop, "res://resources/crops/crop_%s.tres" % stem)

		# 2. Seed Packet ItemData
		var seed_item: ItemData = ItemDataScript.new()
		seed_item.id = seed_id
		seed_item.display_name = "%s Seeds" % crop_name
		seed_item.description = "Plant on tilled soil. Matures in %d days." % crop.days_to_mature
		seed_item.category = ItemData.Category.SEED
		seed_item.icon = seed_pouch_tex
		seed_item.overlay_icon = harvest_tex
		seed_item.max_stack = 99
		seed_item.buy_price = s[5]
		seed_item.sell_price = maxi(1, int(s[5] / 2))
		seed_item.crop_id = crop.crop_id
		_save_res(seed_item, "res://resources/items/%s.tres" % String(seed_id))

		# 3. Harvested Produce ItemData
		var harvest_item: ItemData = ItemDataScript.new()
		harvest_item.id = harvest_id
		harvest_item.display_name = crop_name
		harvest_item.description = "Freshly harvested %s from Solstice Sanctuary." % crop_name
		harvest_item.category = ItemData.Category.CROP
		harvest_item.icon = harvest_tex
		harvest_item.max_stack = 99
		harvest_item.buy_price = s[6] * 2
		harvest_item.sell_price = s[6]
		harvest_item.vitality_restore = s[7]
		harvest_item.crop_id = crop.crop_id
		_save_res(harvest_item, "res://resources/items/item_%s.tres" % stem)


func _build_core_resources() -> void:
	var tileset_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	assert(tileset_tex != null, "Missing tileset texture for resource icons.")

	var wood: ItemData = ItemDataScript.new()
	wood.id = &"wood"
	wood.display_name = "Wood"
	wood.description = "Sturdy sanctuary timber used for crafting fences, chests, and upgrades."
	wood.category = ItemData.Category.RESOURCE
	wood.icon = load(AP.ITEM_WOOD) as Texture2D
	assert(wood.icon != null, "Missing wood.png")
	wood.max_stack = 99
	wood.sell_price = 4
	_save_res(wood, "res://resources/items/item_wood.tres")

	var stone: ItemData = ItemDataScript.new()
	stone.id = &"stone"
	stone.display_name = "Stone"
	stone.description = "Solid grey quarry stone useful for paths, furnaces, and building."
	stone.category = ItemData.Category.RESOURCE
	stone.icon = load(AP.ITEM_ROCK) as Texture2D
	assert(stone.icon != null, "Missing rock.png")
	stone.max_stack = 99
	stone.sell_price = 5
	_save_res(stone, "res://resources/items/item_stone.tres")

	var fiber: ItemData = ItemDataScript.new()
	fiber.id = &"fiber"
	fiber.display_name = "Wild Fiber"
	fiber.description = "Tough meadow stems gathered with a scythe."
	fiber.category = ItemData.Category.RESOURCE
	fiber.icon = load(AP.ICON_PLANT) as Texture2D
	assert(fiber.icon != null, "Missing plant.png")
	fiber.max_stack = 99
	fiber.sell_price = 2
	_save_res(fiber, "res://resources/items/item_fiber.tres")

	var berry_tex: AtlasTexture = AtlasTexture.new()
	berry_tex.atlas = tileset_tex
	berry_tex.region = Rect2(48 * 16, 3 * 16, 16, 16) # Verified red wild berries cluster
	var berry: ItemData = ItemDataScript.new()
	berry.id = &"wild_berry"
	berry.display_name = "Bramble Berry"
	berry.description = "Sweet woodland berries that restore Vitality."
	berry.category = ItemData.Category.FORAGE
	berry.icon = berry_tex
	berry.max_stack = 99
	berry.sell_price = 18
	berry.vitality_restore = 20.0
	_save_res(berry, "res://resources/items/item_wild_berry.tres")
