class_name NpcHouse
extends Node2D

## Verbatim Room1.yy solid exterior NPC building with Stardew-style DoorPortal transition
## into res://scenes/world/npc_interior.tscn (styled uniquely per resident) and warm NightLights.

const DEFAULT_INTERIOR_SCENE_PATH: String = "res://scenes/world/npc_interior.tscn"
const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"

@export var building_id: StringName = &"npc_house"
@export var display_name: String = "Cottage"
@export var interior_theme_id: StringName = &"maren"
@export var interior_scene_path: String = DEFAULT_INTERIOR_SCENE_PATH
@export var door_spawn_offset: Vector2 = Vector2(40.0, 16.0)
@export var footprint_rect: Rect2 = Rect2(-8.0, -80.0, 96.0, 88.0)

@onready var door_portal: Area2D = $DoorPortal
@onready var night_lights: Node2D = get_node_or_null("NightLights") as Node2D

var _is_player_at_door: bool = false
var _night_factor: float = 0.0


func _ready() -> void:
	add_to_group(&"npc_houses")
	assert(door_portal != null, "NpcHouse '%s' requires DoorPortal Area2D." % name)
	door_portal.body_entered.connect(_on_door_body_entered)
	door_portal.body_exited.connect(_on_door_body_exited)
	set_night_light_factor(0.0)


func _physics_process(_delta: float) -> void:
	if not _is_player_at_door:
		return
	if SceneTransition.is_portal_on_cooldown():
		return
	if TimeManager.is_paused():
		return
	# Stardew-style walk-up entry while standing directly in front of the doorway
	if Input.is_action_pressed(&"move_up"):
		enter_house()


func set_night_light_factor(factor: float) -> void:
	_night_factor = clampf(factor, 0.0, 1.0)
	if night_lights == null:
		return
	for child: Node in night_lights.get_children():
		var pl: PointLight2D = child as PointLight2D
		if pl == null:
			continue
		if pl.name == "PorchLight":
			pl.energy = _night_factor * 0.72
		else:
			pl.energy = _night_factor * 0.56


func get_door_spawn_world_position() -> Vector2:
	return global_position + door_spawn_offset


func get_world_footprint_rect() -> Rect2:
	return Rect2(global_position + footprint_rect.position, footprint_rect.size)


func is_player_at_door() -> bool:
	return _is_player_at_door


func enter_house(immediate: bool = false) -> bool:
	if SceneTransition.is_transitioning():
		return false
	var target_scene: String = interior_scene_path if not interior_scene_path.is_empty() else DEFAULT_INTERIOR_SCENE_PATH
	EventBus.door_transition_requested.emit(target_scene, interior_theme_id)
	return SceneTransition.enter_interior(
		target_scene,
		interior_theme_id,
		FARM_SCENE_PATH,
		get_door_spawn_world_position(),
		&"from_exterior",
		immediate
	)


func _on_door_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_is_player_at_door = true
	EventBus.interact_prompt_changed.emit("[E] Enter %s" % display_name)


func _on_door_body_exited(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_is_player_at_door = false
	EventBus.interact_prompt_changed.emit("")
