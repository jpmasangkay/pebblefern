extends Node

## Compiles res://scenes/world/npc_interior.tscn — the clean, straight-walled dark-backdrop
## NPC cabin interior shell dynamically furnished per resident by NpcInterior.configure_theme().

const AP := preload("res://scripts/core/asset_paths.gd")
const NPC_INTERIOR_SCRIPT_PATH: String = "res://scripts/world/npc_interior.gd"
const PLAYER_SCENE_PATH: String = "res://scenes/entities/player.tscn"

var _tileset: TileSet = null
var _tileset_tex: Texture2D = null


func _ready() -> void:
	_tileset = load(AP.TILESET_RESOURCE) as TileSet
	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	assert(_tileset != null and _tileset_tex != null, "Missing tileset for NPC interior.")

	var root: Node2D = Node2D.new()
	root.name = "NpcInterior"
	root.script = load(NPC_INTERIOR_SCRIPT_PATH) as Script
	root.set("room_bounds_px", Rect2i(-48, -16, 320, 212))

	# 1. Clean dark interior void backdrop using real Sunnyside 9-slice PNG
	var backdrop_tex: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(backdrop_tex != null, "Missing w_box_9slice_c.png")
	var void_bg: Sprite2D = Sprite2D.new()
	void_bg.name = "InteriorVoidBackdrop"
	void_bg.texture = backdrop_tex
	void_bg.modulate = Color(0.06, 0.05, 0.09, 1.0)
	void_bg.centered = false
	void_bg.position = Vector2(-240.0, -180.0)
	void_bg.scale = Vector2(180.0, 140.0)
	void_bg.z_index = -20
	root.add_child(void_bg)

	# 2. Cabin Interior Plank Floor (14x9 tiles, warm oak planks + dark-oak exit vestibule)
	var floor_layer: TileMapLayer = TileMapLayer.new()
	floor_layer.name = "InteriorFloor"
	floor_layer.tile_set = _tileset
	floor_layer.z_index = -5
	root.add_child(floor_layer)

	for y: int in range(2, 8):
		for x: int in range(1, 13):
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 9))
	floor_layer.set_cell(Vector2i(6, 7), 0, Vector2i(10, 9))
	floor_layer.set_cell(Vector2i(7, 7), 0, Vector2i(10, 9))
	floor_layer.set_cell(Vector2i(6, 8), 0, Vector2i(10, 9))
	floor_layer.set_cell(Vector2i(7, 8), 0, Vector2i(10, 9))

	# 3. Straight Clean Perimeter Timber Walls (zero broken cutaway stubs!)
	var wall_layer: TileMapLayer = TileMapLayer.new()
	wall_layer.name = "WallsLayer"
	wall_layer.tile_set = _tileset
	wall_layer.z_index = -4
	root.add_child(wall_layer)

	for x: int in range(1, 13):
		wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(1, 9))
		wall_layer.set_cell(Vector2i(x, 1), 0, Vector2i(5, 10))
	for y: int in range(0, 9):
		wall_layer.set_cell(Vector2i(0, y), 0, Vector2i(15, 14))
		wall_layer.set_cell(Vector2i(13, y), 0, Vector2i(17, 14))
	for x: int in range(1, 6):
		wall_layer.set_cell(Vector2i(x, 8), 0, Vector2i(5, 10))
	for x: int in range(8, 13):
		wall_layer.set_cell(Vector2i(x, 8), 0, Vector2i(5, 10))

	# Symmetrical crisp wall windows (x=4 and x=7, y=1)
	_add_window(root, Vector2(4 * 16 + 5, 1 * 16 + 5), "CabinWinLeft")
	_add_window(root, Vector2(7 * 16 + 5, 1 * 16 + 5), "CabinWinRight")

	# 4. Dynamic Theme Containers (populated per resident by NpcInterior.configure_theme())
	var rug_layer: TileMapLayer = TileMapLayer.new()
	rug_layer.name = "InteriorRugs"
	rug_layer.tile_set = _tileset
	rug_layer.z_index = -3
	root.add_child(rug_layer)

	var furn_layer: TileMapLayer = TileMapLayer.new()
	furn_layer.name = "InteriorFurniture"
	furn_layer.tile_set = _tileset
	furn_layer.z_index = -2
	root.add_child(furn_layer)

	var details: Node2D = Node2D.new()
	details.name = "InteriorDetails"
	details.z_index = -1
	root.add_child(details)

	# 5. WorldEntities (y_sort_enabled = true) containing Player
	var entities: Node2D = Node2D.new()
	entities.name = "WorldEntities"
	entities.y_sort_enabled = true
	root.add_child(entities)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	assert(player_scene != null, "Missing player.tscn")
	var player_inst: Node2D = player_scene.instantiate() as Node2D
	player_inst.name = "Player"
	player_inst.position = Vector2(112.0, 108.0)
	entities.add_child(player_inst)

	# 6. Solid Perimeter Collisions + Dynamic FurnitureCollisions Container
	var walls_body: StaticBody2D = StaticBody2D.new()
	walls_body.name = "RoomCollisions"
	walls_body.collision_layer = 1
	walls_body.collision_mask = 0
	root.add_child(walls_body)

	_add_rect_collider(walls_body, Vector2(112.0, 16.0), Vector2(224.0, 32.0), "TopWall")
	_add_rect_collider(walls_body, Vector2(8.0, 72.0), Vector2(16.0, 144.0), "LeftWall")
	_add_rect_collider(walls_body, Vector2(216.0, 72.0), Vector2(16.0, 144.0), "RightWall")
	_add_rect_collider(walls_body, Vector2(48.0, 136.0), Vector2(96.0, 16.0), "BottomWallLeft")
	_add_rect_collider(walls_body, Vector2(176.0, 136.0), Vector2(96.0, 16.0), "BottomWallRight")
	_add_rect_collider(walls_body, Vector2(112.0, 148.0), Vector2(40.0, 10.0), "DoorwayStopper")

	var furn_body: StaticBody2D = StaticBody2D.new()
	furn_body.name = "FurnitureCollisions"
	furn_body.collision_layer = 1
	furn_body.collision_mask = 0
	root.add_child(furn_body)

	# 7. Interactive ExitDoorPortal over Exit Doormat
	var exit_area: Area2D = Area2D.new()
	exit_area.name = "ExitDoorPortal"
	exit_area.collision_layer = 8
	exit_area.collision_mask = 4
	exit_area.monitoring = true
	exit_area.monitorable = true
	root.add_child(exit_area)
	var exit_cs: CollisionShape2D = CollisionShape2D.new()
	exit_cs.name = "ExitZone"
	exit_cs.position = Vector2(112.0, 124.0)
	var exit_rect: RectangleShape2D = RectangleShape2D.new()
	exit_rect.size = Vector2(30.0, 20.0)
	exit_cs.shape = exit_rect
	exit_area.add_child(exit_cs)

	# 8. Warm Interior Lighting
	var mod: CanvasModulate = CanvasModulate.new()
	mod.name = "InteriorModulate"
	mod.color = Color(1.0, 0.98, 0.95, 1.0)
	root.add_child(mod)

	var warm_grad: Gradient = Gradient.new()
	warm_grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	warm_grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.88, 0.62, 0.45), Color(1.0, 0.72, 0.35, 0.0)])
	warm_grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var light_tex: GradientTexture2D = GradientTexture2D.new()
	light_tex.gradient = warm_grad
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(0.5, 0.0)
	light_tex.width = 128
	light_tex.height = 128

	var pl: PointLight2D = PointLight2D.new()
	pl.name = "HearthLight"
	pl.position = Vector2(11 * 16, 2 * 16 + 6.0)
	pl.color = Color(1.0, 0.68, 0.32, 1.0)
	pl.texture = light_tex
	pl.texture_scale = 1.45
	pl.energy = 0.45
	pl.blend_mode = Light2D.BLEND_MODE_ADD
	root.add_child(pl)

	_set_owner_recursive(root, root)
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	assert(pack_err == OK, "Failed to pack npc_interior.tscn: %d" % pack_err)
	var save_err: Error = ResourceSaver.save(packed, "res://scenes/world/npc_interior.tscn")
	assert(save_err == OK, "Failed to save npc_interior.tscn: %d" % save_err)
	print("[BuildNpcInterior] Saved res://scenes/world/npc_interior.tscn cleanly.")
	root.free()
	get_tree().quit(0)


func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_root
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, owner_root)


func _add_window(parent: Node2D, top_left_pos: Vector2, win_name: String) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.name = win_name
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = _tileset_tex
	at.region = Rect2(13 * 16 + 5, 13 * 16 + 6, 6, 8)
	spr.texture = at
	spr.centered = false
	spr.position = top_left_pos
	spr.z_index = -3
	parent.add_child(spr)


func _add_rect_collider(parent: StaticBody2D, pos: Vector2, size: Vector2, shape_name: String) -> void:
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = shape_name
	cs.position = pos
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	parent.add_child(cs)
