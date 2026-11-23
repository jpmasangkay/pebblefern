class_name IslandWorldBuilder
extends RefCounted

## Compiles Pebblefern's original 96x60 tile (1536x960 px) organic archipelago island world
## into res://scenes/world/farm_sanctuary.tscn using 100% verbatim Room1.yy building & terrain
## stamps, organic rounded coastlines & surf foam, a bridged satellite pier islet, 3 offshore
## islets, staggered multi-tier cliffs with overlook fences, seamless pond->waterfall->river
## hydrology, a carved dark-earth mine quarry basin, cozy winding footpaths, natural plazas,
## and dense multi-layered environmental dressing.

const AP := preload("res://scripts/core/asset_paths.gd")

const TILE_SIZE: int = 16
const MAP_W: int = 96
const MAP_H: int = 60
const WORLD_SEED: int = 20260420
const MAX_POISSON_ATTEMPTS: int = 4096

const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H
const FLIP_V: int = TileSetAtlasSource.TRANSFORM_FLIP_V
const TRANSPOSE: int = TileSetAtlasSource.TRANSFORM_TRANSPOSE


class BuildResult:
	extends RefCounted
	var map_size_tiles: Vector2i = Vector2i(MAP_W, MAP_H)
	var world_rect_px: Rect2i = Rect2i(0, 0, MAP_W * TILE_SIZE, MAP_H * TILE_SIZE)
	var player_spawn_px: Vector2 = Vector2.ZERO
	var garden_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []


static func compile_island_into_root(root: Node2D, place_starter_soil: bool = true) -> BuildResult:
	assert(root != null, "IslandWorldBuilder requires a valid root Node2D.")
	var tileset: TileSet = load(AP.TILESET_RESOURCE) as TileSet
	assert(tileset != null, "Missing master TileSet at %s" % AP.TILESET_RESOURCE)

	# 1. Create cleanly ordered TileMapLayer stack + WorldEntities + Marker containers
	var water_layer: TileMapLayer = _make_layer("00_Water", tileset, -10, true)
	var ground_layer: TileMapLayer = _make_layer("01_Ground", tileset, -9, true)
	var beach_layer: TileMapLayer = _make_layer("01c_BeachSand", tileset, -8, false)
	var quarry_layer: TileMapLayer = _make_layer("01d_QuarryGround", tileset, -8, false)
	var cliff_shadow_layer: TileMapLayer = _make_layer("01f_CliffShadows", tileset, -8, false)
	var ladder_cliff_layer: TileMapLayer = _make_layer("01b_CliffLadders", tileset, -8, false)
	var ladder_rungs_layer: TileMapLayer = _make_layer("01b2_LadderRungs", tileset, -6, false)
	var waterfall_layer: TileMapLayer = _make_layer("01e_Waterfalls", tileset, -8, true)
	var paths_layer: TileMapLayer = _make_layer("02_Paths", tileset, -7, false)
	var garden_layer: TileMapLayer = _make_layer("02b_GardenBed", tileset, -7, false)
	var soil_layer: TileMapLayer = _make_layer("03_SoilOverlay", tileset, -6, false)
	var deco_layer: TileMapLayer = _make_layer("04_Decorations", tileset, -5, false)

	var entities_root: Node2D = Node2D.new()
	entities_root.name = "WorldEntities"
	entities_root.y_sort_enabled = true

	var markers_root: Node2D = Node2D.new()
	markers_root.name = "WorldMarkers"

	var waypoints_root: Node2D = Node2D.new()
	waypoints_root.name = "NpcScheduleWaypoints"

	var roof_canopy_layer: TileMapLayer = _make_layer("06_RoofCanopy", tileset, 10, false)

	for child: Node in [
		water_layer, ground_layer, beach_layer, quarry_layer, cliff_shadow_layer,
		ladder_cliff_layer, ladder_rungs_layer, waterfall_layer, paths_layer,
		garden_layer, soil_layer, deco_layer, entities_root, markers_root,
		waypoints_root, roof_canopy_layer,
	]:
		root.add_child(child)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = WORLD_SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.14

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = WORLD_SEED

	var occupied: Dictionary = {} # Vector2i -> true (blocks random tree/decor scatter)

	# 2. Compute Organic Archipelago Masks (Main Island + Bridged Bram Islet + 3 Offshore Islets)
	var land_mask: Dictionary = _build_archipelago_land_mask()
	var beach_mask: Dictionary = _build_beach_sand_mask(land_mask)
	var offshore_grass_islet: Dictionary = _build_nw_grass_islet_mask()
	var offshore_sand_shoal: Dictionary = _build_ne_sand_shoal_mask()
	var offshore_se_islet: Dictionary = _build_se_cove_islet_mask()

	var all_offshore: Dictionary = {}
	for d: Dictionary in [offshore_grass_islet, offshore_sand_shoal, offshore_se_islet]:
		for k: Variant in d.keys():
			all_offshore[k] = true

	# 3. Paint Sparkling Deep Ocean (00_Water) everywhere outside dry land!
	for y: int in range(MAP_H):
		for x: int in range(MAP_W):
			var c: Vector2i = Vector2i(x, y)
			if not land_mask.has(c) and not all_offshore.has(c):
				water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(x, y), 0)
				occupied[c] = true
				if x >= 2 and x < MAP_W - 2 and y >= 2 and y < MAP_H - 2:
					if not _has_neighbor_in(c, land_mask, 2) and not _has_neighbor_in(c, all_offshore, 1):
						if rng.randf() < 0.042:
							deco_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_GLINT_ANIM)

	# 4. Paint Unified Lush Meadow Grass (NO Loud Checkerboard!) matching Room1.yy organic turf!
	var detail_grass_tiles: Array[Vector2i] = [
		AP.TILE_GRASS_DETAIL_D, AP.TILE_GRASS_DETAIL_A, AP.TILE_GRASS_DETAIL_E,
		AP.TILE_GRASS_DETAIL_B, AP.TILE_GRASS_DETAIL_C, AP.TILE_GRASS_DETAIL_F,
	]
	for key: Variant in land_mask.keys():
		var c: Vector2i = key as Vector2i
		var grass_t: Vector2i = AP.TILE_GRASS_SOLID
		if not beach_mask.has(c):
			var nv: float = noise.get_noise_2d(float(c.x), float(c.y))
			if nv > 0.24:
				grass_t = detail_grass_tiles[rng.randi_range(0, detail_grass_tiles.size() - 1)]
			elif nv < -0.34 and rng.randf() < 0.35:
				grass_t = AP.TILE_GRASS_LIGHT
		ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, grass_t)

	# 5. Paint Organic Coastline: Verbatim Land Rounded Grass Edges, Coastal Cliffs & Surf Foam!
	_paint_organic_coastline(water_layer, ground_layer, land_mask, beach_mask, occupied)
	_paint_nw_grass_islet(water_layer, ground_layer, deco_layer, entities_root, offshore_grass_islet, occupied)
	_paint_ne_sand_shoal(water_layer, ground_layer, beach_layer, deco_layer, offshore_sand_shoal, occupied)
	_paint_se_cove_islet(water_layer, ground_layer, beach_layer, deco_layer, entities_root, offshore_se_islet, occupied)

	# 6. Paint Sweeping Curved Golden Sandy Beaches (01c_BeachSand using TERRAIN_SET_SAND Path 03!)
	_paint_curved_beaches(ground_layer, beach_layer, land_mask, beach_mask, rng)

	# 7. Paint Staggered Multi-Tier Inland Cliffs + Walkable Cliff Ladders + Wooden Overlook Fences!
	var cliff_band_set: Dictionary = {}
	# Terrace A: Staggered North Highland Woods Cliff (x=37..69)
	# Align x=42..69 at y_lip=14 so both Highland ladders & the overlook railing sit on a clean continuous terrace!
	var highland_profile: Dictionary = {}
	for x: int in range(37, 70):
		if x <= 41:
			highland_profile[x] = 13
		else:
			highland_profile[x] = 14
	_paint_staggered_cliff_contour(
		ground_layer, ladder_cliff_layer, ladder_rungs_layer, cliff_shadow_layer, deco_layer,
		occupied, cliff_band_set, highland_profile,
		[47, 48],           # seamless highland waterfall chute!
		[53, 54, 64, 65],   # two walkable wooden cliff ladders!
		[38, 39, 40, 41, 44, 45, 50, 51, 57, 58, 59, 60, 61, 67, 68] # cliff-edge wooden railings!
	)

	# Terrace B: Staggered Solstice Farm -> Pebblefern Quarry Cliff (x=7..32)
	var farm_cliff_profile: Dictionary = {}
	for x: int in range(7, 33):
		if x <= 11:
			farm_cliff_profile[x] = 34
		elif x <= 18:
			farm_cliff_profile[x] = 35 # recessed mine cave alcove!
		elif x <= 24:
			farm_cliff_profile[x] = 34 # Farm-to-Quarry ladder terrace!
		else:
			farm_cliff_profile[x] = 35
	_paint_staggered_cliff_contour(
		ground_layer, ladder_cliff_layer, ladder_rungs_layer, cliff_shadow_layer, deco_layer,
		occupied, cliff_band_set, farm_cliff_profile,
		[],
		[21, 22],           # walkable Farm-to-Quarry cliff ladder!
		[8, 9, 10, 19, 20, 23, 24, 26, 27, 28, 29, 30] # cliff-edge overlook fences!
	)

	# 8. Paint Freshwater Hydrology: Farm Pond, Highland Spring Pond, Meandering River & Seamless Waterfalls!
	var river_core: Array[Vector2i] = _build_freshwater_cells()
	var river_set: Dictionary = {}
	for rc: Vector2i in river_core:
		river_set[rc] = true
		occupied[rc] = true

	var river_expanded_raw: Array[Vector2i] = _expand_with_rim(river_core, land_mask)
	var river_expanded: Array[Vector2i] = []
	for cell: Vector2i in river_expanded_raw:
		if not cliff_band_set.has(cell):
			river_expanded.append(cell)
	if river_expanded.size() > 0:
		ground_layer.set_cells_terrain_connect(river_expanded, AP.TERRAIN_SET_RIVER, AP.TERRAIN_RIVER, true)
		for cell: Vector2i in river_expanded:
			occupied[cell] = true
		for cell: Vector2i in river_core:
			water_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_RIVER_ANIM, 0)
			if _is_interior_in_set(cell, river_set) and rng.randf() < 0.25:
				deco_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_GLINT_ANIM)

	# Seamless Highland Waterfall (x=47..48, y=14..16): splash foam sits squarely on y=16 meeting river on y=17!
	_paint_seamless_waterfall(water_layer, ground_layer, waterfall_layer, cliff_shadow_layer, deco_layer, occupied, 47, 48, 14, 16, true)
	# Seamless Southern Coastal Waterfall (x=38..39, y=48..49): FLUSH with southern headland cliffs (y_coast=48, surf y=50)!
	_paint_seamless_waterfall(water_layer, ground_layer, waterfall_layer, cliff_shadow_layer, deco_layer, occupied, 38, 39, 48, 49, false)

	# 9. Rebuild Pebblefern Quarry into a REAL Carved Dark-Earth Mine Basin (01d_QuarryGround + Tracks!)
	var quarry_cells: Array[Vector2i] = _paint_carved_quarry_basin(quarry_layer, paths_layer, deco_layer, occupied, rng)

	# 10. Paint Cozy Winding 2-Tile Dirt Footpaths, Natural Village Plaza, Forge Courtyard & Garden Bed!
	var road_core: Array[Vector2i] = _build_winding_island_roads()
	var road_expanded: Array[Vector2i] = _expand_with_rim(road_core, land_mask)
	var clean_road_cells: Array[Vector2i] = []
	for c: Vector2i in road_expanded:
		if not beach_mask.has(c):
			clean_road_cells.append(c)
	if clean_road_cells.size() > 0:
		paths_layer.set_cells_terrain_connect(clean_road_cells, AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_ROAD, true)
		for ck: Variant in cliff_band_set.keys():
			paths_layer.erase_cell(ck as Vector2i)
		# Stamp clean straight vertical Path 01 dirt landings at the top & bottom of all cliff ladders:
		# Verified Path 01 tiles: left=(6,7), center=(1,7), right=(3,8), BL=(6,8), bottom=(5,8), BR=(7,8)
		for lx_left: int in [52, 63]:
			# Top landing of Highland ladders (y=12..13 solid dirt, y=14 bottom rim right above ladder hooks!)
			paths_layer.set_cell(Vector2i(lx_left + 1, 12), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
			paths_layer.set_cell(Vector2i(lx_left + 2, 12), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
			paths_layer.set_cell(Vector2i(lx_left, 13), AP.SOURCE_MAIN_16PX, Vector2i(6, 7))
			paths_layer.set_cell(Vector2i(lx_left + 1, 13), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
			paths_layer.set_cell(Vector2i(lx_left + 2, 13), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
			paths_layer.set_cell(Vector2i(lx_left + 3, 13), AP.SOURCE_MAIN_16PX, Vector2i(3, 8))
			paths_layer.set_cell(Vector2i(lx_left, 14), AP.SOURCE_MAIN_16PX, Vector2i(6, 8))
			paths_layer.set_cell(Vector2i(lx_left + 1, 14), AP.SOURCE_MAIN_16PX, Vector2i(5, 8))
			paths_layer.set_cell(Vector2i(lx_left + 2, 14), AP.SOURCE_MAIN_16PX, Vector2i(5, 8))
			paths_layer.set_cell(Vector2i(lx_left + 3, 14), AP.SOURCE_MAIN_16PX, Vector2i(7, 8))
			# Bottom landing of Highland ladders (y=17..18 solid straight vertical dirt under ladder feet!)
			for by_lad: int in [17, 18]:
				paths_layer.set_cell(Vector2i(lx_left, by_lad), AP.SOURCE_MAIN_16PX, Vector2i(6, 7))
				paths_layer.set_cell(Vector2i(lx_left + 1, by_lad), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
				paths_layer.set_cell(Vector2i(lx_left + 2, by_lad), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
				paths_layer.set_cell(Vector2i(lx_left + 3, by_lad), AP.SOURCE_MAIN_16PX, Vector2i(3, 8))
		# Top landing of Farm-to-Quarry ladder (x=20..23, y=32..33 solid dirt, y=34 bottom rim above ladder hooks!)
		paths_layer.set_cell(Vector2i(21, 32), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
		paths_layer.set_cell(Vector2i(22, 32), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
		paths_layer.set_cell(Vector2i(20, 33), AP.SOURCE_MAIN_16PX, Vector2i(6, 7))
		paths_layer.set_cell(Vector2i(21, 33), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
		paths_layer.set_cell(Vector2i(22, 33), AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
		paths_layer.set_cell(Vector2i(23, 33), AP.SOURCE_MAIN_16PX, Vector2i(3, 8))
		paths_layer.set_cell(Vector2i(20, 34), AP.SOURCE_MAIN_16PX, Vector2i(6, 8))
		paths_layer.set_cell(Vector2i(21, 34), AP.SOURCE_MAIN_16PX, Vector2i(5, 8))
		paths_layer.set_cell(Vector2i(22, 34), AP.SOURCE_MAIN_16PX, Vector2i(5, 8))
		paths_layer.set_cell(Vector2i(23, 34), AP.SOURCE_MAIN_16PX, Vector2i(7, 8))
		for c: Vector2i in clean_road_cells:
			if not cliff_band_set.has(c):
				occupied[c] = true

	# Natural organic warm terracotta/packed-earth courtyard beneath Kaelen's Forge (NO hard grey box!)
	var forge_yard_core: Array[Vector2i] = []
	for fy: int in range(38, 42):
		for fx: int in range(49, 56):
			if (fx == 49 and fy == 38) or (fx == 55 and fy == 38) or (fx == 55 and fy == 41):
				continue
			forge_yard_core.append(Vector2i(fx, fy))
			occupied[Vector2i(fx, fy)] = true
	var forge_yard_exp: Array[Vector2i] = _expand_with_rim(forge_yard_core, land_mask)
	garden_layer.set_cells_terrain_connect(forge_yard_exp, AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_BED, true)
	for c: Vector2i in forge_yard_exp:
		occupied[c] = true

	# Spacious 14x6 Fenced Garden Bed on Solstice Farm Plateau (x=15..28, y=24..29)
	var garden_core: Array[Vector2i] = []
	for gy: int in range(24, 30):
		for gx: int in range(15, 29):
			var gc: Vector2i = Vector2i(gx, gy)
			garden_core.append(gc)
			occupied[gc] = true
	var garden_expanded: Array[Vector2i] = _expand_with_rim(garden_core, land_mask)
	garden_layer.set_cells_terrain_connect(garden_expanded, AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_BED, true)
	for c: Vector2i in garden_expanded:
		occupied[c] = true

	if place_starter_soil:
		for sx: int in range(17, 23):
			soil_layer.set_cell(Vector2i(sx, 25), AP.SOURCE_SOIL_DRY, Vector2i(0, 0))
			soil_layer.set_cell(Vector2i(sx, 26), AP.SOURCE_SOIL_WATERED, Vector2i(0, 0))

	# 11. Instantiate ALL 6 Verbatim Room1.yy Buildings, Ocean Channel Bridge, River Bridges, Piers & Props!
	var farmhouse_scene: PackedScene = load("res://scenes/props/cutaway_farmhouse.tscn") as PackedScene
	var green_cottage_scene: PackedScene = load("res://scenes/props/house_green_cottage.tscn") as PackedScene
	var orange_forge_scene: PackedScene = load("res://scenes/props/house_orange_forge.tscn") as PackedScene
	var purple_manor_scene: PackedScene = load("res://scenes/props/house_purple_manor.tscn") as PackedScene
	var red_cabin_scene: PackedScene = load("res://scenes/props/house_red_cabin.tscn") as PackedScene
	var timber_cabin_scene: PackedScene = load("res://scenes/props/house_timber_cabin.tscn") as PackedScene
	var bridge_scene: PackedScene = load("res://scenes/props/wooden_bridge.tscn") as PackedScene
	var ocean_bridge_scene: PackedScene = load("res://scenes/props/ocean_channel_bridge.tscn") as PackedScene
	var pier_scene: PackedScene = load("res://scenes/props/fishing_pier.tscn") as PackedScene
	var shipping_scene: PackedScene = load("res://scenes/props/shipping_bin.tscn") as PackedScene
	var stall_scene: PackedScene = load("res://scenes/props/market_stall.tscn") as PackedScene
	var forge_apron_scene: PackedScene = load("res://scenes/props/kaelen_forge_apron.tscn") as PackedScene
	var board_scene: PackedScene = load("res://scenes/props/community_board.tscn") as PackedScene
	var mine_scene: PackedScene = load("res://scenes/props/mine_entrance.tscn") as PackedScene
	var well_scene: PackedScene = load("res://scenes/props/village_well.tscn") as PackedScene
	var statue_scene: PackedScene = load("res://scenes/props/village_statue.tscn") as PackedScene
	var campfire_scene: PackedScene = load("res://scenes/props/woodland_campfire.tscn") as PackedScene
	var coracle_scene: PackedScene = load("res://scenes/props/water_coracle.tscn") as PackedScene
	var duck_scene: PackedScene = load("res://scenes/props/water_duck.tscn") as PackedScene

	# 11a. Player's Blue-Roofed Farmhouse (Solstice Farm Plateau)
	var farmhouse: Node2D = farmhouse_scene.instantiate() as Node2D
	farmhouse.name = "CutawayFarmhouse"
	farmhouse.position = Vector2(13.0 * TILE_SIZE, 17.0 * TILE_SIZE + 8.0)
	entities_root.add_child(farmhouse)
	_mark_rect(occupied, 10, 10, 21, 19)

	# Shipping Bin on packed-dirt spur east of farmhouse
	var shipping_bin: Node2D = shipping_scene.instantiate() as Node2D
	shipping_bin.name = "ShippingBin"
	shipping_bin.position = _tile_center(Vector2i(22, 18)) + Vector2(0.0, 4.0)
	entities_root.add_child(shipping_bin)
	_mark_rect(occupied, 21, 16, 24, 19)

	# 11b. Maren's Green-Roofed Botanist Cottage & Seed Shop (Bramblebrook Village NW)
	var maren_house: Node2D = green_cottage_scene.instantiate() as Node2D
	maren_house.name = "MarenCottage"
	maren_house.position = Vector2(41.0 * TILE_SIZE, 26.0 * TILE_SIZE)
	entities_root.add_child(maren_house)
	_mark_rect(occupied, 40, 19, 46, 27)

	var market_stall: Node2D = stall_scene.instantiate() as Node2D
	market_stall.name = "MarketStall"
	market_stall.position = Vector2(49.0 * TILE_SIZE, 26.0 * TILE_SIZE)
	entities_root.add_child(market_stall)
	_mark_rect(occupied, 46, 22, 53, 28)

	# 11c. Mayor Aldric's Purple-Roofed Village Hall / Manor + Plaza Landmarks!
	var aldric_house: Node2D = purple_manor_scene.instantiate() as Node2D
	aldric_house.name = "AldricVillageHall"
	aldric_house.position = Vector2(57.0 * TILE_SIZE, 25.0 * TILE_SIZE)
	entities_root.add_child(aldric_house)
	_mark_rect(occupied, 56, 18, 63, 26)

	var comm_board: Node2D = board_scene.instantiate() as Node2D
	comm_board.name = "CommunityBoard"
	comm_board.position = _tile_center(Vector2i(55, 25))
	entities_root.add_child(comm_board)
	_mark_rect(occupied, 54, 24, 56, 26)

	var well: Node2D = well_scene.instantiate() as Node2D
	well.name = "VillageWell"
	well.position = _tile_center(Vector2i(60, 33))
	entities_root.add_child(well)
	_mark_rect(occupied, 59, 32, 61, 34)

	var statue: Node2D = statue_scene.instantiate() as Node2D
	statue.name = "VillageStatue"
	statue.position = _tile_center(Vector2i(49, 31))
	entities_root.add_child(statue)
	_mark_rect(occupied, 48, 28, 50, 32)

	# 11d. Kaelen's Orange-Roofed Forge House + Grounded Hearth Courtyard (Village South toward Quarry)
	var kaelen_house: Node2D = orange_forge_scene.instantiate() as Node2D
	kaelen_house.name = "KaelenForgeHouse"
	kaelen_house.position = Vector2(44.0 * TILE_SIZE, 40.0 * TILE_SIZE)
	entities_root.add_child(kaelen_house)
	_mark_rect(occupied, 43, 34, 50, 41)

	var forge_apron: Node2D = forge_apron_scene.instantiate() as Node2D
	forge_apron.name = "KaelenForgeApron"
	forge_apron.position = _tile_center(Vector2i(52, 39))
	entities_root.add_child(forge_apron)
	_mark_rect(occupied, 50, 37, 55, 41)

	# 11e. Lyra's Timber Woodland Cabin + Crackling Highland Campfire (North Upper Plateau)
	var lyra_house: Node2D = timber_cabin_scene.instantiate() as Node2D
	lyra_house.name = "LyraWoodlandCabin"
	lyra_house.position = Vector2(56.0 * TILE_SIZE, 10.0 * TILE_SIZE)
	entities_root.add_child(lyra_house)
	_mark_rect(occupied, 55, 5, 62, 11)

	var highland_fire: Node2D = campfire_scene.instantiate() as Node2D
	highland_fire.name = "HighlandCampfire"
	highland_fire.position = _tile_center(Vector2i(53, 9))
	entities_root.add_child(highland_fire)
	_mark_rect(occupied, 52, 8, 54, 10)

	# 11f. Bram's Red-Roofed Coastal Cabin (Bridged East Satellite Pier Islet!)
	var bram_house: Node2D = red_cabin_scene.instantiate() as Node2D
	bram_house.name = "BramCoastalCabin"
	bram_house.position = Vector2(78.0 * TILE_SIZE, 26.0 * TILE_SIZE)
	entities_root.add_child(bram_house)
	_mark_rect(occupied, 77, 20, 84, 28)

	var beach_fire: Node2D = campfire_scene.instantiate() as Node2D
	beach_fire.name = "BeachCampfire"
	beach_fire.position = _tile_center(Vector2i(79, 38))
	entities_root.add_child(beach_fire)
	_mark_rect(occupied, 78, 37, 80, 39)

	var land_coracle: Sprite2D = Sprite2D.new()
	land_coracle.name = "BeachedCoracle"
	land_coracle.texture = load(AP.CORACLE_LAND_TEX) as Texture2D
	land_coracle.position = _tile_center(Vector2i(82, 35))
	entities_root.add_child(land_coracle)
	_mark_rect(occupied, 81, 34, 83, 36)

	# 11g. Recessed Cliffside Mine Entrance Archway (Embedded flush into stepped Pebblefern Quarry cliff!)
	var mine_entrance: Node2D = mine_scene.instantiate() as Node2D
	mine_entrance.name = "MineEntrance"
	mine_entrance.position = Vector2(15.0 * TILE_SIZE, 38.0 * TILE_SIZE)
	entities_root.add_child(mine_entrance)
	_mark_rect(occupied, 12, 37, 18, 40)

	# 11h. Walkable Wooden River Bridges + Iconic Ocean Channel Bridge with Pilings in Deep Channel Water!
	_place_river_bridge(entities_root, water_layer, ground_layer, paths_layer, deco_layer, occupied, bridge_scene, "WoodenBridgeFarm", Vector2i(35, 21))
	_place_river_bridge(entities_root, water_layer, ground_layer, paths_layer, deco_layer, occupied, bridge_scene, "WoodenBridgeQuarry", Vector2i(37, 42))
	_place_ocean_channel_bridge(entities_root, water_layer, ground_layer, beach_layer, paths_layer, deco_layer, occupied, ocean_bridge_scene, "OceanChannelBridgeEast", Vector2i(74, 31))

	# 11i. TWO Walkable Wooden Ocean Fishing Piers off Bram's Bridged Satellite Islet!
	_place_ocean_pier(entities_root, water_layer, ground_layer, beach_layer, paths_layer, deco_layer, occupied, pier_scene, "FishingPierNorth", Vector2i(85, 29))
	_place_ocean_pier(entities_root, water_layer, ground_layer, beach_layer, paths_layer, deco_layer, occupied, pier_scene, "FishingPierSouth", Vector2i(85, 40))

	# 12. Spawn Animated Villager NPCs (Kaelen, Aldric, Lyra, Bram — Maren lives inside MarketStall!)
	_spawn_npc(
		entities_root, occupied, "NpcKaelen", &"kaelen", "Kaelen", &"spikeyhair",
		Color(0.84, 0.78, 0.76, 1.0), Vector2(52.0 * TILE_SIZE + 8.0, 37.0 * TILE_SIZE + 10.0), false,
		PackedStringArray([
			"Bring me stone, wood, or smelted bars and I'll temper your tools right here at the anvil!",
			"Copper boulders down in Pebblefern Quarry need a Copper Pickaxe to crack open.",
		])
	)
	_spawn_npc(
		entities_root, occupied, "NpcAldric", &"aldric", "Mayor Aldric", &"shorthair",
		Color(0.84, 0.86, 0.90, 1.0), _tile_center(Vector2i(55, 30)), false,
		PackedStringArray([
			"Welcome to Bramblebrook Plaza! Solstice Plateau is already looking lively again.",
			"Check the Community Board by Village Hall — big town festivals are coming soon!",
		])
	)
	_spawn_npc(
		entities_root, occupied, "NpcLyra", &"lyra", "Lyra", &"longhair",
		Color(0.95, 0.78, 0.65, 1.0), _tile_center(Vector2i(55, 11)), true,
		PackedStringArray([
			"The Highland Spring feeds the whole valley! Listen to the waterfall from up here.",
			"Watch for ripe wild berries and sturdy hardwood stumps under these northern pines.",
		])
	)
	_spawn_npc(
		entities_root, occupied, "NpcBram", &"bram", "Bram", &"mophair",
		Color(0.86, 0.82, 0.75, 1.0), _tile_center(Vector2i(82, 28)), false,
		PackedStringArray([
			"Best bite on the island is right off the end of these wooden ocean piers!",
			"Face the deep blue water with your rod and wait for the splash.",
		])
	)

	# 13. Water Wildlife (strictly inside real freshwater & ocean cove cells!)
	var farm_coracle: Node2D = coracle_scene.instantiate() as Node2D
	farm_coracle.name = "WaterCoracle_Farm"
	farm_coracle.position = _tile_center(Vector2i(9, 26))
	entities_root.add_child(farm_coracle)

	var farm_duck: Node2D = duck_scene.instantiate() as Node2D
	farm_duck.name = "WaterDuck_Farm"
	farm_duck.position = _tile_center(Vector2i(10, 28))
	entities_root.add_child(farm_duck)

	var spring_duck: Node2D = duck_scene.instantiate() as Node2D
	spring_duck.name = "WaterDuck_Highland"
	spring_duck.position = _tile_center(Vector2i(46, 9))
	entities_root.add_child(spring_duck)

	var river_duck: Node2D = duck_scene.instantiate() as Node2D
	river_duck.name = "WaterDuck_River"
	river_duck.position = _tile_center(Vector2i(36, 28))
	entities_root.add_child(river_duck)

	var channel_coracle: Node2D = coracle_scene.instantiate() as Node2D
	channel_coracle.name = "WaterCoracle_Channel"
	channel_coracle.position = _tile_center(Vector2i(75, 38))
	entities_root.add_child(channel_coracle)

	var islet_coracle: Node2D = coracle_scene.instantiate() as Node2D
	islet_coracle.name = "WaterCoracle_Coast"
	islet_coracle.position = _tile_center(Vector2i(83, 50))
	entities_root.add_child(islet_coracle)

	# 14. Connected Wooden Garden Fences, Scenic Roadside Fences & Mossy Stone Walls (Quarry & Kaelen's Forge!)
	var fence_set: Dictionary = _build_farm_garden_fence_set()
	for fk: Variant in fence_set.keys():
		occupied[fk] = true
	AsciiMapCompiler._build_connected_fences(entities_root, fence_set, tileset)

	var stone_wall_set: Dictionary = {}
	var stone_gate_set: Dictionary = {}
	# Quarry eastern stone border + 3-tile timber gate (x=31, y=39..48, gate at y=41..43 matching 3-row Quarry Bridge road!)
	for sy: int in range(39, 48):
		if sy >= 41 and sy <= 43:
			stone_gate_set[Vector2i(31, sy)] = true
		else:
			stone_wall_set[Vector2i(31, sy)] = true
		occupied[Vector2i(31, sy)] = true
	for sx: int in range(28, 31):
		stone_wall_set[Vector2i(sx, 39)] = true
		occupied[Vector2i(sx, 39)] = true
	# Grounded low mossy stone wall accent behind Kaelen's Forge Courtyard (wide open to the east road!)
	for kx: int in [50, 51, 54]:
		stone_wall_set[Vector2i(kx, 35)] = true
		occupied[Vector2i(kx, 35)] = true
	AsciiMapCompiler._build_connected_stone_walls(entities_root, stone_wall_set, stone_gate_set)

	# 15. Build Strict Walkway, Doorway, Bridge, Pier & Ladder Exclusion Mask (ZERO scatter debris!)
	var player_spawn_px: Vector2 = Vector2(16.0 * TILE_SIZE, 19.0 * TILE_SIZE + 8.0)
	var walkway_exclusion: Dictionary = _build_walkway_exclusion_mask(water_layer, paths_layer, garden_layer, waterfall_layer)
	for wk: Variant in walkway_exclusion.keys():
		occupied[wk] = true
	_mark_rect(occupied, 14, 17, 18, 22)
	_mark_rect(occupied, 24, 14, 30, 18) # Clear open farm crafting & placeables meadow around OpenMeadowSpot!
	_mark_rect(occupied, 20, 30, 24, 43) # Farm-to-Quarry ladder top & bottom corridor!
	_mark_rect(occupied, 20, 41, 41, 44) # Quarry-to-Bridge-to-Village corridor!
	_mark_rect(occupied, 51, 9, 66, 19)  # Both Highland Ladders & Lyra's Upper Highland Trail!
	_mark_rect(occupied, 50, 26, 61, 35) # Open Bramblebrook Village Plaza center!
	_mark_rect(occupied, 68, 28, 85, 34) # Ocean Channel Bridge approaches!
	_mark_rect(occupied, 79, 26, 85, 42) # Bram's Cabin & Beach pier approaches!

	# 16. Dense Environmental Dressing: Clustered Groves, Stumps, Bushes, Mushrooms, Cottage Clutter & Flowers!
	_populate_highland_woods(entities_root, deco_layer, land_mask, occupied, noise, rng)
	_populate_island_groves(entities_root, deco_layer, land_mask, beach_mask, occupied, noise, rng)
	_populate_quarry_nodes_and_ore(entities_root, deco_layer, quarry_cells, occupied, rng)
	_populate_lived_in_village_and_beach_clutter(entities_root, deco_layer, land_mask, beach_mask, occupied, walkway_exclusion, noise, rng)

	# 16b. Hard Compiler Enforcement Pass: Zero props on 00_Water & Zero scatter debris on DirtRoad / VillagePlaza!
	_enforce_zero_water_and_road_debris(water_layer, paths_layer, garden_layer, deco_layer, walkway_exclusion, all_offshore)

	# 17. Create All Phase 5-6 Ready WorldMarkers, Dusk Walkway Lanterns & NpcScheduleWaypoints!
	_populate_world_markers(markers_root, waypoints_root, farmhouse, shipping_bin, market_stall, forge_apron, comm_board, mine_entrance)

	# 18. Instantiate Player inside WorldEntities (y_sort_enabled = true)
	var player_scene: PackedScene = load("res://scenes/entities/player.tscn") as PackedScene
	assert(player_scene != null, "Missing player.tscn")
	var player: Node2D = player_scene.instantiate() as Node2D
	player.name = "Player"
	player.position = player_spawn_px
	entities_root.add_child(player)

	var res: BuildResult = BuildResult.new()
	res.player_spawn_px = player_spawn_px
	res.garden_cells = garden_core
	res.water_cells = river_core
	return res


static func _make_layer(layer_name: String, ts: TileSet, z_val: int, enable_collision: bool) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = ts
	layer.z_index = z_val
	layer.collision_enabled = enable_collision
	return layer


static func _tile_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x * TILE_SIZE) + 8.0, float(cell.y * TILE_SIZE) + 8.0)


static func _ocean_tile(x: int, y: int) -> Vector2i:
	return Vector2i(11 + posmod(x, 4), 18 + posmod(y, 4))


static func _mark_rect(dict: Dictionary, x0: int, y0: int, x1: int, y1: int) -> void:
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			dict[Vector2i(x, y)] = true


static func _has_neighbor_in(cell: Vector2i, lookup: Dictionary, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if lookup.has(cell + Vector2i(dx, dy)):
				return true
	return false


static func _is_interior_in_set(cell: Vector2i, lookup: Dictionary) -> bool:
	return (
		lookup.has(cell + Vector2i(1, 0))
		and lookup.has(cell + Vector2i(-1, 0))
		and lookup.has(cell + Vector2i(0, 1))
		and lookup.has(cell + Vector2i(0, -1))
	)


static func _expand_with_rim(core: Array[Vector2i], land_mask: Dictionary) -> Array[Vector2i]:
	var cell_set: Dictionary = {}
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c: Vector2i in core:
		cell_set[c] = true
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			if land_mask.has(n):
				cell_set[n] = true
	_eliminate_pointy_tips(cell_set, land_mask)
	var out: Array[Vector2i] = []
	for k: Variant in cell_set.keys():
		out.append(k as Vector2i)
	return out


## Prevents two 45-degree diagonal bevel tiles from touching back-to-back on narrow road/spur ends
## (eliminating pointy <, >, ^, and v spearhead tips across the island).
static func _eliminate_pointy_tips(cell_set: Dictionary, land_mask: Dictionary) -> void:
	for _pass: int in range(3):
		var to_add: Array[Vector2i] = []
		for k: Variant in cell_set.keys():
			var c: Vector2i = k as Vector2i
			# Horizontal pair (c, c+(1,0)) forming ^ (top) or v (bottom) spearhead tip
			var cr: Vector2i = c + Vector2i(1, 0)
			if cell_set.has(cr):
				if cell_set.has(c + Vector2i(0, -1)) and cell_set.has(cr + Vector2i(0, -1)):
					var tl: Vector2i = c + Vector2i(-1, -1)
					var tr: Vector2i = cr + Vector2i(1, -1)
					if not cell_set.has(tl) and not cell_set.has(tr) and cell_set.has(c + Vector2i(-1, 0)) and cell_set.has(cr + Vector2i(1, 0)):
						if land_mask.is_empty() or land_mask.has(tl):
							to_add.append(tl)
						if land_mask.is_empty() or land_mask.has(tr):
							to_add.append(tr)
				if cell_set.has(c + Vector2i(0, 1)) and cell_set.has(cr + Vector2i(0, 1)):
					var bl: Vector2i = c + Vector2i(-1, 1)
					var br: Vector2i = cr + Vector2i(1, 1)
					if not cell_set.has(bl) and not cell_set.has(br) and cell_set.has(c + Vector2i(-1, 0)) and cell_set.has(cr + Vector2i(1, 0)):
						if land_mask.is_empty() or land_mask.has(bl):
							to_add.append(bl)
						if land_mask.is_empty() or land_mask.has(br):
							to_add.append(br)
			# Vertical pair (c, c+(0,1)) forming < (left) or > (right) spearhead tip
			var cd: Vector2i = c + Vector2i(0, 1)
			if cell_set.has(cd):
				if cell_set.has(c + Vector2i(-1, 0)) and cell_set.has(cd + Vector2i(-1, 0)):
					var l_top: Vector2i = c + Vector2i(-1, -1)
					var l_bot: Vector2i = cd + Vector2i(-1, 1)
					if not cell_set.has(l_top) and not cell_set.has(l_bot) and cell_set.has(c + Vector2i(0, -1)) and cell_set.has(cd + Vector2i(0, 1)):
						if land_mask.is_empty() or land_mask.has(l_top):
							to_add.append(l_top)
						if land_mask.is_empty() or land_mask.has(l_bot):
							to_add.append(l_bot)
				if cell_set.has(c + Vector2i(1, 0)) and cell_set.has(cd + Vector2i(1, 0)):
					var r_top: Vector2i = c + Vector2i(1, -1)
					var r_bot: Vector2i = cd + Vector2i(1, 1)
					if not cell_set.has(r_top) and not cell_set.has(r_bot) and cell_set.has(c + Vector2i(0, -1)) and cell_set.has(cd + Vector2i(0, 1)):
						if land_mask.is_empty() or land_mask.has(r_top):
							to_add.append(r_top)
						if land_mask.is_empty() or land_mask.has(r_bot):
							to_add.append(r_bot)
		if to_add.is_empty():
			break
		for ac: Vector2i in to_add:
			cell_set[ac] = true


# ==============================================================================
# 1. ORGANIC ARCHIPELAGO SILHOUETTE & SATELLITE ISLETS (NO RECTANGULAR BRICK!)
# ==============================================================================
static func _build_archipelago_land_mask() -> Dictionary:
	var mask: Dictionary = {}

	# Lobe A: Solstice Farm Plateau (Northwest Headland, separated from Highland Woods by curved NW sea bay!)
	_mark_rect(mask, 11, 8, 25, 8)
	_mark_rect(mask, 9, 9, 28, 9)
	_mark_rect(mask, 7, 10, 30, 10)
	_mark_rect(mask, 6, 11, 31, 12)
	_mark_rect(mask, 5, 13, 36, 15) # Grassy 3-tile northern shoreline separating NW ocean bay from inland river bend!
	_mark_rect(mask, 5, 16, 35, 22) # Solid grassy west bank so river_expanded (x=33..37) is 100% surrounded by land_mask!
	_mark_rect(mask, 5, 23, 35, 26)
	_mark_rect(mask, 6, 27, 35, 31)
	_mark_rect(mask, 7, 32, 35, 34)
	_mark_rect(mask, 8, 35, 35, 35)

	# Lobe B: North Highland Woods & Waterfall Spring (twin rocky northern headlands!)
	_mark_rect(mask, 43, 4, 53, 4)
	_mark_rect(mask, 58, 4, 65, 4)
	_mark_rect(mask, 40, 5, 67, 5)
	_mark_rect(mask, 38, 6, 68, 6)
	_mark_rect(mask, 37, 7, 69, 13)
	_mark_rect(mask, 36, 14, 70, 15)

	# Lobe C: Central Bramblebrook Valley & Straight 5-Tile Ocean Channel (x=72..76 under beach bridge!)
	_mark_rect(mask, 34, 16, 71, 18)
	_mark_rect(mask, 33, 19, 71, 25)
	_mark_rect(mask, 33, 26, 71, 37) # Clean straight vertical ocean channel x=72..76 under bridge & pilings!
	_mark_rect(mask, 33, 38, 71, 42)
	_mark_rect(mask, 34, 43, 70, 44)
	_mark_rect(mask, 35, 45, 67, 46) # Clean 7-tile SE coastal bluff (x=61..67)
	_mark_rect(mask, 36, 47, 60, 47) # Clean 12-tile south-central bluff (x=49..60)
	_mark_rect(mask, 36, 48, 48, 48) # Clean 13-tile south waterfall headland (x=36..48, flush!)

	# Lobe D: Southwest Pebblefern Quarry Cove (smooth wide flat coastal cliff segments, zero 1-tile spikes!)
	_mark_rect(mask, 8, 36, 35, 38)
	_mark_rect(mask, 9, 39, 35, 45)
	_mark_rect(mask, 10, 46, 35, 47)
	_mark_rect(mask, 13, 48, 31, 48) # Clean 19-tile south quarry cape aligned flush on y=48!

	# Lobe E: BRIDGED SATELLITE ISLET — Bram's Coastal Bluff & Fishing Pier Islet (across ocean channel x=72..76!)
	_mark_rect(mask, 79, 20, 82, 20)
	_mark_rect(mask, 78, 21, 83, 25)
	_mark_rect(mask, 77, 26, 84, 33)
	_mark_rect(mask, 77, 34, 83, 36) # Natural sweeping eastern cove curve between the two piers!
	_mark_rect(mask, 77, 37, 84, 41)
	_mark_rect(mask, 78, 42, 83, 42)
	_mark_rect(mask, 79, 43, 82, 43)

	return mask


static func _build_beach_sand_mask(land_mask: Dictionary) -> Dictionary:
	var mask: Dictionary = {}
	# Bram's Bridged Coastal Islet — Northern bluff & bridge road (y=20..33) meets flat dirt road on both bridge ends;
	# Southern expanse (y=34..43) transitions smoothly into sweeping golden sandy beach!
	for y: int in range(34, 44):
		for x: int in range(77, 85):
			var c: Vector2i = Vector2i(x, y)
			if land_mask.has(c):
				mask[c] = true
	return mask


static func _build_nw_grass_islet_mask() -> Dictionary:
	var mask: Dictionary = {}
	_mark_rect(mask, 3, 2, 5, 6)
	return mask


static func _build_ne_sand_shoal_mask() -> Dictionary:
	var mask: Dictionary = {}
	_mark_rect(mask, 79, 7, 82, 10)
	return mask


static func _build_se_cove_islet_mask() -> Dictionary:
	var mask: Dictionary = {}
	_mark_rect(mask, 87, 49, 90, 52)
	return mask


# ==============================================================================
# 2. REAL ROOM1.YY COASTLINES (ZERO RAW GRASS-TO-OCEAN EDGES ANYWHERE!)
# ==============================================================================
static func _paint_organic_coastline(
	water_layer: TileMapLayer,
	ground_layer: TileMapLayer,
	land_mask: Dictionary,
	beach_mask: Dictionary,
	occupied: Dictionary
) -> void:
	# Pass A: Verbatim Room1.yy Land rounded grass edges + inner bevels + North/West/East ocean surf!
	for key: Variant in land_mask.keys():
		var c: Vector2i = key as Vector2i
		if beach_mask.has(c):
			continue
		var has_n: bool = land_mask.has(c + Vector2i(0, -1))
		var has_s: bool = land_mask.has(c + Vector2i(0, 1))
		var has_w: bool = land_mask.has(c + Vector2i(-1, 0))
		var has_e: bool = land_mask.has(c + Vector2i(1, 0))
		var has_nw: bool = land_mask.has(c + Vector2i(-1, -1))
		var has_ne: bool = land_mask.has(c + Vector2i(1, -1))
		var has_sw: bool = land_mask.has(c + Vector2i(-1, 1))
		var has_se: bool = land_mask.has(c + Vector2i(1, 1))

		# 1. Outer North / West / East grass-to-ocean verbatim Room1.yy Land rounded edges (ZERO hard dark-blue bars!)
		if not has_n and not has_w:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_CORNER_TL)
			water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(c.x, c.y), 0)
			occupied[c] = true
		elif not has_n and not has_e:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_CORNER_TR)
			water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(c.x, c.y), 0)
			occupied[c] = true
		elif not has_n:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_TOP)
			water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(c.x, c.y), 1)
			occupied[c] = true
		elif not has_w and has_s:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_LEFT)
			water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(c.x, c.y), 1)
			occupied[c] = true
		elif not has_e and has_s:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_RIGHT)
			water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(c.x, c.y), 1)
			occupied[c] = true
		elif has_n and has_w and not has_nw and has_s and has_e:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_INNER_TL)
		elif has_n and has_e and not has_ne and has_s and has_w:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_INNER_TR)
		elif has_s and has_w and not has_sw and has_n and has_e:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_INNER_BL)
		elif has_s and has_e and not has_se and has_n and has_w:
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, AP.TILE_LAND_INNER_BR)

		# 2. Southern coastal cliffs descending smoothly into crisp white ocean surf (verbatim Room1.yy curved cliff corners — ZERO downward spikes!)
		if not has_s:
			var left_has_lower: bool = land_mask.has(c + Vector2i(-1, 1)) or land_mask.has(c + Vector2i(-1, 2))
			var right_has_lower: bool = land_mask.has(c + Vector2i(1, 1)) or land_mask.has(c + Vector2i(1, 2))
			var left_open: bool = (not has_w) and (not left_has_lower)
			var right_open: bool = (not has_e) and (not right_has_lower)
			var lip: Vector2i = AP.TILE_CLIFF_LIP_L if left_open else (AP.TILE_CLIFF_LIP_R if right_open else AP.TILE_CLIFF_LIP_M)

			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, lip)

			# In Room1.yy, curved cliff end-caps (21,2)=SW and (19,2)=SE sit on the CLIFF FACE row (y+1)
			# so their curved diagonal bottom edge connects 100% seamlessly into (20,2) straight surf on y+2!
			var c_mid: Vector2i = c + Vector2i(0, 1)
			var c_bot: Vector2i = c + Vector2i(0, 2)
			if not land_mask.has(c_mid):
				if left_open:
					ground_layer.set_cell(c_mid, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_CLIFF_SW)
					water_layer.set_cell(c_mid, AP.SOURCE_MAIN_16PX, _ocean_tile(c_mid.x, c_mid.y), 0)
				elif right_open:
					ground_layer.set_cell(c_mid, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_CLIFF_SE)
					water_layer.set_cell(c_mid, AP.SOURCE_MAIN_16PX, _ocean_tile(c_mid.x, c_mid.y), 0)
				else:
					var mid: Vector2i = AP.TILE_CLIFF_FACE_TM if posmod(c.x, 2) == 0 else AP.TILE_CLIFF_FACE_MM
					ground_layer.set_cell(c_mid, AP.SOURCE_MAIN_16PX, mid)

			if not land_mask.has(c_bot):
				if left_open:
					ground_layer.set_cell(c_bot, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_FOAM_TIP, FLIP_H)
				elif right_open:
					ground_layer.set_cell(c_bot, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_FOAM_TIP, 0)
				else:
					ground_layer.set_cell(c_bot, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_CLIFF_S)
				water_layer.set_cell(c_bot, AP.SOURCE_MAIN_16PX, _ocean_tile(c_bot.x, c_bot.y), 0)

			occupied[c] = true
			occupied[c_mid] = true
			occupied[c_bot] = true

	# Pass B: Sweeping Sandy Beach white-and-blue ocean surf along ALL exposed beach edges (E, W, S, N + smooth rounded corners!)
	for key: Variant in beach_mask.keys():
		var c: Vector2i = key as Vector2i
		var east_ocean: bool = not land_mask.has(c + Vector2i(1, 0))
		var west_ocean: bool = not land_mask.has(c + Vector2i(-1, 0))
		var south_ocean: bool = not land_mask.has(c + Vector2i(0, 1))
		var north_ocean: bool = not land_mask.has(c + Vector2i(0, -1))
		if east_ocean:
			var se: Vector2i = c + Vector2i(1, 0)
			if not land_mask.has(se):
				ground_layer.set_cell(se, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_SAND_S, TRANSPOSE)
				water_layer.set_cell(se, AP.SOURCE_MAIN_16PX, _ocean_tile(se.x, se.y), 0)
				occupied[se] = true
		if west_ocean:
			var sw: Vector2i = c + Vector2i(-1, 0)
			if not land_mask.has(sw):
				ground_layer.set_cell(sw, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_SAND_S, TRANSPOSE | FLIP_H)
				water_layer.set_cell(sw, AP.SOURCE_MAIN_16PX, _ocean_tile(sw.x, sw.y), 0)
				occupied[sw] = true
		if south_ocean:
			var ss: Vector2i = c + Vector2i(0, 1)
			if not land_mask.has(ss):
				ground_layer.set_cell(ss, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_SAND_S, 0)
				water_layer.set_cell(ss, AP.SOURCE_MAIN_16PX, _ocean_tile(ss.x, ss.y), 0)
				occupied[ss] = true
		if north_ocean:
			var sn: Vector2i = c + Vector2i(0, -1)
			if not land_mask.has(sn):
				ground_layer.set_cell(sn, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_SAND_S, FLIP_V)
				water_layer.set_cell(sn, AP.SOURCE_MAIN_16PX, _ocean_tile(sn.x, sn.y), 0)
				occupied[sn] = true
		# Smooth rounded outer diagonal sand-surf corners!
		if east_ocean and south_ocean:
			var corner: Vector2i = c + Vector2i(1, 1)
			if not land_mask.has(corner):
				ground_layer.set_cell(corner, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_FOAM_TIP, 0)
		if west_ocean and south_ocean:
			var corner2: Vector2i = c + Vector2i(-1, 1)
			if not land_mask.has(corner2):
				ground_layer.set_cell(corner2, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_FOAM_TIP, FLIP_H)
		if east_ocean and north_ocean:
			var corner3: Vector2i = c + Vector2i(1, -1)
			if not land_mask.has(corner3):
				ground_layer.set_cell(corner3, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_FOAM_TIP, FLIP_V)
		if west_ocean and north_ocean:
			var corner4: Vector2i = c + Vector2i(-1, -1)
			if not land_mask.has(corner4):
				ground_layer.set_cell(corner4, AP.SOURCE_MAIN_16PX, AP.TILE_SURF_FOAM_TIP, FLIP_H | FLIP_V)


static func _paint_curved_beaches(
	ground_layer: TileMapLayer,
	beach_layer: TileMapLayer,
	land_mask: Dictionary,
	beach_mask: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var beach_connect_set: Dictionary = {}
	for key: Variant in beach_mask.keys():
		var c: Vector2i = key as Vector2i
		beach_connect_set[c] = true
		# Extend 1 tile oceanward across ALL open ocean borders so TERRAIN_SET_SAND never draws a green rim on ocean sides!
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not land_mask.has(c + d):
				beach_connect_set[c + d] = true
	var beach_connect_cells: Array[Vector2i] = []
	for k: Variant in beach_connect_set.keys():
		beach_connect_cells.append(k as Vector2i)
	if beach_connect_cells.size() > 0:
		beach_layer.set_cells_terrain_connect(beach_connect_cells, AP.TERRAIN_SET_SAND, AP.TERRAIN_SAND, true)
		for k: Variant in beach_connect_set.keys():
			var bc: Vector2i = k as Vector2i
			if not land_mask.has(bc):
				beach_layer.erase_cell(bc)
		for key: Variant in beach_mask.keys():
			var bc2: Vector2i = key as Vector2i
			var ocean_adj: bool = (
				not land_mask.has(bc2 + Vector2i(1, 0))
				or not land_mask.has(bc2 + Vector2i(-1, 0))
				or not land_mask.has(bc2 + Vector2i(0, 1))
				or not land_mask.has(bc2 + Vector2i(0, -1))
			)
			if ocean_adj:
				beach_layer.set_cell(bc2, AP.SOURCE_MAIN_16PX, AP.TILE_SAND_SOLID)
			elif rng.randf() < 0.14:
				var sand_alt: Vector2i = AP.TILE_SAND_ALT_A if rng.randf() < 0.5 else AP.TILE_SAND_ALT_B
				beach_layer.set_cell(bc2, AP.SOURCE_MAIN_16PX, sand_alt)
				ground_layer.set_cell(bc2, AP.SOURCE_MAIN_16PX, sand_alt)


# Verbatim Sunnyside Tileset 3x5 Rounded Grassy Cliff Rock Islet (cols 1..3, rows 28..32)!
static func _paint_nw_grass_islet(
	water_layer: TileMapLayer,
	ground_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	entities_root: Node2D,
	islet_mask: Dictionary,
	occupied: Dictionary
) -> void:
	for k: Variant in islet_mask.keys():
		occupied[k] = true
	for dy: int in range(5):
		for dx: int in range(3):
			var c: Vector2i = Vector2i(3 + dx, 2 + dy)
			water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(c.x, c.y), 0)
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, Vector2i(1 + dx, 28 + dy))
	var pine_scene: PackedScene = load("res://scenes/props/tree_pine.tscn") as PackedScene
	var pine: Node2D = pine_scene.instantiate() as Node2D
	pine.name = "NwIsletPine"
	pine.position = _tile_center(Vector2i(4, 3))
	entities_root.add_child(pine)
	deco_layer.set_cell(Vector2i(3, 3), AP.SOURCE_MAIN_16PX, AP.TILE_FLOWER_WHITE_CLUSTER)
	deco_layer.set_cell(Vector2i(5, 3), AP.SOURCE_MAIN_16PX, AP.TILE_BUSH_SMALL_A)


# Verbatim Sunnyside Tileset 4x4 Rounded Golden Sandy Ocean Shoal (cols 5..8, rows 29..32)!
static func _paint_ne_sand_shoal(
	water_layer: TileMapLayer,
	ground_layer: TileMapLayer,
	beach_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	shoal_mask: Dictionary,
	occupied: Dictionary
) -> void:
	assert(beach_layer != null)
	for k: Variant in shoal_mask.keys():
		occupied[k] = true
	for dy: int in range(4):
		for dx: int in range(4):
			var c: Vector2i = Vector2i(79 + dx, 7 + dy)
			water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(c.x, c.y), 0)
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, Vector2i(5 + dx, 29 + dy))
	deco_layer.set_cell(Vector2i(80, 8), AP.SOURCE_MAIN_16PX, AP.TILE_STARFISH)
	deco_layer.set_cell(Vector2i(81, 9), AP.SOURCE_MAIN_16PX, AP.TILE_SHELL_PINK)


# Verbatim Sunnyside Tileset 4x4 Rounded Sandy Cove Islet with Pine, Starfish & Crab (cols 5..8, rows 29..32)!
static func _paint_se_cove_islet(
	water_layer: TileMapLayer,
	ground_layer: TileMapLayer,
	beach_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	entities_root: Node2D,
	islet_mask: Dictionary,
	occupied: Dictionary
) -> void:
	assert(beach_layer != null)
	for k: Variant in islet_mask.keys():
		occupied[k] = true
	for dy: int in range(4):
		for dx: int in range(4):
			var c: Vector2i = Vector2i(87 + dx, 49 + dy)
			water_layer.set_cell(c, AP.SOURCE_MAIN_16PX, _ocean_tile(c.x, c.y), 0)
			ground_layer.set_cell(c, AP.SOURCE_MAIN_16PX, Vector2i(5 + dx, 29 + dy))
	var pine_scene: PackedScene = load("res://scenes/props/tree_pine.tscn") as PackedScene
	var pine: Node2D = pine_scene.instantiate() as Node2D
	pine.name = "SeIsletPine"
	pine.position = _tile_center(Vector2i(88, 50)) + Vector2(8.0, 2.0)
	entities_root.add_child(pine)
	deco_layer.set_cell(Vector2i(88, 51), AP.SOURCE_MAIN_16PX, AP.TILE_STARFISH)
	deco_layer.set_cell(Vector2i(89, 51), AP.SOURCE_MAIN_16PX, AP.TILE_SHELL_PINK)
	deco_layer.set_cell(Vector2i(89, 50), AP.SOURCE_MAIN_16PX, AP.TILE_CRAB)


# ==============================================================================
# 3. STAGGERED MULTI-TIER CLIFF CONTOURS, WALKABLE LADDERS & OVERLOOK RAILINGS
# ==============================================================================
static func _paint_staggered_cliff_contour(
	ground_layer: TileMapLayer,
	ladder_cliff_layer: TileMapLayer,
	ladder_rungs_layer: TileMapLayer,
	shadow_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	occupied: Dictionary,
	cliff_band_set: Dictionary,
	y_profile: Dictionary, # int x -> int y_lip
	skip_cols: Array[int],
	ladder_cols: Array[int],
	fence_cols: Array[int]
) -> void:
	var xs: Array[int] = []
	for k: Variant in y_profile.keys():
		xs.append(int(k))
	xs.sort()

	for x: int in xs:
		var y_lip: int = int(y_profile[x])
		for dy: int in range(3):
			cliff_band_set[Vector2i(x, y_lip + dy)] = true
		if x in skip_cols:
			continue

		var left_y: int = int(y_profile.get(x - 1, -99))
		var right_y: int = int(y_profile.get(x + 1, -99))
		var is_left_corner: bool = (left_y == -99) or (left_y < y_lip)
		var is_right_corner: bool = (right_y == -99) or (right_y < y_lip)

		var t_lip: Vector2i = AP.TILE_CLIFF_LIP_L if is_left_corner else (AP.TILE_CLIFF_LIP_R if is_right_corner else AP.TILE_CLIFF_LIP_M)
		var t_mid: Vector2i = AP.TILE_CLIFF_FACE_ML if is_left_corner else (AP.TILE_CLIFF_FACE_MR if is_right_corner else (AP.TILE_CLIFF_FACE_TM if posmod(x, 2) == 0 else AP.TILE_CLIFF_FACE_MM))
		var t_bot: Vector2i = AP.TILE_CLIFF_BASE_L if is_left_corner else (AP.TILE_CLIFF_BASE_R if is_right_corner else AP.TILE_CLIFF_FACE_MM)

		var c0: Vector2i = Vector2i(x, y_lip)
		var c1: Vector2i = Vector2i(x, y_lip + 1)
		var c2: Vector2i = Vector2i(x, y_lip + 2)
		occupied[c0] = true
		occupied[c1] = true
		occupied[c2] = true

		if x in ladder_cols:
			# Verbatim Room1.yy 4-tile cliff ladder (Ladder2 / Ladder4):
			# c0 = (42,11) top hooks on grass lip; c1 = (42,12) mid rungs; c2 = (42,12) mid rungs covering 100% of
			# bottom cliff row (ZERO exposed brown cliff wall below rungs!); c3 = (42,13) bottom feet on lower ground!
			var c3: Vector2i = Vector2i(x, y_lip + 3)
			ground_layer.set_cell(c0, AP.SOURCE_MAIN_16PX, AP.TILE_GRASS_SOLID)
			ground_layer.set_cell(c1, AP.SOURCE_MAIN_16PX, AP.TILE_GRASS_SOLID)
			ground_layer.set_cell(c2, AP.SOURCE_MAIN_16PX, AP.TILE_GRASS_SOLID)
			ground_layer.set_cell(c3, AP.SOURCE_MAIN_16PX, AP.TILE_GRASS_SOLID)
			ladder_cliff_layer.set_cell(c0, AP.SOURCE_MAIN_16PX, AP.TILE_CLIFF_LIP_M)
			ladder_cliff_layer.set_cell(c1, AP.SOURCE_MAIN_16PX, AP.TILE_CLIFF_FACE_TM)
			ladder_cliff_layer.set_cell(c2, AP.SOURCE_MAIN_16PX, AP.TILE_CLIFF_FACE_MM)
			ladder_rungs_layer.set_cell(c0, AP.SOURCE_MAIN_16PX, AP.TILE_LADDER_TOP)
			ladder_rungs_layer.set_cell(c1, AP.SOURCE_MAIN_16PX, AP.TILE_LADDER_MID)
			ladder_rungs_layer.set_cell(c2, AP.SOURCE_MAIN_16PX, AP.TILE_LADDER_MID)
			ladder_rungs_layer.set_cell(c3, AP.SOURCE_MAIN_16PX, AP.TILE_LADDER_BOT)
			occupied[c3] = true
		else:
			ground_layer.set_cell(c0, AP.SOURCE_MAIN_16PX, t_lip)
			ground_layer.set_cell(c1, AP.SOURCE_MAIN_16PX, t_mid)
			ground_layer.set_cell(c2, AP.SOURCE_MAIN_16PX, t_bot)
			# Fill any step transition gap cleanly with rock face so diagonal cliff steps have ZERO walkable cracks!
			if left_y != -99 and left_y > y_lip:
				for sy: int in range(y_lip + 3, left_y + 2):
					ground_layer.set_cell(Vector2i(x, sy), AP.SOURCE_MAIN_16PX, AP.TILE_CLIFF_FACE_MM)
					cliff_band_set[Vector2i(x, sy)] = true
					occupied[Vector2i(x, sy)] = true
			if right_y != -99 and right_y > y_lip:
				for sy: int in range(y_lip + 3, right_y + 2):
					ground_layer.set_cell(Vector2i(x, sy), AP.SOURCE_MAIN_16PX, AP.TILE_CLIFF_FACE_MM)
					cliff_band_set[Vector2i(x, sy)] = true
					occupied[Vector2i(x, sy)] = true

		# Clean unshaded grass beneath the cliff base (matches Room1.yy clean cliff-to-grass transition without dark-green block rectangles!)
		assert(shadow_layer != null)

		# Rustic wooden cliff-edge overlook fences along specified terrace ledges!
		if x in fence_cols:
			var has_fl: bool = (x - 1) in fence_cols and int(y_profile.get(x - 1, -99)) == y_lip
			var has_fr: bool = (x + 1) in fence_cols and int(y_profile.get(x + 1, -99)) == y_lip
			var f_tile: Vector2i = AP.TILE_FENCE_H_MID
			if not has_fl and has_fr:
				f_tile = AP.TILE_FENCE_H_LEFT
			elif has_fl and not has_fr:
				f_tile = AP.TILE_FENCE_H_RIGHT
			elif not has_fl and not has_fr:
				f_tile = AP.TILE_FENCE_POST_SINGLE
			var fc: Vector2i = Vector2i(x, y_lip - 1)
			deco_layer.set_cell(fc, AP.SOURCE_MAIN_16PX, f_tile)
			occupied[fc] = true


# ==============================================================================
# 4. SEAMLESS HIGHLAND POND -> WATERFALL -> MEANDERING RIVER -> OCEAN WATERFALL
# ==============================================================================
static func _build_freshwater_cells() -> Array[Vector2i]:
	var cells: Dictionary = {}

	# 1. Solstice Farm Freshwater Pond (organic oval, x=7..11, y=24..29)
	_mark_rect(cells, 7, 24, 11, 29)
	cells.erase(Vector2i(7, 24))
	cells.erase(Vector2i(11, 24))
	cells.erase(Vector2i(7, 29))
	cells.erase(Vector2i(11, 29))

	# 2. Highland Spring Pond (North Upper Plateau, x=44..51, y=7..11 + brink channel y=12..13!)
	_mark_rect(cells, 44, 7, 51, 11)
	cells.erase(Vector2i(44, 7))
	cells.erase(Vector2i(51, 7))
	cells.erase(Vector2i(44, 11))
	cells.erase(Vector2i(51, 11))
	_mark_rect(cells, 47, 12, 48, 13) # Outlet pouring directly into waterfall lip at y=14!

	# 3. Waterfall Plunge Pool (x=44..50, y=17..18 — directly beneath y=16 waterfall splash foam!)
	_mark_rect(cells, 44, 17, 50, 18)
	cells.erase(Vector2i(50, 18))

	# 4. Central Village River with Straight Vertical Channels Under Every Bridge!
	_mark_rect(cells, 35, 17, 45, 18)
	_mark_rect(cells, 34, 18, 36, 27) # Clean straight vertical 3-tile channel across WoodenBridgeFarm (35, 21) & pilings!
	_mark_rect(cells, 35, 28, 37, 31) # Gentle east meander behind Maren's Cottage!
	_mark_rect(cells, 34, 32, 36, 37) # Gentle west curve near Farm cliff!
	_mark_rect(cells, 35, 38, 37, 38)
	_mark_rect(cells, 36, 39, 38, 46) # Clean straight vertical 3-tile channel across WoodenBridgeQuarry (37, 42) & pilings!
	_mark_rect(cells, 37, 47, 39, 47) # Feeds directly into flush South Coastal Waterfall at y=48..49!

	var out: Array[Vector2i] = []
	for k: Variant in cells.keys():
		out.append(k as Vector2i)
	return out


static func _paint_seamless_waterfall(
	water_layer: TileMapLayer,
	ground_layer: TileMapLayer,
	waterfall_layer: TileMapLayer,
	shadow_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	occupied: Dictionary,
	x_left: int,
	x_right: int,
	y_top: int,
	y_bot: int,
	inland: bool
) -> void:
	for x: int in range(x_left, x_right + 1):
		# A. TOP BRINK FIX: Erase any TERRAIN_RIVER green bottom rim right above the waterfall lip!
		var brink: Vector2i = Vector2i(x, y_top - 1)
		ground_layer.erase_cell(brink)
		water_layer.set_cell(brink, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_RIVER_ANIM, 0)
		occupied[brink] = true

		# B. FALLING CASCADE (y_top .. y_bot - 1): Erase ground_layer so ZERO green grass bleeds through!
		for y: int in range(y_top, y_bot):
			var fc: Vector2i = Vector2i(x, y)
			ground_layer.erase_cell(fc)
			shadow_layer.erase_cell(fc)
			water_layer.set_cell(fc, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_FLOW_ANIM, 0)
			waterfall_layer.set_cell(fc, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_FLOW_ANIM)
			occupied[fc] = true

		# C. BASE SPLASH FOAM (y_bot): Animated waterfall + boiling white base foam!
		var bot_c: Vector2i = Vector2i(x, y_bot)
		ground_layer.erase_cell(bot_c)
		shadow_layer.erase_cell(bot_c)
		water_layer.set_cell(bot_c, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_FOAM_ANIM, 0)
		waterfall_layer.set_cell(bot_c, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_FOAM_ANIM)
		occupied[bot_c] = true

		# D. BOTTOM PLUNGE FIX: Erase TERRAIN_RIVER's green top bank on (x, y_bot + 1) so pure water touches
		# the boiling white foam edge of TILE_WATER_FOAM_ANIM squarely — ZERO duplicate bar or trapped cyan strip!
		var plunge: Vector2i = Vector2i(x, y_bot + 1)
		ground_layer.erase_cell(plunge)
		shadow_layer.erase_cell(plunge)
		if inland:
			water_layer.set_cell(plunge, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_RIVER_ANIM, 0)
			if x == x_left:
				deco_layer.set_cell(plunge, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_GLINT_ANIM)
		else:
			water_layer.set_cell(plunge, AP.SOURCE_MAIN_16PX, _ocean_tile(x, y_bot + 1), 0)
			if x == x_left:
				deco_layer.set_cell(plunge, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_GLINT_ANIM)
		occupied[plunge] = true

	# E. Verbatim Room1.yy wet cliff edges framing the left & right flanks of the waterfall chute!
	for y: int in range(y_top, y_bot + 1):
		ground_layer.set_cell(Vector2i(x_left - 1, y), AP.SOURCE_MAIN_16PX, AP.TILE_CLIFF_WATERFALL_SIDE, 0)
		ground_layer.set_cell(Vector2i(x_right + 1, y), AP.SOURCE_MAIN_16PX, AP.TILE_CLIFF_WATERFALL_SIDE, FLIP_H)
		occupied[Vector2i(x_left - 1, y)] = true
		occupied[Vector2i(x_right + 1, y)] = true


# ==============================================================================
# 5. RECESSED DARK-EARTH CARVED PEBBLEFERN QUARRY & CURVED MINECART TRACKS!
# ==============================================================================
static func _paint_carved_quarry_basin(
	quarry_layer: TileMapLayer,
	paths_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	occupied: Dictionary,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	# Organic irregular carved quarry cove (x=10..29, y=38..48 — NO flat beige rectangle!)
	var basin_set: Dictionary = {}
	for y: int in range(38, 49):
		var x_min: int = 10
		var x_max: int = 29
		if y == 38:
			x_min = 12
			x_max = 26
		elif y == 39:
			x_min = 11
			x_max = 28
		elif y == 46:
			x_min = 11
			x_max = 29
		elif y == 47:
			x_min = 13
			x_max = 28
		elif y == 48:
			x_min = 15
			x_max = 26
		for x: int in range(x_min, x_max + 1):
			basin_set[Vector2i(x, y)] = true

	var q_cells: Array[Vector2i] = []
	var earth_fills: Array[Vector2i] = [
		AP.TILE_QUARRY_EARTH_A, AP.TILE_QUARRY_EARTH_B, AP.TILE_QUARRY_EARTH_C,
	]
	var dark_fills: Array[Vector2i] = [
		AP.TILE_QUARRY_DARK_A, AP.TILE_QUARRY_DARK_B, AP.TILE_QUARRY_DARK_C,
	]

	for key: Variant in basin_set.keys():
		var c: Vector2i = key as Vector2i
		q_cells.append(c)
		var has_n: bool = basin_set.has(c + Vector2i(0, -1))
		var has_s: bool = basin_set.has(c + Vector2i(0, 1))
		var has_w: bool = basin_set.has(c + Vector2i(-1, 0))
		var has_e: bool = basin_set.has(c + Vector2i(1, 0))
		var has_s2: bool = basin_set.has(c + Vector2i(0, 2))

		# Cohesive continuous dark-purple-brown outer quarry ring wrapping a warm earthy rock floor!
		var tile: Vector2i = earth_fills[rng.randi_range(0, earth_fills.size() - 1)]
		var fl: int = 0
		if not has_n:
			if not has_w:
				tile = AP.TILE_QUARRY_CLIFF_TL
			elif not has_e:
				tile = AP.TILE_QUARRY_CLIFF_TR
			else:
				tile = AP.TILE_QUARRY_CLIFF_M
		elif not has_s:
			# Smooth dark shadowed bottom rim with correctly oriented 45-deg grass corners!
			# Original (12,33): TL=green grass, BR=dark earth -> FLIP_V = BL grass (SW corner); FLIP_H|FLIP_V = BR grass (SE corner)!
			if not has_w:
				tile = AP.TILE_QUARRY_GRASS_DIAG
				fl = FLIP_V
			elif not has_e:
				tile = AP.TILE_QUARRY_GRASS_DIAG
				fl = FLIP_H | FLIP_V
			else:
				tile = dark_fills[posmod(c.x, dark_fills.size())]
		elif not has_w:
			tile = AP.TILE_QUARRY_EARTH_TL if not basin_set.has(c + Vector2i(0, -2)) else (AP.TILE_QUARRY_EARTH_BL if not has_s2 else AP.TILE_QUARRY_EARTH_L)
		elif not has_e:
			tile = AP.TILE_QUARRY_EARTH_TR if not basin_set.has(c + Vector2i(0, -2)) else (AP.TILE_QUARRY_EARTH_BR if not has_s2 else AP.TILE_QUARRY_EARTH_R)
		elif not has_s2 and (not basin_set.has(c + Vector2i(-1, 1)) or not basin_set.has(c + Vector2i(1, 1))):
			tile = AP.TILE_QUARRY_EARTH_BL if not basin_set.has(c + Vector2i(-1, 1)) else AP.TILE_QUARRY_EARTH_BR
		quarry_layer.set_cell(c, AP.SOURCE_MAIN_16PX, tile, fl)

	# Keep dark-earth quarry floor cohesive and clean (zero floating light-tan dirt patches at top center!)
	assert(paths_layer != null)

	# Curved & straight minecart tracks emerging DIRECTLY out of the cliffside Mine Entrance (15, 38) — 100% intact rails!
	var track_specs: Array[Array] = [
		[Vector2i(15, 39), AP.TILE_RAIL_V, 0],
		[Vector2i(15, 40), AP.TILE_RAIL_V, 0],                   # Vertical spur holding front-facing loaded minecart!
		[Vector2i(15, 41), AP.TILE_RAIL_CURVE, FLIP_H | FLIP_V], # Top -> East curve!
		[Vector2i(16, 41), AP.TILE_RAIL_H, 0],
		[Vector2i(17, 41), AP.TILE_RAIL_H, 0],
		[Vector2i(18, 41), AP.TILE_RAIL_H, 0],
		[Vector2i(19, 41), AP.TILE_RAIL_H, 0],
		[Vector2i(20, 41), AP.TILE_RAIL_H, 0],
		[Vector2i(21, 41), AP.TILE_RAIL_CURVE, 0],               # Left -> Down curve!
		[Vector2i(21, 42), AP.TILE_RAIL_CURVE, FLIP_H | FLIP_V], # Top -> East curve toward Quarry Gate!
		[Vector2i(22, 42), AP.TILE_RAIL_H, 0],
		[Vector2i(23, 42), AP.TILE_RAIL_H, 0],
		[Vector2i(24, 42), AP.TILE_RAIL_H, 0],
		[Vector2i(25, 42), AP.TILE_RAIL_H, 0],
		[Vector2i(26, 42), AP.TILE_RAIL_H, 0],
		[Vector2i(27, 42), AP.TILE_RAIL_H, 0],
		[Vector2i(28, 42), AP.TILE_RAIL_H, 0],
	]
	for ts: Array in track_specs:
		var tc: Vector2i = ts[0] as Vector2i
		deco_layer.set_cell(tc, AP.SOURCE_MAIN_16PX, ts[1] as Vector2i, int(ts[2]))
		occupied[tc] = true

	return q_cells


# ==============================================================================
# 6. COZY WINDING 2-TILE VILLAGE FOOTPATHS & ORGANIC ROUNDED PLAZA
# ==============================================================================
static func _build_winding_island_roads() -> Array[Vector2i]:
	var r: Dictionary = {}

	# 1. Solstice Farm Cozy Lanes (3-tile flat grounded doorway spurs + 3-row Farm Bridge abutment!)
	_mark_rect(r, 15, 16, 17, 21) # Farmhouse 3-tile front doorstep lane (extends 1 tile under front wall!)
	_mark_rect(r, 21, 18, 23, 21) # Shipping Bin 3-tile flat packed-dirt apron
	_mark_rect(r, 14, 20, 31, 21) # Farm courtyard lane
	_mark_rect(r, 31, 20, 39, 22) # 3-row Farm Bridge approach so both bridge ends meet solid flat dirt road!
	_mark_rect(r, 21, 21, 22, 24) # North garden gate connector
	_mark_rect(r, 20, 30, 23, 32) # South garden gate -> Farm-to-Quarry Ladder flat 4-tile-wide landing!
	_mark_rect(r, 21, 30, 22, 33) # Extends road core to y=33 so t_edge_bot sits on cliff lip y=34 meeting ladder hooks!

	# 2. Winding Bramblebrook Village Footpaths (3-tile grounded doorway spurs + clean wide lanes!)
	_mark_rect(r, 37, 20, 39, 25) # Curves south-east off Farm Bridge
	_mark_rect(r, 39, 25, 42, 28) # Bends gently toward Maren's Botanist Cottage!
	_mark_rect(r, 41, 27, 64, 28) # Main Village Promenade past Maren's Cottage, Seed Shop & Aldric's Hall
	_mark_rect(r, 42, 24, 44, 28) # Maren 3-tile flat doorstep spur (extends under front wall!)
	_mark_rect(r, 47, 25, 51, 28) # Seed Shop customer apron
	_mark_rect(r, 59, 23, 61, 28) # Aldric's Village Hall 3-tile flat doorstep spur (extends under portico wall!)

	# Organic Rounded / Octagonal Bramblebrook Village Plaza (x=51..59, y=28..33 — completely clear of debris!)
	_mark_rect(r, 52, 28, 58, 33)
	_mark_rect(r, 51, 29, 59, 32)

	# 3. Winding Highland Ladder Trails & Rounded Upper Highland Trail (ZERO <, >, or ^ tips!)
	_mark_rect(r, 53, 17, 54, 27) # Straight unobstructed West Highland Ladder descent into Plaza!
	_mark_rect(r, 64, 17, 65, 31) # Straight unobstructed East Highland Ladder descent into East Village lane!
	_mark_rect(r, 53, 10, 65, 11) # Upper Highland Trail connecting both ladder tops cleanly past Lyra's Cabin!
	_mark_rect(r, 53, 10, 54, 13) # West Highland Ladder top spur (t_edge_bot lands on cliff lip y=14 meeting ladder hooks!)
	_mark_rect(r, 64, 10, 65, 13) # East Highland Ladder top spur (t_edge_bot lands on cliff lip y=14 meeting ladder hooks!)
	_mark_rect(r, 57, 8, 59, 11)  # Lyra's Cabin 3-tile flat doorstep spur (extends under front wall!)

	# 4. Winding Southern Forge & Quarry Road (3-row Quarry Bridge abutment + 3-tile Kaelen doorway spur!)
	_mark_rect(r, 55, 33, 57, 42) # Wide Plaza south exit to Kaelen's Forge
	_mark_rect(r, 41, 41, 57, 42) # Cozy lane past Kaelen's Forge House & anvil yard
	_mark_rect(r, 44, 38, 46, 42) # Kaelen 3-tile flat doorstep spur (extends under front wall!)
	_mark_rect(r, 31, 41, 41, 43) # 3-row Quarry Bridge road meeting both bridge ends & 3-tile Quarry Gate squarely!

	# 5. East Coastal Trail -> crosses Ocean Channel Bridge cleanly onto Bram's Islet & North Pier!
	_mark_rect(r, 59, 30, 66, 31)
	_mark_rect(r, 65, 30, 81, 32) # 3-row Ocean Channel Bridge road so both left & right bridge ends meet solid flat dirt!
	_mark_rect(r, 78, 24, 80, 32) # Bram's Coastal Cabin 3-tile flat doorstep spur (extends under front wall!)
	_mark_rect(r, 79, 27, 84, 29) # Connector road out to Bram's North Fishing Pier deck on row y=28!

	var out: Array[Vector2i] = []
	for k: Variant in r.keys():
		out.append(k as Vector2i)
	return out


static func _build_farm_garden_fence_set() -> Dictionary:
	var f: Dictionary = {}
	for x: int in range(14, 30):
		if x != 21 and x != 22:
			f[Vector2i(x, 23)] = true
			f[Vector2i(x, 30)] = true
	for y: int in range(23, 31):
		f[Vector2i(14, y)] = true
		f[Vector2i(29, y)] = true
	return f


# ==============================================================================
# 7. WALKABLE RIVER BRIDGES, OCEAN CHANNEL BRIDGE WITH PILINGS & FISHING PIERS
# ==============================================================================
static func _place_river_bridge(
	entities_root: Node2D,
	water_layer: TileMapLayer,
	ground_layer: TileMapLayer,
	paths_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	occupied: Dictionary,
	bridge_scene: PackedScene,
	node_name: String,
	anchor: Vector2i
) -> void:
	var br: Node2D = bridge_scene.instantiate() as Node2D
	br.name = node_name
	br.position = _tile_center(anchor)
	entities_root.add_child(br)
	for by: int in range(anchor.y - 1, anchor.y + 2):
		for bx: int in range(anchor.x - 3, anchor.x + 4):
			var bc: Vector2i = Vector2i(bx, by)
			if bx >= anchor.x - 1 and bx <= anchor.x + 1:
				water_layer.set_cell(bc, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_RIVER_ANIM, 1)
				ground_layer.erase_cell(bc)
				paths_layer.erase_cell(bc)
			else:
				water_layer.erase_cell(bc)
				ground_layer.set_cell(bc, AP.SOURCE_MAIN_16PX, AP.TILE_GRASS_SOLID)
				paths_layer.set_cell(bc, AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
			deco_layer.erase_cell(bc)
			occupied[bc] = true
	for by_ch: int in [anchor.y + 2, anchor.y + 3]:
		for bx_ch: int in range(anchor.x - 1, anchor.x + 2):
			var wc: Vector2i = Vector2i(bx_ch, by_ch)
			water_layer.set_cell(wc, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_RIVER_ANIM, 0)
			ground_layer.erase_cell(wc)
			paths_layer.erase_cell(wc)
			occupied[wc] = true
	_mark_rect(occupied, anchor.x - 3, anchor.y - 2, anchor.x + 3, anchor.y + 3)


static func _place_ocean_channel_bridge(
	entities_root: Node2D,
	water_layer: TileMapLayer,
	ground_layer: TileMapLayer,
	beach_layer: TileMapLayer,
	paths_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	occupied: Dictionary,
	bridge_scene: PackedScene,
	node_name: String,
	anchor: Vector2i
) -> void:
	var br: Node2D = bridge_scene.instantiate() as Node2D
	br.name = node_name
	br.position = _tile_center(anchor)
	entities_root.add_child(br)
	for by: int in range(anchor.y - 1, anchor.y + 2):
		for bx: int in range(anchor.x - 4, anchor.x + 5):
			var bc: Vector2i = Vector2i(bx, by)
			if bx >= anchor.x - 2 and bx <= anchor.x + 2:
				water_layer.set_cell(bc, AP.SOURCE_MAIN_16PX, _ocean_tile(bx, by), 1)
				ground_layer.erase_cell(bc)
				beach_layer.erase_cell(bc)
				paths_layer.erase_cell(bc)
			else:
				water_layer.erase_cell(bc)
				beach_layer.erase_cell(bc)
				ground_layer.set_cell(bc, AP.SOURCE_MAIN_16PX, AP.TILE_GRASS_SOLID)
				paths_layer.set_cell(bc, AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
			deco_layer.erase_cell(bc)
			occupied[bc] = true
	for by_ch: int in [anchor.y - 2, anchor.y + 2, anchor.y + 3]:
		for bx_ch: int in range(anchor.x - 2, anchor.x + 3):
			var wc: Vector2i = Vector2i(bx_ch, by_ch)
			water_layer.set_cell(wc, AP.SOURCE_MAIN_16PX, _ocean_tile(bx_ch, by_ch), 0)
			ground_layer.erase_cell(wc)
			beach_layer.erase_cell(wc)
			paths_layer.erase_cell(wc)
			occupied[wc] = true
	_mark_rect(occupied, anchor.x - 4, anchor.y - 2, anchor.x + 4, anchor.y + 4)


static func _place_ocean_pier(
	entities_root: Node2D,
	water_layer: TileMapLayer,
	ground_layer: TileMapLayer,
	beach_layer: TileMapLayer,
	paths_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	occupied: Dictionary,
	pier_scene: PackedScene,
	node_name: String,
	anchor: Vector2i
) -> void:
	var pier: Node2D = pier_scene.instantiate() as Node2D
	pier.name = node_name
	pier.position = Vector2(float(anchor.x * TILE_SIZE), float(anchor.y * TILE_SIZE))
	entities_root.add_child(pier)
	# Clear ocean water & stray surf under the 3-row verbatim Room1.yy pier stamp (px in anchor.x..anchor.x+5):
	# - py = anchor.y - 2: top post tips over fishable ocean water (alt 0)
	# - py = anchor.y - 1: walkable (38,5) vertical-plank deck over collision-free water (alt 1)
	# - py = anchor.y:     flush (38,6) support pilings over collision-free water (alt 1)
	for py: int in range(anchor.y - 2, anchor.y + 2):
		for px: int in range(anchor.x, anchor.x + 6):
			var pc: Vector2i = Vector2i(px, py)
			var alt: int = 1 if (py == anchor.y - 1 or py == anchor.y) else 0
			water_layer.set_cell(pc, AP.SOURCE_MAIN_16PX, _ocean_tile(px, py), alt)
			ground_layer.erase_cell(pc)
			beach_layer.erase_cell(pc)
			paths_layer.erase_cell(pc)
			deco_layer.erase_cell(pc)
			occupied[pc] = true
	# Ensure landward entrance (anchor.x-2..anchor.x-1 on deck row anchor.y-1) meets flat dirt road or beach sand cleanly
	for px_land: int in [anchor.x - 2, anchor.x - 1]:
		var lc: Vector2i = Vector2i(px_land, anchor.y - 1)
		water_layer.erase_cell(lc)
		deco_layer.erase_cell(lc)
		if beach_layer.get_cell_source_id(lc) != -1:
			beach_layer.set_cell(lc, AP.SOURCE_MAIN_16PX, AP.TILE_SAND_SOLID)
		else:
			ground_layer.set_cell(lc, AP.SOURCE_MAIN_16PX, AP.TILE_GRASS_SOLID)
			paths_layer.set_cell(lc, AP.SOURCE_MAIN_16PX, Vector2i(1, 7))
		occupied[lc] = true
	_mark_rect(occupied, anchor.x - 2, anchor.y - 2, anchor.x + 6, anchor.y + 2)


static func _spawn_npc(
	entities_root: Node2D,
	occupied: Dictionary,
	node_name: String,
	p_npc_id: StringName,
	p_display_name: String,
	p_hair: StringName,
	p_tint: Color,
	pos: Vector2,
	facing_left: bool,
	lines: PackedStringArray
) -> void:
	var npc: CharacterBody2D = CharacterBody2D.new()
	npc.name = node_name
	npc.script = load("res://scripts/world/npc_actor.gd") as Script
	npc.position = pos
	npc.set("npc_id", p_npc_id)
	npc.set("display_name", p_display_name)
	npc.set("hair_style", p_hair)
	npc.set("hair_tint", p_tint)
	npc.set("default_facing_left", facing_left)
	npc.set("greeting_lines", lines)
	entities_root.add_child(npc)
	var cell: Vector2i = Vector2i(floori(pos.x / float(TILE_SIZE)), floori(pos.y / float(TILE_SIZE)))
	_mark_rect(occupied, cell.x - 1, cell.y - 1, cell.x + 1, cell.y + 1)


# ==============================================================================
# 8. DENSE FOLIAGE CLUSTERS, UNDERSTORY MUSHROOMS, ORE VEINS & VILLAGE CLUTTER!
# ==============================================================================
static func _populate_highland_woods(
	entities_root: Node2D,
	deco_layer: TileMapLayer,
	land_mask: Dictionary,
	occupied: Dictionary,
	noise: FastNoiseLite,
	rng: RandomNumberGenerator
) -> void:
	var res_scene: PackedScene = load("res://scenes/entities/resource_node.tscn") as PackedScene
	var bush_scene: PackedScene = load("res://scenes/props/berry_bush.tscn") as PackedScene
	var mush_red_scene: PackedScene = load("res://scenes/props/mushroom_red.tscn") as PackedScene
	var mush_blue_scene: PackedScene = load("res://scenes/props/mushroom_blue.tscn") as PackedScene

	# Copper-tier Hardwood Stumps & Ripe Berry Bushes nestled among the northern pines!
	var guaranteed_stumps: Array[Vector2i] = [
		Vector2i(41, 8), Vector2i(43, 11), Vector2i(64, 8),
	]
	for idx: int in range(guaranteed_stumps.size()):
		var sc: Vector2i = guaranteed_stumps[idx]
		if land_mask.has(sc) and not occupied.has(sc):
			var st: ResourceNode = res_scene.instantiate() as ResourceNode
			st.name = "HighlandHardwoodStump_%d" % idx
			st.node_kind = ResourceNode.NodeKind.STUMP_LARGE
			st.position = _tile_center(sc)
			entities_root.add_child(st)
			_mark_rect(occupied, sc.x - 1, sc.y - 1, sc.x + 1, sc.y + 1)

	var guaranteed_bushes: Array[Vector2i] = [
		Vector2i(43, 6), Vector2i(52, 7), Vector2i(67, 7), Vector2i(39, 10), Vector2i(67, 9),
	]
	for idx: int in range(guaranteed_bushes.size()):
		var bc: Vector2i = guaranteed_bushes[idx]
		if land_mask.has(bc) and not occupied.has(bc):
			var bb: BerryBush = bush_scene.instantiate() as BerryBush
			bb.name = "HighlandBerryBush_%d" % idx
			bb.berry_variant = 0 if idx % 2 == 0 else 2
			bb.position = _tile_center(bc)
			entities_root.add_child(bb)
			occupied[bc] = true

	# Dense overlapping pine & oak groves across Highland Woods (tight 20px clustering!)
	var candidates: Array[Vector2i] = []
	for y: int in range(5, 13):
		for x: int in range(38, 69):
			var c: Vector2i = Vector2i(x, y)
			if land_mask.has(c) and not occupied.has(c):
				candidates.append(c)
	_scatter_trees_poisson(entities_root, deco_layer, candidates, occupied, noise, rng, "Highland", 20.0, 0.72)

	# Animated red & blue woodland mushrooms beside Lyra's pine groves & stumps!
	var mush_spots: Array[Vector2i] = [
		Vector2i(40, 11), Vector2i(42, 9), Vector2i(51, 10), Vector2i(62, 8), Vector2i(66, 11),
	]
	for idx: int in range(mush_spots.size()):
		var mc: Vector2i = mush_spots[idx]
		if land_mask.has(mc) and not occupied.has(mc):
			var m_node: Node2D = (mush_red_scene if idx % 2 == 0 else mush_blue_scene).instantiate() as Node2D
			m_node.name = "HighlandMushroom_%d" % idx
			m_node.position = _tile_center(mc)
			entities_root.add_child(m_node)
			occupied[mc] = true


static func _populate_island_groves(
	entities_root: Node2D,
	deco_layer: TileMapLayer,
	land_mask: Dictionary,
	beach_mask: Dictionary,
	occupied: Dictionary,
	noise: FastNoiseLite,
	rng: RandomNumberGenerator
) -> void:
	var mush_red_scene: PackedScene = load("res://scenes/props/mushroom_red.tscn") as PackedScene
	var mush_blue_scene: PackedScene = load("res://scenes/props/mushroom_blue.tscn") as PackedScene

	# Fill EVERY empty green pocket across Farm, Village & Coastal Bluff with lush clustered groves
	# while keeping OpenMeadowSpot (24..30, 14..18), Garden Bed, Roads & Plazas wide open!
	var candidates: Array[Vector2i] = []
	for key: Variant in land_mask.keys():
		var c: Vector2i = key as Vector2i
		if occupied.has(c) or beach_mask.has(c):
			continue
		if c.y <= 15 and c.x >= 35:
			continue # Highland Woods handled separately
		if c.y >= 36 and c.x <= 32:
			continue # Quarry handled separately
		var in_farm_nw: bool = (c.x <= 11 and c.y <= 23) or (c.y <= 13 and c.x <= 31)
		var in_farm_sw: bool = (c.x >= 7 and c.x <= 13 and c.y >= 30 and c.y <= 33)
		var in_farm_se: bool = (c.x >= 30 and c.x <= 32 and c.y >= 24 and c.y <= 33)
		var in_mid_west: bool = (c.x >= 37 and c.x <= 43 and c.y >= 28 and c.y <= 38)
		var in_north_valley: bool = (c.x >= 39 and c.x <= 51 and c.y >= 17 and c.y <= 22) or (c.x >= 56 and c.x <= 70 and c.y >= 17 and c.y <= 21)
		var in_east_woods: bool = (c.x >= 64 and c.x <= 70 and c.y >= 20 and c.y <= 29) or (c.x >= 61 and c.x <= 68 and c.y >= 34 and c.y <= 45)
		var in_south_park: bool = (c.x >= 41 and c.x <= 66 and c.y >= 43 and c.y <= 47)
		var in_bram_bluff: bool = (c.x >= 78 and c.x <= 83 and c.y >= 21 and c.y <= 26)
		if in_farm_nw or in_farm_sw or in_farm_se or in_mid_west or in_north_valley or in_east_woods or in_south_park or in_bram_bluff:
			candidates.append(c)

	_scatter_trees_poisson(entities_root, deco_layer, candidates, occupied, noise, rng, "Grove", 21.0, 0.45)

	# Animated spotted mushrooms nestled in damp grove shadows & near rivers!
	var grove_mushrooms: Array[Vector2i] = [
		Vector2i(9, 15), Vector2i(10, 21), Vector2i(39, 32), Vector2i(40, 35),
		Vector2i(66, 23), Vector2i(65, 37), Vector2i(46, 46), Vector2i(58, 45),
	]
	for idx: int in range(grove_mushrooms.size()):
		var mc: Vector2i = grove_mushrooms[idx]
		if land_mask.has(mc) and not occupied.has(mc):
			var m_node: Node2D = (mush_red_scene if idx % 2 == 0 else mush_blue_scene).instantiate() as Node2D
			m_node.name = "GroveMushroom_%d" % idx
			m_node.position = _tile_center(mc)
			entities_root.add_child(m_node)
			occupied[mc] = true


static func _scatter_trees_poisson(
	entities_root: Node2D,
	deco_layer: TileMapLayer,
	candidates: Array[Vector2i],
	occupied: Dictionary,
	noise: FastNoiseLite,
	rng: RandomNumberGenerator,
	prefix: String,
	min_dist_px: float,
	pine_bias: float
) -> void:
	var res_scene: PackedScene = load("res://scenes/entities/resource_node.tscn") as PackedScene
	var bush_scene: PackedScene = load("res://scenes/props/berry_bush.tscn") as PackedScene
	var n_cand: int = candidates.size()
	for i: int in range(n_cand - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var placed: Array[Vector2] = []
	var min_sq: float = min_dist_px * min_dist_px
	var t_idx: int = 0
	var b_idx: int = 0
	var understory_tiles: Array[Vector2i] = [
		AP.TILE_BUSH_SMALL_A, AP.TILE_BUSH_SMALL_B, AP.TILE_BUSH_SMALL_C,
		AP.TILE_GRASS_TUFT_A, AP.TILE_GRASS_TUFT_B, AP.TILE_FLOWER_WHITE_CLUSTER,
	]
	var max_iter: int = mini(n_cand, MAX_POISSON_ATTEMPTS)
	for i: int in range(max_iter):
		var cell: Vector2i = candidates[i]
		if occupied.has(cell):
			continue
		var pos: Vector2 = _tile_center(cell) + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		var too_close: bool = false
		for ex: Vector2 in placed:
			if ex.distance_squared_to(pos) < min_sq:
				too_close = true
				break
		if too_close:
			continue
		var roll: float = rng.randf()
		if roll < 0.76:
			var nv: float = noise.get_noise_2d(float(cell.x) * 1.4, float(cell.y) * 1.4)
			var is_pine: bool = (nv < 0.10 and rng.randf() < pine_bias)
			var tree: ResourceNode = res_scene.instantiate() as ResourceNode
			tree.name = "%sTree_%d" % [prefix, t_idx]
			tree.node_kind = ResourceNode.NodeKind.TREE_PINE if is_pine else ResourceNode.NodeKind.TREE_DECIDUOUS
			tree.position = pos.round()
			entities_root.add_child(tree)
			placed.append(pos)
			occupied[cell] = true
			t_idx += 1
			# Organic understory companion bush/flower beside tree base!
			var side: Vector2i = cell + (Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(-1, 0))
			if not occupied.has(side) and deco_layer.get_cell_source_id(side) == -1 and rng.randf() < 0.55:
				deco_layer.set_cell(side, AP.SOURCE_MAIN_16PX, understory_tiles[rng.randi_range(0, understory_tiles.size() - 1)])
		elif roll < 0.92:
			var bb: BerryBush = bush_scene.instantiate() as BerryBush
			bb.name = "%sBush_%d" % [prefix, b_idx]
			bb.berry_variant = 0 if rng.randf() < 0.72 else 1
			bb.position = pos.round()
			entities_root.add_child(bb)
			placed.append(pos)
			occupied[cell] = true
			b_idx += 1


static func _populate_quarry_nodes_and_ore(
	entities_root: Node2D,
	deco_layer: TileMapLayer,
	quarry_cells: Array[Vector2i],
	occupied: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var res_scene: PackedScene = load("res://scenes/entities/resource_node.tscn") as PackedScene
	var idx: int = 0

	# Keep QuarryCenter (18..20, 43..45) clear for Phase 2 verification player + wood/stone drops,
	# framed closely by dramatic Copper-tier BOULDER_LARGE, BOULDER_MEDIUM, ROCK_SMALL & stumps!
	var guaranteed: Array[Array] = [
		[Vector2i(14, 43), ResourceNode.NodeKind.BOULDER_LARGE],
		[Vector2i(25, 45), ResourceNode.NodeKind.BOULDER_LARGE],
		[Vector2i(16, 46), ResourceNode.NodeKind.BOULDER_LARGE],
		[Vector2i(26, 46), ResourceNode.NodeKind.BOULDER_MEDIUM],
		[Vector2i(13, 46), ResourceNode.NodeKind.BOULDER_MEDIUM],
		[Vector2i(21, 46), ResourceNode.NodeKind.BOULDER_MEDIUM],
		[Vector2i(17, 42), ResourceNode.NodeKind.ROCK_SMALL],
		[Vector2i(25, 40), ResourceNode.NodeKind.ROCK_SMALL],
		[Vector2i(15, 45), ResourceNode.NodeKind.ROCK_SMALL],
		[Vector2i(22, 47), ResourceNode.NodeKind.ROCK_SMALL],
		[Vector2i(28, 45), ResourceNode.NodeKind.STUMP_MEDIUM],
		[Vector2i(11, 42), ResourceNode.NodeKind.STUMP_SMALL],
	]
	for g: Array in guaranteed:
		var c: Vector2i = g[0] as Vector2i
		if occupied.has(c):
			continue
		var kind: ResourceNode.NodeKind = g[1] as ResourceNode.NodeKind
		var rn: ResourceNode = res_scene.instantiate() as ResourceNode
		rn.name = "QuarryNode_%d" % idx
		rn.node_kind = kind
		rn.position = _tile_center(c)
		entities_root.add_child(rn)
		occupied[c] = true
		if kind in [ResourceNode.NodeKind.BOULDER_LARGE, ResourceNode.NodeKind.BOULDER_MEDIUM]:
			_mark_rect(occupied, c.x - 1, c.y - 1, c.x + 1, c.y + 1)
		idx += 1

	# Scenic Room1.yy Gold/Copper & Crystal Ore Clusters + Front-Facing Minecart on Vertical Track!
	var tileset_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	var rim_props: Array[Array] = [
		[Vector2i(11, 40), 49, 27, 2, 2, "QuarryGoldVein_NW", Vector2.ZERO],
		[Vector2i(28, 40), 51, 25, 2, 2, "QuarryCrystalVein_NE", Vector2.ZERO],
		[Vector2i(12, 44), 51, 27, 2, 2, "QuarryCopperVein_W", Vector2.ZERO],
		[Vector2i(27, 47), 49, 27, 2, 2, "QuarryGoldVein_SE", Vector2.ZERO],
		[Vector2i(13, 41), 39, 9, 1, 2, "QuarryTimberCrate", Vector2.ZERO],
		[Vector2i(28, 44), 40, 30, 1, 1, "QuarryTimberLogs", Vector2.ZERO],
		# Front-facing wooden minecart seated cleanly ON TOP OF intact vertical rail (15, 40) emerging from mine mouth!
		[Vector2i(15, 40), 44, 6, 1, 2, "QuarryMinecartOnTrack", Vector2(0.0, -5.0)],
		# Gold ore nugget load inside the front-facing minecart (matching Room1.yy minecarts!)
		[Vector2i(15, 40), 55, 28, 1, 1, "QuarryMinecartOre", Vector2(0.0, -10.0)],
	]
	for rp: Array in rim_props:
		var cell: Vector2i = rp[0] as Vector2i
		var spr: Sprite2D = Sprite2D.new()
		spr.name = rp[5] as String
		var at: AtlasTexture = AtlasTexture.new()
		at.atlas = tileset_tex
		at.region = Rect2(int(rp[1]) * 16, int(rp[2]) * 16, int(rp[3]) * 16, int(rp[4]) * 16)
		spr.texture = at
		spr.position = _tile_center(cell) + (rp[6] as Vector2)
		entities_root.add_child(spr)
		occupied[cell] = true

	# Reserve wide clear zone around QuarryCenter & drop positions (17..21, 41..45) so spawned wood/stone drops NEVER overlap rocks!
	_mark_rect(occupied, 17, 41, 21, 45)

	for c: Vector2i in quarry_cells:
		if occupied.has(c) or c.y <= 39:
			continue
		var roll: float = rng.randf()
		if roll < 0.045:
			var rn: ResourceNode = res_scene.instantiate() as ResourceNode
			rn.name = "QuarryRock_%d" % idx
			rn.node_kind = ResourceNode.NodeKind.ROCK_SMALL
			rn.position = _tile_center(c)
			entities_root.add_child(rn)
			occupied[c] = true
			idx += 1
		elif roll < 0.28:
			var peb: Array[Vector2i] = [AP.TILE_PEBBLE_LARGE, AP.TILE_PEBBLE_DOUBLE, AP.TILE_PEBBLE_SMALL, AP.TILE_PEBBLE_TINY]
			deco_layer.set_cell(c, AP.SOURCE_MAIN_16PX, peb[rng.randi_range(0, peb.size() - 1)])


static func _populate_lived_in_village_and_beach_clutter(
	entities_root: Node2D,
	deco_layer: TileMapLayer,
	land_mask: Dictionary,
	beach_mask: Dictionary,
	occupied: Dictionary,
	walkway_exclusion: Dictionary,
	noise: FastNoiseLite,
	rng: RandomNumberGenerator
) -> void:
	var res_scene: PackedScene = load("res://scenes/entities/resource_node.tscn") as PackedScene
	var weed_idx: int = 0

	# 1. Village & Beach Outer-Edge Accents (strictly outside DirtRoad, VillagePlaza, doorways & bridges!)
	var handcrafted_deco: Array[Array] = [
		[Vector2i(52, 24), AP.TILE_SACK_CLUSTER], # Seed sacks tucked beside Maren's shop roof
		[Vector2i(62, 8), AP.TILE_LOG_PILE],      # Firewood tucked behind Lyra's Highland Cabin
		[Vector2i(48, 39), AP.TILE_BARREL_WOOD],  # Barrel tucked on outer left corner of Kaelen's Forge
		[Vector2i(13, 19), AP.TILE_BARREL_WOOD],
		[Vector2i(25, 18), AP.TILE_LOG_PILE],
		[Vector2i(13, 27), AP.TILE_FLOWER_BLUE_CLUSTER],
		[Vector2i(13, 28), AP.TILE_FLOWER_WHITE_BIG],
		# Bram's Beach southern sandy shore shells, crabs & starfish (strictly on y>=34 beach sand!)
		[Vector2i(82, 37), AP.TILE_SHELL_PINK],
		[Vector2i(83, 38), AP.TILE_CRAB],
		[Vector2i(80, 41), AP.TILE_STARFISH],
		[Vector2i(78, 35), AP.TILE_CRAB],
		[Vector2i(82, 42), AP.TILE_SHELL_TAN],
	]
	for hd: Array in handcrafted_deco:
		var cell: Vector2i = hd[0] as Vector2i
		if land_mask.has(cell) and not walkway_exclusion.has(cell):
			deco_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, hd[1] as Vector2i)

	# 2. Natural Organic Wildflower Clusters, Grass Tufts & Pebbles on open meadow (NEVER on roads/plazas/water!)
	var flower_tiles: Array[Vector2i] = [
		AP.TILE_FLOWER_WHITE_SINGLE, AP.TILE_FLOWER_WHITE_CLUSTER, AP.TILE_FLOWER_WHITE_LARGE,
		AP.TILE_FLOWER_BLUE_SINGLE, AP.TILE_FLOWER_BLUE_CLUSTER,
		AP.TILE_FLOWER_RED_SINGLE, AP.TILE_FLOWER_RED_CLUSTER,
	]
	var tuft_tiles: Array[Vector2i] = [
		AP.TILE_GRASS_TUFT_A, AP.TILE_GRASS_TUFT_B, AP.TILE_GRASS_TUFT_C,
		AP.TILE_BUSH_SMALL_A, AP.TILE_BUSH_SMALL_D, AP.TILE_PEBBLE_TINY,
	]

	for key: Variant in land_mask.keys():
		var c: Vector2i = key as Vector2i
		if occupied.has(c) or walkway_exclusion.has(c) or beach_mask.has(c):
			continue
		if deco_layer.get_cell_source_id(c) != -1:
			continue
		if c.y >= 36 and c.x <= 32:
			continue # Quarry handled separately
		var nv: float = noise.get_noise_2d(float(c.x) * 2.1, float(c.y) * 2.1)
		var roll: float = rng.randf()
		if nv > 0.22 and roll < 0.34:
			deco_layer.set_cell(c, AP.SOURCE_MAIN_16PX, flower_tiles[rng.randi_range(0, flower_tiles.size() - 1)])
		elif roll < 0.14:
			deco_layer.set_cell(c, AP.SOURCE_MAIN_16PX, tuft_tiles[rng.randi_range(0, tuft_tiles.size() - 1)])
		elif roll < 0.165 and nv < -0.15:
			var weed: ResourceNode = res_scene.instantiate() as ResourceNode
			weed.name = "MeadowWeed_%d" % weed_idx
			weed.node_kind = ResourceNode.NodeKind.WEED_TUFT
			weed.position = _tile_center(c)
			entities_root.add_child(weed)
			occupied[c] = true
			weed_idx += 1


## Builds a strict exclusion mask covering EVERY DirtRoad, VillagePlaza, GardenBed, Water, Waterfall,
## plus a 1-tile clearance around every doorway, bridge entrance, pier entrance, and cliff ladder top/bottom.
static func _build_walkway_exclusion_mask(
	water_layer: TileMapLayer,
	paths_layer: TileMapLayer,
	garden_layer: TileMapLayer,
	waterfall_layer: TileMapLayer
) -> Dictionary:
	var mask: Dictionary = {}
	for wc: Vector2i in water_layer.get_used_cells():
		mask[wc] = true
	for fc: Vector2i in waterfall_layer.get_used_cells():
		mask[fc] = true
	for pc: Vector2i in paths_layer.get_used_cells():
		mask[pc] = true
	for gc: Vector2i in garden_layer.get_used_cells():
		mask[gc] = true

	# 1-tile clearance zones around all doorways, bridge entrances, pier entrances, and cliff ladder tops/bottoms
	_mark_rect(mask, 14, 16, 18, 22) # Farmhouse doorway & porch
	_mark_rect(mask, 20, 17, 24, 21) # Shipping Bin apron
	_mark_rect(mask, 31, 19, 39, 23) # Farm-to-Village Bridge & both entrances
	_mark_rect(mask, 41, 24, 52, 29) # Maren's Cottage door & Market Stall counter
	_mark_rect(mask, 58, 23, 62, 28) # Aldric's Village Hall door
	_mark_rect(mask, 50, 26, 60, 34) # Bramblebrook Village Plaza
	_mark_rect(mask, 43, 38, 57, 43) # Kaelen's Forge door & courtyard
	_mark_rect(mask, 30, 40, 41, 44) # Quarry Bridge, Quarry Stone Gate & both entrances
	_mark_rect(mask, 13, 37, 17, 41) # Pebblefern Mine Entrance archway
	_mark_rect(mask, 20, 29, 23, 39) # Farm-to-Quarry Cliff Ladder top & bottom
	_mark_rect(mask, 52, 10, 55, 19) # West Highland Cliff Ladder top & bottom
	_mark_rect(mask, 63, 10, 66, 19) # East Highland Cliff Ladder top & bottom
	_mark_rect(mask, 56, 8, 60, 12)  # Lyra's Woodland Cabin door
	_mark_rect(mask, 69, 29, 79, 33) # Beach Island Bridge & both entrances
	_mark_rect(mask, 77, 24, 81, 28) # Bram's Coastal Cabin door
	_mark_rect(mask, 83, 27, 91, 30) # North Ocean Fishing Pier & entrance
	_mark_rect(mask, 83, 38, 91, 41) # South Ocean Fishing Pier & entrance
	return mask


## Hard compiler rule: erases any stray non-glint decoration on 00_Water and any scatter tile on DirtRoad/VillagePlaza.
static func _enforce_zero_water_and_road_debris(
	water_layer: TileMapLayer,
	paths_layer: TileMapLayer,
	garden_layer: TileMapLayer,
	deco_layer: TileMapLayer,
	walkway_exclusion: Dictionary,
	offshore_islets: Dictionary = {}
) -> void:
	for wc: Vector2i in water_layer.get_used_cells():
		if offshore_islets.has(wc):
			continue
		if deco_layer.get_cell_source_id(wc) != -1:
			if deco_layer.get_cell_atlas_coords(wc) != AP.TILE_WATER_GLINT_ANIM:
				deco_layer.erase_cell(wc)
	for pc: Vector2i in paths_layer.get_used_cells():
		if deco_layer.get_cell_source_id(pc) != -1:
			deco_layer.erase_cell(pc)
	for gc: Vector2i in garden_layer.get_used_cells():
		if deco_layer.get_cell_source_id(gc) != -1:
			deco_layer.erase_cell(gc)
	for k: Variant in walkway_exclusion.keys():
		var c: Vector2i = k as Vector2i
		if offshore_islets.has(c):
			continue
		if deco_layer.get_cell_source_id(c) != -1:
			var coords: Vector2i = deco_layer.get_cell_atlas_coords(c)
			var is_fence: bool = coords in [AP.TILE_FENCE_H_LEFT, AP.TILE_FENCE_H_MID, AP.TILE_FENCE_H_RIGHT, AP.TILE_FENCE_POST_SINGLE]
			if coords != AP.TILE_WATER_GLINT_ANIM and coords != AP.TILE_RAIL_H and coords != AP.TILE_RAIL_V and coords != AP.TILE_RAIL_CURVE and not is_fence:
				deco_layer.erase_cell(c)


# ==============================================================================
# 9. DYNAMIC WORLD MARKERS, DUSK WALKWAY LANTERNS & PHASE 5-6 NPC WAYPOINTS
# ==============================================================================
static func _populate_world_markers(
	markers_root: Node2D,
	waypoints_root: Node2D,
	farmhouse: Node2D,
	shipping_bin: Node2D,
	market_stall: Node2D,
	forge_apron: Node2D,
	comm_board: Node2D,
	mine_entrance: Node2D
) -> void:
	# Core dynamic verification & Phase 5-6 landmarks
	_add_marker(markers_root, "FarmhouseDoor", farmhouse.position + Vector2(48.0, 16.0))
	_add_marker(markers_root, "ShippingBin", shipping_bin.position)
	_add_marker(markers_root, "MarketStall", market_stall.position)
	_add_marker(markers_root, "KaelenForge", forge_apron.position)
	_add_marker(markers_root, "GardenOrigin", _tile_center(Vector2i(15, 24)))
	_add_marker(markers_root, "OpenMeadowSpot", _tile_center(Vector2i(27, 16)))
	_add_marker(markers_root, "RiverBankSpot", _tile_center(Vector2i(12, 26))) # Facing west into Farm Pond (11, 26)
	_add_marker(markers_root, "BridgeCrossing", _tile_center(Vector2i(35, 21)))
	_add_marker(markers_root, "OceanBridgeCrossing", _tile_center(Vector2i(74, 31)))
	_add_marker(markers_root, "OceanPierNorth", _tile_center(Vector2i(89, 28))) # Facing north into open ocean (89, 27)!
	_add_marker(markers_root, "OceanPierSouth", _tile_center(Vector2i(89, 39)))
	_add_marker(markers_root, "BeachSandInland", _tile_center(Vector2i(80, 35)))
	_add_marker(markers_root, "HighlandLadderBottom", _tile_center(Vector2i(53, 17)))
	_add_marker(markers_root, "HighlandLadderTop", _tile_center(Vector2i(53, 13)))
	_add_marker(markers_root, "CliffCheck", _tile_center(Vector2i(40, 15)))
	_add_marker(markers_root, "QuarryCenter", _tile_center(Vector2i(19, 44)))
	_add_marker(markers_root, "CommunityBoard", comm_board.position)
	_add_marker(markers_root, "FestivalPlazaCenter", _tile_center(Vector2i(55, 31)))
	_add_marker(markers_root, "MineEntrance", mine_entrance.position + Vector2(0.0, 14.0))

	# Dusk/Night Walkway Lanterns tucked neatly on outer grass edges (NEVER on 00_Water or DirtRoad!)
	var lanterns_folder: Node2D = Node2D.new()
	lanterns_folder.name = "LanternPosts"
	markers_root.add_child(lanterns_folder)
	var lantern_cells: Array[Vector2i] = [
		Vector2i(30, 18), # Farm Bridge west outer grass approach
		Vector2i(39, 29), # Village west outer grass approach (well clear of river & roads!)
		Vector2i(48, 30), # Village NW outer grass edge
		Vector2i(62, 25), # Village NE outer grass edge
		Vector2i(53, 35), # Village Plaza SW outer grass edge
		Vector2i(59, 35), # Village Plaza SE outer grass edge
		Vector2i(69, 28), # Ocean Channel Bridge west outer grass edge
		Vector2i(83, 26), # Bram's North Pier outer grass edge
		Vector2i(51, 21), # Highland Ladder outer grass edge (well clear of waterfall plunge pool!)
		Vector2i(42, 39), # Quarry Bridge east outer grass edge
	]
	for idx: int in range(lantern_cells.size()):
		_add_marker(lanterns_folder, "Lantern_%d" % idx, _tile_center(lantern_cells[idx]))

	# Phase 5 NPC Schedule Waypoints (HomeDoor tucked slightly beside porch door so doorway is never crowded!)
	var npc_specs: Array[Array] = [
		["Maren", Vector2(41.0 * TILE_SIZE + 24.0, 26.0 * TILE_SIZE + 14.0), market_stall.position + Vector2(0.0, 10.0), _tile_center(Vector2i(53, 31))],
		["Kaelen", Vector2(44.0 * TILE_SIZE + 40.0, 40.0 * TILE_SIZE + 14.0), Vector2(52.0 * TILE_SIZE + 8.0, 37.0 * TILE_SIZE + 10.0), _tile_center(Vector2i(55, 32))],
		["Aldric", Vector2(57.0 * TILE_SIZE + 40.0, 25.0 * TILE_SIZE + 14.0), _tile_center(Vector2i(55, 30)), _tile_center(Vector2i(56, 30))],
		["Lyra", Vector2(56.0 * TILE_SIZE + 16.0, 10.0 * TILE_SIZE + 14.0), _tile_center(Vector2i(55, 11)), _tile_center(Vector2i(57, 31))],
		["Bram", Vector2(78.0 * TILE_SIZE + 40.0, 26.0 * TILE_SIZE + 14.0), _tile_center(Vector2i(82, 28)), _tile_center(Vector2i(58, 32))],
	]
	for sp: Array in npc_specs:
		var folder: Node2D = Node2D.new()
		folder.name = sp[0] as String
		waypoints_root.add_child(folder)
		_add_marker(folder, "HomeDoor", sp[1] as Vector2)
		_add_marker(folder, "WorkPost", sp[2] as Vector2)
		_add_marker(folder, "PlazaSpot", sp[3] as Vector2)


static func _add_marker(parent: Node2D, marker_name: String, pos: Vector2) -> Marker2D:
	var m: Marker2D = Marker2D.new()
	m.name = marker_name
	m.position = pos
	parent.add_child(m)
	return m
