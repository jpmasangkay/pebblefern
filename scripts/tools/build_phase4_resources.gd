extends Node

## Generates all Phase 4 Smelted Metal Bars, 6 Placeable Craftable Items, and 6 Crafting Recipes (.tres)
## using 100% real Sunnyside World V2.1 PNGs and tileset AtlasTextures (zero procedural images).

const AP := preload("res://scripts/core/asset_paths.gd")
const ItemDataScript := preload("res://resources/item_data.gd")
const RecipeDataScript := preload("res://resources/recipe_data.gd")

var _tileset_tex: Texture2D = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/items"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/recipes"))

	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	assert(_tileset_tex != null, "Missing Sunnyside tileset PNG: %s" % AP.TILESET_16PX)

	_build_smelted_bars()
	_build_placeable_items()
	_build_recipes()

	print("[BuildPhase4Res] Generated 2 smelted metal bars, 6 placeable items, and 6 crafting recipes cleanly.")
	get_tree().quit(0)


func _atlas_icon(coords: Vector2i, w_tiles: int = 1, h_tiles: int = 1) -> AtlasTexture:
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = _tileset_tex
	at.region = Rect2(coords.x * 16, coords.y * 16, w_tiles * 16, h_tiles * 16)
	return at


func _build_smelted_bars() -> void:
	var hammer_tex: Texture2D = load(AP.UI_HAMMER) as Texture2D
	assert(hammer_tex != null, "Missing UI hammer PNG: %s" % AP.UI_HAMMER)

	var specs: Array[Array] = [
		[
			"item_copper_bar", &"copper_bar", "Copper Bar",
			"Warm copper ingot smelted from Rock & Wood in a Stone Furnace. Used for Kaelen's upgrades.",
			_atlas_icon(AP.TILE_COPPER_ORE), hammer_tex, 0, 65,
		],
		[
			"item_iron_bar", &"iron_bar", "Iron Bar",
			"Tempered iron ingot forged in a Stone Furnace. Required for top-grade Iron tools.",
			_atlas_icon(AP.TILE_METAL_BAR), hammer_tex, 0, 130,
		],
	]

	for sp: Array in specs:
		var item: ItemData = ItemDataScript.new()
		item.id = sp[1] as StringName
		item.display_name = sp[2] as String
		item.description = sp[3] as String
		item.category = ItemData.Category.RESOURCE
		item.icon = sp[4] as Texture2D
		item.overlay_icon = sp[5] as Texture2D
		item.max_stack = 99
		item.buy_price = sp[6] as int
		item.sell_price = sp[7] as int
		var err: Error = ResourceSaver.save(item, "res://resources/items/%s.tres" % (sp[0] as String))
		assert(err == OK, "Failed to save %s" % (sp[0] as String))


func _build_placeable_items() -> void:
	var fire_strip: Texture2D = load(AP.FIRE_01_STRIP4) as Texture2D
	var pumpkin_tex: Texture2D = load(AP.CROPS_ROOT + "/pumpkin_05.png") as Texture2D
	assert(fire_strip != null and pumpkin_tex != null, "Missing fire/pumpkin sprites for craftables.")

	var fire_frame0: AtlasTexture = AtlasTexture.new()
	fire_frame0.atlas = fire_strip
	fire_frame0.region = Rect2(0, 0, int(fire_strip.get_width() / 4.0), fire_strip.get_height())

	var furnace_atlas: AtlasTexture = AtlasTexture.new()
	furnace_atlas.atlas = _tileset_tex
	furnace_atlas.region = Rect2(46 * 16 + 1, 19 * 16, 30, 44)

	var specs: Array[Array] = [
		[
			"item_placed_chest", &"place_chest", &"chest", "Storage Chest",
			"Sturdy 16-slot persistent storage chest. Place on the sanctuary to store crops, tools, and bars.",
			_atlas_icon(AP.TILE_CHEST_CLOSED), null, 10, 40,
		],
		[
			"item_wooden_fence", &"place_fence", &"fence", "Wooden Fence",
			"Classic wooden farm fence to border garden plots and walkways.",
			_atlas_icon(AP.TILE_FENCE_H_MID), null, 99, 5,
		],
		[
			"item_outdoor_torch", &"place_torch", &"torch", "Outdoor Torch",
			"Warm lantern post with animated flame that illuminates your farm at dusk and night.",
			_atlas_icon(AP.TILE_FENCE_V_BOTTOM), fire_frame0, 50, 10,
		],
		[
			"item_stone_path", &"place_stone_path", &"stone_path", "Stone Path",
			"Walkable grey cobblestone paver for neat courtyard footpaths.",
			_atlas_icon(AP.TILE_STONE_PATH), null, 99, 4,
		],
		[
			"item_scarecrow", &"place_scarecrow", &"scarecrow", "Scarecrow",
			"Cozy pumpkin guardian protecting surrounding garden crops across a 5-tile radius.",
			pumpkin_tex, _atlas_icon(AP.TILE_FENCE_V_BOTTOM), 10, 50,
		],
		[
			"item_furnace", &"place_furnace", &"furnace", "Stone Furnace",
			"Interact [E] to smelt Rock + Wood into Copper Bars and Iron Bars for Kaelen's upgrades.",
			furnace_atlas, fire_frame0, 10, 60,
		],
	]

	for sp: Array in specs:
		var item: ItemData = ItemDataScript.new()
		item.id = sp[1] as StringName
		item.placeable_object_id = sp[2] as StringName
		item.display_name = sp[3] as String
		item.description = sp[4] as String
		item.category = ItemData.Category.CRAFTABLE
		item.icon = sp[5] as Texture2D
		item.overlay_icon = sp[6] as Texture2D
		item.max_stack = sp[7] as int
		item.buy_price = 0
		item.sell_price = sp[8] as int
		var err: Error = ResourceSaver.save(item, "res://resources/items/%s.tres" % (sp[0] as String))
		assert(err == OK, "Failed to save %s" % (sp[0] as String))


func _build_recipes() -> void:
	# [file_stem, recipe_id, display_name, desc, out_id, out_count, ing_ids, ing_counts]
	var specs: Array[Array] = [
		[
			"recipe_chest", &"recipe_chest", "Storage Chest",
			"16-slot persistent storage chest for crops, seeds, fish, and bars.",
			&"place_chest", 1,
			[&"wood"], PackedInt32Array([15]),
		],
		[
			"recipe_fence", &"recipe_fence", "Wooden Fence",
			"Craft 2 wooden fence segments to frame your sanctuary garden.",
			&"place_fence", 2,
			[&"wood"], PackedInt32Array([2]),
		],
		[
			"recipe_torch", &"recipe_torch", "Outdoor Torch",
			"Animated lantern post casting warm light across your farm at night.",
			&"place_torch", 1,
			[&"wood", &"fiber"], PackedInt32Array([2, 1]),
		],
		[
			"recipe_stone_path", &"recipe_stone_path", "Stone Path",
			"Craft 2 walkable cobblestone pavers for courtyard walkways.",
			&"place_stone_path", 2,
			[&"stone"], PackedInt32Array([2]),
		],
		[
			"recipe_scarecrow", &"recipe_scarecrow", "Scarecrow",
			"Protects nearby garden beds in a 5-tile radius.",
			&"place_scarecrow", 1,
			[&"wood", &"fiber", &"stone"], PackedInt32Array([12, 5, 2]),
		],
		[
			"recipe_furnace", &"recipe_furnace", "Stone Furnace",
			"Smelt Rock + Wood into Copper Bars and Iron Bars for tool upgrades.",
			&"place_furnace", 1,
			[&"stone", &"wood"], PackedInt32Array([12, 4]),
		],
	]

	for sp: Array in specs:
		var r: RecipeData = RecipeDataScript.new()
		r.id = sp[1] as StringName
		r.display_name = sp[2] as String
		r.description = sp[3] as String
		r.output_item_id = sp[4] as StringName
		r.output_count = sp[5] as int
		var ing_ids: Array[StringName] = []
		for iid: Variant in (sp[6] as Array):
			ing_ids.append(iid as StringName)
		r.ingredient_ids = ing_ids
		r.ingredient_counts = sp[7] as PackedInt32Array
		var err: Error = ResourceSaver.save(r, "res://resources/recipes/%s.tres" % (sp[0] as String))
		assert(err == OK, "Failed to save %s" % (sp[0] as String))
