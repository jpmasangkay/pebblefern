class_name WorldAtmosphere
extends Node2D

## Manages Pebblefern's 24-hour Day/Night CanvasModulate gradient, warm PointLight2D glow
## (farmhouse hearth/windows + outdoor sanctuary torches), seasonal foliage tinting shader,
## and camera-following Rain/Snow pixel weather particles (100% real Sunnyside assets).

const AP := preload("res://scripts/core/asset_paths.gd")
const SEASON_SHADER_PATH: String = "res://shaders/season_tint.gdshader"

var _canvas_modulate: CanvasModulate = null
var _day_gradient: Gradient = null
var _season_mat: ShaderMaterial = null
var _rain_particles: CPUParticles2D = null
var _snow_particles: CPUParticles2D = null
var _outdoor_lights: Array[PointLight2D] = []
var _outdoor_flames: Array[Sprite2D] = []
var _farmhouse: CutawayFarmhouse = null
var _follow_target: Node2D = null
var _is_indoors: bool = false
var _flicker_elapsed: float = 0.0
var _current_night_factor: float = 0.0


func setup(
	ground_layer: TileMapLayer,
	world_entities: Node2D,
	farmhouse: CutawayFarmhouse,
	follow_target: Node2D
) -> void:
	_farmhouse = farmhouse
	_follow_target = follow_target

	_build_day_gradient()
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "DayNightModulate"
	add_child(_canvas_modulate)

	_setup_seasonal_shader(ground_layer, world_entities)
	_setup_outdoor_torches(world_entities, farmhouse)
	_setup_weather_particles()

	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.interior_entered.connect(_on_interior_entered)
	EventBus.interior_exited.connect(_on_interior_exited)

	_apply_season(TimeManager.current_season)
	_apply_weather(TimeManager.current_weather)
	refresh_lighting()


func _exit_tree() -> void:
	if EventBus.time_ticked.is_connected(_on_time_ticked):
		EventBus.time_ticked.disconnect(_on_time_ticked)
	if EventBus.season_changed.is_connected(_on_season_changed):
		EventBus.season_changed.disconnect(_on_season_changed)
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)
	if EventBus.interior_entered.is_connected(_on_interior_entered):
		EventBus.interior_entered.disconnect(_on_interior_entered)
	if EventBus.interior_exited.is_connected(_on_interior_exited):
		EventBus.interior_exited.disconnect(_on_interior_exited)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	_flicker_elapsed += dt
	refresh_lighting()

	if _follow_target != null and is_instance_valid(_follow_target):
		var cam_pos: Vector2 = _follow_target.global_position
		if _rain_particles != null:
			_rain_particles.global_position = cam_pos + Vector2(0.0, -110.0)
		if _snow_particles != null:
			_snow_particles.global_position = cam_pos + Vector2(0.0, -110.0)

	# Subtle warm flicker on outdoor courtyard torch PointLight2Ds at dusk/night
	for idx: int in range(_outdoor_lights.size()):
		var pl: PointLight2D = _outdoor_lights[idx]
		if is_instance_valid(pl) and _current_night_factor > 0.01:
			var wave: float = 0.93 + 0.07 * sin(_flicker_elapsed * 8.2 + float(idx) * 2.1)
			pl.energy = _current_night_factor * 0.85 * wave


func refresh_lighting() -> void:
	if _canvas_modulate == null or _day_gradient == null:
		return
	var progress: float = TimeManager.get_day_progress()
	var base_col: Color = _day_gradient.sample(progress)

	# Gentle cool overcast shift on rainy days during daylight
	var hour_f: float = TimeManager.get_hour_float()
	if TimeManager.is_raining() and hour_f < 20.0:
		base_col = base_col.lerp(Color(0.76, 0.82, 0.92, 1.0), 0.28)
	elif TimeManager.is_snowing() and hour_f < 20.0:
		base_col = base_col.lerp(Color(0.86, 0.92, 1.0, 1.0), 0.22)

	# Slightly warmer interior ambient when standing inside the cozy lit farmhouse at night
	if _is_indoors and hour_f >= 18.0:
		base_col = base_col.lerp(Color(0.68, 0.60, 0.56, 1.0), 0.35)

	_canvas_modulate.color = base_col

	# Compute smooth warm-light ramp factor (0.0 daytime -> 1.0 night starting at 17:30 -> 20:30)
	_current_night_factor = clampf((hour_f - 17.5) / 3.0, 0.0, 1.0)
	if _farmhouse != null and is_instance_valid(_farmhouse):
		_farmhouse.set_night_light_factor(_current_night_factor)
	if is_inside_tree():
		for h_node: Node in get_tree().get_nodes_in_group(&"npc_houses"):
			var nh: NpcHouse = h_node as NpcHouse
			if nh != null and is_instance_valid(nh):
				nh.set_night_light_factor(_current_night_factor)
		for wi_node: Node in get_tree().get_nodes_in_group(&"world_interactables"):
			var wi: WorldInteractable = wi_node as WorldInteractable
			if wi != null and is_instance_valid(wi):
				wi.set_night_light_factor(_current_night_factor)

	var flames_lit: bool = _current_night_factor > 0.08
	for i: int in range(_outdoor_lights.size()):
		if is_instance_valid(_outdoor_lights[i]):
			_outdoor_lights[i].energy = _current_night_factor * 0.85
		if i < _outdoor_flames.size() and is_instance_valid(_outdoor_flames[i]):
			_outdoor_flames[i].visible = flames_lit


func get_canvas_modulate_color() -> Color:
	return _canvas_modulate.color if _canvas_modulate != null else Color.WHITE


func get_night_factor() -> float:
	return _current_night_factor


func _build_day_gradient() -> void:
	# Maps normalized day progress [0.0 .. 1.0] across 06:00 AM .. 02:00 AM (20 in-game hours)
	_day_gradient = Gradient.new()
	_day_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	_day_gradient.offsets = PackedFloat32Array([
		0.00,  # 06:00 AM Dawn warm peach
		0.10,  # 08:00 AM Crisp morning
		0.30,  # 12:00 PM Pure noon daylight
		0.52,  # 16:24 PM Golden late afternoon
		0.65,  # 19:00 PM Warm amber sunset
		0.73,  # 20:36 PM Deep indigo twilight
		0.82,  # 22:24 PM Cozy readable starry night blue
		1.00,  # 02:00 AM Deep midnight blue
	])
	_day_gradient.colors = PackedColorArray([
		Color(0.93, 0.84, 0.78, 1.0),
		Color(1.00, 0.99, 0.96, 1.0),
		Color(1.00, 1.00, 1.00, 1.0),
		Color(1.00, 0.92, 0.80, 1.0),
		Color(0.84, 0.62, 0.58, 1.0),
		Color(0.44, 0.48, 0.70, 1.0),
		Color(0.26, 0.32, 0.54, 1.0),
		Color(0.22, 0.27, 0.48, 1.0),
	])


func _setup_seasonal_shader(ground_layer: TileMapLayer, world_entities: Node2D) -> void:
	var sh: Shader = load(SEASON_SHADER_PATH) as Shader
	assert(sh != null, "Missing seasonal foliage shader: %s" % SEASON_SHADER_PATH)
	_season_mat = ShaderMaterial.new()
	_season_mat.shader = sh
	_season_mat.set_shader_parameter(&"season_index", TimeManager.current_season)

	if ground_layer != null:
		ground_layer.material = _season_mat
		var parent_root: Node = ground_layer.get_parent()
		if parent_root != null:
			var quarry_ground: TileMapLayer = parent_root.get_node_or_null("01d_QuarryGround") as TileMapLayer
			if quarry_ground != null:
				quarry_ground.material = _season_mat

	# Apply shared seasonal shader cleanly to foliage trees & bushes (never to player, crops, or houses)
	if world_entities != null:
		for child: Node in world_entities.get_children():
			if child is ResourceNode:
				var rn: ResourceNode = child as ResourceNode
				if rn.node_kind == ResourceNode.NodeKind.TREE_DECIDUOUS or rn.node_kind == ResourceNode.NodeKind.TREE_PINE or rn.node_kind == ResourceNode.NodeKind.WEED_TUFT:
					rn.material = _season_mat
			elif child.name.begins_with("Tree") or child.name.begins_with("BerryBush"):
				if child is CanvasItem:
					(child as CanvasItem).material = _season_mat


func _setup_outdoor_torches(world_entities: Node2D, farmhouse: CutawayFarmhouse) -> void:
	if world_entities == null or farmhouse == null:
		return
	var tileset_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	var fire_tex: Texture2D = load(AP.FIRE_01_STRIP4) as Texture2D
	var strip_script: Script = load("res://scripts/world/strip_sprite_2d.gd") as Script
	assert(tileset_tex != null and fire_tex != null and strip_script != null, "Missing torch assets.")

	var post_atlas: AtlasTexture = AtlasTexture.new()
	post_atlas.atlas = tileset_tex
	post_atlas.region = Rect2(40 * 16, 4 * 16, 16, 16)

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

	# Place two symmetrical sanctuary torches cleanly on the front-yard grass flanking the vertical dirt path
	# (Path center = farmhouse.x + 48; symmetrical grass posts at ±40px; 1 tile south of front wall at y=+24px!)
	var torch_positions: Array[Vector2] = [
		farmhouse.position + Vector2(8.0, 24.0),
		farmhouse.position + Vector2(88.0, 24.0),
	]
	# Also discover any island walkway lantern markers placed in WorldMarkers/LanternPosts!
	var parent_root: Node = world_entities.get_parent()
	var water_layer: TileMapLayer = null
	var ground_layer: TileMapLayer = null
	var paths_layer: TileMapLayer = null
	if parent_root != null:
		water_layer = parent_root.get_node_or_null("00_Water") as TileMapLayer
		ground_layer = parent_root.get_node_or_null("01_Ground") as TileMapLayer
		paths_layer = parent_root.get_node_or_null("02_Paths") as TileMapLayer
		var lanterns_dir: Node = parent_root.get_node_or_null("WorldMarkers/LanternPosts")
		if lanterns_dir != null:
			for child: Node in lanterns_dir.get_children():
				var lm: Marker2D = child as Marker2D
				if lm != null:
					torch_positions.append(lm.position)

	for idx: int in range(torch_positions.size()):
		var tpos: Vector2 = torch_positions[idx]
		var tcell: Vector2i = Vector2i(floori(tpos.x / 16.0), floori(tpos.y / 16.0))
		var tcell_up: Vector2i = tcell + Vector2i(0, -1)
		if water_layer != null and (water_layer.get_cell_source_id(tcell) != -1 or water_layer.get_cell_source_id(tcell_up) != -1):
			continue
		if paths_layer != null and paths_layer.get_cell_source_id(tcell) != -1:
			continue
		if ground_layer != null:
			var td0: TileData = ground_layer.get_cell_tile_data(tcell)
			var td1: TileData = ground_layer.get_cell_tile_data(tcell_up)
			if (td0 != null and td0.terrain_set == AP.TERRAIN_SET_RIVER) or (td1 != null and td1.terrain_set == AP.TERRAIN_SET_RIVER):
				continue
		var torch: Node2D = Node2D.new()
		torch.name = ("CourtyardTorch_%d" % idx) if idx < 2 else ("WalkwayTorch_%d" % (idx - 2))
		torch.position = tpos

		var post_spr: Sprite2D = Sprite2D.new()
		post_spr.name = "Post"
		post_spr.texture = post_atlas
		post_spr.offset = Vector2(0.0, -5.0)
		torch.add_child(post_spr)

		var flame_spr: Sprite2D = Sprite2D.new()
		flame_spr.name = "Flame"
		flame_spr.script = strip_script
		flame_spr.texture = fire_tex
		flame_spr.hframes = 4
		flame_spr.vframes = 1
		flame_spr.scale = Vector2(0.85, 0.85)
		flame_spr.position = Vector2(0.0, -12.0)
		flame_spr.set("frame_rate", 8.0)
		flame_spr.visible = false
		torch.add_child(flame_spr)

		var pl: PointLight2D = PointLight2D.new()
		pl.name = "TorchLight"
		pl.position = Vector2(0.0, -10.0)
		pl.color = Color(1.0, 0.72, 0.34, 1.0)
		pl.texture = light_tex
		pl.texture_scale = 1.05
		pl.energy = 0.0
		pl.blend_mode = Light2D.BLEND_MODE_ADD
		torch.add_child(pl)

		world_entities.add_child(torch)
		_outdoor_lights.append(pl)
		_outdoor_flames.append(flame_spr)


func _setup_weather_particles() -> void:
	var tileset_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	assert(tileset_tex != null, "Missing tileset for weather particle AtlasTextures.")

	# Crisp pixel raindrop sliced from real Sunnyside river water tile (30,8)
	var rain_tex: AtlasTexture = AtlasTexture.new()
	rain_tex.atlas = tileset_tex
	rain_tex.region = Rect2(30 * 16 + 4, 8 * 16 + 4, 2, 5)

	_rain_particles = CPUParticles2D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.texture = rain_tex
	_rain_particles.emitting = false
	_rain_particles.amount = 64
	_rain_particles.lifetime = 0.95
	_rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain_particles.emission_rect_extents = Vector2(210.0, 12.0)
	_rain_particles.direction = Vector2(-0.22, 1.0)
	_rain_particles.spread = 3.0
	_rain_particles.gravity = Vector2.ZERO
	_rain_particles.initial_velocity_min = 210.0
	_rain_particles.initial_velocity_max = 260.0
	_rain_particles.color = Color(0.82, 0.94, 1.0, 0.78)
	_rain_particles.z_index = 20
	add_child(_rain_particles)

	# Crisp pixel snowflake sliced from real Sunnyside water glint tile (11,22)
	var snow_tex: AtlasTexture = AtlasTexture.new()
	snow_tex.atlas = tileset_tex
	snow_tex.region = Rect2(11 * 16 + 7, 22 * 16 + 7, 2, 2)

	_snow_particles = CPUParticles2D.new()
	_snow_particles.name = "SnowParticles"
	_snow_particles.texture = snow_tex
	_snow_particles.emitting = false
	_snow_particles.amount = 48
	_snow_particles.lifetime = 3.2
	_snow_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_snow_particles.emission_rect_extents = Vector2(210.0, 12.0)
	_snow_particles.direction = Vector2(-0.18, 1.0)
	_snow_particles.spread = 18.0
	_snow_particles.gravity = Vector2(0.0, 6.0)
	_snow_particles.initial_velocity_min = 24.0
	_snow_particles.initial_velocity_max = 42.0
	_snow_particles.color = Color(0.96, 0.98, 1.0, 0.9)
	_snow_particles.z_index = 20
	add_child(_snow_particles)


func _on_time_ticked(_day: int, _season_index: int, _hour: int, _minute: int) -> void:
	refresh_lighting()


func _on_season_changed(new_season_index: int) -> void:
	_apply_season(new_season_index)


func _on_weather_changed(new_weather: StringName) -> void:
	_apply_weather(new_weather)


func _on_interior_entered(_building_id: StringName) -> void:
	_is_indoors = true
	_apply_weather(TimeManager.current_weather)
	refresh_lighting()


func _on_interior_exited(_building_id: StringName) -> void:
	_is_indoors = false
	_apply_weather(TimeManager.current_weather)
	refresh_lighting()


func _apply_season(season_idx: int) -> void:
	if _season_mat != null:
		_season_mat.set_shader_parameter(&"season_index", clampi(season_idx, 0, 3))


func _apply_weather(weather: StringName) -> void:
	if _rain_particles != null:
		_rain_particles.emitting = (weather == TimeManager.WEATHER_RAIN) and not _is_indoors
	if _snow_particles != null:
		_snow_particles.emitting = (weather == TimeManager.WEATHER_SNOW) and not _is_indoors
	refresh_lighting()
