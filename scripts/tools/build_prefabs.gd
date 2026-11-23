extends Node

const AP := preload("res://scripts/core/asset_paths.gd")

## Builds all verified multi-tile .tscn prefabs under res://scenes/props/.
## Run via: Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/tools/build_prefabs.tscn

var _tileset: TileSet = null
var _tileset_tex: Texture2D = null
var _strip_sprite_script: Script = null
var _farmhouse_script: Script = null
var _stump_script: Script = null
var _berry_bush_script: Script = null
var _shipping_bin_script: Script = null
var _market_stall_script: Script = null
var _placed_chest_script: Script = null
var _npc_house_script: Script = null
var _world_interactable_script: Script = null


func _ready() -> void:
	_tileset = load(AP.TILESET_RESOURCE) as TileSet
	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	_strip_sprite_script = load("res://scripts/world/strip_sprite_2d.gd") as Script
	_farmhouse_script = load("res://scripts/world/cutaway_farmhouse.gd") as Script
	_stump_script = load("res://scripts/world/stump_node.gd") as Script
	_berry_bush_script = load("res://scripts/world/berry_bush.gd") as Script
	_shipping_bin_script = load("res://scripts/world/shipping_bin.gd") as Script
	_market_stall_script = load("res://scripts/world/market_stall.gd") as Script
	_placed_chest_script = load("res://scripts/world/placed_chest.gd") as Script
	_npc_house_script = load("res://scripts/world/npc_house.gd") as Script
	_world_interactable_script = load("res://scripts/world/world_interactable.gd") as Script
	assert(_tileset != null, "sunnyside_tileset.tres must be built before build_prefabs.gd")
	assert(_tileset_tex != null, "Main 16px tileset PNG missing.")

	_build_cutaway_farmhouse()
	_build_house_green_cottage()
	_build_house_orange_forge()
	_build_house_purple_manor()
	_build_house_red_cabin()
	_build_house_timber_cabin()
	_build_wooden_bridge()
	_build_ocean_channel_bridge()
	_build_fishing_pier()
	_build_shipping_bin()
	_build_market_stall()
	_build_kaelen_forge_apron()
	_build_community_board()
	_build_mine_entrance()
	_build_village_well()
	_build_village_statue()
	_build_woodland_campfire()
	_build_mushroom_prefabs()
	_build_placed_chest()
	_build_stone_wall_gate()
	_build_connected_fence_h()
	_build_connected_fence_v()
	_build_tree_deciduous()
	_build_tree_pine()
	_build_berry_bush()
	_build_stump_node()
	_build_water_coracle()
	_build_water_duck()

	print("[BuildPrefabs] All 29 verified prefabs built cleanly.")
	get_tree().quit(0)


func _save_prefab(root: Node, path: String) -> void:
	_set_owner_recursive(root, root)
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	assert(pack_err == OK, "Failed to pack %s: %d" % [path, pack_err])
	var save_err: Error = ResourceSaver.save(packed, path)
	assert(save_err == OK, "Failed to save %s: %d" % [path, save_err])
	root.free()
	print("[BuildPrefabs] Saved %s" % path)


func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_root
		_set_owner_recursive(child, owner_root)


func _make_atlas_tex(col: int, row: int, w_tiles: int = 1, h_tiles: int = 1) -> AtlasTexture:
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = _tileset_tex
	tex.region = Rect2(col * 16, row * 16, w_tiles * 16, h_tiles * 16)
	return tex


func _add_rect_collider(parent: StaticBody2D, pos: Vector2, size: Vector2, shape_name: String) -> void:
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = shape_name
	cs.position = pos
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	parent.add_child(cs)


func _make_atlas_rect_tex(px_x: int, px_y: int, px_w: int, px_h: int) -> AtlasTexture:
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = _tileset_tex
	tex.region = Rect2(px_x, px_y, px_w, px_h)
	return tex


func _make_warm_light_tex(size_px: int = 128) -> GradientTexture2D:
	var grad: Gradient = Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.92, 0.72, 0.45), Color(1.0, 0.8, 0.5, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var gtex: GradientTexture2D = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = size_px
	gtex.height = size_px
	return gtex


func _add_point_light(parent: Node2D, pos: Vector2, light_color: Color, tex: Texture2D, scale_val: float, base_energy: float, node_name: String) -> PointLight2D:
	var pl: PointLight2D = PointLight2D.new()
	pl.name = node_name
	pl.position = pos
	pl.color = light_color
	pl.texture = tex
	pl.texture_scale = scale_val
	pl.energy = base_energy
	pl.blend_mode = Light2D.BLEND_MODE_ADD
	parent.add_child(pl)
	return pl


func _add_full_window(parent: Node2D, top_left_pos: Vector2, win_w: int, win_h: int, win_name: String) -> void:
	# Symmetrical crisp rectangular dark-pane wall window from real (13,13) tile pixels:
	# 5px pure dark navy (38,43,68) + 3px warm-brown sill (115,62,57), zero notched/rounded corners!
	var spr: Sprite2D = Sprite2D.new()
	spr.name = win_name
	spr.texture = _make_atlas_rect_tex(13 * 16 + 5, 13 * 16 + 6, win_w, win_h)
	spr.centered = false
	spr.position = top_left_pos
	parent.add_child(spr)


# ------------------------------------------------------------------------------
# 1. CUTAWAY FARMHOUSE (Wide 2-Wing Roof-ON / Roof-OFF matching official mockups)
# ------------------------------------------------------------------------------
# Origin (0, 0) = anchor on world tile (24, 12) + (0, 8); grid_offset (-136, -112) aligns:
#   - Extracted 1:1 VERBATIM from Daniel Diggle's official Sunnyside World Room1.yy (cols 39..45, rows 24..30)
#   - Covered center front doorway (local col 3, row 5) DEAD-CENTER over 2-tile vertical dirt path (world cols 26..27)
func _build_cutaway_farmhouse() -> void:
	var root: Node2D = Node2D.new()
	root.name = "CutawayFarmhouse"
	root.script = _farmhouse_script

	# Local doorway center (col 3.5 = +56px) lands on local x=+48px (world col 27.0, center of 2-tile vertical dirt path);
	# ground-wall base (row 6 = +96px) lands flush on local y=0px (world y=200px, top of doorstep dirt path!).
	var grid_offset: Vector2 = Vector2(-8, -96)
	const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H

	# Layer 0: Verbatim Room1.yy [shadows] layer (depth=1100, flush beneath building base on row 6)
	var shadow_layer: TileMapLayer = TileMapLayer.new()
	shadow_layer.name = "GroundShadows"
	shadow_layer.tile_set = _tileset
	shadow_layer.position = grid_offset
	shadow_layer.z_index = -5
	root.add_child(shadow_layer)
	shadow_layer.set_cell(Vector2i(0, 6), 0, Vector2i(18, 1))
	shadow_layer.set_cell(Vector2i(1, 6), 0, Vector2i(12, 1))
	shadow_layer.set_cell(Vector2i(2, 6), 0, Vector2i(12, 1))
	shadow_layer.set_cell(Vector2i(3, 6), 0, Vector2i(12, 1))
	shadow_layer.set_cell(Vector2i(4, 6), 0, Vector2i(12, 1))
	shadow_layer.set_cell(Vector2i(5, 6), 0, Vector2i(12, 1))
	shadow_layer.set_cell(Vector2i(6, 6), 0, Vector2i(18, 1), FLIP_H)

	# RoofLayer container holds the 100% verbatim Room1.yy [building] + [decoration_02] exterior layers (zero interior rooms!)
	var roof_group: Node2D = Node2D.new()
	roof_group.name = "RoofLayer"
	roof_group.z_index = 0
	root.add_child(roof_group)

	# Layer 1: Verbatim Room1.yy [building] layer (depth=700, 40 tiles 1:1 from cols 39..45, rows 24..29)
	var bld_layer: TileMapLayer = TileMapLayer.new()
	bld_layer.name = "Room1BuildingLayer"
	bld_layer.tile_set = _tileset
	bld_layer.position = grid_offset
	bld_layer.z_index = 0
	roof_group.add_child(bld_layer)

	# Row 0 (Room1 row 24)
	bld_layer.set_cell(Vector2i(1, 0), 0, Vector2i(21, 14))
	bld_layer.set_cell(Vector2i(2, 0), 0, Vector2i(22, 14))
	bld_layer.set_cell(Vector2i(3, 0), 0, Vector2i(23, 22))
	bld_layer.set_cell(Vector2i(4, 0), 0, Vector2i(22, 14), FLIP_H)
	bld_layer.set_cell(Vector2i(5, 0), 0, Vector2i(21, 14), FLIP_H)
	# Row 1 (Room1 row 25)
	bld_layer.set_cell(Vector2i(0, 1), 0, Vector2i(28, 23), FLIP_H)
	bld_layer.set_cell(Vector2i(1, 1), 0, Vector2i(21, 15))
	bld_layer.set_cell(Vector2i(2, 1), 0, Vector2i(22, 15))
	bld_layer.set_cell(Vector2i(3, 1), 0, Vector2i(18, 9))
	bld_layer.set_cell(Vector2i(4, 1), 0, Vector2i(22, 15), FLIP_H)
	bld_layer.set_cell(Vector2i(5, 1), 0, Vector2i(21, 15), FLIP_H)
	bld_layer.set_cell(Vector2i(6, 1), 0, Vector2i(28, 23))
	# Row 2 (Room1 row 26)
	bld_layer.set_cell(Vector2i(0, 2), 0, Vector2i(28, 11), FLIP_H)
	bld_layer.set_cell(Vector2i(1, 2), 0, Vector2i(21, 11))
	bld_layer.set_cell(Vector2i(2, 2), 0, Vector2i(28, 9))
	bld_layer.set_cell(Vector2i(3, 2), 0, Vector2i(18, 9))
	bld_layer.set_cell(Vector2i(4, 2), 0, Vector2i(28, 9), FLIP_H)
	bld_layer.set_cell(Vector2i(5, 2), 0, Vector2i(21, 11), FLIP_H)
	bld_layer.set_cell(Vector2i(6, 2), 0, Vector2i(28, 11))
	# Row 3 (Room1 row 27)
	bld_layer.set_cell(Vector2i(0, 3), 0, Vector2i(28, 11), FLIP_H)
	bld_layer.set_cell(Vector2i(1, 3), 0, Vector2i(28, 9))
	bld_layer.set_cell(Vector2i(2, 3), 0, Vector2i(22, 11))
	bld_layer.set_cell(Vector2i(3, 3), 0, Vector2i(24, 11))
	bld_layer.set_cell(Vector2i(4, 3), 0, Vector2i(22, 11), FLIP_H)
	bld_layer.set_cell(Vector2i(5, 3), 0, Vector2i(21, 11), FLIP_H)
	bld_layer.set_cell(Vector2i(6, 3), 0, Vector2i(28, 11))
	# Row 4 (Room1 row 28)
	bld_layer.set_cell(Vector2i(0, 4), 0, Vector2i(20, 12))
	bld_layer.set_cell(Vector2i(1, 4), 0, Vector2i(21, 12))
	bld_layer.set_cell(Vector2i(2, 4), 0, Vector2i(22, 20))
	bld_layer.set_cell(Vector2i(3, 4), 0, Vector2i(16, 12))
	bld_layer.set_cell(Vector2i(4, 4), 0, Vector2i(22, 20), FLIP_H)
	bld_layer.set_cell(Vector2i(5, 4), 0, Vector2i(21, 12), FLIP_H)
	bld_layer.set_cell(Vector2i(6, 4), 0, Vector2i(20, 12), FLIP_H)
	# Row 5 (Room1 row 29)
	bld_layer.set_cell(Vector2i(0, 5), 0, Vector2i(20, 21))
	bld_layer.set_cell(Vector2i(1, 5), 0, Vector2i(33, 21))
	bld_layer.set_cell(Vector2i(2, 5), 0, Vector2i(33, 21))
	bld_layer.set_cell(Vector2i(3, 5), 0, Vector2i(16, 13))
	bld_layer.set_cell(Vector2i(4, 5), 0, Vector2i(33, 21))
	bld_layer.set_cell(Vector2i(5, 5), 0, Vector2i(33, 21))
	bld_layer.set_cell(Vector2i(6, 5), 0, Vector2i(28, 21))

	# Layer 2: Verbatim Room1.yy [decoration_02] layer (depth=500, strictly above [building])
	# Includes the exact roof-seated Stone Chimney (4,1), porch pillars, blue doorway, front benches & corner sunflower!
	var deco2_layer: TileMapLayer = TileMapLayer.new()
	deco2_layer.name = "Room1Decoration02Layer"
	deco2_layer.tile_set = _tileset
	deco2_layer.position = grid_offset
	deco2_layer.z_index = 1
	roof_group.add_child(deco2_layer)

	deco2_layer.set_cell(Vector2i(4, 1), 0, Vector2i(28, 5), FLIP_H) # Official roof-seated Stone Chimney
	deco2_layer.set_cell(Vector2i(2, 4), 0, Vector2i(15, 21))        # Front porch upper left pillar
	deco2_layer.set_cell(Vector2i(4, 4), 0, Vector2i(15, 21), FLIP_H) # Front porch upper right pillar
	deco2_layer.set_cell(Vector2i(6, 4), 0, Vector2i(52, 31))        # Corner potted sunflower top
	deco2_layer.set_cell(Vector2i(1, 5), 0, Vector2i(49, 33))        # Left front bench top
	deco2_layer.set_cell(Vector2i(2, 5), 0, Vector2i(15, 22))        # Front porch lower left pillar
	deco2_layer.set_cell(Vector2i(3, 5), 0, Vector2i(39, 27))        # Covered blue-draped front doorway
	deco2_layer.set_cell(Vector2i(4, 5), 0, Vector2i(15, 22), FLIP_H) # Front porch lower right pillar
	deco2_layer.set_cell(Vector2i(5, 5), 0, Vector2i(49, 33))        # Right front bench top
	deco2_layer.set_cell(Vector2i(6, 5), 0, Vector2i(52, 32))        # Corner potted sunflower pot
	deco2_layer.set_cell(Vector2i(1, 6), 0, Vector2i(49, 34))        # Left front bench legs
	deco2_layer.set_cell(Vector2i(5, 6), 0, Vector2i(49, 34))        # Right front bench legs

	# Animated Chimney Smoke anchored DEAD-CENTER on top of the verbatim chimney tile (4, 1) flue opening (x=+7, y=+3)!
	var smoke: Sprite2D = Sprite2D.new()
	smoke.name = "ChimneySmoke"
	smoke.script = _strip_sprite_script
	smoke.texture = load(AP.CHIMNEY_SMOKE_STRIP30) as Texture2D
	smoke.hframes = 30
	smoke.vframes = 1
	smoke.centered = false
	smoke.offset = Vector2(-7.5, -36.0)
	smoke.set("frame_rate", 10.0)
	smoke.position = grid_offset + Vector2(4 * 16 + 7.0, 1 * 16 + 3.0)
	smoke.z_index = 2
	roof_group.add_child(smoke)

	# Layer 3: Neat Grounded Exterior Yard Props Flanking the Extracted Building (zero overlap with benches, sunflower, or path!)
	var yard_props: Node2D = Node2D.new()
	yard_props.name = "ExteriorYardProps"
	yard_props.z_index = 0
	root.add_child(yard_props)

	# Wooden barrels & berry bush neatly tucked on the left flank of the farmhouse
	var barrel_l: Sprite2D = Sprite2D.new()
	barrel_l.name = "YardBarrelLeft"
	barrel_l.texture = _make_atlas_tex(39, 16, 1, 1)
	barrel_l.centered = false
	barrel_l.position = grid_offset + Vector2(-2 * 16 + 4, 5 * 16 - 4)
	yard_props.add_child(barrel_l)

	var barrel_r: Sprite2D = Sprite2D.new()
	barrel_r.name = "YardBarrelRight"
	barrel_r.texture = _make_atlas_tex(39, 16, 1, 1)
	barrel_r.centered = false
	barrel_r.position = grid_offset + Vector2(-1 * 16 + 1, 5 * 16 - 4)
	yard_props.add_child(barrel_r)

	var barrel_water: Sprite2D = Sprite2D.new()
	barrel_water.name = "YardBarrelWater"
	barrel_water.texture = _make_atlas_tex(38, 16, 1, 1)
	barrel_water.centered = false
	barrel_water.position = grid_offset + Vector2(-2 * 16 + 10, 5 * 16 + 6)
	yard_props.add_child(barrel_water)

	var yard_bush: Sprite2D = Sprite2D.new()
	yard_bush.name = "YardBerryBush"
	yard_bush.texture = _make_atlas_tex(49, 3, 2, 2)
	yard_bush.centered = false
	yard_bush.position = grid_offset + Vector2(-3 * 16 - 4, 4 * 16 + 10)
	yard_props.add_child(yard_bush)

	# Authentic 3-clay-jug cluster neatly centered between the potted sunflower & ShippingBin!
	var yard_jugs: Sprite2D = Sprite2D.new()
	yard_jugs.name = "YardClayJugs"
	yard_jugs.texture = _make_atlas_tex(51, 19, 2, 2)
	yard_jugs.centered = false
	yard_jugs.position = grid_offset + Vector2(7 * 16 - 2, 4 * 16 + 14)
	yard_props.add_child(yard_jugs)

	# --- 100% Solid Exterior Collisions Aligned to Extracted 7x6 Building Footprint & Yard Props ---
	var walls_body: StaticBody2D = StaticBody2D.new()
	walls_body.name = "WallCollisions"
	walls_body.collision_layer = 1
	walls_body.collision_mask = 0
	root.add_child(walls_body)

	_add_rect_collider(walls_body, grid_offset + Vector2(3.5 * 16, 3.4 * 16), Vector2(108, 84), "SolidMainWingHull")
	_add_rect_collider(walls_body, grid_offset + Vector2(1.5 * 16, 6.0 * 16), Vector2(14, 6), "LeftBenchCollider")
	_add_rect_collider(walls_body, grid_offset + Vector2(5.5 * 16, 6.0 * 16), Vector2(14, 6), "RightBenchCollider")
	_add_rect_collider(walls_body, grid_offset + Vector2(-1.0 * 16 + 2, 5.7 * 16), Vector2(22, 12), "YardBarrelsCollider")
	_add_rect_collider(walls_body, grid_offset + Vector2(-2.2 * 16, 5.7 * 16), Vector2(16, 10), "YardBushCollider")
	_add_rect_collider(walls_body, grid_offset + Vector2(7.55 * 16, 5.8 * 16), Vector2(14, 10), "YardJugsCollider")

	# --- DoorPortal Area2D Directly in Front of the Extracted Covered Center Front Door (col 3, row 5 -> y=6.25) ---
	var door_portal: Area2D = Area2D.new()
	door_portal.name = "DoorPortal"
	door_portal.collision_layer = 8
	door_portal.collision_mask = 4
	door_portal.monitoring = true
	door_portal.monitorable = true
	root.add_child(door_portal)

	var door_shape: CollisionShape2D = CollisionShape2D.new()
	door_shape.name = "DoorZone"
	door_shape.position = grid_offset + Vector2(3.5 * 16, 6.25 * 16)
	var door_rect: RectangleShape2D = RectangleShape2D.new()
	door_rect.size = Vector2(22, 14)
	door_shape.shape = door_rect
	door_portal.add_child(door_shape)

	# --- Warm Night Lighting Aligned to Extracted Windows & Covered Front Porch ---
	var lights_root: Node2D = Node2D.new()
	lights_root.name = "NightLights"
	root.add_child(lights_root)

	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(lights_root, grid_offset + Vector2(1.5 * 16, 5.5 * 16), Color(1.0, 0.78, 0.42, 1.0), warm_tex, 0.75, 0.0, "WindowLight1")
	_add_point_light(lights_root, grid_offset + Vector2(2.5 * 16, 5.5 * 16), Color(1.0, 0.78, 0.42, 1.0), warm_tex, 0.75, 0.0, "WindowLight2")
	_add_point_light(lights_root, grid_offset + Vector2(4.5 * 16, 5.5 * 16), Color(1.0, 0.78, 0.42, 1.0), warm_tex, 0.75, 0.0, "WindowLight3")
	_add_point_light(lights_root, grid_offset + Vector2(5.5 * 16, 5.5 * 16), Color(1.0, 0.78, 0.42, 1.0), warm_tex, 0.75, 0.0, "WindowLight4")
	_add_point_light(lights_root, grid_offset + Vector2(3.5 * 16, 5.8 * 16), Color(1.0, 0.74, 0.38, 1.0), warm_tex, 1.15, 0.0, "PorchLight")

	_save_prefab(root, "res://scenes/props/cutaway_farmhouse.tscn")


# ------------------------------------------------------------------------------
# 2. WOODEN BRIDGE (Verbatim Room1.yy 5x3 single-span horizontal river bridge + pilings in water)
# ------------------------------------------------------------------------------
func _build_wooden_bridge() -> void:
	var root: Node2D = Node2D.new()
	root.name = "WoodenBridge"

	const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H
	# Verbatim Room1.yy wooden cross-braced support pilings shifted up (-16px) so their tops tuck
	# directly flush underneath the bottom edge of the bridge deck (ZERO water gap!)
	var pilings_layer: TileMapLayer = TileMapLayer.new()
	pilings_layer.name = "BridgePilings"
	pilings_layer.tile_set = _tileset
	pilings_layer.position = Vector2(-8.0, -16.0)
	pilings_layer.z_index = -6
	root.add_child(pilings_layer)
	for px: int in [-1, 1]:
		pilings_layer.set_cell(Vector2i(px, 2), 0, Vector2i(37, 5))
		pilings_layer.set_cell(Vector2i(px, 3), 0, Vector2i(37, 2))

	# Walkable 5-tile-wide (-2..+2) x 3-row (-1..+1) verbatim Room1.yy plank deck (zero middle seam!)
	var deck_layer: TileMapLayer = TileMapLayer.new()
	deck_layer.name = "BridgeDeck"
	deck_layer.tile_set = _tileset
	deck_layer.position = Vector2(-8.0, -8.0)
	deck_layer.z_index = -5
	root.add_child(deck_layer)

	for bx: int in range(-2, 3):
		var tx_top: Vector2i = Vector2i(39, 11) if (bx == -2 or bx == 2) else Vector2i(40, 11)
		var tx_mid: Vector2i = Vector2i(39, 12) if (bx == -2 or bx == 2) else Vector2i(40, 12)
		var tx_bot: Vector2i = Vector2i(39, 13) if (bx == -2 or bx == 2) else Vector2i(40, 13)
		var fl: int = FLIP_H if (bx == 2 or (bx > -2 and bx < 2 and posmod(bx, 2) == 1)) else 0
		deck_layer.set_cell(Vector2i(bx, -1), 0, tx_top, fl)
		deck_layer.set_cell(Vector2i(bx, 0), 0, tx_mid, fl)
		deck_layer.set_cell(Vector2i(bx, 1), 0, tx_bot, fl)

	# Upper & lower wooden handrails matching Room1.yy bridge rim
	var rails_layer: TileMapLayer = TileMapLayer.new()
	rails_layer.name = "BridgeRails"
	rails_layer.tile_set = _tileset
	rails_layer.position = Vector2(-8.0, -8.0)
	rails_layer.z_index = -4
	root.add_child(rails_layer)
	for bx: int in range(-2, 3):
		if bx == -2:
			rails_layer.set_cell(Vector2i(bx, -1), 0, Vector2i(42, 2), FLIP_H)
			rails_layer.set_cell(Vector2i(bx, 1), 0, Vector2i(38, 0), 0)
		elif bx == 2:
			rails_layer.set_cell(Vector2i(bx, -1), 0, Vector2i(42, 2), 0)
			rails_layer.set_cell(Vector2i(bx, 1), 0, Vector2i(38, 0), FLIP_H)
		else:
			rails_layer.set_cell(Vector2i(bx, -1), 0, Vector2i(39, 2), 0)
			rails_layer.set_cell(Vector2i(bx, 1), 0, Vector2i(39, 0), 0)

	# Thin 4px railing colliders strictly on the outer top & bottom railing edges (40px unobstructed walkway!)
	var rails_body: StaticBody2D = StaticBody2D.new()
	rails_body.name = "RailColliders"
	rails_body.collision_layer = 1
	rails_body.collision_mask = 0
	root.add_child(rails_body)
	_add_rect_collider(rails_body, Vector2(0.0, -22.0), Vector2(80.0, 4.0), "TopRailCollider")
	_add_rect_collider(rails_body, Vector2(0.0, 22.0), Vector2(80.0, 4.0), "BottomRailCollider")

	_save_prefab(root, "res://scenes/props/wooden_bridge.tscn")


# ------------------------------------------------------------------------------
# 3. SHIPPING BIN (Sanctuary Chest: clean stacked produce crate cluster matching image_6f0525.png)
# ------------------------------------------------------------------------------
func _build_shipping_bin() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "ShippingBin"
	root.script = _shipping_bin_script
	root.collision_layer = 1
	root.collision_mask = 0

	# Back stacked upper wooden crate (39, 10) — clean flat top, zero sticking-up horns!
	var back_crate: Sprite2D = Sprite2D.new()
	back_crate.name = "BackStackedCrate"
	back_crate.texture = _make_atlas_tex(39, 10, 1, 1)
	back_crate.offset = Vector2(6, -18)
	root.add_child(back_crate)

	# Front-left open produce crate (39, 9) filled with real Sunnyside harvest produce (pumpkin_05.png)
	var front_left: Sprite2D = Sprite2D.new()
	front_left.name = "ProduceCrateBase"
	front_left.texture = _make_atlas_tex(39, 9, 1, 1)
	front_left.offset = Vector2(0, -6)
	root.add_child(front_left)

	var produce_icon: Sprite2D = Sprite2D.new()
	produce_icon.name = "ProduceFill"
	produce_icon.texture = load(AP.CROPS_ROOT + "/pumpkin_05.png") as Texture2D
	produce_icon.scale = Vector2(0.75, 0.75)
	produce_icon.position = Vector2(0, -10)
	root.add_child(produce_icon)

	# Front-right slatted wooden crate (40, 10) flush beside the produce crate
	var front_right: Sprite2D = Sprite2D.new()
	front_right.name = "SideCrate"
	front_right.texture = _make_atlas_tex(40, 10, 1, 1)
	front_right.offset = Vector2(16, -6)
	root.add_child(front_right)

	_add_rect_collider(root, Vector2(8, -3), Vector2(26, 9), "BinCollider")

	var interact_area: Area2D = Area2D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 8
	interact_area.collision_mask = 4
	root.add_child(interact_area)
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "InteractShape"
	cs.position = Vector2(8, -4)
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(42, 28)
	cs.shape = rect
	interact_area.add_child(cs)

	_save_prefab(root, "res://scenes/props/shipping_bin.tscn")


# ------------------------------------------------------------------------------
# 4. MARKET STALL (Cozy Open-Front Sunnyside Trading Booth + Live Maren + Blended Kaelen Anvil)
# ------------------------------------------------------------------------------
func _build_market_stall() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "MarketStall"
	root.script = _market_stall_script
	root.collision_layer = 1
	root.collision_mask = 0

	# 5-col grid (0..4) where outer timber posts sit on inner edges of col 0 & col 4 -> EXACT 64px (4.0 tiles) booth width!
	var kiosk_origin: Vector2 = Vector2(-40, -52)

	# 1. Botanical Flower Planters flanking Maren's open Seed Trading Booth!
	var planters: Node2D = Node2D.new()
	planters.name = "BotanicalPlanters"
	planters.z_index = -1
	root.add_child(planters)

	var pot_sun: Sprite2D = Sprite2D.new()
	pot_sun.name = "RightPottedSunflower"
	pot_sun.texture = _make_atlas_tex(52, 31, 1, 2)
	pot_sun.position = Vector2(40, 2)
	planters.add_child(pot_sun)

	var pot_daisy: Sprite2D = Sprite2D.new()
	pot_daisy.name = "RightPottedDaisies"
	pot_daisy.texture = _make_atlas_tex(53, 32, 1, 1)
	pot_daisy.position = Vector2(52, 8)
	planters.add_child(pot_daisy)

	# 2. Open-Front Shaded Wooden Booth Interior (dark recessed wood back wall + timber posts — ZERO closed house door!)
	var booth_back: TileMapLayer = TileMapLayer.new()
	booth_back.name = "OpenBoothInterior"
	booth_back.tile_set = _tileset
	booth_back.position = kiosk_origin
	booth_back.z_index = -4
	root.add_child(booth_back)
	for x: int in range(1, 4):
		booth_back.set_cell(Vector2i(x, 3), 0, Vector2i(10, 9)) # Rich shaded dark-wood booth back wall

	var facade_layer: TileMapLayer = TileMapLayer.new()
	facade_layer.name = "BoothSupportPosts"
	facade_layer.tile_set = _tileset
	facade_layer.position = kiosk_origin
	facade_layer.z_index = -3
	root.add_child(facade_layer)
	facade_layer.set_cell(Vector2i(0, 3), 0, Vector2i(15, 14)) # Outer left wooden support post
	facade_layer.set_cell(Vector2i(4, 3), 0, Vector2i(17, 14)) # Outer right wooden support post

	# Cozy built-in shop shelves, cabinet & ceramic jar tucked cleanly INSIDE the open booth behind Maren!
	var interior_props: Node2D = Node2D.new()
	interior_props.name = "BoothShelves"
	interior_props.z_index = -3
	root.add_child(interior_props)

	var left_shelf: Sprite2D = Sprite2D.new()
	left_shelf.name = "SeedPacketShelf"
	left_shelf.texture = _make_atlas_rect_tex(45 * 16, 33 * 16 + 4, 16, 18)
	left_shelf.centered = false
	left_shelf.position = kiosk_origin + Vector2(1 * 16 + 1, 3 * 16 - 2)
	interior_props.add_child(left_shelf)

	var right_cabinet: Sprite2D = Sprite2D.new()
	right_cabinet.name = "ShopSupplyCabinet"
	right_cabinet.texture = _make_atlas_rect_tex(47 * 16, 33 * 16 + 6, 16, 16)
	right_cabinet.centered = false
	right_cabinet.position = kiosk_origin + Vector2(3 * 16 - 1, 3 * 16)
	interior_props.add_child(right_cabinet)

	var shop_jar: Sprite2D = Sprite2D.new()
	shop_jar.name = "CounterCeramicJar"
	shop_jar.texture = _make_atlas_tex(47, 32, 1, 1)
	shop_jar.scale = Vector2(0.75, 0.75)
	shop_jar.position = kiosk_origin + Vector2(3 * 16 + 7, 3 * 16 - 2)
	interior_props.add_child(shop_jar)

	# 3. Clean Pitched Green-Shingle Botanist Booth Roof matching Maren's Green Cottage!
	var roof_layer: TileMapLayer = TileMapLayer.new()
	roof_layer.name = "KioskRoof"
	roof_layer.tile_set = _tileset
	roof_layer.position = kiosk_origin
	roof_layer.z_index = -2
	root.add_child(roof_layer)
	# Row 0: Crisp top ridge & left/right gable timber caps (Green roof row 17)
	roof_layer.set_cell(Vector2i(0, 0), 0, Vector2i(17, 17), TileSetAtlasSource.TRANSFORM_FLIP_H)
	for rx: int in range(1, 4):
		roof_layer.set_cell(Vector2i(rx, 0), 0, Vector2i(16, 17))
	roof_layer.set_cell(Vector2i(4, 0), 0, Vector2i(17, 17))
	# Row 1: Rich emerald green shingles + outer vertical fascia trims (Green roof rows 18..19)
	roof_layer.set_cell(Vector2i(0, 1), 0, Vector2i(15, 19))
	for rx: int in range(1, 4):
		roof_layer.set_cell(Vector2i(rx, 1), 0, Vector2i(18, 18))
	roof_layer.set_cell(Vector2i(4, 1), 0, Vector2i(17, 18))
	# Row 2: Shaded horizontal timber eave beam framing the open trading booth cleanly overhead (Green row 20)
	roof_layer.set_cell(Vector2i(0, 2), 0, Vector2i(15, 20))
	for rx: int in range(1, 4):
		roof_layer.set_cell(Vector2i(rx, 2), 0, Vector2i(16, 20))
	roof_layer.set_cell(Vector2i(4, 2), 0, Vector2i(17, 20))

	# 4. Stacked Wooden Produce Crates & Barrel Grounded Directly on the Left Trading Plaza Apron
	var crates_bottom: Sprite2D = Sprite2D.new()
	crates_bottom.name = "ProduceCrateBottom"
	crates_bottom.texture = _make_atlas_tex(40, 10, 1, 1)
	crates_bottom.position = Vector2(-40, 4)
	crates_bottom.z_index = -1
	root.add_child(crates_bottom)

	var crates_top: Sprite2D = Sprite2D.new()
	crates_top.name = "ProduceCrateTop"
	crates_top.texture = _make_atlas_tex(39, 10, 1, 1)
	crates_top.position = Vector2(-40, -8)
	crates_top.z_index = -1
	root.add_child(crates_top)

	var side_barrel: Sprite2D = Sprite2D.new()
	side_barrel.name = "ShopBarrel"
	side_barrel.texture = _make_atlas_tex(39, 16, 1, 1)
	side_barrel.position = Vector2(-28, 12)
	side_barrel.z_index = -1
	root.add_child(side_barrel)

	# 5. Live Animated Shopkeeper NPC (Maren: NpcActor with 3-layer 9-frame IDLE strips behind counter!)
	var maren_npc: CharacterBody2D = CharacterBody2D.new()
	maren_npc.name = "MarenNPC"
	maren_npc.script = load("res://scripts/world/npc_actor.gd") as Script
	maren_npc.set("npc_id", &"maren")
	maren_npc.set("display_name", "Maren")
	maren_npc.set("hair_style", &"curlyhair")
	maren_npc.set("interact_enabled", false)
	maren_npc.set("add_feet_collider", false)
	maren_npc.set("greeting_lines", PackedStringArray([
		"Fresh Bloom seeds just arrived! Step up to the counter anytime.",
		"The soil on Solstice Plateau grows the sweetest parsnips on the island.",
	]))
	maren_npc.position = Vector2(0, 9)
	maren_npc.z_index = -1
	root.add_child(maren_npc)

	var maren_body: Sprite2D = Sprite2D.new()
	maren_body.name = "BodySprite"
	maren_body.texture = load(AP.MAREN_IDLE_BODY) as Texture2D
	maren_body.hframes = 9
	maren_body.vframes = 1
	maren_body.offset = Vector2(0, -6)
	maren_npc.add_child(maren_body)

	var maren_hair: Sprite2D = Sprite2D.new()
	maren_hair.name = "HairSprite"
	maren_hair.texture = load(AP.MAREN_IDLE_HAIR) as Texture2D
	maren_hair.hframes = 9
	maren_hair.vframes = 1
	maren_hair.offset = Vector2(0, -6)
	maren_npc.add_child(maren_hair)

	var maren_tool: Sprite2D = Sprite2D.new()
	maren_tool.name = "ToolSprite"
	maren_tool.texture = load(AP.MAREN_IDLE_TOOLS) as Texture2D
	maren_tool.hframes = 9
	maren_tool.vframes = 1
	maren_tool.offset = Vector2(0, -6)
	maren_npc.add_child(maren_tool)

	# Seamless light-oak wooden trading counter directly in front of Maren (z_index = 0 for clean Y-sort!)
	var counter_left_tex: AtlasTexture = _make_atlas_rect_tex(45 * 16 - 2, 10 * 16, 16, 15)
	var counter_right_tex: AtlasTexture = _make_atlas_rect_tex(45 * 16 + 2, 10 * 16, 16, 15)
	var counter_l: Sprite2D = Sprite2D.new()
	counter_l.name = "ShopCounterLeft"
	counter_l.texture = counter_left_tex
	counter_l.scale = Vector2(1.0, 0.84)
	counter_l.position = Vector2(-8, 13)
	counter_l.z_index = 0
	root.add_child(counter_l)

	var counter_r: Sprite2D = Sprite2D.new()
	counter_r.name = "ShopCounterRight"
	counter_r.texture = counter_right_tex
	counter_r.scale = Vector2(1.0, 0.84)
	counter_r.position = Vector2(8, 13)
	counter_r.z_index = 0
	root.add_child(counter_r)

	# 6. Right-side Seed Crate & Garden Water Barrel beside Maren's Booth
	var garden_barrel: Sprite2D = Sprite2D.new()
	garden_barrel.name = "GardenWaterBarrel"
	garden_barrel.texture = _make_atlas_tex(38, 16, 1, 1)
	garden_barrel.position = Vector2(40, 12)
	garden_barrel.z_index = -1
	root.add_child(garden_barrel)

	# Warm evening booth lantern glow
	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(root, Vector2(0, 6), Color(1.0, 0.78, 0.42, 1.0), warm_tex, 1.15, 0.0, "ShopWarmLight")

	# Solid Colliders (tightened strictly to bottom visual base of booth, counter, crates & planters)
	_add_rect_collider(root, Vector2(0, -12), Vector2(60, 34), "KioskHullCollider")
	_add_rect_collider(root, Vector2(0, 11), Vector2(30, 8), "ShopCounterCollider")
	_add_rect_collider(root, Vector2(-38, 5), Vector2(14, 10), "CratesCollider")
	_add_rect_collider(root, Vector2(42, 9), Vector2(14, 9), "PlantersCollider")

	# Tightened InteractArea — triggers ONLY right in front of Maren's Seed Shop counter!
	var interact_area: Area2D = Area2D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 8
	interact_area.collision_mask = 4
	root.add_child(interact_area)
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "InteractShape"
	cs.position = Vector2(0, 20)
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(64, 18)
	cs.shape = rect
	interact_area.add_child(cs)

	_save_prefab(root, "res://scenes/props/market_stall.tscn")


# ------------------------------------------------------------------------------
# 4b. PLACED CHEST (16-Slot Persistent Storage Chest Prefab)
# ------------------------------------------------------------------------------
func _build_placed_chest() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "PlacedChest"
	root.script = _placed_chest_script
	root.collision_layer = 1
	root.collision_mask = 0

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = _make_atlas_tex(AP.TILE_CHEST_CLOSED.x, AP.TILE_CHEST_CLOSED.y, 1, 1)
	spr.offset = Vector2(0, -4)
	root.add_child(spr)

	_add_rect_collider(root, Vector2(0, -2), Vector2(14, 10), "ChestCollider")

	var interact_area: Area2D = Area2D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 8
	interact_area.collision_mask = 4
	root.add_child(interact_area)
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "InteractShape"
	cs.position = Vector2(0, -1)
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(30, 26)
	cs.shape = rect
	interact_area.add_child(cs)

	_save_prefab(root, "res://scenes/props/placed_chest.tscn")


# ------------------------------------------------------------------------------
# 5. STONE WALL + WOODEN GATE (Flush stone wall + centered wooden gate matching image_89fec2.png!)
# ------------------------------------------------------------------------------
func _build_stone_wall_gate() -> void:
	var root: Node2D = Node2D.new()
	root.name = "StoneWallGate"

	var wall_layer: TileMapLayer = TileMapLayer.new()
	wall_layer.name = "StoneWallTiles"
	wall_layer.tile_set = _tileset
	wall_layer.position = Vector2(-48, -16)
	root.add_child(wall_layer)

	# Continuous grey stone wall with wooden gate inserted cleanly at tile 4:
	wall_layer.set_cell(Vector2i(0, 0), 0, AP.TILE_STONE_WALL_TL)
	wall_layer.set_cell(Vector2i(1, 0), 0, AP.TILE_STONE_WALL_H1)
	wall_layer.set_cell(Vector2i(2, 0), 0, AP.TILE_STONE_WALL_H2)
	wall_layer.set_cell(Vector2i(3, 0), 0, AP.TILE_STONE_WALL_H1)
	wall_layer.set_cell(Vector2i(4, 0), 0, AP.TILE_STONE_GATE_WOOD)
	wall_layer.set_cell(Vector2i(5, 0), 0, AP.TILE_STONE_WALL_TR)

	_save_prefab(root, "res://scenes/props/stone_wall_gate.tscn")


# ------------------------------------------------------------------------------
# 6 & 7. CONNECTED WOODEN FENCES (o==o==o Horizontal & Vertical segments)
# ------------------------------------------------------------------------------
func _build_connected_fence_h() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "ConnectedFenceH"
	root.collision_layer = 1
	root.collision_mask = 0

	var sp_l: Sprite2D = Sprite2D.new()
	sp_l.name = "LeftPost"
	sp_l.texture = _make_atlas_tex(38, 2, 1, 1)
	sp_l.offset = Vector2(-16, -6)
	root.add_child(sp_l)

	var sp_m: Sprite2D = Sprite2D.new()
	sp_m.name = "MidPost"
	sp_m.texture = _make_atlas_tex(39, 2, 1, 1)
	sp_m.offset = Vector2(0, -6)
	root.add_child(sp_m)

	var sp_r: Sprite2D = Sprite2D.new()
	sp_r.name = "RightPost"
	sp_r.texture = _make_atlas_tex(42, 2, 1, 1)
	sp_r.offset = Vector2(16, -6)
	root.add_child(sp_r)

	_add_rect_collider(root, Vector2(0, -3), Vector2(44, 8), "FenceHCollider")
	_save_prefab(root, "res://scenes/props/connected_fence_h.tscn")


func _build_connected_fence_v() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "ConnectedFenceV"
	root.collision_layer = 1
	root.collision_mask = 0

	var sp_t: Sprite2D = Sprite2D.new()
	sp_t.name = "TopPost"
	sp_t.texture = _make_atlas_tex(40, 1, 1, 1)
	sp_t.offset = Vector2(0, -22)
	root.add_child(sp_t)

	var sp_m: Sprite2D = Sprite2D.new()
	sp_m.name = "MidPost"
	sp_m.texture = _make_atlas_tex(40, 3, 1, 1)
	sp_m.offset = Vector2(0, -6)
	root.add_child(sp_m)

	var sp_b: Sprite2D = Sprite2D.new()
	sp_b.name = "BottomPost"
	sp_b.texture = _make_atlas_tex(40, 4, 1, 1)
	sp_b.offset = Vector2(0, 10)
	root.add_child(sp_b)

	_add_rect_collider(root, Vector2(0, -4), Vector2(8, 42), "FenceVCollider")
	_save_prefab(root, "res://scenes/props/connected_fence_v.tscn")


# ------------------------------------------------------------------------------
# 8 & 9. TREES (Animated spr_deco_tree_01_strip4 & spr_deco_tree_02_strip4)
# ------------------------------------------------------------------------------
func _build_tree_deciduous() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "TreeDeciduous"
	root.collision_layer = 1
	root.collision_mask = 0

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.script = _strip_sprite_script
	spr.texture = load(AP.TREE_DECIDUOUS_STRIP4) as Texture2D
	spr.hframes = 4
	spr.vframes = 1
	spr.offset = Vector2(0, -14)
	spr.set("frame_rate", 3.5)
	spr.set("random_start_phase", true)
	root.add_child(spr)

	_add_rect_collider(root, Vector2(0, -3), Vector2(12, 8), "TrunkCollider")
	_save_prefab(root, "res://scenes/props/tree_deciduous.tscn")


func _build_tree_pine() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "TreePine"
	root.collision_layer = 1
	root.collision_mask = 0

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.script = _strip_sprite_script
	spr.texture = load(AP.TREE_PINE_STRIP4) as Texture2D
	spr.hframes = 4
	spr.vframes = 1
	spr.offset = Vector2(0, -17)
	spr.set("frame_rate", 3.0)
	spr.set("random_start_phase", true)
	root.add_child(spr)

	_add_rect_collider(root, Vector2(0, -3), Vector2(10, 8), "TrunkCollider")
	_save_prefab(root, "res://scenes/props/tree_pine.tscn")


# ------------------------------------------------------------------------------
# 10. BERRY BUSH
# ------------------------------------------------------------------------------
func _build_berry_bush() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "BerryBush"
	root.script = _berry_bush_script
	root.collision_layer = 1
	root.collision_mask = 0

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = _make_atlas_tex(49, 3, 2, 2)
	spr.offset = Vector2(0, -8)
	root.add_child(spr)

	_add_rect_collider(root, Vector2(0, -2), Vector2(14, 8), "BushCollider")
	_save_prefab(root, "res://scenes/props/berry_bush.tscn")


# ------------------------------------------------------------------------------
# 11. STUMP NODE (3 sizes: Small, Medium, Large)
# ------------------------------------------------------------------------------
func _build_stump_node() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "StumpNode"
	root.script = _stump_script
	root.collision_layer = 1
	root.collision_mask = 0

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = _make_atlas_tex(31, 5, 1, 1)
	spr.offset = Vector2(0, -5)
	root.add_child(spr)

	_add_rect_collider(root, Vector2(0, -2), Vector2(12, 8), "StumpCollider")
	_save_prefab(root, "res://scenes/props/stump_node.tscn")


# ------------------------------------------------------------------------------
# 12 & 13. WATER WILDLIFE (Coracle Boat & Ducks — spawned ONLY inside water!)
# ------------------------------------------------------------------------------
func _build_water_coracle() -> void:
	var root: Node2D = Node2D.new()
	root.name = "WaterCoracle"

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.script = _strip_sprite_script
	spr.texture = load(AP.CORACLE_WATER_STRIP4) as Texture2D
	spr.hframes = 4
	spr.vframes = 1
	spr.set("frame_rate", 4.0)
	spr.set("random_start_phase", true)
	root.add_child(spr)

	_save_prefab(root, "res://scenes/props/water_coracle.tscn")


func _build_water_duck() -> void:
	var root: Node2D = Node2D.new()
	root.name = "WaterDuck"

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.script = _strip_sprite_script
	spr.texture = load(AP.DUCK_STRIP4) as Texture2D
	spr.hframes = 4
	spr.vframes = 1
	spr.set("frame_rate", 4.5)
	spr.set("random_start_phase", true)
	root.add_child(spr)

	_save_prefab(root, "res://scenes/props/water_duck.tscn")


# ------------------------------------------------------------------------------
# HELPER FOR VERBATIM ROOM1.YY NPC HOUSES
# ------------------------------------------------------------------------------
func _make_npc_house_base(
	node_name: String,
	bld_id: StringName,
	disp_name: String,
	theme_id: StringName,
	grid_offset: Vector2,
	door_portal_pos: Vector2,
	door_spawn_offset: Vector2,
	footprint_rect: Rect2
) -> Dictionary:
	var root: Node2D = Node2D.new()
	root.name = node_name
	root.script = _npc_house_script
	root.set("building_id", bld_id)
	root.set("display_name", disp_name)
	root.set("interior_theme_id", theme_id)
	root.set("door_spawn_offset", door_spawn_offset)
	root.set("footprint_rect", footprint_rect)

	var shadow_layer: TileMapLayer = TileMapLayer.new()
	shadow_layer.name = "GroundShadows"
	shadow_layer.tile_set = _tileset
	shadow_layer.position = grid_offset
	shadow_layer.z_index = -5
	root.add_child(shadow_layer)

	var bld_layer: TileMapLayer = TileMapLayer.new()
	bld_layer.name = "Room1BuildingLayer"
	bld_layer.tile_set = _tileset
	bld_layer.position = grid_offset
	bld_layer.z_index = 0
	root.add_child(bld_layer)

	var deco2_layer: TileMapLayer = TileMapLayer.new()
	deco2_layer.name = "Room1Decoration02Layer"
	deco2_layer.tile_set = _tileset
	deco2_layer.position = grid_offset
	deco2_layer.z_index = 1
	root.add_child(deco2_layer)

	var walls_body: StaticBody2D = StaticBody2D.new()
	walls_body.name = "WallCollisions"
	walls_body.collision_layer = 1
	walls_body.collision_mask = 0
	root.add_child(walls_body)

	var door_portal: Area2D = Area2D.new()
	door_portal.name = "DoorPortal"
	door_portal.collision_layer = 8
	door_portal.collision_mask = 4
	door_portal.monitoring = true
	door_portal.monitorable = true
	root.add_child(door_portal)

	var door_shape: CollisionShape2D = CollisionShape2D.new()
	door_shape.name = "DoorZone"
	door_shape.position = door_portal_pos
	var door_rect: RectangleShape2D = RectangleShape2D.new()
	door_rect.size = Vector2(22.0, 14.0)
	door_shape.shape = door_rect
	door_portal.add_child(door_shape)

	var lights_root: Node2D = Node2D.new()
	lights_root.name = "NightLights"
	root.add_child(lights_root)

	return {
		"root": root,
		"shadows": shadow_layer,
		"bld": bld_layer,
		"deco2": deco2_layer,
		"walls": walls_body,
		"lights": lights_root,
	}


func _add_chimney_smoke(parent: Node2D, smoke_pos: Vector2) -> void:
	var smoke: Sprite2D = Sprite2D.new()
	smoke.name = "ChimneySmoke"
	smoke.script = _strip_sprite_script
	smoke.texture = load(AP.CHIMNEY_SMOKE_STRIP30) as Texture2D
	smoke.hframes = 30
	smoke.vframes = 1
	smoke.centered = false
	smoke.offset = Vector2(-7.5, -36.0)
	smoke.set("frame_rate", 10.0)
	smoke.position = smoke_pos
	smoke.z_index = 2
	parent.add_child(smoke)


# ------------------------------------------------------------------------------
# 14. GREEN-ROOFED COTTAGE — MAREN'S BOTANIST COTTAGE (Verbatim Room1.yy cols 40..44, rows 32..38)
# ------------------------------------------------------------------------------
func _build_house_green_cottage() -> void:
	const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H
	var grid_offset: Vector2 = Vector2(0.0, -96.0)
	var h: Dictionary = _make_npc_house_base(
		"MarenCottage",
		&"maren_cottage",
		"Maren's Cottage",
		&"maren",
		grid_offset,
		grid_offset + Vector2(2.5 * 16.0, 6.2 * 16.0),
		Vector2(40.0, 14.0),
		Rect2(-4.0, -96.0, 88.0, 100.0)
	)
	var root: Node2D = h["root"] as Node2D
	var sh: TileMapLayer = h["shadows"] as TileMapLayer
	var bld: TileMapLayer = h["bld"] as TileMapLayer
	var d2: TileMapLayer = h["deco2"] as TileMapLayer
	var walls: StaticBody2D = h["walls"] as StaticBody2D
	var lights: Node2D = h["lights"] as Node2D

	# Shadows (Room1 y=38 -> local row 6)
	sh.set_cell(Vector2i(0, 6), 0, Vector2i(14, 1))
	sh.set_cell(Vector2i(1, 6), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(2, 6), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(3, 6), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(4, 6), 0, Vector2i(14, 1), FLIP_H)

	# Building (Room1 rows 33..37 -> local rows 1..5)
	bld.set_cell(Vector2i(0, 1), 0, Vector2i(28, 23), FLIP_H)
	bld.set_cell(Vector2i(1, 1), 0, Vector2i(27, 18), FLIP_H)
	bld.set_cell(Vector2i(2, 1), 0, Vector2i(18, 18))
	bld.set_cell(Vector2i(3, 1), 0, Vector2i(27, 18))
	bld.set_cell(Vector2i(4, 1), 0, Vector2i(28, 23))

	bld.set_cell(Vector2i(0, 2), 0, Vector2i(28, 19), FLIP_H)
	bld.set_cell(Vector2i(1, 2), 0, Vector2i(21, 19))
	bld.set_cell(Vector2i(2, 2), 0, Vector2i(18, 18))
	bld.set_cell(Vector2i(3, 2), 0, Vector2i(21, 19), FLIP_H)
	bld.set_cell(Vector2i(4, 2), 0, Vector2i(28, 19))

	bld.set_cell(Vector2i(0, 3), 0, Vector2i(28, 19), FLIP_H)
	bld.set_cell(Vector2i(1, 3), 0, Vector2i(27, 19), FLIP_H)
	bld.set_cell(Vector2i(2, 3), 0, Vector2i(18, 18))
	bld.set_cell(Vector2i(3, 3), 0, Vector2i(27, 19))
	bld.set_cell(Vector2i(4, 3), 0, Vector2i(28, 19))

	bld.set_cell(Vector2i(0, 4), 0, Vector2i(28, 20), FLIP_H)
	bld.set_cell(Vector2i(1, 4), 0, Vector2i(27, 20), FLIP_H)
	bld.set_cell(Vector2i(2, 4), 0, Vector2i(24, 21))
	bld.set_cell(Vector2i(3, 4), 0, Vector2i(27, 20))
	bld.set_cell(Vector2i(4, 4), 0, Vector2i(28, 20))

	bld.set_cell(Vector2i(0, 5), 0, Vector2i(28, 21), FLIP_H)
	bld.set_cell(Vector2i(1, 5), 0, Vector2i(33, 21))
	bld.set_cell(Vector2i(2, 5), 0, Vector2i(33, 21))
	bld.set_cell(Vector2i(3, 5), 0, Vector2i(33, 21))
	bld.set_cell(Vector2i(4, 5), 0, Vector2i(28, 21))

	# Decoration_02 (Verbatim pitched green dormer rows 0..3 + center front wooden door!)
	d2.set_cell(Vector2i(1, 0), 0, Vector2i(32, 17))
	d2.set_cell(Vector2i(2, 0), 0, Vector2i(33, 17))
	d2.set_cell(Vector2i(3, 0), 0, Vector2i(34, 17))
	d2.set_cell(Vector2i(1, 1), 0, Vector2i(32, 19))
	d2.set_cell(Vector2i(2, 1), 0, Vector2i(33, 19))
	d2.set_cell(Vector2i(3, 1), 0, Vector2i(34, 19))
	d2.set_cell(Vector2i(1, 2), 0, Vector2i(32, 20))
	d2.set_cell(Vector2i(2, 2), 0, Vector2i(33, 20))
	d2.set_cell(Vector2i(3, 2), 0, Vector2i(34, 20))
	d2.set_cell(Vector2i(1, 3), 0, Vector2i(32, 21))
	d2.set_cell(Vector2i(2, 3), 0, Vector2i(33, 21))
	d2.set_cell(Vector2i(3, 3), 0, Vector2i(34, 21))
	d2.set_cell(Vector2i(2, 5), 0, Vector2i(14, 12)) # Center front doorway

	# Subtle potted flowers flanking Maren's Botanist Cottage doorway
	var pot_l: Sprite2D = Sprite2D.new()
	pot_l.name = "DoorDaisies"
	pot_l.texture = _make_atlas_tex(53, 32, 1, 1)
	pot_l.centered = false
	pot_l.position = grid_offset + Vector2(0.0, 5.25 * 16.0)
	pot_l.z_index = 1
	root.add_child(pot_l)

	var pot_r: Sprite2D = Sprite2D.new()
	pot_r.name = "DoorSunflower"
	pot_r.texture = _make_atlas_tex(52, 31, 1, 2)
	pot_r.centered = false
	pot_r.position = grid_offset + Vector2(4.0 * 16.0, 4.25 * 16.0)
	pot_r.z_index = 1
	root.add_child(pot_r)

	_add_rect_collider(walls, grid_offset + Vector2(2.5 * 16.0, 3.6 * 16.0), Vector2(76.0, 74.0), "SolidHull")

	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(lights, grid_offset + Vector2(1.5 * 16.0, 5.5 * 16.0), Color(1.0, 0.80, 0.44, 1.0), warm_tex, 0.72, 0.0, "WinL")
	_add_point_light(lights, grid_offset + Vector2(3.5 * 16.0, 5.5 * 16.0), Color(1.0, 0.80, 0.44, 1.0), warm_tex, 0.72, 0.0, "WinR")
	_add_point_light(lights, grid_offset + Vector2(2.5 * 16.0, 5.8 * 16.0), Color(1.0, 0.74, 0.38, 1.0), warm_tex, 1.05, 0.0, "PorchLight")

	_save_prefab(root, "res://scenes/props/house_green_cottage.tscn")


# ------------------------------------------------------------------------------
# 15. ORANGE-ROOFED FORGE HOUSE — KAELEN'S BLACKSMITH HOME (Verbatim Room1.yy cols 54..59, rows 24..29)
# ------------------------------------------------------------------------------
func _build_house_orange_forge() -> void:
	const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H
	var grid_offset: Vector2 = Vector2(0.0, -80.0)
	var h: Dictionary = _make_npc_house_base(
		"KaelenForgeHouse",
		&"kaelen_forge",
		"Kaelen's Forge",
		&"kaelen",
		grid_offset,
		grid_offset + Vector2(1.5 * 16.0, 5.2 * 16.0),
		Vector2(24.0, 14.0),
		Rect2(-4.0, -80.0, 104.0, 84.0)
	)
	var root: Node2D = h["root"] as Node2D
	var sh: TileMapLayer = h["shadows"] as TileMapLayer
	var bld: TileMapLayer = h["bld"] as TileMapLayer
	var d2: TileMapLayer = h["deco2"] as TileMapLayer
	var walls: StaticBody2D = h["walls"] as StaticBody2D
	var lights: Node2D = h["lights"] as Node2D

	# Ground shadows under L-shaped base (right wing row 4, left wing row 5)
	sh.set_cell(Vector2i(3, 4), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(4, 4), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(5, 4), 0, Vector2i(14, 1), FLIP_H)
	sh.set_cell(Vector2i(0, 5), 0, Vector2i(14, 1))
	sh.set_cell(Vector2i(1, 5), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(2, 5), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(3, 5), 0, Vector2i(14, 1), FLIP_H)

	# Building (Room1 rows 24..28 -> local rows 0..4)
	bld.set_cell(Vector2i(0, 0), 0, Vector2i(15, 25))
	bld.set_cell(Vector2i(1, 0), 0, Vector2i(16, 25))
	bld.set_cell(Vector2i(2, 0), 0, Vector2i(16, 25))
	bld.set_cell(Vector2i(3, 0), 0, Vector2i(16, 25))
	bld.set_cell(Vector2i(4, 0), 0, Vector2i(16, 25))
	bld.set_cell(Vector2i(5, 0), 0, Vector2i(17, 25))

	bld.set_cell(Vector2i(0, 1), 0, Vector2i(17, 26), FLIP_H)
	bld.set_cell(Vector2i(1, 1), 0, Vector2i(18, 26))
	bld.set_cell(Vector2i(2, 1), 0, Vector2i(18, 26))
	bld.set_cell(Vector2i(3, 1), 0, Vector2i(18, 26))
	bld.set_cell(Vector2i(4, 1), 0, Vector2i(18, 26))
	bld.set_cell(Vector2i(5, 1), 0, Vector2i(17, 26))

	bld.set_cell(Vector2i(0, 2), 0, Vector2i(15, 28))
	bld.set_cell(Vector2i(1, 2), 0, Vector2i(16, 28))
	bld.set_cell(Vector2i(2, 2), 0, Vector2i(16, 28))
	bld.set_cell(Vector2i(3, 2), 0, Vector2i(16, 28))
	bld.set_cell(Vector2i(4, 2), 0, Vector2i(20, 26))
	bld.set_cell(Vector2i(5, 2), 0, Vector2i(17, 28))

	bld.set_cell(Vector2i(0, 3), 0, Vector2i(15, 28))
	bld.set_cell(Vector2i(1, 3), 0, Vector2i(16, 28))
	bld.set_cell(Vector2i(2, 3), 0, Vector2i(16, 28))
	bld.set_cell(Vector2i(3, 3), 0, Vector2i(16, 29))
	bld.set_cell(Vector2i(4, 3), 0, Vector2i(16, 30))
	bld.set_cell(Vector2i(5, 3), 0, Vector2i(17, 29))

	bld.set_cell(Vector2i(0, 4), 0, Vector2i(15, 29))
	bld.set_cell(Vector2i(1, 4), 0, Vector2i(16, 31))
	bld.set_cell(Vector2i(2, 4), 0, Vector2i(16, 30))
	bld.set_cell(Vector2i(3, 4), 0, Vector2i(17, 29))

	# Decoration_02 (Verbatim Stone Chimney (1,2), gable seam trim (3,2..3), wooden front door (1,4))
	d2.set_cell(Vector2i(1, 2), 0, Vector2i(29, 5))
	d2.set_cell(Vector2i(3, 2), 0, Vector2i(17, 28))
	d2.set_cell(Vector2i(3, 3), 0, Vector2i(17, 28))
	d2.set_cell(Vector2i(1, 4), 0, Vector2i(36, 27))

	_add_chimney_smoke(root, grid_offset + Vector2(1.0 * 16.0 + 8.0, 2.0 * 16.0 + 2.0))

	# L-shaped solid colliders matching left & right wings cleanly
	_add_rect_collider(walls, grid_offset + Vector2(2.0 * 16.0, 2.8 * 16.0), Vector2(60.0, 68.0), "SolidLeftWing")
	_add_rect_collider(walls, grid_offset + Vector2(4.5 * 16.0, 2.2 * 16.0), Vector2(44.0, 56.0), "SolidRightWing")

	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(lights, grid_offset + Vector2(2.5 * 16.0, 4.5 * 16.0), Color(1.0, 0.68, 0.32, 1.0), warm_tex, 0.85, 0.0, "WinL")
	_add_point_light(lights, grid_offset + Vector2(4.5 * 16.0, 3.6 * 16.0), Color(1.0, 0.68, 0.32, 1.0), warm_tex, 0.80, 0.0, "WinR")
	_add_point_light(lights, grid_offset + Vector2(1.5 * 16.0, 4.8 * 16.0), Color(1.0, 0.66, 0.30, 1.0), warm_tex, 1.10, 0.0, "PorchLight")

	_save_prefab(root, "res://scenes/props/house_orange_forge.tscn")


# ------------------------------------------------------------------------------
# 16. PURPLE-ROOFED VILLAGE MANOR / HALL — MAYOR ALDRIC (Verbatim Room1.yy cols 13..18, rows 26..32)
# ------------------------------------------------------------------------------
func _build_house_purple_manor() -> void:
	const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H
	var grid_offset: Vector2 = Vector2(0.0, -96.0)
	var h: Dictionary = _make_npc_house_base(
		"AldricVillageHall",
		&"aldric_hall",
		"Village Hall",
		&"aldric",
		grid_offset,
		grid_offset + Vector2(3.5 * 16.0, 6.2 * 16.0),
		Vector2(56.0, 14.0),
		Rect2(-4.0, -96.0, 104.0, 100.0)
	)
	var root: Node2D = h["root"] as Node2D
	var sh: TileMapLayer = h["shadows"] as TileMapLayer
	var bld: TileMapLayer = h["bld"] as TileMapLayer
	var d2: TileMapLayer = h["deco2"] as TileMapLayer
	var walls: StaticBody2D = h["walls"] as StaticBody2D
	var lights: Node2D = h["lights"] as Node2D

	# Ground shadows (Room1 rows 31..32 -> local rows 5..6)
	sh.set_cell(Vector2i(0, 5), 0, Vector2i(14, 1))
	sh.set_cell(Vector2i(1, 5), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(4, 5), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(5, 5), 0, Vector2i(14, 1), FLIP_H)
	sh.set_cell(Vector2i(1, 6), 0, Vector2i(14, 1))
	sh.set_cell(Vector2i(2, 6), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(3, 6), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(4, 6), 0, Vector2i(14, 1), FLIP_H)

	# Building (Room1 rows 26..31 -> local rows 0..5)
	bld.set_cell(Vector2i(0, 0), 0, Vector2i(15, 41))
	bld.set_cell(Vector2i(1, 0), 0, Vector2i(16, 41))
	bld.set_cell(Vector2i(2, 0), 0, Vector2i(16, 41))
	bld.set_cell(Vector2i(3, 0), 0, Vector2i(16, 41))
	bld.set_cell(Vector2i(4, 0), 0, Vector2i(16, 41), FLIP_H)
	bld.set_cell(Vector2i(5, 0), 0, Vector2i(15, 41), FLIP_H)

	bld.set_cell(Vector2i(0, 1), 0, Vector2i(15, 43))
	bld.set_cell(Vector2i(1, 1), 0, Vector2i(18, 42))
	bld.set_cell(Vector2i(2, 1), 0, Vector2i(18, 42))
	bld.set_cell(Vector2i(3, 1), 0, Vector2i(18, 42))
	bld.set_cell(Vector2i(4, 1), 0, Vector2i(18, 42))
	bld.set_cell(Vector2i(5, 1), 0, Vector2i(17, 42))

	bld.set_cell(Vector2i(0, 2), 0, Vector2i(17, 44), FLIP_H)
	bld.set_cell(Vector2i(1, 2), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(2, 2), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(3, 2), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(4, 2), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(5, 2), 0, Vector2i(17, 44))

	bld.set_cell(Vector2i(0, 3), 0, Vector2i(15, 44))
	bld.set_cell(Vector2i(1, 3), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(2, 3), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(3, 3), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(4, 3), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(5, 3), 0, Vector2i(15, 44), FLIP_H)

	bld.set_cell(Vector2i(0, 4), 0, Vector2i(15, 45))
	bld.set_cell(Vector2i(1, 4), 0, Vector2i(16, 45))
	bld.set_cell(Vector2i(2, 4), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(3, 4), 0, Vector2i(16, 44))
	bld.set_cell(Vector2i(4, 4), 0, Vector2i(16, 45))
	bld.set_cell(Vector2i(5, 4), 0, Vector2i(15, 45), FLIP_H)

	bld.set_cell(Vector2i(1, 5), 0, Vector2i(6, 10))
	bld.set_cell(Vector2i(2, 5), 0, Vector2i(16, 46))
	bld.set_cell(Vector2i(3, 5), 0, Vector2i(16, 47))
	bld.set_cell(Vector2i(4, 5), 0, Vector2i(7, 10))

	# Decoration_02 (Verbatim Twin Purple Dormers + Portico Roof & Front Door!)
	d2.set_cell(Vector2i(1, 0), 0, Vector2i(29, 41))
	d2.set_cell(Vector2i(2, 0), 0, Vector2i(30, 41))
	d2.set_cell(Vector2i(3, 0), 0, Vector2i(30, 41))
	d2.set_cell(Vector2i(4, 0), 0, Vector2i(31, 41))
	d2.set_cell(Vector2i(1, 1), 0, Vector2i(29, 42))
	d2.set_cell(Vector2i(2, 1), 0, Vector2i(30, 42))
	d2.set_cell(Vector2i(3, 1), 0, Vector2i(30, 42))
	d2.set_cell(Vector2i(4, 1), 0, Vector2i(31, 42))
	d2.set_cell(Vector2i(1, 2), 0, Vector2i(29, 45))
	d2.set_cell(Vector2i(2, 2), 0, Vector2i(30, 45))
	d2.set_cell(Vector2i(3, 2), 0, Vector2i(30, 45))
	d2.set_cell(Vector2i(4, 2), 0, Vector2i(31, 45))
	d2.set_cell(Vector2i(2, 3), 0, Vector2i(1, 12))
	d2.set_cell(Vector2i(1, 4), 0, Vector2i(17, 44), FLIP_H)
	d2.set_cell(Vector2i(2, 4), 0, Vector2i(1, 12))
	d2.set_cell(Vector2i(4, 4), 0, Vector2i(17, 44))
	d2.set_cell(Vector2i(1, 5), 0, Vector2i(17, 45), FLIP_H)
	d2.set_cell(Vector2i(3, 5), 0, Vector2i(36, 27))
	d2.set_cell(Vector2i(4, 5), 0, Vector2i(17, 45))

	_add_rect_collider(walls, grid_offset + Vector2(3.0 * 16.0, 2.75 * 16.0), Vector2(92.0, 72.0), "SolidMainHall")
	_add_rect_collider(walls, grid_offset + Vector2(3.0 * 16.0, 5.4 * 16.0), Vector2(56.0, 18.0), "SolidPortico")

	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(lights, grid_offset + Vector2(2.3 * 16.0, 2.3 * 16.0), Color(1.0, 0.80, 0.45, 1.0), warm_tex, 0.72, 0.0, "DormerL")
	_add_point_light(lights, grid_offset + Vector2(3.7 * 16.0, 2.3 * 16.0), Color(1.0, 0.80, 0.45, 1.0), warm_tex, 0.72, 0.0, "DormerR")
	_add_point_light(lights, grid_offset + Vector2(2.5 * 16.0, 5.5 * 16.0), Color(1.0, 0.78, 0.42, 1.0), warm_tex, 0.85, 0.0, "HallWin")
	_add_point_light(lights, grid_offset + Vector2(3.5 * 16.0, 5.8 * 16.0), Color(1.0, 0.74, 0.38, 1.0), warm_tex, 1.15, 0.0, "PorchLight")

	_save_prefab(root, "res://scenes/props/house_purple_manor.tscn")


# ------------------------------------------------------------------------------
# 17. RED-ROOFED COASTAL CABIN — BRAM'S FISHERMAN CABIN (Verbatim Room1.yy cols 32..36, rows 19..24)
# ------------------------------------------------------------------------------
func _build_house_red_cabin() -> void:
	const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H
	var grid_offset: Vector2 = Vector2(0.0, -80.0)
	var h: Dictionary = _make_npc_house_base(
		"BramCoastalCabin",
		&"bram_cabin",
		"Bram's Cabin",
		&"bram",
		grid_offset,
		grid_offset + Vector2(1.5 * 16.0, 5.2 * 16.0),
		Vector2(24.0, 14.0),
		Rect2(-4.0, -80.0, 88.0, 84.0)
	)
	var root: Node2D = h["root"] as Node2D
	var sh: TileMapLayer = h["shadows"] as TileMapLayer
	var bld: TileMapLayer = h["bld"] as TileMapLayer
	var d2: TileMapLayer = h["deco2"] as TileMapLayer
	var walls: StaticBody2D = h["walls"] as StaticBody2D
	var lights: Node2D = h["lights"] as Node2D

	# Shadows (Room1 y=24 -> local row 5)
	sh.set_cell(Vector2i(0, 5), 0, Vector2i(14, 1))
	sh.set_cell(Vector2i(1, 5), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(2, 5), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(3, 5), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(4, 5), 0, Vector2i(14, 1), FLIP_H)

	# Building (Room1 rows 19..23 -> local rows 0..4)
	bld.set_cell(Vector2i(0, 0), 0, Vector2i(17, 33), FLIP_H)
	bld.set_cell(Vector2i(1, 0), 0, Vector2i(16, 33))
	bld.set_cell(Vector2i(2, 0), 0, Vector2i(16, 33))
	bld.set_cell(Vector2i(3, 0), 0, Vector2i(16, 33))
	bld.set_cell(Vector2i(4, 0), 0, Vector2i(17, 33))

	bld.set_cell(Vector2i(0, 1), 0, Vector2i(15, 36))
	bld.set_cell(Vector2i(1, 1), 0, Vector2i(16, 36))
	bld.set_cell(Vector2i(2, 1), 0, Vector2i(20, 34))
	bld.set_cell(Vector2i(3, 1), 0, Vector2i(16, 36))
	bld.set_cell(Vector2i(4, 1), 0, Vector2i(17, 36))

	bld.set_cell(Vector2i(0, 2), 0, Vector2i(15, 36))
	bld.set_cell(Vector2i(1, 2), 0, Vector2i(16, 36))
	bld.set_cell(Vector2i(2, 2), 0, Vector2i(16, 36))
	bld.set_cell(Vector2i(3, 2), 0, Vector2i(16, 36))
	bld.set_cell(Vector2i(4, 2), 0, Vector2i(17, 36))

	bld.set_cell(Vector2i(0, 3), 0, Vector2i(15, 37))
	bld.set_cell(Vector2i(1, 3), 0, Vector2i(16, 38))
	bld.set_cell(Vector2i(2, 3), 0, Vector2i(16, 38))
	bld.set_cell(Vector2i(3, 3), 0, Vector2i(16, 38))
	bld.set_cell(Vector2i(4, 3), 0, Vector2i(17, 37))

	bld.set_cell(Vector2i(0, 4), 0, Vector2i(15, 38))
	bld.set_cell(Vector2i(1, 4), 0, Vector2i(12, 12))
	bld.set_cell(Vector2i(2, 4), 0, Vector2i(33, 37))
	bld.set_cell(Vector2i(3, 4), 0, Vector2i(33, 37))
	bld.set_cell(Vector2i(4, 4), 0, Vector2i(15, 38), FLIP_H)

	# Decoration_02 (Verbatim Stone Chimney (1,0), wooden upper shutters (1..3,3), front door (1,4))
	d2.set_cell(Vector2i(1, 0), 0, Vector2i(29, 5))
	d2.set_cell(Vector2i(1, 3), 0, Vector2i(14, 12))
	d2.set_cell(Vector2i(2, 3), 0, Vector2i(14, 12))
	d2.set_cell(Vector2i(3, 3), 0, Vector2i(14, 12))
	d2.set_cell(Vector2i(4, 3), 0, Vector2i(8, 13))
	d2.set_cell(Vector2i(1, 4), 0, Vector2i(36, 27))
	d2.set_cell(Vector2i(2, 4), 0, Vector2i(8, 13))
	d2.set_cell(Vector2i(4, 4), 0, Vector2i(8, 13))

	_add_chimney_smoke(root, grid_offset + Vector2(1.0 * 16.0 + 8.0, 0.0 * 16.0 + 2.0))

	# Coastal barrels beside Bram's Red Cabin
	var b1: Sprite2D = Sprite2D.new()
	b1.name = "CoastalWaterBarrel"
	b1.texture = _make_atlas_tex(38, 16, 1, 1)
	b1.centered = false
	b1.position = grid_offset + Vector2(5.0 * 16.0 - 2.0, 4.1 * 16.0)
	root.add_child(b1)

	var b2: Sprite2D = Sprite2D.new()
	b2.name = "CoastalClosedBarrel"
	b2.texture = _make_atlas_tex(39, 16, 1, 1)
	b2.centered = false
	b2.position = grid_offset + Vector2(-1.0 * 16.0 + 2.0, 4.1 * 16.0)
	root.add_child(b2)

	_add_rect_collider(walls, grid_offset + Vector2(2.5 * 16.0, 2.8 * 16.0), Vector2(78.0, 68.0), "SolidHull")
	_add_rect_collider(walls, grid_offset + Vector2(5.4 * 16.0, 4.75 * 16.0), Vector2(10.0, 8.0), "RightBarrelCol")
	_add_rect_collider(walls, grid_offset + Vector2(-0.4 * 16.0, 4.75 * 16.0), Vector2(10.0, 8.0), "LeftBarrelCol")

	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(lights, grid_offset + Vector2(2.5 * 16.0, 4.5 * 16.0), Color(1.0, 0.78, 0.44, 1.0), warm_tex, 0.75, 0.0, "Win1")
	_add_point_light(lights, grid_offset + Vector2(3.5 * 16.0, 4.5 * 16.0), Color(1.0, 0.78, 0.44, 1.0), warm_tex, 0.75, 0.0, "Win2")
	_add_point_light(lights, grid_offset + Vector2(1.5 * 16.0, 4.8 * 16.0), Color(1.0, 0.74, 0.38, 1.0), warm_tex, 1.05, 0.0, "PorchLight")

	_save_prefab(root, "res://scenes/props/house_red_cabin.tscn")


# ------------------------------------------------------------------------------
# 18. TIMBER WOODLAND CABIN — LYRA'S CABIN (Verbatim Room1.yy cols 55..60, rows 31..35)
# ------------------------------------------------------------------------------
func _build_house_timber_cabin() -> void:
	const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H
	const FLIP_HV: int = TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
	var grid_offset: Vector2 = Vector2(0.0, -64.0)
	var h: Dictionary = _make_npc_house_base(
		"LyraWoodlandCabin",
		&"lyra_cabin",
		"Lyra's Cabin",
		&"lyra",
		grid_offset,
		grid_offset + Vector2(2.0 * 16.0, 4.2 * 16.0),
		Vector2(32.0, 14.0),
		Rect2(-4.0, -64.0, 104.0, 68.0)
	)
	var root: Node2D = h["root"] as Node2D
	var sh: TileMapLayer = h["shadows"] as TileMapLayer
	var bld: TileMapLayer = h["bld"] as TileMapLayer
	var d2: TileMapLayer = h["deco2"] as TileMapLayer
	var walls: StaticBody2D = h["walls"] as StaticBody2D
	var lights: Node2D = h["lights"] as Node2D

	# Shadows (Room1 y=35 -> local row 4)
	sh.set_cell(Vector2i(0, 4), 0, Vector2i(14, 1))
	sh.set_cell(Vector2i(1, 4), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(2, 4), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(3, 4), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(4, 4), 0, Vector2i(12, 1))
	sh.set_cell(Vector2i(5, 4), 0, Vector2i(14, 1), FLIP_H)

	# Building (Room1 rows 31..34 -> local rows 0..3)
	bld.set_cell(Vector2i(1, 0), 0, Vector2i(26, 30), FLIP_H)
	bld.set_cell(Vector2i(2, 0), 0, Vector2i(26, 26))
	bld.set_cell(Vector2i(3, 0), 0, Vector2i(27, 26))
	bld.set_cell(Vector2i(4, 0), 0, Vector2i(26, 30))

	bld.set_cell(Vector2i(0, 1), 0, Vector2i(28, 26), FLIP_H)
	bld.set_cell(Vector2i(1, 1), 0, Vector2i(26, 31), FLIP_H)
	bld.set_cell(Vector2i(2, 1), 0, Vector2i(24, 25))
	bld.set_cell(Vector2i(3, 1), 0, Vector2i(25, 25))
	bld.set_cell(Vector2i(4, 1), 0, Vector2i(26, 31))
	bld.set_cell(Vector2i(5, 1), 0, Vector2i(28, 26))

	bld.set_cell(Vector2i(0, 2), 0, Vector2i(20, 28))
	bld.set_cell(Vector2i(1, 2), 0, Vector2i(21, 28))
	bld.set_cell(Vector2i(2, 2), 0, Vector2i(22, 28))
	bld.set_cell(Vector2i(3, 2), 0, Vector2i(22, 28), FLIP_H)
	bld.set_cell(Vector2i(4, 2), 0, Vector2i(21, 28), FLIP_H)
	bld.set_cell(Vector2i(5, 2), 0, Vector2i(20, 28), FLIP_H)

	bld.set_cell(Vector2i(0, 3), 0, Vector2i(20, 29))
	bld.set_cell(Vector2i(1, 3), 0, Vector2i(33, 29))
	bld.set_cell(Vector2i(2, 3), 0, Vector2i(33, 29))
	bld.set_cell(Vector2i(3, 3), 0, Vector2i(33, 29))
	bld.set_cell(Vector2i(4, 3), 0, Vector2i(33, 29))
	bld.set_cell(Vector2i(5, 3), 0, Vector2i(20, 29), FLIP_H)

	# Decoration_02 (Verbatim Stone Chimney (4,1) + double rustic wooden doors (1..2,3))
	d2.set_cell(Vector2i(4, 1), 0, Vector2i(28, 5), FLIP_H)
	d2.set_cell(Vector2i(1, 3), 0, Vector2i(14, 12), FLIP_HV)
	d2.set_cell(Vector2i(2, 3), 0, Vector2i(14, 12), FLIP_HV)

	_add_chimney_smoke(root, grid_offset + Vector2(4.0 * 16.0 + 7.0, 1.0 * 16.0 + 3.0))

	_add_rect_collider(walls, grid_offset + Vector2(3.0 * 16.0, 2.3 * 16.0), Vector2(92.0, 52.0), "SolidHull")

	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(lights, grid_offset + Vector2(3.5 * 16.0, 3.5 * 16.0), Color(1.0, 0.78, 0.44, 1.0), warm_tex, 0.75, 0.0, "Win1")
	_add_point_light(lights, grid_offset + Vector2(4.5 * 16.0, 3.5 * 16.0), Color(1.0, 0.78, 0.44, 1.0), warm_tex, 0.75, 0.0, "Win2")
	_add_point_light(lights, grid_offset + Vector2(2.0 * 16.0, 3.8 * 16.0), Color(1.0, 0.74, 0.38, 1.0), warm_tex, 1.05, 0.0, "PorchLight")

	_save_prefab(root, "res://scenes/props/house_timber_cabin.tscn")


# ------------------------------------------------------------------------------
# 19. WALKABLE WOODEN OCEAN FISHING PIER (Verbatim Room1.yy SouthDock/EastDock (38,4..6) stamp!)
# ------------------------------------------------------------------------------
func _build_fishing_pier() -> void:
	var root: Node2D = Node2D.new()
	root.name = "FishingPier"

	# Contiguous 3-row verbatim Room1.yy wooden pier stamp:
	# - Row 0 (y=-32..-17, world anchor.y-2): (38, 4) top mooring posts attached flush to top edge of deck
	# - Row 1 (y=-16..-1,  world anchor.y-1): (38, 5) solid connected vertical wooden deck planks
	# - Row 2 (y=0..+15,   world anchor.y):   (38, 6) bottom deck beam + pilings tucked 100% flush under deck!
	var deck_layer: TileMapLayer = TileMapLayer.new()
	deck_layer.name = "PierDeck"
	deck_layer.tile_set = _tileset
	deck_layer.position = Vector2(0.0, -32.0)
	deck_layer.z_index = -6
	root.add_child(deck_layer)

	for x: int in range(6):
		if x in [0, 2, 4, 5]:
			deck_layer.set_cell(Vector2i(x, 0), 0, Vector2i(38, 4))
		deck_layer.set_cell(Vector2i(x, 1), 0, Vector2i(38, 5))
		deck_layer.set_cell(Vector2i(x, 2), 0, Vector2i(38, 6))

	_save_prefab(root, "res://scenes/props/fishing_pier.tscn")


# ------------------------------------------------------------------------------
# 20. KAELEN'S BLACKSMITH FORGE APRON (Grounded on Organic Dirt/Stone Courtyard — Zero Hard Grey Box!)
# ------------------------------------------------------------------------------
func _build_kaelen_forge_apron() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "KaelenForgeApron"
	root.script = _world_interactable_script
	root.collision_layer = 1
	root.collision_mask = 0
	root.set("interactable_id", &"kaelen_forge_apron")
	root.set("action_kind", WorldInteractable.ActionKind.OPEN_SHOP_FORGE)
	root.set("prompt_text", "[E] Forge (Kaelen's Upgrades)")

	# Stone Blacksmith Furnace (39..40, 17..18) with roaring animated forge flame!
	var furnace_spr: Sprite2D = Sprite2D.new()
	furnace_spr.name = "BlacksmithFurnace"
	furnace_spr.texture = _make_atlas_tex(39, 17, 2, 2)
	furnace_spr.position = Vector2(-14.0, -12.0)
	root.add_child(furnace_spr)

	var flame: Sprite2D = Sprite2D.new()
	flame.name = "ForgeFlame"
	flame.script = _strip_sprite_script
	flame.texture = load(AP.FIRE_02_STRIP4) as Texture2D
	flame.hframes = 4
	flame.vframes = 1
	flame.scale = Vector2(0.75, 0.75)
	flame.position = Vector2(-14.0, -4.0)
	flame.set("frame_rate", 8.0)
	root.add_child(flame)

	# Blue Water Quench Trough (37..38, 17)
	var trough: Sprite2D = Sprite2D.new()
	trough.name = "QuenchTrough"
	trough.texture = _make_atlas_tex(37, 17, 2, 1)
	trough.position = Vector2(14.0, -10.0)
	root.add_child(trough)

	# Heavy Iron Anvil (37..38, 18) centered on the warm forge hearth
	var anvil: Sprite2D = Sprite2D.new()
	anvil.name = "BlacksmithAnvil"
	anvil.texture = _make_atlas_tex(37, 18, 2, 1)
	anvil.position = Vector2(4.0, 4.0)
	root.add_child(anvil)

	# Weapon barrel (41,16), quench water barrel (38,16), ore crate (39,10), and firewood pile (40,30)
	var weapon_barrel: Sprite2D = Sprite2D.new()
	weapon_barrel.name = "ForgeWeaponBarrel"
	weapon_barrel.texture = _make_atlas_tex(41, 16, 1, 1)
	weapon_barrel.position = Vector2(24.0, -4.0)
	root.add_child(weapon_barrel)

	var barrel: Sprite2D = Sprite2D.new()
	barrel.name = "ForgeWaterBarrel"
	barrel.texture = _make_atlas_tex(38, 16, 1, 1)
	barrel.position = Vector2(26.0, 8.0)
	root.add_child(barrel)

	var logs: Sprite2D = Sprite2D.new()
	logs.name = "ForgeFirewood"
	logs.texture = _make_atlas_tex(40, 30, 1, 1)
	logs.position = Vector2(-28.0, 4.0)
	root.add_child(logs)

	_add_rect_collider(root, Vector2(0.0, 0.0), Vector2(48.0, 18.0), "ForgeApronCollider")

	var interact_area: Area2D = Area2D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 8
	interact_area.collision_mask = 4
	root.add_child(interact_area)
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "InteractShape"
	cs.position = Vector2(2.0, 12.0)
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(70.0, 34.0)
	cs.shape = rect
	interact_area.add_child(cs)

	var lights_root: Node2D = Node2D.new()
	lights_root.name = "NightLights"
	root.add_child(lights_root)
	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(lights_root, Vector2(-14.0, -4.0), Color(1.0, 0.56, 0.20, 1.0), warm_tex, 1.3, 0.0, "ForgeGlow")

	_save_prefab(root, "res://scenes/props/kaelen_forge_apron.tscn")


# ------------------------------------------------------------------------------
# 21. VILLAGE COMMUNITY BOARD (Clean Single Wooden 2-Post Notice Board — Zero Double-Stacking!)
# ------------------------------------------------------------------------------
func _build_community_board() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "CommunityBoard"
	root.script = _world_interactable_script
	root.collision_layer = 1
	root.collision_mask = 0
	root.set("interactable_id", &"community_board")
	root.set("action_kind", WorldInteractable.ActionKind.TOAST_HOOK)
	root.set("prompt_text", "[E] Community Board")
	root.set("toast_message", "Community Board — Village Quests arrive in Phase 5!")

	# Clean single 2-post wooden notice board (47, 13) + side flower box (53, 32)
	var board_spr: Sprite2D = Sprite2D.new()
	board_spr.name = "BoardSprite"
	board_spr.texture = _make_atlas_tex(47, 13, 1, 1)
	board_spr.position = Vector2(0.0, -6.0)
	root.add_child(board_spr)

	var pot_l: Sprite2D = Sprite2D.new()
	pot_l.name = "BoardFlowers"
	pot_l.texture = _make_atlas_tex(53, 32, 1, 1)
	pot_l.position = Vector2(-13.0, -2.0)
	root.add_child(pot_l)

	_add_rect_collider(root, Vector2(-3.0, -1.0), Vector2(18.0, 7.0), "BoardCollider")

	var interact_area: Area2D = Area2D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 8
	interact_area.collision_mask = 4
	root.add_child(interact_area)
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "InteractShape"
	cs.position = Vector2(0.0, 8.0)
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(44.0, 32.0)
	cs.shape = rect
	interact_area.add_child(cs)

	_save_prefab(root, "res://scenes/props/community_board.tscn")


# ------------------------------------------------------------------------------
# 22. CLIFFSIDE MINE ENTRANCE ARCH (Embedded Directly Into Quarry Cliff Wall!)
# ------------------------------------------------------------------------------
func _build_mine_entrance() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "MineEntrance"
	root.script = _world_interactable_script
	root.collision_layer = 1
	root.collision_mask = 0
	root.set("interactable_id", &"mine_entrance")
	root.set("action_kind", WorldInteractable.ActionKind.TOAST_HOOK)
	root.set("prompt_text", "[E] Pebblefern Mine")
	root.set("toast_message", "Pebblefern Mine — Opens in Phase 6!")

	# Verbatim Room1.yy dark recessed cliff cave archway (11,2) + mirrored (11,2) framed by stone timber supports!
	var arch_l: Sprite2D = Sprite2D.new()
	arch_l.name = "CaveArchLeft"
	arch_l.texture = _make_atlas_tex(11, 2, 1, 1)
	arch_l.position = Vector2(-8.0, -8.0)
	root.add_child(arch_l)

	var arch_r: Sprite2D = Sprite2D.new()
	arch_r.name = "CaveArchRight"
	arch_r.texture = _make_atlas_tex(11, 2, 1, 1)
	arch_r.flip_h = true
	arch_r.position = Vector2(8.0, -8.0)
	root.add_child(arch_r)

	var pillar_l: Sprite2D = Sprite2D.new()
	pillar_l.name = "StonePillarLeft"
	pillar_l.texture = _make_atlas_tex(44, 2, 1, 2)
	pillar_l.position = Vector2(-22.0, -10.0)
	root.add_child(pillar_l)

	var pillar_r: Sprite2D = Sprite2D.new()
	pillar_r.name = "StonePillarRight"
	pillar_r.texture = _make_atlas_tex(44, 2, 1, 2)
	pillar_r.position = Vector2(22.0, -10.0)
	root.add_child(pillar_r)

	# Full 2-tile wooden minecart (44, 6..7) parked on outgoing spur + ore crates & timber logs
	var cart: Sprite2D = Sprite2D.new()
	cart.name = "MineCart"
	cart.texture = _make_atlas_tex(44, 6, 1, 2)
	cart.position = Vector2(26.0, 4.0)
	root.add_child(cart)

	var crate: Sprite2D = Sprite2D.new()
	crate.name = "MineCrate"
	crate.texture = _make_atlas_tex(39, 9, 1, 2)
	crate.position = Vector2(-28.0, 4.0)
	root.add_child(crate)

	var sacks: Sprite2D = Sprite2D.new()
	sacks.name = "OreSacks"
	sacks.texture = _make_atlas_tex(52, 19, 1, 2)
	sacks.position = Vector2(-42.0, 8.0)
	root.add_child(sacks)

	# Flickering mine lantern flame perched atop left timber support
	var mine_flame: Sprite2D = Sprite2D.new()
	mine_flame.name = "MineLanternFlame"
	mine_flame.script = _strip_sprite_script
	mine_flame.texture = load(AP.FIRE_01_STRIP4) as Texture2D
	mine_flame.hframes = 4
	mine_flame.vframes = 1
	mine_flame.scale = Vector2(0.85, 0.85)
	mine_flame.position = Vector2(-22.0, -24.0)
	mine_flame.set("frame_rate", 8.0)
	root.add_child(mine_flame)

	_add_rect_collider(root, Vector2(0.0, -8.0), Vector2(56.0, 20.0), "MineArchCollider")
	_add_rect_collider(root, Vector2(26.0, 10.0), Vector2(14.0, 12.0), "MineCartCollider")
	_add_rect_collider(root, Vector2(-28.0, 10.0), Vector2(14.0, 12.0), "MineCrateCollider")

	var interact_area: Area2D = Area2D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 8
	interact_area.collision_mask = 4
	root.add_child(interact_area)
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "InteractShape"
	cs.position = Vector2(0.0, 10.0)
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(44.0, 24.0)
	cs.shape = rect
	interact_area.add_child(cs)

	var lights_root: Node2D = Node2D.new()
	lights_root.name = "NightLights"
	root.add_child(lights_root)
	var warm_tex: GradientTexture2D = _make_warm_light_tex(128)
	_add_point_light(lights_root, Vector2(-22.0, -20.0), Color(1.0, 0.72, 0.34, 1.0), warm_tex, 1.25, 0.0, "MineTorchLight")

	_save_prefab(root, "res://scenes/props/mine_entrance.tscn")


# ------------------------------------------------------------------------------
# 23. VILLAGE STONE WELL (Bramblebrook Plaza Landmark)
# ------------------------------------------------------------------------------
func _build_village_well() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "VillageWell"
	root.collision_layer = 1
	root.collision_mask = 0

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "WellSprite"
	spr.texture = _make_atlas_tex(40, 19, 2, 2)
	spr.offset = Vector2(0.0, -10.0)
	root.add_child(spr)

	_add_rect_collider(root, Vector2(0.0, -1.0), Vector2(20.0, 10.0), "WellCollider")
	_save_prefab(root, "res://scenes/props/village_well.tscn")


# ------------------------------------------------------------------------------
# 24. VERBATIM ROOM1.YY HORIZONTAL OCEAN CHANNEL BRIDGE WITH SUPPORT PILINGS (7x3 walkable deck)
# ------------------------------------------------------------------------------
func _build_ocean_channel_bridge() -> void:
	var root: Node2D = Node2D.new()
	root.name = "OceanChannelBridge"

	const FLIP_H: int = TileSetAtlasSource.TRANSFORM_FLIP_H
	# Iconic Room1.yy wooden cross-braced support pilings shifted up (-16px) so their tops tuck
	# directly flush underneath the bottom edge of the bridge deck (ZERO water gap!)
	var pilings_layer: TileMapLayer = TileMapLayer.new()
	pilings_layer.name = "BridgePilings"
	pilings_layer.tile_set = _tileset
	pilings_layer.position = Vector2(-8.0, -16.0)
	pilings_layer.z_index = -6
	root.add_child(pilings_layer)
	for px: int in [-1, 1]:
		pilings_layer.set_cell(Vector2i(px, 2), 0, Vector2i(37, 5))
		pilings_layer.set_cell(Vector2i(px, 3), 0, Vector2i(37, 2))

	var deck_layer: TileMapLayer = TileMapLayer.new()
	deck_layer.name = "BridgeDeck"
	deck_layer.tile_set = _tileset
	deck_layer.position = Vector2(-8.0, -8.0)
	deck_layer.z_index = -5
	root.add_child(deck_layer)

	# 7-tile-wide plank deck (-3..+3) x 3 rows (-1..+1) matching Room1.yy west ocean bridge!
	for bx: int in range(-3, 4):
		var tx_top: Vector2i = Vector2i(39, 11) if (bx == -3 or bx == 3) else Vector2i(40, 11)
		var tx_mid: Vector2i = Vector2i(39, 12) if (bx == -3 or bx == 3) else Vector2i(40, 12)
		var tx_bot: Vector2i = Vector2i(39, 13) if (bx == -3 or bx == 3) else Vector2i(40, 13)
		var fl: int = FLIP_H if (bx == 3 or (bx > -3 and bx < 3 and posmod(bx, 2) == 1)) else 0
		deck_layer.set_cell(Vector2i(bx, -1), 0, tx_top, fl)
		deck_layer.set_cell(Vector2i(bx, 0), 0, tx_mid, fl)
		deck_layer.set_cell(Vector2i(bx, 1), 0, tx_bot, fl)

	# Upper & lower wooden handrails (purely visual at bridge rim)
	var rails_layer: TileMapLayer = TileMapLayer.new()
	rails_layer.name = "BridgeRails"
	rails_layer.tile_set = _tileset
	rails_layer.position = Vector2(-8.0, -8.0)
	rails_layer.z_index = -4
	root.add_child(rails_layer)
	for bx: int in range(-3, 4):
		if bx == -3:
			rails_layer.set_cell(Vector2i(bx, -1), 0, Vector2i(42, 2), FLIP_H)
			rails_layer.set_cell(Vector2i(bx, 1), 0, Vector2i(38, 0), 0)
		elif bx == 3:
			rails_layer.set_cell(Vector2i(bx, -1), 0, Vector2i(42, 2), 0)
			rails_layer.set_cell(Vector2i(bx, 1), 0, Vector2i(38, 0), FLIP_H)
		else:
			rails_layer.set_cell(Vector2i(bx, -1), 0, Vector2i(39, 2), 0)
			rails_layer.set_cell(Vector2i(bx, 1), 0, Vector2i(39, 0), 0)

	# Thin 4px railing colliders strictly on outer top & bottom rims (keeps central 40px deck wide open for smooth crossing!)
	var rail_body: StaticBody2D = StaticBody2D.new()
	rail_body.name = "RailColliders"
	rail_body.collision_layer = 1
	rail_body.collision_mask = 0
	root.add_child(rail_body)
	_add_rect_collider(rail_body, Vector2(0.0, -22.0), Vector2(112.0, 4.0), "TopRail")
	_add_rect_collider(rail_body, Vector2(0.0, 22.0), Vector2(112.0, 4.0), "BottomRail")

	_save_prefab(root, "res://scenes/props/ocean_channel_bridge.tscn")


# ------------------------------------------------------------------------------
# 25. VILLAGE STONE FOUNDER STATUE (Verbatim Room1.yy 2x4 Stone Landmark!)
# ------------------------------------------------------------------------------
func _build_village_statue() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "VillageStatue"
	root.collision_layer = 1
	root.collision_mask = 0

	var spr: Sprite2D = Sprite2D.new()
	spr.name = "StatueSprite"
	spr.texture = _make_atlas_tex(44, 18, 2, 4)
	spr.offset = Vector2(0.0, -24.0)
	root.add_child(spr)

	_add_rect_collider(root, Vector2(0.0, -2.0), Vector2(22.0, 10.0), "StatueBaseCollider")
	_save_prefab(root, "res://scenes/props/village_statue.tscn")


# ------------------------------------------------------------------------------
# 26. WOODLAND & BEACH STONE-RING CAMPFIRE (Animated Fire + Warm Dusk PointLight!)
# ------------------------------------------------------------------------------
func _build_woodland_campfire() -> void:
	var root: StaticBody2D = StaticBody2D.new()
	root.name = "WoodlandCampfire"
	root.collision_layer = 1
	root.collision_mask = 0

	var ring_spr: Sprite2D = Sprite2D.new()
	ring_spr.name = "StoneRing"
	ring_spr.texture = _make_atlas_tex(37, 21, 2, 1)
	ring_spr.position = Vector2(0.0, 0.0)
	root.add_child(ring_spr)

	var flame: Sprite2D = Sprite2D.new()
	flame.name = "CampfireFlame"
	flame.script = _strip_sprite_script
	flame.texture = load(AP.FIRE_01_STRIP4) as Texture2D
	flame.hframes = 4
	flame.vframes = 1
	flame.position = Vector2(0.0, -5.0)
	flame.set("frame_rate", 8.0)
	root.add_child(flame)

	_add_rect_collider(root, Vector2(0.0, 0.0), Vector2(20.0, 12.0), "CampfireCollider")
	_save_prefab(root, "res://scenes/props/woodland_campfire.tscn")


# ------------------------------------------------------------------------------
# 27-28. ANIMATED SPOTTED WOODLAND MUSHROOMS (Red & Blue 4-Frame Strips!)
# ------------------------------------------------------------------------------
func _build_mushroom_prefabs() -> void:
	for spec: Array in [
		["MushroomRed", AP.MUSHROOM_RED_STRIP4, "res://scenes/props/mushroom_red.tscn"],
		["MushroomBlue", AP.MUSHROOM_BLUE_STRIP4, "res://scenes/props/mushroom_blue.tscn"],
	]:
		var root: Node2D = Node2D.new()
		root.name = spec[0] as String
		var spr: Sprite2D = Sprite2D.new()
		spr.name = "Sprite2D"
		spr.script = _strip_sprite_script
		spr.texture = load(spec[1] as String) as Texture2D
		spr.hframes = 4
		spr.vframes = 1
		spr.offset = Vector2(0.0, -3.0)
		spr.set("frame_rate", 3.5)
		root.add_child(spr)
		_save_prefab(root, spec[2] as String)

