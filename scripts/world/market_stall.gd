class_name MarketStall
extends StaticBody2D

## Authentic Sunnyside World Roadside Trading Post & Blacksmith Forge Corner
## for Maren's Seed Shop & Kaelen's Tool Upgrades.
## Animates Maren's 3-layer frame-locked idle sprites (base + curlyhair + foreground arm/hand)
## and subtly faces toward the player when they approach the shop counter.

@export var shop_id: StringName = &"sanctuary_market"

const MAREN_IDLE_FPS: float = 7.5
const MAREN_IDLE_FRAMES: int = 9

@onready var interact_area: Area2D = $InteractArea
@onready var maren_root: Node2D = get_node_or_null("MarenNPC") as Node2D
@onready var _maren_body: Sprite2D = get_node_or_null("MarenNPC/BodySprite") as Sprite2D
@onready var _maren_hair: Sprite2D = get_node_or_null("MarenNPC/HairSprite") as Sprite2D
@onready var _maren_tool: Sprite2D = get_node_or_null("MarenNPC/ToolSprite") as Sprite2D
@onready var _shop_light: PointLight2D = get_node_or_null("ShopWarmLight") as PointLight2D

var _player_nearby: bool = false
var _player_ref: Node2D = null
var _anim_time: float = 0.0


func _ready() -> void:
	add_to_group(&"market_stalls")
	assert(interact_area != null, "MarketStall requires InteractArea child.")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	_anim_time += dt
	# When MarenNPC is a live Phase 5 NpcActor, let NpcActor drive her 3-layer IDLE/WALK schedule!
	if maren_root != null and not (maren_root is NpcActor):
		var frame_idx: int = int(_anim_time * MAREN_IDLE_FPS) % MAREN_IDLE_FRAMES
		var flip_left: bool = false
		if _player_nearby and _player_ref != null and is_instance_valid(_player_ref):
			flip_left = (_player_ref.global_position.x < maren_root.global_position.x - 4.0)

		if _maren_body != null:
			_maren_body.frame = frame_idx
			_maren_body.flip_h = flip_left
		if _maren_hair != null:
			_maren_hair.frame = frame_idx
			_maren_hair.flip_h = flip_left
		if _maren_tool != null:
			_maren_tool.frame = frame_idx
			_maren_tool.flip_h = flip_left

	if _shop_light != null:
		var hour_f: float = TimeManager.get_hour_float()
		var night_factor: float = clampf((hour_f - 17.0) / 3.0, 0.0, 1.0)
		_shop_light.energy = night_factor * 0.72


func is_player_nearby() -> bool:
	return _player_nearby


func trigger_interact() -> void:
	EventBus.shop_requested.emit(shop_id)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = true
		_player_ref = body
		EventBus.interact_prompt_changed.emit("[E] Shop (Maren's Seeds)")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = false
		_player_ref = null
		EventBus.interact_prompt_changed.emit("")
