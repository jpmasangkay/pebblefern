@tool
class_name StumpNode
extends StaticBody2D

## Choppable tree stump prop supporting 3 verified Sunnyside World sizes (Small, Medium, Large).

const AP := preload("res://scripts/core/asset_paths.gd")

enum StumpSize {
	SMALL = 0,
	MEDIUM = 1,
	LARGE = 2,
}

@export_enum("Small", "Medium", "Large") var stump_size: int = StumpSize.MEDIUM:
	set(value):
		stump_size = clampi(value, StumpSize.SMALL, StumpSize.LARGE)
		if is_inside_tree():
			_apply_visual()

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	assert(sprite != null, "StumpNode requires Sprite2D child.")
	_apply_visual()


func _apply_visual() -> void:
	var atlas_tex: AtlasTexture = sprite.texture as AtlasTexture
	if atlas_tex == null:
		return
	var coords: Vector2i = AP.TILE_STUMP_MEDIUM
	match stump_size:
		StumpSize.SMALL:
			coords = AP.TILE_STUMP_SMALL
		StumpSize.MEDIUM:
			coords = AP.TILE_STUMP_MEDIUM
		StumpSize.LARGE:
			coords = AP.TILE_STUMP_LARGE
	var unique_tex: AtlasTexture = atlas_tex.duplicate() as AtlasTexture
	unique_tex.region = Rect2(coords.x * 16, coords.y * 16, 16, 16)
	sprite.texture = unique_tex
