class_name ShippingBin
extends StaticBody2D

## Sanctuary Shipping Chest built from verified Sunnyside crate_base.png and crate_top.png.

@onready var interact_area: Area2D = $InteractArea

var _player_nearby: bool = false


func _ready() -> void:
	assert(interact_area != null, "ShippingBin requires InteractArea child.")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


func is_player_nearby() -> bool:
	return _player_nearby


func trigger_interact() -> void:
	EventBus.shipping_bin_interacted.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = true
		EventBus.interact_prompt_changed.emit("[E] Shipping Chest")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = false
		EventBus.interact_prompt_changed.emit("")
