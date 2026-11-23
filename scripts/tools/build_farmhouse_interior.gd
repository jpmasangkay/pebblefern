extends Node

## Compiles the dedicated, clean Stardew-style Farmhouse Interior room (res://scenes/world/farmhouse_interior.tscn)
## using 100% real Sunnyside World V2.1 tileset art:
## - Smooth continuous horizontal back-wall planks (zero repeating vertical notches) + 2 clean windows
## - Real wooden end tables under BOTH potted white daisies & potted sunflower
## - Clean white dining tablecloth (zero grey blob)
## - Chunky symmetrical 2-tile stone hearth fireplace with fire tucked cleanly inside
## - Visible wooden threshold & red woven exit doormat cleanly above the HUD hotbar.

const AP := preload("res://scripts/core/asset_paths.gd")
const INTERIOR_SCRIPT_PATH: String = "res://scripts/world/farmhouse_interior.gd"
const PLAYER_SCENE_PATH: String = "res://scenes/entities/player.tscn"

var _tileset: TileSet = null
var _tileset_tex: Texture2D = null
var _strip_sprite_script: Script = null


func _ready() -> void:
	_tileset = load(AP.TILESET_RESOURCE) as TileSet
	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	_strip_sprite_script = load("res://scripts/world/strip_sprite_2d.gd") as Script
	assert(_tileset != null and _tileset_tex != null and _strip_sprite_script != null, "Missing tileset or strip script.")

	var root: Node2D = Node2D.new()
	root.name = "FarmhouseInterior"
	root.script = load(INTERIOR_SCRIPT_PATH) as Script
	# Lift room slightly in camera bounds so the bottom wooden exit doormat sits clearly ABOVE the hotbar!
	root.set("room_bounds_px", Rect2i(-48, -16, 320, 212))

	# 1. Clean dark interior backdrop behind the 14x9 cabin using real Sunnyside 9-slice PNG
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

	# 2. Cabin Interior Plank Floor (14 cols x 9 rows: x=0..13 -> 0..224px, y=0..8 -> 0..144px)
	var floor_layer: TileMapLayer = TileMapLayer.new()
	floor_layer.name = "InteriorFloor"
	floor_layer.tile_set = _tileset
	floor_layer.z_index = -5
	root.add_child(floor_layer)

	# Warm seamless oak planks across main cabin floor (x=1..12, y=2..7)
	for y: int in range(2, 8):
		for x: int in range(1, 13):
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 9))
	# Rich dark-oak wooden doorstep vestibule at bottom exit doorway (x=6..7, y=7..8)
	floor_layer.set_cell(Vector2i(6, 7), 0, Vector2i(10, 9))
	floor_layer.set_cell(Vector2i(7, 7), 0, Vector2i(10, 9))
	floor_layer.set_cell(Vector2i(6, 8), 0, Vector2i(10, 9))
	floor_layer.set_cell(Vector2i(7, 8), 0, Vector2i(10, 9))

	# 3. Straight Clean Perimeter Timber Walls (SMOOTH continuous horizontal planks, zero notched seams!)
	var wall_layer: TileMapLayer = TileMapLayer.new()
	wall_layer.name = "WallsLayer"
	wall_layer.tile_set = _tileset
	wall_layer.z_index = -4
	root.add_child(wall_layer)

	# Top straight smooth horizontal interior timber wall (5, 10) across x=1..12, y=0..1 (zero vertical notch seams!)
	for x: int in range(1, 13):
		wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(1, 9))
		wall_layer.set_cell(Vector2i(x, 1), 0, Vector2i(5, 10))
	# Straight left & right timber side beams (x=0 and x=13, y=0..8)
	for y: int in range(0, 9):
		wall_layer.set_cell(Vector2i(0, y), 0, Vector2i(15, 14))
		wall_layer.set_cell(Vector2i(13, y), 0, Vector2i(17, 14))
	# Straight bottom front framing wall with crisp 2-tile doorway gap at x=6..7!
	for x: int in range(1, 6):
		wall_layer.set_cell(Vector2i(x, 8), 0, Vector2i(5, 10))
	for x: int in range(8, 13):
		wall_layer.set_cell(Vector2i(x, 8), 0, Vector2i(5, 10))

	# 2 clean symmetrical recessed back-wall windows (x=4 and x=7, y=1)
	_add_window(root, Vector2(4 * 16 + 5, 1 * 16 + 5), "CabinWinLeft")
	_add_window(root, Vector2(7 * 16 + 5, 1 * 16 + 5), "CabinWinRight")

	# 4. Cozy Rugs (Bedroom rug + Centered 3x3 Dining Rug + Visible Wooden-Bordered Exit Doormat)
	var rug_layer: TileMapLayer = TileMapLayer.new()
	rug_layer.name = "InteriorRugs"
	rug_layer.tile_set = _tileset
	rug_layer.z_index = -3
	root.add_child(rug_layer)

	# Bedroom striped red rug beside Red Bed (x=2, y=3)
	rug_layer.set_cell(Vector2i(2, 3), 0, Vector2i(47, 36))
	# Centered 3x3 patterned red/gold rug under dining table (x=5..7, y=3..5)
	for ry: int in range(3):
		for rx: int in range(3):
			rug_layer.set_cell(Vector2i(5 + rx, 3 + ry), 0, Vector2i(40 + rx, 35 + ry))
	# Visible red woven exit doormat seated neatly on the dark-oak threshold ABOVE the hotbar (x=6..7, y=7)
	rug_layer.set_cell(Vector2i(6, 7), 0, Vector2i(47, 36))
	rug_layer.set_cell(Vector2i(7, 7), 0, Vector2i(47, 36))

	# 5. Clean Cabin Furniture (Bed, Dresser, 2 Real Wooden End Tables, Bookshelf, Chunky Symmetrical Stone Hearth)
	var furn_layer: TileMapLayer = TileMapLayer.new()
	furn_layer.name = "InteriorFurniture"
	furn_layer.tile_set = _tileset
	furn_layer.z_index = -2
	root.add_child(furn_layer)

	# Left bedroom nook: Red Bed (x=1, y=2..3) + Full 2-tile wooden dresser (x=2, y=1..2)
	furn_layer.set_cell(Vector2i(1, 2), 0, Vector2i(39, 33))
	furn_layer.set_cell(Vector2i(1, 3), 0, Vector2i(39, 34))
	furn_layer.set_cell(Vector2i(2, 1), 0, Vector2i(47, 33))
	furn_layer.set_cell(Vector2i(2, 2), 0, Vector2i(47, 34))

	# Wooden end table #1 (49, 33..34) under Potted White Daisies at (x=3, y=1..2)!
	furn_layer.set_cell(Vector2i(3, 1), 0, Vector2i(49, 33))
	furn_layer.set_cell(Vector2i(3, 2), 0, Vector2i(49, 34))

	# Bookshelf (45, 33..34) at (x=8, y=1..2) + Wooden end table #2 (49, 33..34) under Potted Sunflower at (x=9, y=1..2)!
	furn_layer.set_cell(Vector2i(8, 1), 0, Vector2i(45, 33))
	furn_layer.set_cell(Vector2i(8, 2), 0, Vector2i(45, 34))
	furn_layer.set_cell(Vector2i(9, 1), 0, Vector2i(49, 33))
	furn_layer.set_cell(Vector2i(9, 2), 0, Vector2i(49, 34))

	# Chunky symmetrical 2-tile Stone Hearth Fireplace (46..47, 19..21) safely in the top-right corner (x=10..11, y=0..2)!
	furn_layer.set_cell(Vector2i(10, 0), 0, Vector2i(46, 19))
	furn_layer.set_cell(Vector2i(11, 0), 0, Vector2i(47, 19))
	furn_layer.set_cell(Vector2i(10, 1), 0, Vector2i(46, 20))
	furn_layer.set_cell(Vector2i(11, 1), 0, Vector2i(47, 20))
	furn_layer.set_cell(Vector2i(10, 2), 0, Vector2i(46, 21))
	furn_layer.set_cell(Vector2i(11, 2), 0, Vector2i(47, 21))

	# 6. Potted Plants on End Tables + Clean Dining Table + Tucked Hearth Fire (z_index = -1)
	var details: Node2D = Node2D.new()
	details.name = "InteriorDetails"
	details.z_index = -1
	root.add_child(details)

	# Potted White Daisies (53, 32) resting cleanly ON TOP of Wooden End Table #1 (x=3, y=1..2)
	var daisies: Sprite2D = Sprite2D.new()
	daisies.name = "PottedDaisies"
	daisies.texture = _make_atlas_tex(53, 32, 1, 1)
	daisies.centered = false
	daisies.position = Vector2(3 * 16, 1 * 16 + 5)
	details.add_child(daisies)

	# Proper Potted Sunflower in blue ceramic planter (52, 32) resting cleanly ON TOP of Wooden End Table #2 (x=9, y=1..2)
	var potted_sunflower: Sprite2D = Sprite2D.new()
	potted_sunflower.name = "PottedSunflower"
	potted_sunflower.texture = _make_atlas_tex(52, 32, 1, 1)
	potted_sunflower.centered = false
	potted_sunflower.position = Vector2(9 * 16, 1 * 16 + 5)
	details.add_child(potted_sunflower)

	# Animated orange flame tucked cleanly dead-center inside the chunky stone hearth firebox (x=10..11, y=2)
	var hearth_fire: Sprite2D = Sprite2D.new()
	hearth_fire.name = "HearthFire"
	hearth_fire.script = _strip_sprite_script
	hearth_fire.texture = load(AP.FIRE_02_STRIP4) as Texture2D
	hearth_fire.hframes = 4
	hearth_fire.vframes = 1
	hearth_fire.centered = true
	hearth_fire.scale = Vector2(0.75, 0.65)
	hearth_fire.set("frame_rate", 7.0)
	hearth_fire.position = Vector2(11 * 16, 2 * 16 + 4.0)
	details.add_child(hearth_fire)

	# Clean wooden dining table (50, 36..37) + crisp white tablecloth (53, 34) + 2 wooden stools (NO grey blob!)
	var stool_l: Sprite2D = Sprite2D.new()
	stool_l.name = "DiningStoolLeft"
	stool_l.texture = _make_atlas_tex(50, 33, 1, 2)
	stool_l.centered = false
	stool_l.position = Vector2(5 * 16 + 3, 3 * 16 + 13)
	details.add_child(stool_l)

	var stool_r: Sprite2D = Sprite2D.new()
	stool_r.name = "DiningStoolRight"
	stool_r.texture = _make_atlas_tex(50, 33, 1, 2)
	stool_r.centered = false
	stool_r.position = Vector2(7 * 16 - 3, 3 * 16 + 13)
	details.add_child(stool_r)

	var dining_table: Sprite2D = Sprite2D.new()
	dining_table.name = "DiningTable"
	dining_table.texture = _make_atlas_tex(50, 36, 1, 2)
	dining_table.centered = false
	dining_table.position = Vector2(6 * 16, 3 * 16 + 10)
	details.add_child(dining_table)

	var tablecloth: Sprite2D = Sprite2D.new()
	tablecloth.name = "DiningTablecloth"
	tablecloth.texture = _make_atlas_tex(53, 34, 1, 1)
	tablecloth.centered = false
	tablecloth.position = Vector2(6 * 16, 3 * 16 + 11)
	details.add_child(tablecloth)

	# 7. WorldEntities (y_sort_enabled = true) containing Player!
	var entities: Node2D = Node2D.new()
	entities.name = "WorldEntities"
	entities.y_sort_enabled = true
	root.add_child(entities)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	assert(player_scene != null, "Missing player.tscn")
	var player_inst: Node2D = player_scene.instantiate() as Node2D
	player_inst.name = "Player"
	player_inst.position = Vector2(112.0, 106.0)
	entities.add_child(player_inst)

	# 8. Solid Perimeter & Furniture Collisions
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

	# Compact furniture colliders leaving wide walking aisles
	_add_rect_collider(walls_body, Vector2(24.0, 48.0), Vector2(14.0, 26.0), "BedCollider")
	_add_rect_collider(walls_body, Vector2(48.0, 36.0), Vector2(30.0, 12.0), "DresserAndTableCollider")
	_add_rect_collider(walls_body, Vector2(104.0, 68.0), Vector2(16.0, 18.0), "DiningTableCollider")
	_add_rect_collider(walls_body, Vector2(160.0, 38.0), Vector2(64.0, 16.0), "ShelfTableHearthCollider")

	# 9. Interactive BedSleepTrigger beside Red Bed
	var bed_area: Area2D = Area2D.new()
	bed_area.name = "BedSleepTrigger"
	bed_area.collision_layer = 8
	bed_area.collision_mask = 4
	bed_area.monitoring = true
	bed_area.monitorable = true
	root.add_child(bed_area)
	var bed_cs: CollisionShape2D = CollisionShape2D.new()
	bed_cs.name = "BedZone"
	bed_cs.position = Vector2(40.0, 56.0)
	var bed_rect: RectangleShape2D = RectangleShape2D.new()
	bed_rect.size = Vector2(36.0, 38.0)
	bed_cs.shape = bed_rect
	bed_area.add_child(bed_cs)

	# 10. Interactive ExitDoorPortal over the bottom Exit Doormat
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

	# 11. Warm Interior Lighting (CanvasModulate + Chunky Hearth PointLight2D)
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
	assert(pack_err == OK, "Failed to pack farmhouse_interior.tscn: %d" % pack_err)
	var save_err: Error = ResourceSaver.save(packed, "res://scenes/world/farmhouse_interior.tscn")
	assert(save_err == OK, "Failed to save farmhouse_interior.tscn: %d" % save_err)
	print("[BuildInterior] Saved res://scenes/world/farmhouse_interior.tscn cleanly.")
	root.free()
	get_tree().quit(0)


func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_root
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, owner_root)


func _make_atlas_tex(col: int, row: int, w_tiles: int = 1, h_tiles: int = 1) -> AtlasTexture:
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = _tileset_tex
	tex.region = Rect2(col * 16, row * 16, w_tiles * 16, h_tiles * 16)
	return tex


func _make_atlas_rect_tex(px_x: int, px_y: int, px_w: int, px_h: int) -> AtlasTexture:
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = _tileset_tex
	tex.region = Rect2(px_x, px_y, px_w, px_h)
	return tex


func _add_window(parent: Node2D, top_left_pos: Vector2, win_name: String) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.name = win_name
	spr.texture = _make_atlas_rect_tex(13 * 16 + 5, 13 * 16 + 6, 6, 8)
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
