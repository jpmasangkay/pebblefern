class_name AsciiMapCompiler
extends RefCounted

## Compiles handcrafted ASCII world blueprints into Godot 4.7 TileMapLayer stacks
## using TileMapLayer.set_cells_terrain_connect(), verified .tscn prefabs,
## FastNoiseLite meadow detail layering, and deterministic Poisson-disc forest scattering.

const AP := preload("res://scripts/core/asset_paths.gd")

const TILE_SIZE: int = 16
const MAX_MAP_WIDTH: int = 256
const MAX_MAP_HEIGHT: int = 256
const MAX_POISSON_ATTEMPTS: int = 4096


class MapCompileResult:
	extends RefCounted
	var map_size_tiles: Vector2i = Vector2i.ZERO
	var world_rect_px: Rect2i = Rect2i()
	var player_spawn_px: Vector2 = Vector2.ZERO
	var garden_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []


static func compile_into_root(
	root: Node2D,
	blueprint_rows: PackedStringArray,
	world_seed: int = 20260407,
	place_starter_soil: bool = true
) -> MapCompileResult:
	assert(root != null, "AsciiMapCompiler requires a valid root Node2D.")
	assert(blueprint_rows.size() > 0 and blueprint_rows.size() <= MAX_MAP_HEIGHT, "Invalid blueprint row count.")

	var height: int = blueprint_rows.size()
	var width: int = blueprint_rows[0].length()
	assert(width > 0 and width <= MAX_MAP_WIDTH, "Invalid blueprint column count.")
	for r: int in range(height):
		assert(blueprint_rows[r].length() == width, "Blueprint row %d length mismatch (%d != %d)." % [r, blueprint_rows[r].length(), width])

	var tileset: TileSet = load(AP.TILESET_RESOURCE) as TileSet
	assert(tileset != null, "Missing master TileSet at %s" % AP.TILESET_RESOURCE)

	# 1. Create the exact ordered TileMapLayer + WorldEntities stack (Section 3.1)
	var water_layer: TileMapLayer = _make_layer("00_Water", tileset, -10, true)
	var ground_layer: TileMapLayer = _make_layer("01_Ground", tileset, -9, true)
	var paths_layer: TileMapLayer = _make_layer("02_Paths", tileset, -8, false)
	var garden_layer: TileMapLayer = _make_layer("02b_GardenBed", tileset, -8, false)
	var soil_layer: TileMapLayer = _make_layer("03_SoilOverlay", tileset, -7, false)
	var deco_layer: TileMapLayer = _make_layer("04_Decorations", tileset, -6, false)

	var entities_root: Node2D = Node2D.new()
	entities_root.name = "WorldEntities"
	entities_root.y_sort_enabled = true

	var roof_canopy_layer: TileMapLayer = _make_layer("06_RoofCanopy", tileset, 10, false)

	root.add_child(water_layer)
	root.add_child(ground_layer)
	root.add_child(paths_layer)
	root.add_child(garden_layer)
	root.add_child(soil_layer)
	root.add_child(deco_layer)
	root.add_child(entities_root)
	root.add_child(roof_canopy_layer)

	# 2. Parse ASCII symbols into typed coordinate buckets
	var river_core: Array[Vector2i] = []
	var road_core: Array[Vector2i] = []
	var garden_core: Array[Vector2i] = []
	var cliff_cells: Array[Vector2i] = []
	var forest_cells: Array[Vector2i] = []
	var quarry_cells: Array[Vector2i] = []
	var meadow_cells: Array[Vector2i] = []
	var fence_set: Dictionary = {}
	var stone_wall_set: Dictionary = {}
	var stone_gate_set: Dictionary = {}
	var water_set: Dictionary = {}
	var occupied_set: Dictionary = {}

	var farmhouse_anchors: Array[Vector2i] = []
	var bridge_anchors: Array[Vector2i] = []
	var shipping_anchors: Array[Vector2i] = []
	var stall_anchors: Array[Vector2i] = []
	var water_prop_anchors: Array[Vector2i] = []
	var player_spawn_tile: Vector2i = Vector2i(floori(float(width) / 2.0), floori(float(height) / 2.0))

	for y: int in range(height):
		var row_str: String = blueprint_rows[y]
		for x: int in range(width):
			var ch: String = row_str.substr(x, 1)
			var cell: Vector2i = Vector2i(x, y)
			match ch:
				"~":
					river_core.append(cell)
					water_set[cell] = true
					occupied_set[cell] = true
				"W":
					river_core.append(cell)
					water_set[cell] = true
					occupied_set[cell] = true
					water_prop_anchors.append(cell)
				"B":
					river_core.append(cell)
					water_set[cell] = true
					bridge_anchors.append(cell)
				"=":
					road_core.append(cell)
					occupied_set[cell] = true
				"F":
					garden_core.append(cell)
					occupied_set[cell] = true
				"C":
					cliff_cells.append(cell)
					occupied_set[cell] = true
				"T":
					forest_cells.append(cell)
				"R":
					quarry_cells.append(cell)
				"P":
					fence_set[cell] = true
					occupied_set[cell] = true
				"K":
					stone_wall_set[cell] = true
					occupied_set[cell] = true
				"G":
					stone_gate_set[cell] = true
					occupied_set[cell] = true
				"H":
					farmhouse_anchors.append(cell)
				"S":
					shipping_anchors.append(cell)
				"M":
					stall_anchors.append(cell)
				"@":
					player_spawn_tile = cell
					road_core.append(cell)
					occupied_set[cell] = true
				".":
					meadow_cells.append(cell)
				_:
					meadow_cells.append(cell)

	# 3. Deterministic Noise for Subtle Meadow Variation & Forest Clustering
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.14

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed

	# 4. Paint 01_Ground base subtle two-tone 16x16 meadow checkerboard + darker grass mats
	for y: int in range(height):
		for x: int in range(width):
			var cell: Vector2i = Vector2i(x, y)
			var grass_tile: Vector2i = AP.TILE_GRASS_LIGHT if ((x + y) % 2 == 0) else AP.TILE_GRASS_ALT
			ground_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, grass_tile)

	# Paint soft darker-green grass detail mats on open meadow zones (matching image_89fec2.png)
	for cell: Vector2i in meadow_cells:
		var nv: float = noise.get_noise_2d(float(cell.x), float(cell.y))
		if nv > 0.34 and not _has_adjacent_in_set(cell, water_set, 1):
			var detail_tile: Vector2i = AP.TILE_GRASS_DETAIL_A
			var pick: int = rng.randi_range(0, 2)
			if pick == 1:
				detail_tile = AP.TILE_GRASS_DETAIL_B
			elif pick == 2:
				detail_tile = AP.TILE_GRASS_DETAIL_C
			ground_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, detail_tile)

	# 5. Paint TERRAIN_RIVER on 01_Ground + Animated Sparkling Water on 00_Water
	var river_expanded: Array[Vector2i] = _expand_with_rounded_rim(river_core, width, height)
	if river_expanded.size() > 0:
		ground_layer.set_cells_terrain_connect(river_expanded, AP.TERRAIN_SET_RIVER, AP.TERRAIN_RIVER, true)
		for cell: Vector2i in river_expanded:
			occupied_set[cell] = true
		# Place animated flowing cyan water underneath and shimmering sparkles on deep interior cells
		for cell: Vector2i in river_core:
			water_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_RIVER_ANIM)
			if _is_interior_water(cell, water_set) and rng.randf() < 0.22:
				deco_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_GLINT_ANIM)

	# 6. Paint TERRAIN_CLIFF on 01_Ground (elevated terraced rock cliff walls)
	if cliff_cells.size() > 0:
		ground_layer.set_cells_terrain_connect(cliff_cells, AP.TERRAIN_SET_CLIFF, AP.TERRAIN_CLIFF, true)
		for cell: Vector2i in cliff_cells:
			occupied_set[cell] = true

	# 7. Paint TERRAIN_PATH_ROAD (Path 01) on 02_Paths & TERRAIN_GARDEN_BED (Path 02) on 02b_GardenBed
	# Separate Path 01 / Path 02 layers allow vertical paths to connect seamlessly flush into garden beds!
	var road_set: Dictionary = {}
	for rc: Vector2i in road_core:
		road_set[rc] = true
	var garden_set_check: Dictionary = {}
	for gc: Vector2i in garden_core:
		garden_set_check[gc] = true

	# Auto-extend vertical road stems 1 tile under farmhouse threshold or into adjacent garden bed edge
	# so 2-tile vertical paths meet doorways & garden beds squarely with zero tapered gaps!
	var road_core_seamless: Array[Vector2i] = road_core.duplicate()
	for rc: Vector2i in road_core:
		var south_neighbor: Vector2i = rc + Vector2i(0, 1)
		if garden_set_check.has(south_neighbor) and not road_set.has(south_neighbor):
			road_core_seamless.append(south_neighbor)
			road_set[south_neighbor] = true
	for anchor: Vector2i in farmhouse_anchors:
		# Extend north path 1 tile deeper under front wall & widen to 3 tiles (anchor.x+1..anchor.x+3, anchor.y-1..anchor.y)
		# so doorway entrance is flat and grounded, never a pointy ^ triangle!
		for dy: int in [-1, 0]:
			for dx: int in [1, 2, 3]:
				var door_step: Vector2i = Vector2i(anchor.x + dx, anchor.y + dy)
				if door_step.x >= 0 and door_step.x < width and door_step.y >= 0 and door_step.y < height and not road_set.has(door_step):
					road_core_seamless.append(door_step)
					road_set[door_step] = true
	for anchor: Vector2i in shipping_anchors:
		# Ground the Sanctuary Shipping Bin on a 3-tile flat packed-dirt apron connected cleanly into the east road!
		for dy: int in range(0, 3):
			for dx: int in range(-1, 2):
				var bin_pad: Vector2i = Vector2i(anchor.x + dx, anchor.y + dy)
				if bin_pad.x >= 0 and bin_pad.x < width and bin_pad.y >= 0 and bin_pad.y < height and not road_set.has(bin_pad):
					road_core_seamless.append(bin_pad)
					road_set[bin_pad] = true
	for anchor: Vector2i in stall_anchors:
		# Connect the entire Trading Post (left crates, Maren's open booth, and Kaelen's Anvil apron) cleanly into the main east road!
		for dy: int in range(0, 3):
			for dx: int in range(-3, 4):
				var pad_cell: Vector2i = Vector2i(anchor.x + dx, anchor.y + dy)
				if pad_cell.x >= 0 and pad_cell.x < width and pad_cell.y >= 0 and pad_cell.y < height and not road_set.has(pad_cell):
					road_core_seamless.append(pad_cell)
					road_set[pad_cell] = true

	var road_expanded: Array[Vector2i] = _expand_with_rounded_rim(road_core_seamless, width, height)
	if road_expanded.size() > 0:
		paths_layer.set_cells_terrain_connect(road_expanded, AP.TERRAIN_SET_PATHS, AP.TERRAIN_PATH_ROAD, true)
		for cell: Vector2i in road_expanded:
			occupied_set[cell] = true

	var garden_expanded: Array[Vector2i] = _expand_with_rounded_rim(garden_core, width, height)
	if garden_expanded.size() > 0:
		garden_layer.set_cells_terrain_connect(garden_expanded, AP.TERRAIN_SET_GARDEN, AP.TERRAIN_GARDEN_BED, true)
		for cell: Vector2i in garden_expanded:
			occupied_set[cell] = true

	# Optional starter tilled soil preview INSIDE the Path 02 garden bed (never on raw grass!)
	if place_starter_soil and garden_core.size() >= 12:
		_place_starter_tilled_plots(soil_layer, garden_core)

	# 8. Clear river water collision under Wooden Bridge crossings & instantiate verified .tscn prefabs!
	var farmhouse_scene: PackedScene = load("res://scenes/props/cutaway_farmhouse.tscn") as PackedScene
	var bridge_scene: PackedScene = load("res://scenes/props/wooden_bridge.tscn") as PackedScene
	var shipping_scene: PackedScene = load("res://scenes/props/shipping_bin.tscn") as PackedScene
	var stall_scene: PackedScene = load("res://scenes/props/market_stall.tscn") as PackedScene
	var coracle_scene: PackedScene = load("res://scenes/props/water_coracle.tscn") as PackedScene
	var duck_scene: PackedScene = load("res://scenes/props/water_duck.tscn") as PackedScene

	for anchor: Vector2i in farmhouse_anchors:
		var fh: Node2D = farmhouse_scene.instantiate() as Node2D
		fh.name = "CutawayFarmhouse"
		# Align exactly to 16px tile grid so front door (local x=10) lands cleanly on world col anchor.x+3!
		fh.position = Vector2(float(anchor.x * TILE_SIZE), float(anchor.y * TILE_SIZE) + 8.0)
		entities_root.add_child(fh)
		# Reserve compact 7x6 verbatim Room1.yy building + flanking yard prop footprint so zero trees clip roof/walls!
		_mark_rect_occupied(occupied_set, anchor.x - 4, anchor.y - 7, anchor.x + 7, anchor.y)

	for anchor: Vector2i in bridge_anchors:
		var br: Node2D = bridge_scene.instantiate() as Node2D
		br.name = "WoodenBridge"
		br.position = _tile_center(anchor)
		entities_root.add_child(br)
		# Disable water physics across the 5x3 walkable bridge span while keeping animated cyan water visible underneath!
		for by: int in range(anchor.y - 1, anchor.y + 2):
			for bx: int in range(anchor.x - 3, anchor.x + 4):
				var bcell: Vector2i = Vector2i(bx, by)
				if bx >= anchor.x - 1 and bx <= anchor.x + 1:
					water_layer.set_cell(bcell, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_RIVER_ANIM, 1)
					ground_layer.erase_cell(bcell)
					paths_layer.erase_cell(bcell)
				else:
					water_layer.erase_cell(bcell)
					ground_layer.set_cell(bcell, AP.SOURCE_MAIN_16PX, AP.TILE_GRASS_LIGHT)
				deco_layer.erase_cell(bcell)
				occupied_set[bcell] = true
		for by_ch: int in [anchor.y - 2, anchor.y + 2, anchor.y + 3]:
			for bx_ch: int in range(anchor.x - 1, anchor.x + 2):
				var wc: Vector2i = Vector2i(bx_ch, by_ch)
				water_layer.set_cell(wc, AP.SOURCE_MAIN_16PX, AP.TILE_WATER_RIVER_ANIM, 0)
				ground_layer.erase_cell(wc)
				paths_layer.erase_cell(wc)
				occupied_set[wc] = true
		_mark_rect_occupied(occupied_set, anchor.x - 3, anchor.y - 2, anchor.x + 3, anchor.y + 3)

	for anchor: Vector2i in shipping_anchors:
		var sb: Node2D = shipping_scene.instantiate() as Node2D
		sb.name = "ShippingBin"
		sb.position = _tile_center(anchor) + Vector2(0, 4)
		entities_root.add_child(sb)
		_mark_rect_occupied(occupied_set, anchor.x - 1, anchor.y - 1, anchor.x + 2, anchor.y + 1)

	for anchor: Vector2i in stall_anchors:
		var ms: Node2D = stall_scene.instantiate() as Node2D
		ms.name = "MarketStall"
		ms.position = Vector2(float(anchor.x * TILE_SIZE), float(anchor.y * TILE_SIZE))
		entities_root.add_child(ms)
		_mark_rect_occupied(occupied_set, anchor.x - 4, anchor.y - 4, anchor.x + 5, anchor.y + 2)

	# Water wildlife (Coracle Boat & Ducks) — STRICTLY asserted inside water!
	for idx: int in range(water_prop_anchors.size()):
		var anchor: Vector2i = water_prop_anchors[idx]
		assert(water_set.has(anchor), "Water wildlife anchor %s MUST lie inside water!" % str(anchor))
		var prop: Node2D = (coracle_scene if idx == 0 else duck_scene).instantiate() as Node2D
		prop.name = "WaterCoracle_%d" % idx if idx == 0 else "WaterDuck_%d" % idx
		prop.position = _tile_center(anchor)
		entities_root.add_child(prop)

	# 9. Build Connected Wooden Fences (o==o==o) & Anchored Stone Walls + Wooden Gates on WorldEntities
	_build_connected_fences(entities_root, fence_set, tileset)
	_build_connected_stone_walls(entities_root, stone_wall_set, stone_gate_set)

	# 10. Reserve player spawn clearing
	_mark_rect_occupied(occupied_set, player_spawn_tile.x - 1, player_spawn_tile.y - 1, player_spawn_tile.x + 1, player_spawn_tile.y + 1)

	# 11. Soften northern cliff base with natural trees, boulders, and berry bushes
	_frame_cliff_foothills(entities_root, cliff_cells, occupied_set, rng)

	# 12. Organic Forest Scattering (Poisson-disc minimum distance + FastNoiseLite) inside T zones
	_scatter_forest_props(entities_root, forest_cells, occupied_set, noise, rng)

	# 13. Quarry & Choppable Stumps (all 3 sizes!) inside R zones
	_scatter_quarry_props(entities_root, deco_layer, quarry_cells, occupied_set, rng)

	# 14. Wildflowers, Pebbles, Grass Tufts & Mushrooms on open meadow cells
	_scatter_meadow_decor(entities_root, deco_layer, meadow_cells, occupied_set, noise, rng)

	# Hard compiler rule: Zero non-glint props on 00_Water & zero scatter debris on 02_Paths / 02b_GardenBed
	for wc: Vector2i in water_layer.get_used_cells():
		if deco_layer.get_cell_source_id(wc) != -1 and deco_layer.get_cell_atlas_coords(wc) != AP.TILE_WATER_GLINT_ANIM:
			deco_layer.erase_cell(wc)
	for pc: Vector2i in paths_layer.get_used_cells():
		if deco_layer.get_cell_source_id(pc) != -1:
			deco_layer.erase_cell(pc)
	for gc: Vector2i in garden_layer.get_used_cells():
		if deco_layer.get_cell_source_id(gc) != -1:
			deco_layer.erase_cell(gc)

	var result: MapCompileResult = MapCompileResult.new()
	result.map_size_tiles = Vector2i(width, height)
	result.world_rect_px = Rect2i(0, 0, width * TILE_SIZE, height * TILE_SIZE)
	result.player_spawn_px = _tile_center(player_spawn_tile)
	result.garden_cells = garden_core
	result.water_cells = river_core
	return result


static func _make_layer(layer_name: String, ts: TileSet, z_val: int, enable_collision: bool = true) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = ts
	layer.z_index = z_val
	layer.collision_enabled = enable_collision
	return layer


static func _tile_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x * TILE_SIZE) + 8.0, float(cell.y * TILE_SIZE) + 8.0)


static func _expand_with_rounded_rim(core: Array[Vector2i], width: int, height: int) -> Array[Vector2i]:
	var cell_set: Dictionary = {}
	for c: Vector2i in core:
		cell_set[c] = true
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			# Allow 1-tile bleed outside map border when a road/river exits off-screen so borders stay open!
			if n.x >= -1 and n.x <= width and n.y >= -1 and n.y <= height:
				cell_set[n] = true
	IslandWorldBuilder._eliminate_pointy_tips(cell_set, {})
	var out: Array[Vector2i] = []
	for k: Variant in cell_set.keys():
		out.append(k as Vector2i)
	return out


static func _is_interior_water(cell: Vector2i, water_set: Dictionary) -> bool:
	return (
		water_set.has(cell + Vector2i(1, 0))
		and water_set.has(cell + Vector2i(-1, 0))
		and water_set.has(cell + Vector2i(0, 1))
		and water_set.has(cell + Vector2i(0, -1))
	)


static func _has_adjacent_in_set(cell: Vector2i, lookup: Dictionary, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if lookup.has(cell + Vector2i(dx, dy)):
				return true
	return false


static func _mark_rect_occupied(occupied: Dictionary, x0: int, y0: int, x1: int, y1: int) -> void:
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			occupied[Vector2i(x, y)] = true


static func _place_starter_tilled_plots(soil_layer: TileMapLayer, garden_core: Array[Vector2i]) -> void:
	var min_x: int = 99999
	var max_x: int = -99999
	var min_y: int = 99999
	var max_y: int = -99999
	var garden_set: Dictionary = {}
	for c: Vector2i in garden_core:
		garden_set[c] = true
		min_x = mini(min_x, c.x)
		max_x = maxi(max_x, c.x)
		min_y = mini(min_y, c.y)
		max_y = maxi(max_y, c.y)

	# Place 2 neat starter rows inside the interior of the Path 02 garden bed (1-tile inset from rim)
	var row_dry: int = min_y + 1
	var row_wet: int = min_y + 2
	for x: int in range(min_x + 2, mini(min_x + 8, max_x)):
		var cd: Vector2i = Vector2i(x, row_dry)
		var cw: Vector2i = Vector2i(x, row_wet)
		if garden_set.has(cd):
			soil_layer.set_cell(cd, AP.SOURCE_SOIL_DRY, Vector2i(0, 0))
		if garden_set.has(cw):
			soil_layer.set_cell(cw, AP.SOURCE_SOIL_WATERED, Vector2i(0, 0))


static func _build_connected_fences(entities_root: Node2D, fence_set: Dictionary, tileset: TileSet) -> void:
	if fence_set.is_empty():
		return
	var atlas_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	assert(atlas_tex != null, "Missing tileset texture for fences.")
	var idx: int = 0
	for key: Variant in fence_set.keys():
		var cell: Vector2i = key as Vector2i
		var has_l: bool = fence_set.has(cell + Vector2i(-1, 0))
		var has_r: bool = fence_set.has(cell + Vector2i(1, 0))
		var has_u: bool = fence_set.has(cell + Vector2i(0, -1))
		var has_d: bool = fence_set.has(cell + Vector2i(0, 1))

		var coords: Vector2i = AP.TILE_FENCE_POST_SINGLE
		if has_l and has_r and (has_u or has_d):
			coords = AP.TILE_FENCE_CROSS
		elif has_l and has_r:
			coords = AP.TILE_FENCE_H_MID if (cell.x % 2 == 0) else AP.TILE_FENCE_H_MID_ALT
		elif has_r and not has_l and not has_u and not has_d:
			coords = AP.TILE_FENCE_H_LEFT
		elif has_l and not has_r and not has_u and not has_d:
			coords = AP.TILE_FENCE_H_RIGHT
		elif has_u and has_d:
			coords = AP.TILE_FENCE_V_MID
		elif has_d and has_r:
			coords = AP.TILE_FENCE_CORNER_TL # Verified (42,1): connects RIGHT + DOWN cleanly!
		elif has_d and has_l:
			coords = AP.TILE_FENCE_CORNER_TR # Verified (41,1): connects LEFT + DOWN cleanly!
		elif has_u and has_r:
			coords = AP.TILE_FENCE_CORNER_BL # Verified (39,1): connects RIGHT + UP cleanly!
		elif has_u and has_l:
			coords = AP.TILE_FENCE_CORNER_BR # Verified (38,1): connects LEFT + UP cleanly!
		elif has_d:
			coords = AP.TILE_FENCE_V_TOP
		elif has_u:
			coords = AP.TILE_FENCE_V_BOTTOM

		var body: StaticBody2D = StaticBody2D.new()
		body.name = "FencePost_%d" % idx
		body.position = _tile_center(cell) + Vector2(0, 4)
		body.collision_layer = 1
		body.collision_mask = 0

		var spr: Sprite2D = Sprite2D.new()
		spr.name = "Sprite2D"
		var at: AtlasTexture = AtlasTexture.new()
		at.atlas = atlas_tex
		at.region = Rect2(coords.x * 16, coords.y * 16, 16, 16)
		spr.texture = at
		spr.offset = Vector2(0, -4)
		body.add_child(spr)

		var cs: CollisionShape2D = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		cs.position = Vector2(0, -2)
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(14, 7)
		cs.shape = rect
		body.add_child(cs)

		entities_root.add_child(body)
		idx += 1
	# Reference tileset to silence unused parameter warning while keeping API uniform
	assert(tileset != null)


static func _build_connected_stone_walls(
	entities_root: Node2D,
	wall_set: Dictionary,
	gate_set: Dictionary
) -> void:
	if wall_set.is_empty() and gate_set.is_empty():
		return
	var atlas_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	assert(atlas_tex != null, "Missing tileset texture for stone walls.")

	var all_stone: Dictionary = wall_set.duplicate()
	for gk: Variant in gate_set.keys():
		all_stone[gk] = true

	var idx: int = 0
	for key: Variant in all_stone.keys():
		var cell: Vector2i = key as Vector2i
		var is_gate: bool = gate_set.has(cell)
		var has_l: bool = all_stone.has(cell + Vector2i(-1, 0))
		var has_r: bool = all_stone.has(cell + Vector2i(1, 0))
		var has_u: bool = all_stone.has(cell + Vector2i(0, -1))
		var has_d: bool = all_stone.has(cell + Vector2i(0, 1))
		var left_is_gate: bool = gate_set.has(cell + Vector2i(-1, 0))
		var right_is_gate: bool = gate_set.has(cell + Vector2i(1, 0))

		# Seamless Sunnyside stone wall mapping (verified on spr_tileset_sunnysideworld_16px.png cols 44..47, rows 1..5):
		# - Horizontal left cap: (45, 1)  | Seamless horizontal middle: (46, 1)  | Right cap: (47, 1)
		# - Seamless vertical column: (44, 2..4)  | Bottom vertical cap: (44, 5)
		# - Bottom-left L-corner (has_u and has_r): horizontal base (45, 1) + overlapping vertical stem (44, 5) -> zero green gap!
		var coords: Vector2i = AP.TILE_STONE_WALL_H2 # (46, 1) seamless horizontal middle
		var add_vertical_corner_stem: bool = false
		if is_gate:
			coords = AP.TILE_STONE_GATE_WOOD
		elif has_u and has_r and not has_d:
			coords = AP.TILE_STONE_WALL_H1 # (45, 1) seamless left-to-right base
			add_vertical_corner_stem = true
		elif has_d and has_r and not has_u:
			coords = AP.TILE_STONE_WALL_H1
		elif right_is_gate:
			coords = AP.TILE_STONE_WALL_TR # (47, 1) neat rounded stone end framing left side of gate
		elif left_is_gate:
			coords = AP.TILE_STONE_WALL_H1 # (45, 1) neat rounded stone start framing right side of gate
		elif has_l and has_r:
			coords = AP.TILE_STONE_WALL_H2 # (46, 1) seamless middle horizontal masonry (zero vertical seams!)
		elif has_u and has_d:
			coords = AP.TILE_STONE_WALL_V2 if (cell.y % 2 == 0) else AP.TILE_STONE_WALL_V3
		elif has_u and not has_l and not has_r:
			coords = AP.TILE_STONE_WALL_VB
		elif has_d and not has_l and not has_r:
			coords = AP.TILE_STONE_WALL_V1
		elif has_l and not has_r:
			coords = AP.TILE_STONE_WALL_TR
		elif has_r and not has_l:
			coords = AP.TILE_STONE_WALL_H1

		var spr: Sprite2D = Sprite2D.new()
		spr.name = "Sprite2D"
		var at: AtlasTexture = AtlasTexture.new()
		at.atlas = atlas_tex
		at.region = Rect2(coords.x * 16, coords.y * 16, 16, 16)
		spr.texture = at
		spr.offset = Vector2(0, -4)

		if is_gate:
			# Walkable wooden gate embedded cleanly in the grey stone wall!
			var gate_node: Node2D = Node2D.new()
			gate_node.name = "StoneWallGate_%d" % idx
			gate_node.position = _tile_center(cell) + Vector2(0, 4)
			gate_node.add_child(spr)
			entities_root.add_child(gate_node)
		else:
			var body: StaticBody2D = StaticBody2D.new()
			body.name = "StoneWall_%d" % idx
			body.position = _tile_center(cell) + Vector2(0, 4)
			body.collision_layer = 1
			body.collision_mask = 0
			body.add_child(spr)

			if add_vertical_corner_stem:
				# Seamless vertical stone pillar joining down into the horizontal base with zero green grass gap!
				var stem_spr: Sprite2D = Sprite2D.new()
				stem_spr.name = "CornerVerticalStem"
				var stem_at: AtlasTexture = AtlasTexture.new()
				stem_at.atlas = atlas_tex
				stem_at.region = Rect2(AP.TILE_STONE_WALL_VB.x * 16, AP.TILE_STONE_WALL_VB.y * 16, 16, 16)
				stem_spr.texture = stem_at
				stem_spr.offset = Vector2(0, -7)
				body.add_child(stem_spr)

			var cs: CollisionShape2D = CollisionShape2D.new()
			cs.name = "CollisionShape2D"
			cs.position = Vector2(0, -3)
			var rect: RectangleShape2D = RectangleShape2D.new()
			rect.size = Vector2(16, 11)
			cs.shape = rect
			body.add_child(cs)
			entities_root.add_child(body)
		idx += 1


static func _frame_cliff_foothills(
	entities_root: Node2D,
	cliff_cells: Array[Vector2i],
	occupied_set: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	if cliff_cells.is_empty():
		return
	var cliff_set: Dictionary = {}
	for c: Vector2i in cliff_cells:
		cliff_set[c] = true

	var res_node_scene: PackedScene = load("res://scenes/entities/resource_node.tscn") as PackedScene
	var bush_scene: PackedScene = load("res://scenes/props/berry_bush.tscn") as PackedScene
	var placed: Array[Vector2] = []
	var idx: int = 0

	# Frame the base edge directly below each cliff wall with natural pines, deciduous trees, rocks, and berry bushes!
	for c: Vector2i in cliff_cells:
		var base_cell: Vector2i = c + Vector2i(0, 1)
		if cliff_set.has(base_cell) or occupied_set.has(base_cell):
			continue
		var pos: Vector2 = _tile_center(base_cell) + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0))
		var too_close: bool = false
		for p: Vector2 in placed:
			if p.distance_squared_to(pos) < 26.0 * 26.0:
				too_close = true
				break
		if too_close:
			continue
		var roll: float = rng.randf()
		if roll < 0.55:
			var tree: ResourceNode = res_node_scene.instantiate() as ResourceNode
			tree.name = "CliffTree_%d" % idx
			tree.node_kind = ResourceNode.NodeKind.TREE_PINE if rng.randf() < 0.6 else ResourceNode.NodeKind.TREE_DECIDUOUS
			tree.position = pos.round()
			entities_root.add_child(tree)
			placed.append(pos)
			occupied_set[base_cell] = true
			idx += 1
		elif roll < 0.78:
			var rock: ResourceNode = res_node_scene.instantiate() as ResourceNode
			rock.name = "CliffRock_%d" % idx
			rock.node_kind = ResourceNode.NodeKind.ROCK_SMALL if rng.randf() < 0.65 else ResourceNode.NodeKind.BOULDER_MEDIUM
			rock.position = pos.round()
			entities_root.add_child(rock)
			placed.append(pos)
			occupied_set[base_cell] = true
			idx += 1
		elif roll < 0.94:
			var bush: BerryBush = bush_scene.instantiate() as BerryBush
			bush.name = "CliffBush_%d" % idx
			bush.berry_variant = 0 if rng.randf() < 0.7 else 2
			bush.position = pos.round()
			entities_root.add_child(bush)
			placed.append(pos)
			occupied_set[base_cell] = true
			idx += 1


static func _scatter_forest_props(
	entities_root: Node2D,
	forest_cells: Array[Vector2i],
	occupied_set: Dictionary,
	noise: FastNoiseLite,
	rng: RandomNumberGenerator
) -> void:
	if forest_cells.is_empty():
		return
	var res_node_scene: PackedScene = load("res://scenes/entities/resource_node.tscn") as PackedScene
	var bush_scene: PackedScene = load("res://scenes/props/berry_bush.tscn") as PackedScene

	# Deterministic Fisher-Yates shuffle of candidate forest cells (bounded!)
	var candidates: Array[Vector2i] = forest_cells.duplicate()
	var n_cand: int = candidates.size()
	for i: int in range(n_cand - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var placed_trees: Array[Vector2] = []
	var min_tree_dist_sq: float = 28.0 * 28.0
	var tree_idx: int = 0
	var bush_idx: int = 0
	var stump_idx: int = 0

	var max_iter: int = mini(candidates.size(), MAX_POISSON_ATTEMPTS)
	for i: int in range(max_iter):
		var cell: Vector2i = candidates[i]
		if occupied_set.has(cell):
			continue
		var jitter: Vector2 = Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
		var pos: Vector2 = _tile_center(cell) + jitter
		var too_close: bool = false
		for existing: Vector2 in placed_trees:
			if existing.distance_squared_to(pos) < min_tree_dist_sq:
				too_close = true
				break
		if too_close:
			continue

		var nv: float = noise.get_noise_2d(float(cell.x) * 1.4, float(cell.y) * 1.4)
		var roll: float = rng.randf()
		if roll < 0.72:
			var is_pine: bool = (nv < -0.05) or (rng.randf() < 0.35)
			var tree: ResourceNode = res_node_scene.instantiate() as ResourceNode
			tree.name = ("TreePine_%d" if is_pine else "TreeDeciduous_%d") % tree_idx
			tree.node_kind = ResourceNode.NodeKind.TREE_PINE if is_pine else ResourceNode.NodeKind.TREE_DECIDUOUS
			tree.position = pos.round()
			entities_root.add_child(tree)
			placed_trees.append(pos)
			occupied_set[cell] = true
			tree_idx += 1
		elif roll < 0.88:
			var bush: BerryBush = bush_scene.instantiate() as BerryBush
			bush.name = "BerryBush_%d" % bush_idx
			bush.berry_variant = 0 if rng.randf() < 0.75 else 1
			bush.position = pos.round()
			entities_root.add_child(bush)
			placed_trees.append(pos)
			occupied_set[cell] = true
			bush_idx += 1
		else:
			var st: ResourceNode = res_node_scene.instantiate() as ResourceNode
			st.name = "ForestStump_%d" % stump_idx
			st.node_kind = (ResourceNode.NodeKind.STUMP_SMALL + rng.randi_range(0, 2)) as ResourceNode.NodeKind
			st.position = pos.round()
			entities_root.add_child(st)
			occupied_set[cell] = true
			stump_idx += 1


static func _scatter_quarry_props(
	entities_root: Node2D,
	deco_layer: TileMapLayer,
	quarry_cells: Array[Vector2i],
	occupied_set: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var res_node_scene: PackedScene = load("res://scenes/entities/resource_node.tscn") as PackedScene
	var bush_scene: PackedScene = load("res://scenes/props/berry_bush.tscn") as PackedScene
	var node_idx: int = 0
	var bush_idx: int = 0

	# Guarantee all 3 choppable stump sizes + small/medium/large mineable rocks appear in the quarry!
	var guaranteed_kinds: Array[ResourceNode.NodeKind] = [
		ResourceNode.NodeKind.BOULDER_LARGE,
		ResourceNode.NodeKind.BOULDER_MEDIUM,
		ResourceNode.NodeKind.ROCK_SMALL,
		ResourceNode.NodeKind.ROCK_SMALL,
		ResourceNode.NodeKind.STUMP_LARGE,
		ResourceNode.NodeKind.STUMP_MEDIUM,
		ResourceNode.NodeKind.STUMP_SMALL,
	]
	for cell: Vector2i in quarry_cells:
		if occupied_set.has(cell):
			continue
		var roll: float = rng.randf()
		if guaranteed_kinds.size() > 0 and roll < 0.45:
			var kind: ResourceNode.NodeKind = guaranteed_kinds.pop_back()
			if kind in [ResourceNode.NodeKind.BOULDER_MEDIUM, ResourceNode.NodeKind.BOULDER_LARGE] and _has_adjacent_in_set(cell, occupied_set, 1):
				guaranteed_kinds.push_front(kind)
				continue
			var rn: ResourceNode = res_node_scene.instantiate() as ResourceNode
			rn.name = "QuarryNode_%d" % node_idx
			rn.node_kind = kind
			rn.position = _tile_center(cell)
			entities_root.add_child(rn)
			occupied_set[cell] = true
			if kind in [ResourceNode.NodeKind.BOULDER_MEDIUM, ResourceNode.NodeKind.BOULDER_LARGE]:
				_mark_rect_occupied(occupied_set, cell.x - 1, cell.y - 1, cell.x + 1, cell.y + 1)
			node_idx += 1
		elif roll < 0.14:
			var rn2: ResourceNode = res_node_scene.instantiate() as ResourceNode
			rn2.name = "QuarryNode_%d" % node_idx
			rn2.node_kind = ResourceNode.NodeKind.ROCK_SMALL if rng.randf() < 0.55 else (ResourceNode.NodeKind.STUMP_SMALL + rng.randi_range(0, 2)) as ResourceNode.NodeKind
			rn2.position = _tile_center(cell)
			entities_root.add_child(rn2)
			occupied_set[cell] = true
			node_idx += 1
		elif roll < 0.20:
			var bush: BerryBush = bush_scene.instantiate() as BerryBush
			bush.name = "QuarryBush_%d" % bush_idx
			bush.berry_variant = 0
			bush.position = _tile_center(cell)
			entities_root.add_child(bush)
			occupied_set[cell] = true
			bush_idx += 1
		elif roll < 0.40:
			var pebbles: Array[Vector2i] = [
				AP.TILE_PEBBLE_DOUBLE, AP.TILE_PEBBLE_SMALL, AP.TILE_PEBBLE_TINY
			]
			deco_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, pebbles[rng.randi_range(0, pebbles.size() - 1)])


static func _scatter_meadow_decor(
	entities_root: Node2D,
	deco_layer: TileMapLayer,
	meadow_cells: Array[Vector2i],
	occupied_set: Dictionary,
	noise: FastNoiseLite,
	rng: RandomNumberGenerator
) -> void:
	var res_node_scene: PackedScene = load("res://scenes/entities/resource_node.tscn") as PackedScene
	var bush_scene: PackedScene = load("res://scenes/props/berry_bush.tscn") as PackedScene
	var bush_idx: int = 0
	var stump_idx: int = 0
	var weed_idx: int = 0

	for cell: Vector2i in meadow_cells:
		if occupied_set.has(cell):
			continue
		var nv: float = noise.get_noise_2d(float(cell.x) * 2.1, float(cell.y) * 2.1)
		var roll: float = rng.randf()
		if roll < 0.085:
			var fl: Vector2i = AP.TILE_FLOWER_WHITE_SINGLE
			var f_roll: float = rng.randf()
			if f_roll < 0.25:
				fl = AP.TILE_FLOWER_WHITE_CLUSTER
			elif f_roll < 0.40:
				fl = AP.TILE_FLOWER_WHITE_LARGE
			elif f_roll < 0.48:
				fl = AP.TILE_FLOWER_BLUE_SINGLE
			elif f_roll < 0.55:
				fl = AP.TILE_FLOWER_RED_SINGLE
			deco_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, fl)
		elif roll < 0.125:
			var pebbles: Array[Vector2i] = [AP.TILE_PEBBLE_SMALL, AP.TILE_PEBBLE_TINY, AP.TILE_PEBBLE_DOUBLE]
			deco_layer.set_cell(cell, AP.SOURCE_MAIN_16PX, pebbles[rng.randi_range(0, pebbles.size() - 1)])
		elif roll < 0.15 and nv > 0.2:
			var weed: ResourceNode = res_node_scene.instantiate() as ResourceNode
			weed.name = "MeadowWeed_%d" % weed_idx
			weed.node_kind = ResourceNode.NodeKind.WEED_TUFT
			weed.position = _tile_center(cell)
			entities_root.add_child(weed)
			occupied_set[cell] = true
			weed_idx += 1
		elif roll < 0.162 and not _has_adjacent_in_set(cell, occupied_set, 1):
			var bush: BerryBush = bush_scene.instantiate() as BerryBush
			bush.name = "MeadowBush_%d" % bush_idx
			bush.berry_variant = 0
			bush.position = _tile_center(cell)
			entities_root.add_child(bush)
			occupied_set[cell] = true
			bush_idx += 1
		elif roll < 0.170 and not _has_adjacent_in_set(cell, occupied_set, 1):
			var st: ResourceNode = res_node_scene.instantiate() as ResourceNode
			st.name = "MeadowStump_%d" % stump_idx
			st.node_kind = (ResourceNode.NodeKind.STUMP_SMALL + rng.randi_range(0, 2)) as ResourceNode.NodeKind
			st.position = _tile_center(cell)
			entities_root.add_child(st)
			occupied_set[cell] = true
			stump_idx += 1
