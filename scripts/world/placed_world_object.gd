class_name PlacedWorldObject
extends Node2D

## Persistent world entity for crafted placeables: Wooden Fence, Outdoor Torch (animated fire + night PointLight2D),
## Stone Path (walkable cobble paver), Scarecrow (5-tile crop guard radius preview), and Stone Furnace (smelting).

const AP := preload("res://scripts/core/asset_paths.gd")
const SCARECROW_RADIUS_TILES: int = 5

var scene_id: StringName = &"farm_sanctuary"
var grid_cell: Vector2i = Vector2i.ZERO
var object_id: StringName = &""

var _torch_light: PointLight2D = null
var _torch_flame: Sprite2D = null
var _furnace_light: PointLight2D = null
var _furnace_flame: Sprite2D = null
var _furnace_ember_timer: float = 0.0
var _scarecrow_ring: Node2D = null
var _player_nearby: bool = false
var _flicker_t: float = 0.0


func configure(p_scene_id: StringName, p_cell: Vector2i, p_object_id: StringName) -> void:
	scene_id = p_scene_id
	grid_cell = p_cell
	object_id = p_object_id
	add_to_group(&"placed_objects")

	var ts_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	var strip_script: Script = load("res://scripts/world/strip_sprite_2d.gd") as Script
	assert(ts_tex != null and strip_script != null, "Missing tileset or strip script for PlacedWorldObject.")

	match object_id:
		&"fence":
			_build_fence(ts_tex)
		&"torch":
			_build_torch(ts_tex, strip_script)
		&"stone_path":
			_build_stone_path(ts_tex)
		&"scarecrow":
			_build_scarecrow(ts_tex)
		&"furnace":
			_build_furnace(ts_tex, strip_script)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	_flicker_t += dt

	if _torch_light != null and _torch_flame != null:
		var hour_f: float = TimeManager.get_hour_float()
		var night_factor: float = clampf((hour_f - 17.5) / 3.0, 0.0, 1.0)
		_torch_flame.visible = true
		var wave: float = 0.92 + 0.08 * sin(_flicker_t * 8.5 + float(grid_cell.x) * 1.7)
		_torch_light.energy = maxf(0.18, night_factor * 0.92) * wave

	if _furnace_light != null and _furnace_flame != null:
		if _furnace_ember_timer > 0.0:
			_furnace_ember_timer = maxf(0.0, _furnace_ember_timer - dt)
			_furnace_flame.visible = true
			var wave2: float = 0.90 + 0.10 * sin(_flicker_t * 10.2)
			_furnace_light.energy = 0.95 * wave2
		else:
			var hour_f: float = TimeManager.get_hour_float()
			var night_factor: float = clampf((hour_f - 17.5) / 3.0, 0.0, 1.0)
			_furnace_flame.visible = true
			_furnace_light.energy = (0.30 + night_factor * 0.55) * (0.94 + 0.06 * sin(_flicker_t * 7.4))


func is_player_nearby() -> bool:
	return _player_nearby


func trigger_interact() -> void:
	if object_id == &"furnace":
		EventBus.furnace_interacted.emit(scene_id, grid_cell)
	elif object_id == &"scarecrow":
		EventBus.toast_requested.emit("Scarecrow protects crops within 5 tiles!")


func ignite_ember_burst() -> void:
	_furnace_ember_timer = 5.0


func _build_fence(ts_tex: Texture2D) -> void:
	var body: StaticBody2D = _add_solid_body(Vector2(14.0, 7.0), Vector2(0.0, -2.0))
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = _atlas(ts_tex, AP.TILE_FENCE_H_MID)
	spr.offset = Vector2(0.0, -4.0)
	body.add_child(spr)


func _build_torch(ts_tex: Texture2D, strip_script: Script) -> void:
	var body: StaticBody2D = _add_solid_body(Vector2(8.0, 6.0), Vector2(0.0, -2.0))
	var post: Sprite2D = Sprite2D.new()
	post.texture = _atlas(ts_tex, AP.TILE_FENCE_V_BOTTOM)
	post.offset = Vector2(0.0, -5.0)
	body.add_child(post)

	_torch_flame = Sprite2D.new()
	_torch_flame.name = "Flame"
	_torch_flame.script = strip_script
	_torch_flame.texture = load(AP.FIRE_01_STRIP4) as Texture2D
	_torch_flame.hframes = 4
	_torch_flame.vframes = 1
	_torch_flame.scale = Vector2(0.88, 0.88)
	_torch_flame.position = Vector2(0.0, -12.0)
	_torch_flame.set("frame_rate", 8.0)
	body.add_child(_torch_flame)

	_torch_light = PointLight2D.new()
	_torch_light.name = "TorchLight"
	_torch_light.position = Vector2(0.0, -10.0)
	_torch_light.color = Color(1.0, 0.72, 0.34, 1.0)
	_torch_light.texture = _make_warm_light_tex()
	_torch_light.texture_scale = 1.15
	_torch_light.energy = 0.25
	_torch_light.blend_mode = Light2D.BLEND_MODE_ADD
	body.add_child(_torch_light)


func _build_stone_path(ts_tex: Texture2D) -> void:
	# Walkable flat cobblestone paver drawn flush with the ground
	z_index = -7
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "StonePaver"
	spr.texture = _atlas(ts_tex, AP.TILE_STONE_PATH)
	add_child(spr)


func _build_scarecrow(ts_tex: Texture2D) -> void:
	var body: StaticBody2D = _add_solid_body(Vector2(10.0, 7.0), Vector2(0.0, -2.0))

	var post: Sprite2D = Sprite2D.new()
	post.texture = _atlas(ts_tex, AP.TILE_FENCE_V_BOTTOM)
	post.offset = Vector2(0.0, -5.0)
	body.add_child(post)

	var crossbar: Sprite2D = Sprite2D.new()
	crossbar.texture = _atlas(ts_tex, AP.TILE_FENCE_H_MID)
	crossbar.scale = Vector2(0.95, 0.75)
	crossbar.position = Vector2(0.0, -11.0)
	body.add_child(crossbar)

	var straw: Sprite2D = Sprite2D.new()
	straw.texture = load(AP.CROPS_ROOT + "/wheat_05.png") as Texture2D
	straw.scale = Vector2(0.75, 0.75)
	straw.position = Vector2(0.0, -10.0)
	body.add_child(straw)

	var head: Sprite2D = Sprite2D.new()
	head.texture = load(AP.CROPS_ROOT + "/pumpkin_05.png") as Texture2D
	head.scale = Vector2(0.85, 0.85)
	head.position = Vector2(0.0, -17.0)
	body.add_child(head)

	# Visual 5-tile protection boundary corner brackets shown when player stands nearby!
	_scarecrow_ring = Node2D.new()
	_scarecrow_ring.name = "ProtectionRadiusIndicator"
	_scarecrow_ring.z_index = 4
	_scarecrow_ring.visible = false
	var r_px: float = float(SCARECROW_RADIUS_TILES) * 16.0 + 6.0
	var corners: Array[Array] = [
		[AP.SELECTBOX_TL, Vector2(-r_px, -r_px)],
		[AP.SELECTBOX_TR, Vector2(r_px, -r_px)],
		[AP.SELECTBOX_BL, Vector2(-r_px, r_px)],
		[AP.SELECTBOX_BR, Vector2(r_px, r_px)],
	]
	for c: Array in corners:
		var cspr: Sprite2D = Sprite2D.new()
		cspr.texture = load(c[0] as String) as Texture2D
		cspr.position = c[1] as Vector2
		cspr.modulate = Color(0.65, 1.0, 0.65, 0.85)
		_scarecrow_ring.add_child(cspr)
	add_child(_scarecrow_ring)

	_add_interact_area(Vector2(30.0, 28.0), "[E] Scarecrow (5-Tile Guard)")


func _build_furnace(ts_tex: Texture2D, strip_script: Script) -> void:
	var body: StaticBody2D = _add_solid_body(Vector2(18.0, 10.0), Vector2(0.0, -3.0))
	var f_atlas: AtlasTexture = AtlasTexture.new()
	f_atlas.atlas = ts_tex
	f_atlas.region = Rect2(46 * 16 + 1, 19 * 16, 30, 44)
	var spr: Sprite2D = Sprite2D.new()
	spr.name = "FurnaceSprite"
	spr.texture = f_atlas
	spr.scale = Vector2(0.76, 0.76)
	spr.offset = Vector2(0.0, -18.0)
	body.add_child(spr)

	_furnace_flame = Sprite2D.new()
	_furnace_flame.name = "FurnaceFire"
	_furnace_flame.script = strip_script
	_furnace_flame.texture = load(AP.FIRE_02_STRIP4) as Texture2D
	_furnace_flame.hframes = 4
	_furnace_flame.vframes = 1
	_furnace_flame.scale = Vector2(0.56, 0.52)
	_furnace_flame.position = Vector2(0.0, -5.0)
	_furnace_flame.set("frame_rate", 7.5)
	body.add_child(_furnace_flame)

	_furnace_light = PointLight2D.new()
	_furnace_light.name = "FurnaceLight"
	_furnace_light.position = Vector2(0.0, -5.0)
	_furnace_light.color = Color(1.0, 0.58, 0.22, 1.0)
	_furnace_light.texture = _make_warm_light_tex()
	_furnace_light.texture_scale = 0.95
	_furnace_light.energy = 0.35
	_furnace_light.blend_mode = Light2D.BLEND_MODE_ADD
	body.add_child(_furnace_light)

	_add_interact_area(Vector2(34.0, 30.0), "[E] Stone Furnace (Smelt)")


func _add_solid_body(size_px: Vector2, offset_px: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Collider"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.position = offset_px
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size_px
	cs.shape = rect
	body.add_child(cs)
	add_child(body)
	return body


func _add_interact_area(size_px: Vector2, prompt_text: String) -> void:
	var area: Area2D = Area2D.new()
	area.name = "InteractArea"
	area.collision_layer = 8
	area.collision_mask = 4
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.position = Vector2(0.0, -2.0)
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size_px
	cs.shape = rect
	area.add_child(cs)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group(&"player"):
			_player_nearby = true
			if _scarecrow_ring != null:
				_scarecrow_ring.visible = true
			EventBus.interact_prompt_changed.emit(prompt_text)
	)
	area.body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group(&"player"):
			_player_nearby = false
			if _scarecrow_ring != null:
				_scarecrow_ring.visible = false
			EventBus.interact_prompt_changed.emit("")
	)
	add_child(area)


func _atlas(ts_tex: Texture2D, coords: Vector2i, w_tiles: int = 1, h_tiles: int = 1) -> AtlasTexture:
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = ts_tex
	at.region = Rect2(coords.x * 16, coords.y * 16, w_tiles * 16, h_tiles * 16)
	return at


func _make_warm_light_tex() -> GradientTexture2D:
	var grad: Gradient = Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.88, 0.62, 0.45), Color(1.0, 0.72, 0.35, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var gtex: GradientTexture2D = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 128
	gtex.height = 128
	return gtex
