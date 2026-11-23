extends SceneTree

const AP := preload("res://scripts/core/asset_paths.gd")

## Builds res://resources/sunnyside_tileset.tres with visually verified Sunnyside World V2.1
## TileSetAtlasSource definitions, physics colliders, animated water tiles, and Terrain Sets.
## Run via: Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/tools/build_sunnyside_tileset.gd

const TILE_SIZE: Vector2i = Vector2i(16, 16)
const ATLAS_COLS: int = 64
const ATLAS_ROWS: int = 50


func _init() -> void:
	var tileset: TileSet = _build_tileset()
	assert(tileset != null, "TileSet construction failed.")
	var err: Error = ResourceSaver.save(tileset, AP.TILESET_RESOURCE)
	assert(err == OK, "Failed to save sunnyside_tileset.tres: %d" % err)
	print("[BuildTileSet] Saved %s successfully." % AP.TILESET_RESOURCE)
	quit(0)


func _build_tileset() -> TileSet:
	var ts: TileSet = TileSet.new()
	ts.tile_size = TILE_SIZE

	# Physics layers: 0 = WorldSolid (bit 1), 1 = Water (bit 2)
	ts.add_physics_layer(AP.PHYSICS_LAYER_WORLD_SOLID)
	ts.set_physics_layer_collision_layer(AP.PHYSICS_LAYER_WORLD_SOLID, 1)
	ts.set_physics_layer_collision_mask(AP.PHYSICS_LAYER_WORLD_SOLID, 0)

	ts.add_physics_layer(AP.PHYSICS_LAYER_WATER)
	ts.set_physics_layer_collision_layer(AP.PHYSICS_LAYER_WATER, 2)
	ts.set_physics_layer_collision_mask(AP.PHYSICS_LAYER_WATER, 0)

	# Terrain Set 0: TERRAIN_RIVER (Match Corners & Sides — clean straight banks + 45-deg rounded bends)
	ts.add_terrain_set(AP.TERRAIN_SET_RIVER)
	ts.set_terrain_set_mode(AP.TERRAIN_SET_RIVER, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(AP.TERRAIN_SET_RIVER, AP.TERRAIN_GRASS_BASE)
	ts.set_terrain_name(AP.TERRAIN_SET_RIVER, AP.TERRAIN_GRASS_BASE, "MeadowGrass")
	ts.set_terrain_color(AP.TERRAIN_SET_RIVER, AP.TERRAIN_GRASS_BASE, Color(0.37, 0.76, 0.30))
	ts.add_terrain(AP.TERRAIN_SET_RIVER, AP.TERRAIN_RIVER)
	ts.set_terrain_name(AP.TERRAIN_SET_RIVER, AP.TERRAIN_RIVER, "TERRAIN_RIVER")
	ts.set_terrain_color(AP.TERRAIN_SET_RIVER, AP.TERRAIN_RIVER, Color(0.20, 0.86, 0.91))

	# Terrain Set 1: TERRAIN_PATH_ROAD (Path 01 scalloped dirt road)
	ts.add_terrain_set(AP.TERRAIN_SET_PATHS)
	ts.set_terrain_set_mode(AP.TERRAIN_SET_PATHS, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_EMPTY)
	ts.set_terrain_name(AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_EMPTY, "EmptyMeadow")
	ts.set_terrain_color(AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_EMPTY, Color(0.45, 0.80, 0.35))
	ts.add_terrain(AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_ROAD)
	ts.set_terrain_name(AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_ROAD, "TERRAIN_PATH_ROAD")
	ts.set_terrain_color(AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_ROAD, Color(0.89, 0.65, 0.45))

	# Terrain Set 2: TERRAIN_GARDEN_BED (Path 02 rounded farming dirt bed)
	ts.add_terrain_set(AP.TERRAIN_SET_GARDEN)
	ts.set_terrain_set_mode(AP.TERRAIN_SET_GARDEN, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_EMPTY)
	ts.set_terrain_name(AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_EMPTY, "EmptyGarden")
	ts.set_terrain_color(AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_EMPTY, Color(0.45, 0.80, 0.35))
	ts.add_terrain(AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_BED)
	ts.set_terrain_name(AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_BED, "TERRAIN_GARDEN_BED")
	ts.set_terrain_color(AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_BED, Color(0.76, 0.52, 0.41))

	# Terrain Set 3: TERRAIN_CLIFF (Elevated rock cliff walls)
	ts.add_terrain_set(AP.TERRAIN_SET_CLIFF)
	ts.set_terrain_set_mode(AP.TERRAIN_SET_CLIFF, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(AP.TERRAIN_SET_CLIFF, AP.TERRAIN_CLIFF_EMPTY)
	ts.set_terrain_name(AP.TERRAIN_SET_CLIFF, AP.TERRAIN_CLIFF_EMPTY, "LowGround")
	ts.set_terrain_color(AP.TERRAIN_SET_CLIFF, AP.TERRAIN_CLIFF_EMPTY, Color(0.37, 0.76, 0.30))
	ts.add_terrain(AP.TERRAIN_SET_CLIFF, AP.TERRAIN_CLIFF)
	ts.set_terrain_name(AP.TERRAIN_SET_CLIFF, AP.TERRAIN_CLIFF, "TERRAIN_CLIFF")
	ts.set_terrain_color(AP.TERRAIN_SET_CLIFF, AP.TERRAIN_CLIFF, Color(0.65, 0.39, 0.28))

	# Terrain Set 4: TERRAIN_SAND (Path 03 golden coastal beach sand)
	ts.add_terrain_set(AP.TERRAIN_SET_SAND)
	ts.set_terrain_set_mode(AP.TERRAIN_SET_SAND, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(AP.TERRAIN_SET_SAND, AP.TERRAIN_SAND_EMPTY)
	ts.set_terrain_name(AP.TERRAIN_SET_SAND, AP.TERRAIN_SAND_EMPTY, "NonSand")
	ts.set_terrain_color(AP.TERRAIN_SET_SAND, AP.TERRAIN_SAND_EMPTY, Color(0.37, 0.76, 0.30))
	ts.add_terrain(AP.TERRAIN_SET_SAND, AP.TERRAIN_SAND)
	ts.set_terrain_name(AP.TERRAIN_SET_SAND, AP.TERRAIN_SAND, "TERRAIN_SAND")
	ts.set_terrain_color(AP.TERRAIN_SET_SAND, AP.TERRAIN_SAND, Color(0.95, 0.87, 0.55))

	# Source 0: Main 16x16 Sunnyside World tileset
	var main_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	assert(main_tex != null, "Failed to load main tileset PNG: %s" % AP.TILESET_16PX)
	var main_src: TileSetAtlasSource = TileSetAtlasSource.new()
	main_src.texture = main_tex
	main_src.texture_region_size = TILE_SIZE
	ts.add_source(main_src, AP.SOURCE_MAIN_16PX)

	var img: Image = main_tex.get_image()
	assert(img != null, "Main tileset image could not be read.")

	var created_count: int = 0
	for r: int in range(ATLAS_ROWS):
		for c: int in range(ATLAS_COLS):
			var coords: Vector2i = Vector2i(c, r)
			var is_helper: bool = (coords == Vector2i(0, 0) or coords == Vector2i(0, 1))
			if is_helper or _cell_has_pixels(img, c, r):
				if not _is_animation_tail_frame(coords):
					main_src.create_tile(coords)
					created_count += 1

	print("[BuildTileSet] Created %d tiles in Source 0." % created_count)

	# Configure animated water & waterfall tiles (4 contiguous horizontal frames each)
	_setup_animated_tile(main_src, AP.TILE_WATER_FOAM_ANIM, 4, 4.0)
	_setup_animated_tile(main_src, AP.TILE_WATER_FLOW_ANIM, 4, 4.0)
	_setup_animated_tile(main_src, AP.TILE_WATER_RIVER_ANIM, 4, 4.0)
	_setup_animated_tile(main_src, AP.TILE_WATER_GLINT_ANIM, 4, 3.0)
	_setup_animated_tile(main_src, AP.TILE_WATERFALL_CREST_ANIM, 4, 4.0)

	# Terrain Set 0: TERRAIN_RIVER (cols 22..29, rows 7..8; solid=(22,7))
	_configure_sunnyside_blob_terrain(
		main_src,
		AP.TERRAIN_SET_RIVER,
		AP.TERRAIN_RIVER,
		22,
		7,
		true
	)
	_set_full_collision(main_src, AP.TILE_WATER_RIVER_ANIM, AP.PHYSICS_LAYER_WATER)
	# Non-colliding animated river water alternative (alt_id = 1) for visual water underneath walkable bridges!
	var bridge_water_alt: int = main_src.create_alternative_tile(AP.TILE_WATER_RIVER_ANIM)
	assert(bridge_water_alt == 1, "Expected bridge visual water alt_id == 1")
	_set_full_collision(main_src, AP.TILE_WATER_FLOW_ANIM, AP.PHYSICS_LAYER_WATER)
	_set_full_collision(main_src, AP.TILE_WATER_FOAM_ANIM, AP.PHYSICS_LAYER_WATER)
	for wc: int in range(11, 15):
		for wr: int in range(18, 22):
			var oc: Vector2i = Vector2i(wc, wr)
			_set_full_collision(main_src, oc, AP.PHYSICS_LAYER_WATER)
			# Non-colliding ocean alt_id = 1 underneath walkable ocean fishing piers!
			var pier_alt: int = main_src.create_alternative_tile(oc)
			assert(pier_alt == 1, "Expected ocean pier visual water alt_id == 1 for %s" % str(oc))
	# Ocean shoreline & coastal surf water collision (cols 19..21, rows 2..6)
	for sc: int in range(19, 22):
		for sr: int in range(2, 7):
			_set_full_collision(main_src, Vector2i(sc, sr), AP.PHYSICS_LAYER_WATER)

	# Terrain Set 1: TERRAIN_PATH_ROAD (Path 01: cols 1..8, rows 7..8 + pebbled fills cols 9..11)
	_configure_sunnyside_blob_terrain(
		main_src,
		AP.TERRAIN_SET_PATHS,
		AP.TERRAIN_PATH_ROAD,
		1,
		7,
		false
	)
	var road_variants: Array[Vector2i] = [
		Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7),
		Vector2i(9, 8), Vector2i(10, 8),
	]
	_set_solid_probability(main_src, Vector2i(1, 7), 4.5)
	for v: Vector2i in road_variants:
		_set_full_peering(main_src, v, 0, AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_ROAD, 1, 1, 1, 1, 1, 1, 1, 1)
		_set_solid_probability(main_src, v, 1.0)

	# Terrain Set 2: TERRAIN_GARDEN_BED (Path 02: cols 12..19, rows 7..8 + earthy pebble fills cols 20..21)
	_configure_sunnyside_blob_terrain(
		main_src,
		AP.TERRAIN_SET_GARDEN,
		AP.TERRAIN_GARDEN_BED,
		12,
		7,
		false
	)
	var garden_variants: Array[Vector2i] = [
		Vector2i(20, 7), Vector2i(21, 7), Vector2i(20, 8), Vector2i(21, 8),
	]
	_set_solid_probability(main_src, Vector2i(12, 7), 5.0)
	for v: Vector2i in garden_variants:
		_set_full_peering(main_src, v, 0, AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_BED, 1, 1, 1, 1, 1, 1, 1, 1)
		_set_solid_probability(main_src, v, 0.9)

	# Terrain Set 3: TERRAIN_CLIFF
	_configure_cliff_terrain(main_src)

	# Terrain Set 4: TERRAIN_SAND (Path 03: cols 34..41, rows 7..8 + textured sand fills cols 42..43)
	_configure_sunnyside_blob_terrain(
		main_src,
		AP.TERRAIN_SET_SAND,
		AP.TERRAIN_SAND,
		34,
		7,
		false
	)
	var sand_variants: Array[Vector2i] = [
		Vector2i(42, 7), Vector2i(43, 7), Vector2i(42, 8), Vector2i(43, 8),
	]
	_set_solid_probability(main_src, Vector2i(34, 7), 4.5)
	for sv: Vector2i in sand_variants:
		_set_full_peering(main_src, sv, 0, AP.TERRAIN_SET_SAND, AP.TERRAIN_SAND, 1, 1, 1, 1, 1, 1, 1, 1)
		_set_solid_probability(main_src, sv, 0.85)

	_configure_structural_collisions(main_src)

	# Source 1: Standalone Dry Tilled Soil (soil_04.png = 16x12 recessed hollowed hole!)
	var soil_dry_tex: Texture2D = load(AP.SOIL_DRY) as Texture2D
	assert(soil_dry_tex != null, "Failed to load tilled soil_04.png")
	var soil_dry_src: TileSetAtlasSource = TileSetAtlasSource.new()
	soil_dry_src.texture = soil_dry_tex
	soil_dry_src.texture_region_size = Vector2i(16, 12)
	soil_dry_src.create_tile(Vector2i(0, 0))
	ts.add_source(soil_dry_src, AP.SOURCE_SOIL_DRY)

	# Source 2: Standalone Watered Tilled Soil (soil_04.png = 16x12 with rich damp moistened tint!)
	var soil_wet_tex: Texture2D = load(AP.SOIL_WATERED) as Texture2D
	assert(soil_wet_tex != null, "Failed to load watered soil_04.png")
	var soil_wet_src: TileSetAtlasSource = TileSetAtlasSource.new()
	soil_wet_src.texture = soil_wet_tex
	soil_wet_src.texture_region_size = Vector2i(16, 12)
	soil_wet_src.create_tile(Vector2i(0, 0))
	var wet_td: TileData = soil_wet_src.get_tile_data(Vector2i(0, 0), 0)
	assert(wet_td != null, "Missing TileData for watered soil.")
	wet_td.modulate = Color(0.56, 0.49, 0.50, 1.0)
	ts.add_source(soil_wet_src, AP.SOURCE_SOIL_WATERED)

	return ts


func _cell_has_pixels(img: Image, col: int, row: int) -> bool:
	var x0: int = col * TILE_SIZE.x
	var y0: int = row * TILE_SIZE.y
	for y: int in range(y0, y0 + TILE_SIZE.y):
		for x: int in range(x0, x0 + TILE_SIZE.x):
			if img.get_pixel(x, y).a > 0.02:
				return true
	return false


func _is_animation_tail_frame(coords: Vector2i) -> bool:
	if coords.y in [6, 7, 8] and coords.x >= 31 and coords.x <= 33:
		return true
	if coords.y == 6 and coords.x >= 27 and coords.x <= 29:
		return true
	if coords.y == 22 and coords.x >= 12 and coords.x <= 14:
		return true
	return false


func _setup_animated_tile(src: TileSetAtlasSource, base_coords: Vector2i, frames: int, fps: float) -> void:
	if not src.has_tile(base_coords):
		src.create_tile(base_coords)
	src.set_tile_animation_columns(base_coords, frames)
	src.set_tile_animation_frames_count(base_coords, frames)
	src.set_tile_animation_speed(base_coords, fps)


func _configure_sunnyside_blob_terrain(
	src: TileSetAtlasSource,
	terrain_set: int,
	terrain_id: int,
	col_start: int,
	row_start: int,
	add_water_collision: bool
) -> void:
	# Maps all 15 Sunnyside dual-grid tiles onto Godot's 8-neighbor MATCH_CORNERS_AND_SIDES blob rules!
	# Using -1 for non-terrain neighbors so ignore_empty_terrains=true works cleanly on sparse layers.
	# Tile indices inside (col_start..col_start+7, row_start..row_start+1):
	#  0=(+0,+0) solid   1=(+1,+0) TL bevel  2=(+2,+0) TR bevel   3=(+3,+0) Top straight rim
	#  4=(+4,+0) BL bev  5=(+5,+0) L rim     6=(+6,+0) diag       7=(+7,+0) BR tiny corner
	#  8=(+0,+1) BR bev  9=(+1,+1) diag     10=(+2,+1) R rim     11=(+3,+1) BL tiny corner
	# 12=(+4,+1) Bot rim 13=(+5,+1) TR tiny 14=(+6,+1) TL tiny
	var t_solid: Vector2i = Vector2i(col_start + 0, row_start + 0)
	var t_bevel_tl: Vector2i = Vector2i(col_start + 1, row_start + 0)
	var t_bevel_tr: Vector2i = Vector2i(col_start + 2, row_start + 0)
	var t_edge_top: Vector2i = Vector2i(col_start + 3, row_start + 0)
	var t_bevel_bl: Vector2i = Vector2i(col_start + 4, row_start + 0)
	var t_edge_left: Vector2i = Vector2i(col_start + 5, row_start + 0)
	var t_corner_tl: Vector2i = Vector2i(col_start + 7, row_start + 0) # Tiny BR pixel connects to BR terrain!
	var t_bevel_br: Vector2i = Vector2i(col_start + 0, row_start + 1)
	var t_edge_right: Vector2i = Vector2i(col_start + 2, row_start + 1)
	var t_corner_tr: Vector2i = Vector2i(col_start + 3, row_start + 1) # Tiny BL pixel connects to BL terrain!
	var t_edge_bot: Vector2i = Vector2i(col_start + 4, row_start + 1)
	var t_corner_bl: Vector2i = Vector2i(col_start + 5, row_start + 1) # Tiny TR pixel connects to TR terrain!
	var t_corner_br: Vector2i = Vector2i(col_start + 6, row_start + 1) # Tiny TL pixel connects to TL terrain!

	var o: int = -1
	var i: int = terrain_id

	# 1. Full interior solid (all 8 neighbors = terrain)
	_set_full_peering(src, t_solid, 0, terrain_set, i, i, i, i, i, i, i, i, i)

	# 2. Straight edges (3 cardinal sides + 2 inner corners = terrain, 1 outer side = empty)
	# Order: T, R, B, L, TL, TR, BR, BL
	_set_full_peering(src, t_edge_top, 0, terrain_set, i, o, i, i, i, o, o, i, i)
	_set_full_peering(src, t_edge_bot, 0, terrain_set, i, i, i, o, i, i, i, o, o)
	_set_full_peering(src, t_edge_left, 0, terrain_set, i, i, i, i, o, o, i, i, o)
	_set_full_peering(src, t_edge_right, 0, terrain_set, i, i, o, i, i, i, o, o, i)

	# 3. 90-degree outer square corners of a rectangular block (tiny 3px outer wrap)
	_set_full_peering(src, t_corner_tl, 0, terrain_set, i, o, i, i, o, o, o, i, o)
	_set_full_peering(src, t_corner_tr, 0, terrain_set, i, o, o, i, i, o, o, o, i)
	_set_full_peering(src, t_corner_bl, 0, terrain_set, i, i, i, o, o, o, i, o, o)
	_set_full_peering(src, t_corner_br, 0, terrain_set, i, i, o, o, i, i, o, o, o)

	# 4. 45-degree smooth rounded bevels (missing 1 diagonal corner -> smooth concave/convex bend!)
	_set_full_peering(src, t_bevel_tl, 0, terrain_set, i, i, i, i, i, o, i, i, i)
	_set_full_peering(src, t_bevel_tr, 0, terrain_set, i, i, i, i, i, i, o, i, i)
	_set_full_peering(src, t_bevel_bl, 0, terrain_set, i, i, i, i, i, i, i, i, o)
	_set_full_peering(src, t_bevel_br, 0, terrain_set, i, i, i, i, i, i, i, o, i)

	# 5. Alternative tiles for edges adjacent to beveled corners & dead-end rim caps (zero overlap with corner tiles!)
	var extra_patterns: Array[Array] = [
		# [coords, T, R, B, L, TL, TR, BR, BL]
		# Straight top/bottom/left/right edges where 1 inner diagonal is missing (next to an L-bend)
		[t_edge_top, o, i, i, i, o, o, o, i],
		[t_edge_top, o, i, i, i, o, o, i, o],
		[t_edge_top, o, i, i, i, o, o, o, o],
		[t_edge_bot, i, i, o, i, o, i, o, o],
		[t_edge_bot, i, i, o, i, i, o, o, o],
		[t_edge_bot, i, i, o, i, o, o, o, o],
		[t_edge_left, i, i, i, o, o, o, i, o],
		[t_edge_left, i, i, i, o, o, i, o, o],
		[t_edge_left, i, i, i, o, o, o, o, o],
		[t_edge_right, i, o, i, i, o, o, o, i],
		[t_edge_right, i, o, i, i, i, o, o, o],
		[t_edge_right, i, o, i, i, o, o, o, o],
		# Dead-end rim caps (single neighbor connected -> crisp 3px scalloped rim!)
		[t_edge_left, o, i, o, o, o, o, o, o],
		[t_edge_right, o, o, o, i, o, o, o, o],
		[t_edge_top, o, o, i, o, o, o, o, o],
		[t_edge_bot, i, o, o, o, o, o, o, o],
		# Corner dots when inner diagonal is also empty (isolated tight bend)
		[t_corner_tl, o, i, i, o, o, o, o, o],
		[t_corner_tr, o, o, i, i, o, o, o, o],
		[t_corner_bl, i, i, o, o, o, o, o, o],
		[t_corner_br, i, o, o, i, o, o, o, o],
		# Solid fills with 2..4 missing diagonal corners (1-tile roads/rivers & narrow bends)
		[t_solid, i, i, i, i, o, o, i, i],
		[t_solid, i, i, i, i, i, i, o, o],
		[t_solid, i, i, i, i, o, i, i, o],
		[t_solid, i, i, i, i, i, o, o, i],
		[t_solid, i, i, i, i, o, i, o, i],
		[t_solid, i, i, i, i, i, o, i, o],
		[t_solid, i, i, i, i, o, o, o, i],
		[t_solid, i, i, i, i, o, o, i, o],
		[t_solid, i, i, i, i, o, i, o, o],
		[t_solid, i, i, i, i, i, o, o, o],
		[t_solid, i, i, i, i, o, o, o, o],
		[t_solid, o, i, o, i, o, o, o, o],
		[t_solid, i, o, i, o, o, o, o, o],
		[t_solid, o, o, o, o, o, o, o, o],
	]

	for p: Array in extra_patterns:
		var coords: Vector2i = p[0]
		var alt_id: int = src.create_alternative_tile(coords)
		_set_full_peering(src, coords, alt_id, terrain_set, i, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
		if add_water_collision and (coords == t_solid or coords in [t_bevel_tl, t_bevel_tr, t_bevel_bl, t_bevel_br]):
			_set_alt_collision(src, coords, alt_id, AP.PHYSICS_LAYER_WATER)

	# Water collision on main tiles (solid water + 45-deg bank bevels; leave 3px grass rim banks walkable!)
	if add_water_collision:
		for wc: Vector2i in [t_solid, t_bevel_tl, t_bevel_tr, t_bevel_bl, t_bevel_br]:
			_set_full_collision(src, wc, AP.PHYSICS_LAYER_WATER)


func _set_full_peering(
	src: TileSetAtlasSource,
	coords: Vector2i,
	alt_id: int,
	terrain_set: int,
	center: int,
	t: int, r: int, b: int, l: int,
	tl: int, top_r: int, br: int, bl: int
) -> void:
	var td: TileData = src.get_tile_data(coords, alt_id)
	assert(td != null, "Missing TileData for %s alt=%d" % [str(coords), alt_id])
	td.terrain_set = terrain_set
	td.terrain = center
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, t)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, r)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, b)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, l)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, tl)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, top_r)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, br)
	td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, bl)


func _set_solid_probability(src: TileSetAtlasSource, coords: Vector2i, prob: float) -> void:
	var td: TileData = src.get_tile_data(coords, 0)
	assert(td != null, "Missing TileData for probability on %s" % str(coords))
	td.probability = prob


func _configure_cliff_terrain(src: TileSetAtlasSource) -> void:
	# Elevated rock cliff 3x3 autotile (clean straight sides & grass-footed base):
	# Top lip: (10,4 alt) left, (11,3) center, (12,4 alt) right
	# Mid rock face: (10,4) left, (11,4) center, (12,4) right
	# Bottom grass-foot base: (10,6) left, (11,4 alt) center, (12,6) right
	var o: int = -1
	var i: int = AP.TERRAIN_CLIFF
	var cliff_defs: Array[Array] = [
		[Vector2i(11, 3), o, i, i, i, o, o, i, i], # Top rock face below grass
		[Vector2i(10, 4), i, i, i, o, o, i, i, o], # Left rock wall
		[Vector2i(11, 4), i, i, i, i, i, i, i, i], # Center rock wall
		[Vector2i(12, 4), i, o, i, i, i, o, o, i], # Right rock wall
		[Vector2i(10, 6), i, i, o, o, o, i, o, o], # Bottom-Left rock base on grass
		[Vector2i(12, 6), i, o, o, i, i, o, o, o], # Bottom-Right rock base on grass
	]

	for d: Array in cliff_defs:
		var coords: Vector2i = d[0]
		_set_full_peering(src, coords, 0, AP.TERRAIN_SET_CLIFF, i, d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8])
		_set_full_collision(src, coords, AP.PHYSICS_LAYER_WORLD_SOLID)

	# Top-left, Top-right, and Bottom-middle rock walls as alternative tiles
	var cliff_alts: Array[Array] = [
		[Vector2i(10, 4), o, i, i, o, o, o, i, o], # Top-Left corner
		[Vector2i(12, 4), o, o, i, i, o, o, o, i], # Top-Right corner
		[Vector2i(11, 4), i, i, o, i, i, i, o, o], # Bottom-Middle base
		[Vector2i(11, 3), o, i, o, i, o, o, o, o], # 1-row horizontal cliff strip
	]
	for ca: Array in cliff_alts:
		var coords: Vector2i = ca[0]
		var alt_id: int = src.create_alternative_tile(coords)
		_set_full_peering(src, coords, alt_id, AP.TERRAIN_SET_CLIFF, i, ca[1], ca[2], ca[3], ca[4], ca[5], ca[6], ca[7], ca[8])
		_set_alt_collision(src, coords, alt_id, AP.PHYSICS_LAYER_WORLD_SOLID)


func _configure_structural_collisions(src: TileSetAtlasSource) -> void:
	var stone_walls: Array[Vector2i] = [
		AP.TILE_STONE_WALL_TL, AP.TILE_STONE_WALL_H1,
		AP.TILE_STONE_WALL_H2, AP.TILE_STONE_WALL_TR,
		AP.TILE_STONE_WALL_V1, AP.TILE_STONE_WALL_V2,
		AP.TILE_STONE_WALL_V3, AP.TILE_STONE_WALL_VB,
		AP.TILE_STONE_GATE_LEFT, AP.TILE_STONE_GATE_RIGHT,
		# Additional Room1 multi-tier cliff edges, lips, waterfall flanks & cliff cave arches
		AP.TILE_CLIFF_FACE_TL, AP.TILE_CLIFF_FACE_TR,
		Vector2i(10, 5), Vector2i(12, 5),
		AP.TILE_CLIFF_WATERFALL_SIDE,
		AP.TILE_CLIFF_LIP_M, AP.TILE_CLIFF_LIP_L, AP.TILE_CLIFF_LIP_R,
		AP.TILE_CAVE_ARCH_L, AP.TILE_CAVE_ARCH_R,
	]
	for coords: Vector2i in stone_walls:
		_set_full_collision(src, coords, AP.PHYSICS_LAYER_WORLD_SOLID)


func _set_full_collision(src: TileSetAtlasSource, coords: Vector2i, physics_layer: int) -> void:
	_set_alt_collision(src, coords, 0, physics_layer)


func _set_alt_collision(src: TileSetAtlasSource, coords: Vector2i, alt_id: int, physics_layer: int) -> void:
	if not src.has_tile(coords):
		return
	var td: TileData = src.get_tile_data(coords, alt_id)
	if td == null:
		return
	if td.get_collision_polygons_count(physics_layer) == 0:
		td.add_collision_polygon(physics_layer)
	td.set_collision_polygon_points(
		physics_layer,
		0,
		PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	)
