class_name CutawayFarmhouse
extends Node2D

## Solid exterior 2-wing Farmhouse with Stardew-style DoorPortal transition into farmhouse_interior.tscn.
## Exterior walls, roof, and double front door are 100% solid (zero phasing); walking up into the
## DoorPortal or pressing [E] fades smoothly (0.18s) into the dedicated interior cabin room.

const INTERIOR_SCENE_PATH: String = "res://scenes/world/farmhouse_interior.tscn"

@export var building_id: StringName = &"farmhouse"

@onready var roof_layer: Node2D = $RoofLayer
@onready var door_portal: Area2D = $DoorPortal
@onready var night_lights: Node2D = get_node_or_null("NightLights") as Node2D

var _is_player_at_door: bool = false
var _night_factor: float = 0.0


func _ready() -> void:
	assert(roof_layer != null, "CutawayFarmhouse requires RoofLayer Node2D.")
	assert(door_portal != null, "CutawayFarmhouse requires DoorPortal Area2D.")
	roof_layer.modulate.a = 1.0
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
	# Stardew-style walk-up entry: pushing Up while standing in front of the door enters smoothly!
	if Input.is_action_pressed(&"move_up"):
		enter_farmhouse()


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
		elif pl.name == "HearthLight":
			pl.energy = 0.0
		else:
			pl.energy = _night_factor * 0.58


func get_door_spawn_world_position() -> Vector2:
	# Exact sunlit doorstep centered below the double front door (world col 26.5..27.5 path center)
	return global_position + Vector2(48.0, 16.0)


func get_bed_wake_world_position() -> Vector2:
	return get_door_spawn_world_position()


func is_player_inside() -> bool:
	return false


func is_player_at_bed() -> bool:
	return false


func is_player_at_door() -> bool:
	return _is_player_at_door


func enter_farmhouse(immediate: bool = false) -> bool:
	if SceneTransition.is_transitioning():
		return false
	EventBus.door_transition_requested.emit(INTERIOR_SCENE_PATH, &"from_farm")
	return SceneTransition.enter_interior(
		INTERIOR_SCENE_PATH,
		&"farmhouse",
		"res://scenes/world/farm_sanctuary.tscn",
		get_door_spawn_world_position(),
		&"from_farm",
		immediate
	)


func set_roof_visible_immediate(_show_roof: bool) -> void:
	# Exterior roof stays solid permanently; interior lives in farmhouse_interior.tscn
	roof_layer.modulate.a = 1.0


func _on_door_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_is_player_at_door = true
	EventBus.interact_prompt_changed.emit("[E] Enter Farmhouse")


func _on_door_body_exited(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_is_player_at_door = false
	EventBus.interact_prompt_changed.emit("")
