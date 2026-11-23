class_name CropNode
extends Node2D

## Visual world entity for a planted crop inside WorldEntities (y_sort_enabled = true).
## Uses verified Sunnyside World V2.1 *_00.._04 PNGs with soil-centered bottom alignment.

@onready var sprite: Sprite2D = $Sprite2D

var crop_id: StringName = &""
var current_stage: int = 0
var is_withered: bool = false
var _pop_tween: Tween = null


func _ready() -> void:
	assert(sprite != null, "CropNode requires Sprite2D child.")


func configure(crop_data: CropData, stage: int, withered: bool, play_pop: bool = false) -> void:
	assert(crop_data != null, "CropNode.configure requires valid CropData.")
	crop_id = crop_data.crop_id
	current_stage = clampi(stage, 0, CropData.MATURE_STAGE)
	is_withered = withered

	var tex: Texture2D = crop_data.get_texture_for_stage(current_stage)
	assert(tex != null, "Missing crop stage texture for %s stage %d" % [String(crop_id), current_stage])
	sprite.texture = tex
	# Stage-0 planted seeds nestle centered inside the dark hollowed soil_04 pit; sprouts/crops root cleanly above it
	if current_stage == 0:
		sprite.offset = Vector2(0.0, -1.0)
	else:
		sprite.offset = Vector2(0.0, -float(tex.get_height()) * 0.5 + 3.0)
	sprite.modulate = Color(0.60, 0.50, 0.38, 1.0) if withered else Color.WHITE

	if play_pop and is_inside_tree():
		_play_pop_effect()


func _play_pop_effect() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	sprite.scale = Vector2(1.2, 0.8)
	_pop_tween = create_tween()
	_pop_tween.set_trans(Tween.TRANS_BACK)
	_pop_tween.set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(sprite, "scale", Vector2.ONE, 0.16)
