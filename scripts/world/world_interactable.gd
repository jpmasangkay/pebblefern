class_name WorldInteractable
extends StaticBody2D

## Clean reusable world interaction prop (Kaelen's Forge Apron, Village Community Board,
## Pebblefern Mine Entrance Arch) with Area2D proximity prompt and optional NightLights.

enum ActionKind {
	TOAST_HOOK = 0,
	OPEN_SHOP_SEEDS = 1,
	OPEN_SHOP_FORGE = 2,
	OPEN_QUEST_BOARD = 3,
	ENTER_MINE = 4,
}

@export var interactable_id: StringName = &"prop"
@export var action_kind: ActionKind = ActionKind.TOAST_HOOK
@export var prompt_text: String = "[E] Inspect"
@export var toast_message: String = ""

@onready var interact_area: Area2D = $InteractArea
@onready var night_lights: Node2D = get_node_or_null("NightLights") as Node2D

var _player_nearby: bool = false


func _ready() -> void:
	add_to_group(&"world_interactables")
	assert(interact_area != null, "WorldInteractable '%s' requires InteractArea child." % name)
	# Phase 5: Wire the locked Village Plaza Community Board directly to QuestBoardModal!
	if interactable_id == &"community_board":
		action_kind = ActionKind.OPEN_QUEST_BOARD
		prompt_text = "[E] Quests (Community Board)"
	elif interactable_id == &"mine_entrance":
		action_kind = ActionKind.ENTER_MINE
		prompt_text = "[E] Enter Pebblefern Mine"
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	set_night_light_factor(0.0)


func set_night_light_factor(factor: float) -> void:
	var nf: float = clampf(factor, 0.0, 1.0)
	if night_lights == null:
		return
	for child: Node in night_lights.get_children():
		var pl: PointLight2D = child as PointLight2D
		if pl != null:
			pl.energy = nf * 0.78


func is_player_nearby() -> bool:
	return _player_nearby


func trigger_interact() -> void:
	match action_kind:
		ActionKind.OPEN_SHOP_SEEDS:
			EventBus.shop_requested.emit(&"maren_seeds")
		ActionKind.OPEN_SHOP_FORGE:
			EventBus.shop_requested.emit(&"kaelen_forge")
		ActionKind.OPEN_QUEST_BOARD:
			AudioManager.play_sfx(&"pickup", -9.0, 0.04)
			EventBus.quest_board_requested.emit()
		ActionKind.ENTER_MINE:
			AudioManager.play_sfx(&"door", -5.0, 0.03)
			EventBus.mine_entrance_requested.emit()
		ActionKind.TOAST_HOOK:
			AudioManager.play_sfx(&"pickup", -10.0, 0.04)
			if not toast_message.is_empty():
				EventBus.toast_requested.emit(toast_message)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = true
		EventBus.interact_prompt_changed.emit(prompt_text)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = false
		EventBus.interact_prompt_changed.emit("")
