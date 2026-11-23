class_name DroppedItem
extends Node2D

## Pooled magnetic world item pickup displaying real Sunnyside World item PNGs.
## Zero runtime allocations: spawned/recycled cleanly by DroppedItemPool.

const POP_DURATION: float = 0.26
const POP_HEIGHT: float = 12.0
const PICKUP_DELAY: float = 0.28
const MAGNET_RADIUS_SQ: float = 44.0 * 44.0
const COLLECT_RADIUS_SQ: float = 9.0 * 9.0
const MAGNET_SPEED: float = 152.0
const BOB_SPEED: float = 4.2
const BOB_AMPLITUDE: float = 1.6

@onready var sprite: Sprite2D = $Sprite2D

var item_id: StringName = &""
var count: int = 0

var _active: bool = false
var _player_ref: Node2D = null
var _start_pos: Vector2 = Vector2.ZERO
var _land_pos: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0


func _ready() -> void:
	assert(sprite != null, "DroppedItem requires Sprite2D child.")
	deactivate()


func is_active() -> bool:
	return _active


func activate(
	spawn_pos: Vector2,
	target_land_pos: Vector2,
	p_item_id: StringName,
	p_count: int,
	player_node: Node2D
) -> void:
	assert(p_count > 0, "DroppedItem requires count > 0.")
	var data: ItemData = InventoryManager.get_item(p_item_id)
	assert(data != null and data.icon != null, "DroppedItem missing ItemData/icon for %s" % String(p_item_id))

	item_id = p_item_id
	count = p_count
	_player_ref = player_node
	_start_pos = spawn_pos
	_land_pos = target_land_pos
	_elapsed = 0.0
	_active = true

	global_position = spawn_pos
	sprite.texture = data.icon
	sprite.offset = Vector2(0.0, -4.0)
	sprite.modulate = Color.WHITE
	visible = true
	set_physics_process(true)


func deactivate() -> void:
	_active = false
	item_id = &""
	count = 0
	_player_ref = null
	visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var dt: float = minf(delta, 0.1)
	_elapsed += dt

	if _elapsed < POP_DURATION:
		var t: float = _elapsed / POP_DURATION
		var ground_pos: Vector2 = _start_pos.lerp(_land_pos, t)
		var arc_y: float = -sin(t * PI) * POP_HEIGHT
		global_position = ground_pos
		sprite.offset = Vector2(0.0, -4.0 + arc_y)
		return

	# Gentle idle bob after landing
	var bob_y: float = sin((_elapsed - POP_DURATION) * BOB_SPEED) * BOB_AMPLITUDE
	sprite.offset = Vector2(0.0, -4.0 + bob_y)

	if _elapsed < PICKUP_DELAY or _player_ref == null or not is_instance_valid(_player_ref):
		return

	var to_player: Vector2 = _player_ref.global_position - global_position
	var dist_sq: float = to_player.length_squared()
	if dist_sq <= COLLECT_RADIUS_SQ:
		var leftover: int = InventoryManager.add_item(item_id, count)
		var collected: int = count - leftover
		if collected > 0:
			EventBus.item_picked_up.emit(item_id, collected)
		if leftover <= 0:
			deactivate()
		else:
			count = leftover
	elif dist_sq <= MAGNET_RADIUS_SQ:
		var step: float = MAGNET_SPEED * dt
		global_position = global_position.move_toward(_player_ref.global_position, step)
