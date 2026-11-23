@tool
class_name BerryBush
extends StaticBody2D

## Verified 32x32 Sunnyside World berry bush (Red or Orange berry variant).
## Supports smart harvesting (LMB or E) dropping Wild Berries, persisting harvested state across
## door transitions, and regrowing fresh berries overnight.

const TILE_SIZE: float = 16.0

@export_enum("RedBerries", "OrangeBerries", "Plain") var berry_variant: int = 0:
	set(value):
		berry_variant = clampi(value, 0, 2)
		if is_inside_tree() and sprite != null:
			_apply_variant()

@onready var sprite: Sprite2D = $Sprite2D

var _base_ripe_variant: int = 0
var _shake_tween: Tween = null


func _ready() -> void:
	assert(sprite != null, "BerryBush requires Sprite2D child.")
	_base_ripe_variant = berry_variant
	if not Engine.is_editor_hint():
		add_to_group(&"berry_bushes")
		if _base_ripe_variant < 2 and GridStateManager.is_bush_harvested(&"farm_sanctuary", get_grid_cell()):
			berry_variant = 2
		EventBus.day_started.connect(_on_day_started)
	_apply_variant()


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func get_grid_cell() -> Vector2i:
	return Vector2i(floori(global_position.x / TILE_SIZE), floori(global_position.y / TILE_SIZE))


func is_ripe() -> bool:
	return berry_variant == 0 or berry_variant == 1


func harvest_berries(drop_pool: DroppedItemPool, player_ref: Node2D, scene_id: StringName = &"farm_sanctuary") -> bool:
	if not is_ripe():
		return false
	berry_variant = 2
	GridStateManager.mark_bush_harvested(scene_id, get_grid_cell())
	_play_shake()
	if drop_pool != null:
		drop_pool.spawn_scatter_drops(global_position + Vector2(0.0, -4.0), &"wild_berry", 2, player_ref)
	return true


func _on_day_started(_day: int, _season: int, _year: int, _weather: StringName) -> void:
	if _base_ripe_variant < 2 and berry_variant == 2:
		berry_variant = _base_ripe_variant


func _play_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	sprite.position.x = 0.0
	_shake_tween = create_tween()
	_shake_tween.tween_property(sprite, "position:x", -2.0, 0.04)
	_shake_tween.tween_property(sprite, "position:x", 2.0, 0.04)
	_shake_tween.tween_property(sprite, "position:x", 0.0, 0.04)


func _apply_variant() -> void:
	var atlas_tex: AtlasTexture = sprite.texture as AtlasTexture
	if atlas_tex == null:
		return
	var row_start: int = 3 # Red berries: cols 49..50, rows 3..4
	match berry_variant:
		0:
			row_start = 3
		1:
			row_start = 5 # Orange berries: cols 49..50, rows 5..6
		2:
			row_start = 1 # Plain green bush: cols 49..50, rows 1..2
	var unique_tex: AtlasTexture = atlas_tex.duplicate() as AtlasTexture
	unique_tex.region = Rect2(49 * 16, row_start * 16, 32, 32)
	sprite.texture = unique_tex
