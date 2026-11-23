extends CanvasLayer

## Handles smooth 0.18s fade-to-black door transitions between outdoor scenes and interiors
## while preserving persistent world state and spawn tags across change_scene_to_file().

const AP := preload("res://scripts/core/asset_paths.gd")

const FADE_DURATION: float = 0.18
const PORTAL_EXIT_GRACE_SEC: float = 0.45

var pending_spawn_tag: StringName = &""
var pending_interior_id: StringName = &""
var pending_return_position: Vector2 = Vector2.ZERO
var has_pending_return_position: bool = false
var active_return_scene: String = "res://scenes/world/farm_sanctuary.tscn"
var active_return_position: Vector2 = Vector2.ZERO
var active_interior_id: StringName = &""

var _is_transitioning: bool = false
var _portal_grace_remaining: float = 0.0
var _fade_overlay: TextureRect = null
var _fade_tween: Tween = null


func _ready() -> void:
	layer = 50
	var tex: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(tex != null, "SceneTransition missing w_box_9slice_c.png")

	_fade_overlay = TextureRect.new()
	_fade_overlay.name = "DoorFadeOverlay"
	_fade_overlay.texture = tex
	_fade_overlay.modulate = Color(0.02, 0.02, 0.05, 0.0)
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fade_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)


func _process(delta: float) -> void:
	if _portal_grace_remaining > 0.0:
		_portal_grace_remaining = maxf(0.0, _portal_grace_remaining - minf(delta, 0.1))


func is_transitioning() -> bool:
	return _is_transitioning


func is_portal_on_cooldown() -> bool:
	return _is_transitioning or _portal_grace_remaining > 0.0


func consume_spawn_tag() -> StringName:
	var tag: StringName = pending_spawn_tag
	pending_spawn_tag = &""
	return tag


func consume_interior_id() -> StringName:
	var iid: StringName = pending_interior_id
	pending_interior_id = &""
	return iid


func consume_return_position() -> Dictionary:
	if not has_pending_return_position:
		return { "valid": false, "position": Vector2.ZERO }
	var pos: Vector2 = pending_return_position
	has_pending_return_position = false
	pending_return_position = Vector2.ZERO
	return { "valid": true, "position": pos }


func enter_interior(
	interior_scene_path: String,
	interior_id: StringName,
	return_scene_path: String,
	return_doorstep_pos: Vector2,
	spawn_tag: StringName = &"from_exterior",
	immediate: bool = false
) -> bool:
	assert(not return_scene_path.is_empty(), "SceneTransition.enter_interior requires return_scene_path.")
	active_return_scene = return_scene_path
	active_return_position = return_doorstep_pos
	active_interior_id = interior_id
	pending_interior_id = interior_id
	has_pending_return_position = false
	return transition_to_scene(interior_scene_path, spawn_tag, immediate)


func exit_interior(spawn_tag: StringName = &"from_interior", immediate: bool = false) -> bool:
	var target_scene: String = active_return_scene if not active_return_scene.is_empty() else "res://scenes/world/farm_sanctuary.tscn"
	if active_return_position != Vector2.ZERO:
		pending_return_position = active_return_position
		has_pending_return_position = true
	return transition_to_scene(target_scene, spawn_tag, immediate)


func transition_to_scene(target_scene_path: String, spawn_tag: StringName = &"", immediate: bool = false) -> bool:
	if _is_transitioning:
		return false
	assert(ResourceLoader.exists(target_scene_path), "SceneTransition target missing: %s" % target_scene_path)

	_is_transitioning = true
	pending_spawn_tag = spawn_tag
	AudioManager.play_sfx(&"door", -5.0, 0.03)
	EventBus.interact_prompt_changed.emit("")
	TimeManager.set_paused(true)

	if immediate:
		var err: Error = get_tree().change_scene_to_file(target_scene_path)
		assert(err == OK, "SceneTransition failed to load %s (err=%d)" % [target_scene_path, err])
		_fade_overlay.modulate.a = 0.0
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portal_grace_remaining = PORTAL_EXIT_GRACE_SEC
		_is_transitioning = false
		TimeManager.set_paused(false)
		return true

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "modulate:a", 1.0, FADE_DURATION)
	_fade_tween.tween_callback(func() -> void:
		var err: Error = get_tree().change_scene_to_file(target_scene_path)
		assert(err == OK, "SceneTransition failed to load %s (err=%d)" % [target_scene_path, err])
	)
	_fade_tween.tween_interval(0.04)
	_fade_tween.tween_property(_fade_overlay, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func() -> void:
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portal_grace_remaining = PORTAL_EXIT_GRACE_SEC
		_is_transitioning = false
		TimeManager.set_paused(false)
	)
	return true
