extends Node

## Compiles Pebblefern Mine Cave (res://scenes/world/mine_floor.tscn) using 100% real
## Sunnyside World V2.1 Quarry, Cliff, Ladder, Minecart, Rail, and Animated Torch assets.

const AP := preload("res://scripts/core/asset_paths.gd")
const MINE_FLOOR_SCRIPT_PATH: String = "res://scripts/world/mine_floor.gd"
const PLAYER_SCENE_PATH: String = "res://scenes/entities/player.tscn"

var _tileset: TileSet = null
var _tileset_tex: Texture2D = null
var _strip_sprite_script: Script = null


func _ready() -> void:
	_tileset = load(AP.TILESET_RESOURCE) as TileSet
	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	_strip_sprite_script = load("res://scripts/world/strip_sprite_2d.gd") as Script
	assert(_tileset != null and _tileset_tex != null and _strip_sprite_script != null, "BuildMineFloor missing tileset or strip script.")

	var root: Node2D = Node2D.new()
	root.name = "MineFloor"
	root.script = load(MINE_FLOOR_SCRIPT_PATH) as Script
	root.set("room_bounds_px", Rect2i(-32, -16, 448, 288))

	# 1. Subterranean dark rock void backdrop (real Sunnyside 9-slice PNG)
	var backdrop_tex: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(backdrop_tex != null, "Missing w_box_9slice_c.png")
	var void_bg: Sprite2D = Sprite2D.new()
	void_bg.name = "CaveVoidBackdrop"
	void_bg.texture = backdrop_tex
	void_bg.modulate = Color(0.05, 0.05, 0.08, 1.0)
	void_bg.centered = false
	void_bg.position = Vector2(-240.0, -180.0)
	void_bg.scale = Vector2(260.0, 180.0)
	void_bg.z_index = -20
	root.add_child(void_bg)

	# 2. Cave Floor (24x16 cavern: walkable floor cols 2..21, rows 3..13)
	var floor_layer: TileMapLayer = TileMapLayer.new()
	floor_layer.name = "00_CaveFloor"
	floor_layer.tile_set = _tileset
	floor_layer.z_index = -5
	root.add_child(floor_layer)

	var floor_variants: Array[Vector2i] = [
		AP.TILE_QUARRY_EARTH_A,
		AP.TILE_QUARRY_EARTH_B,
		AP.TILE_QUARRY_EARTH_C,
		AP.TILE_QUARRY_EARTH_B,
	]
	for y: int in range(3, 14):
		for x: int in range(2, 22):
			var tile: Vector2i = floor_variants[(x * 7 + y * 13) % floor_variants.size()]
			if x == 2:
				tile = AP.TILE_QUARRY_EARTH_L
			elif x == 21:
				tile = AP.TILE_QUARRY_EARTH_R
			if y == 3:
				tile = AP.TILE_QUARRY_EARTH_TL if x == 2 else (AP.TILE_QUARRY_EARTH_TR if x == 21 else AP.TILE_QUARRY_EARTH_A)
			elif y == 13:
				tile = AP.TILE_QUARRY_EARTH_BL if x == 2 else (AP.TILE_QUARRY_EARTH_BR if x == 21 else AP.TILE_QUARRY_EARTH_C)
			floor_layer.set_cell(Vector2i(x, y), 0, tile)

	# 3. Cave Perimeter Cliff Walls (cols 0..23, rows 0..15)
	var wall_layer: TileMapLayer = TileMapLayer.new()
	wall_layer.name = "01_CaveWalls"
	wall_layer.tile_set = _tileset
	wall_layer.z_index = -3
	root.add_child(wall_layer)

	# Dark rock cap top/bottom/sides
	for y: int in range(0, 16):
		for x: int in range(0, 24):
			if x >= 2 and x <= 21 and y >= 3 and y <= 13:
				continue
			if y == 2 and x >= 2 and x <= 21:
				var top_tile: Vector2i = AP.TILE_QUARRY_CLIFF_TL if x == 2 else (AP.TILE_QUARRY_CLIFF_TR if x == 21 else AP.TILE_QUARRY_CLIFF_M)
				wall_layer.set_cell(Vector2i(x, y), 0, top_tile)
			elif y == 1 and x >= 2 and x <= 21:
				wall_layer.set_cell(Vector2i(x, y), 0, AP.TILE_CLIFF_FACE_MM)
			elif y == 14 and x >= 2 and x <= 21:
				wall_layer.set_cell(Vector2i(x, y), 0, AP.TILE_QUARRY_DARK_B)
			elif x == 1 and y >= 2 and y <= 14:
				wall_layer.set_cell(Vector2i(x, y), 0, AP.TILE_QUARRY_CLIFF_WL)
			elif x == 22 and y >= 2 and y <= 14:
				wall_layer.set_cell(Vector2i(x, y), 0, AP.TILE_QUARRY_CLIFF_WR)
			else:
				wall_layer.set_cell(Vector2i(x, y), 0, AP.TILE_QUARRY_DARK_SOLID)

	# 4. Cave Props Layer: Wooden Exit Ladder (col 11, rows 1..3) + Minecart Rails along row 4!
	var deco_layer: TileMapLayer = TileMapLayer.new()
	deco_layer.name = "02_CaveProps"
	deco_layer.tile_set = _tileset
	deco_layer.z_index = -2
	root.add_child(deco_layer)

	# Exit Ladder leading up to Pebblefern Quarry
	deco_layer.set_cell(Vector2i(11, 1), 0, AP.TILE_LADDER_TOP)
	deco_layer.set_cell(Vector2i(11, 2), 0, AP.TILE_LADDER_MID)
	deco_layer.set_cell(Vector2i(11, 3), 0, AP.TILE_LADDER_BOT)

	# Mining track & parked ore minecart on left chamber entrance
	for rx: int in range(4, 10):
		deco_layer.set_cell(Vector2i(rx, 4), 0, AP.TILE_RAIL_H)
	deco_layer.set_cell(Vector2i(4, 3), 0, AP.TILE_MINECART_TOP)
	deco_layer.set_cell(Vector2i(4, 4), 0, AP.TILE_MINECART)

	# Decorative rock barrels & support crates on upper-right alcove
	deco_layer.set_cell(Vector2i(18, 3), 0, AP.TILE_BARREL_WOOD)
	deco_layer.set_cell(Vector2i(19, 3), 0, AP.TILE_SACK_SINGLE)
	deco_layer.set_cell(Vector2i(20, 3), 0, AP.TILE_BARREL_WOOD)

	# 5. Solid Perimeter Wall Colliders (Physics Layer 1 = WorldSolid)
	var wall_body: StaticBody2D = StaticBody2D.new()
	wall_body.name = "CaveWallColliders"
	wall_body.collision_layer = 1
	wall_body.collision_mask = 0
	root.add_child(wall_body)
	_add_rect_col(wall_body, Vector2(192.0, 24.0), Vector2(384.0, 48.0), "NorthWallCol")
	_add_rect_col(wall_body, Vector2(192.0, 236.0), Vector2(384.0, 32.0), "SouthWallCol")
	_add_rect_col(wall_body, Vector2(16.0, 128.0), Vector2(32.0, 256.0), "WestWallCol")
	_add_rect_col(wall_body, Vector2(368.0, 128.0), Vector2(32.0, 256.0), "EastWallCol")
	_add_rect_col(wall_body, Vector2(72.0, 68.0), Vector2(16.0, 14.0), "MinecartCol")
	_add_rect_col(wall_body, Vector2(312.0, 56.0), Vector2(46.0, 14.0), "RightBarrelsCol")

	# 6. Interactive ExitLadderArea at base of upper wooden ladder
	var exit_area: Area2D = Area2D.new()
	exit_area.name = "ExitLadderArea"
	exit_area.collision_layer = 8
	exit_area.collision_mask = 4
	exit_area.monitoring = true
	exit_area.monitorable = true
	root.add_child(exit_area)
	var exit_cs: CollisionShape2D = CollisionShape2D.new()
	exit_cs.name = "ExitLadderZone"
	exit_cs.position = Vector2(11.5 * 16.0, 3.8 * 16.0)
	var exit_rect: RectangleShape2D = RectangleShape2D.new()
	exit_rect.size = Vector2(28.0, 26.0)
	exit_cs.shape = exit_rect
	exit_area.add_child(exit_cs)

	# 7. WorldEntities container (Y-sorted Player + dynamic FloorContent)
	var entities: Node2D = Node2D.new()
	entities.name = "WorldEntities"
	entities.y_sort_enabled = true
	root.add_child(entities)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	assert(player_scene != null, "BuildMineFloor missing player.tscn")
	var player_inst: Node2D = player_scene.instantiate() as Node2D
	player_inst.name = "Player"
	player_inst.position = Vector2(11.5 * 16.0, 4.2 * 16.0)
	entities.add_child(player_inst)

	var floor_content: Node2D = Node2D.new()
	floor_content.name = "FloorContent"
	floor_content.y_sort_enabled = true
	entities.add_child(floor_content)

	# 8. Atmospheric Subterranean CanvasModulate + 4 Warm Flickering Sunnyside Wall Torches!
	var mod: CanvasModulate = CanvasModulate.new()
	mod.name = "CaveModulate"
	mod.color = Color(0.58, 0.60, 0.70, 1.0)
	root.add_child(mod)

	var light_tex: GradientTexture2D = _make_warm_light_tex()
	var lights_root: Node2D = Node2D.new()
	lights_root.name = "WallLights"
	root.add_child(lights_root)

	var torch_positions: Array[Vector2] = [
		Vector2(8.5 * 16.0, 2.3 * 16.0),
		Vector2(14.5 * 16.0, 2.3 * 16.0),
		Vector2(2.6 * 16.0, 8.5 * 16.0),
		Vector2(21.4 * 16.0, 8.5 * 16.0),
	]
	var fire_tex: Texture2D = load(AP.FIRE_01_STRIP4) as Texture2D
	assert(fire_tex != null, "Missing FIRE_01_STRIP4 for mine torches")
	for i: int in range(torch_positions.size()):
		var tpos: Vector2 = torch_positions[i]
		# Wooden torch sconce + animated Sunnyside flame
		var post: Sprite2D = Sprite2D.new()
		post.name = "TorchPost_%d" % i
		var post_at: AtlasTexture = AtlasTexture.new()
		post_at.atlas = _tileset_tex
		post_at.region = Rect2(AP.TILE_FENCE_POST_SINGLE.x * 16, AP.TILE_FENCE_POST_SINGLE.y * 16, 16, 16)
		post.texture = post_at
		post.position = tpos + Vector2(0.0, 4.0)
		post.z_index = -1
		root.add_child(post)

		var flame: Sprite2D = Sprite2D.new()
		flame.name = "TorchFlame_%d" % i
		flame.script = _strip_sprite_script
		flame.texture = fire_tex
		flame.hframes = 4
		flame.vframes = 1
		flame.scale = Vector2(0.70, 0.70)
		flame.set("frame_rate", 8.0)
		flame.position = tpos + Vector2(0.0, -3.0)
		flame.z_index = 0
		root.add_child(flame)

		var pl: PointLight2D = PointLight2D.new()
		pl.name = "WallTorchLight_%d" % i
		pl.position = tpos
		pl.color = Color(1.0, 0.70, 0.34, 1.0)
		pl.texture = light_tex
		pl.texture_scale = 1.45
		pl.energy = 0.72
		pl.blend_mode = Light2D.BLEND_MODE_ADD
		lights_root.add_child(pl)

	_set_owner_recursive(root, root)
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	assert(pack_err == OK, "Failed to pack mine_floor.tscn: %d" % pack_err)
	var save_err: Error = ResourceSaver.save(packed, "res://scenes/world/mine_floor.tscn")
	assert(save_err == OK, "Failed to save mine_floor.tscn: %d" % save_err)
	print("[BuildMineFloor] Saved res://scenes/world/mine_floor.tscn cleanly.")
	root.free()
	get_tree().quit(0)


func _make_warm_light_tex() -> GradientTexture2D:
	var grad: Gradient = Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.88, 0.62, 0.45), Color(1.0, 0.72, 0.35, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	return tex


func _add_rect_col(parent: StaticBody2D, pos: Vector2, size: Vector2, col_name: String) -> void:
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = col_name
	cs.position = pos
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	parent.add_child(cs)


func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_root
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, owner_root)
