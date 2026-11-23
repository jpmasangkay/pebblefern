class_name DroppedItemPool
extends Node2D

## Fixed-capacity pre-allocated object pool for magnetic DroppedItem pickups.
## Guarantees zero per-frame scene instantiations or queue_free() allocations.

const MAX_POOL_SIZE: int = 64
const DROPPED_ITEM_SCENE_PATH: String = "res://scenes/entities/dropped_item.tscn"

var _pool: Array[DroppedItem] = []
var _cursor: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	y_sort_enabled = true
	_rng.seed = 20260408
	var item_scene: PackedScene = load(DROPPED_ITEM_SCENE_PATH) as PackedScene
	assert(item_scene != null, "Missing dropped_item.tscn")
	_pool.resize(MAX_POOL_SIZE)
	for i: int in range(MAX_POOL_SIZE):
		var item: DroppedItem = item_scene.instantiate() as DroppedItem
		item.name = "DropSlot_%02d" % i
		add_child(item)
		item.deactivate()
		_pool[i] = item


func spawn_drop(world_pos: Vector2, item_id: StringName, count: int, player_ref: Node2D) -> DroppedItem:
	assert(count > 0, "DroppedItemPool.spawn_drop requires count > 0.")
	var slot: DroppedItem = _acquire_slot()
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(8.0, 15.0)
	var land_pos: Vector2 = world_pos + Vector2(cos(angle), sin(angle)) * radius
	slot.activate(world_pos, land_pos, item_id, count, player_ref)
	return slot


func spawn_scatter_drops(world_pos: Vector2, item_id: StringName, total_count: int, player_ref: Node2D) -> void:
	assert(total_count > 0, "spawn_scatter_drops requires total_count > 0.")
	# Split into up to 4 individual magnetic visual pickups for juicy harvest/chop feel
	var pieces: int = mini(total_count, 4)
	var base_each: int = floori(float(total_count) / float(pieces))
	var remainder: int = total_count % pieces
	for i: int in range(pieces):
		var piece_cnt: int = base_each + (1 if i < remainder else 0)
		spawn_drop(world_pos, item_id, piece_cnt, player_ref)


func get_active_count() -> int:
	var n: int = 0
	for item: DroppedItem in _pool:
		if item.is_active():
			n += 1
	return n


func clear_all_drops() -> void:
	for item: DroppedItem in _pool:
		if item != null and item.is_active():
			item.deactivate()


func _acquire_slot() -> DroppedItem:
	for offset: int in range(MAX_POOL_SIZE):
		var idx: int = (_cursor + offset) % MAX_POOL_SIZE
		if not _pool[idx].is_active():
			_cursor = (idx + 1) % MAX_POOL_SIZE
			return _pool[idx]
	# Bounded pool ring-buffer eviction: recycle oldest active slot rather than unbounded allocation
	var recycled: DroppedItem = _pool[_cursor]
	_cursor = (_cursor + 1) % MAX_POOL_SIZE
	return recycled
