extends Node

## Generates all Phase 6 Mine Cave ItemData (.tres) resources (Copper Ore, Iron Ore,
## Azure Crystal, Ember Gem, and Shadow Shard) using 100% real Sunnyside World V2.1 PNGs.

const AP := preload("res://scripts/core/asset_paths.gd")
const ItemDataScript := preload("res://resources/item_data.gd")

var _tileset_tex: Texture2D = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/items"))
	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	assert(_tileset_tex != null, "Missing Sunnyside tileset PNG: %s" % AP.TILESET_16PX)

	_build_phase6_items()
	print("[BuildPhase6Res] Generated 5 mine cave ore/gem/loot ItemData resources cleanly.")
	get_tree().quit(0)


func _atlas_icon(coords: Vector2i) -> AtlasTexture:
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = _tileset_tex
	# Tight-crop 12x12 around verified ore/crystal sprite bounds (3..12 inside 16x16)
	at.region = Rect2(coords.x * 16 + 2, coords.y * 16 + 2, 12, 12)
	return at


func _build_phase6_items() -> void:
	# [file_stem, id, display_name, desc, category, atlas_coords, tint, sell_price]
	var specs: Array[Array] = [
		[
			"item_copper_ore",
			&"copper_ore",
			"Copper Ore",
			"Gleaming raw copper mined inside Pebblefern Cave. Smelt 3 with 1 Wood in a Stone Furnace!",
			ItemData.Category.RESOURCE,
			AP.TILE_COPPER_ORE,
			Color.WHITE,
			20,
		],
		[
			"item_iron_ore",
			&"iron_ore",
			"Iron Ore",
			"Heavy subterranean iron ore from deeper mine floors. Smelt 3 with 1 Wood into an Iron Bar!",
			ItemData.Category.RESOURCE,
			AP.TILE_IRON_ORE,
			Color.WHITE,
			35,
		],
		[
			"item_cave_crystal",
			&"cave_crystal",
			"Azure Crystal",
			"Luminous cyan quartz crystal chipped from cave walls. Prized at shops and the Bloom Festival!",
			ItemData.Category.FORAGE,
			AP.TILE_CAVE_CRYSTAL,
			Color.WHITE,
			95,
		],
		[
			"item_cave_ruby",
			&"cave_ruby",
			"Ember Gem",
			"Rare ruby-red crystal from Floor 3 of Pebblefern Mine. Commands top Sunbursts & festival glory!",
			ItemData.Category.FORAGE,
			AP.TILE_IRON_ORE,
			Color(1.0, 0.34, 0.44, 1.0),
			160,
		],
		[
			"item_shadow_shard",
			&"shadow_shard",
			"Shadow Shard",
			"Eerie dark crystal dropped by cave skeletons. Kaelen and merchants buy them for a tidy sum.",
			ItemData.Category.RESOURCE,
			AP.TILE_CAVE_DARK_ORE,
			Color.WHITE,
			40,
		],
	]

	for sp: Array in specs:
		var item: ItemData = ItemDataScript.new()
		item.id = sp[1] as StringName
		item.display_name = sp[2] as String
		item.description = sp[3] as String
		item.category = sp[4] as ItemData.Category
		item.icon = _atlas_icon(sp[5] as Vector2i)
		item.icon_tint = sp[6] as Color
		item.max_stack = 99
		item.buy_price = 0
		item.sell_price = sp[7] as int
		item.vitality_restore = 0.0
		var err: Error = ResourceSaver.save(item, "res://resources/items/%s.tres" % (sp[0] as String))
		assert(err == OK, "Failed to save Phase 6 item %s" % (sp[0] as String))
