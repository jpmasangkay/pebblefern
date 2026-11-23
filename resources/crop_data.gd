class_name CropData
extends Resource

## Data definition for each of the 11 Sunnyside World crops (5 growth stages _00.._04 + harvest _05).

enum Season {
	BLOOM = 0,
	SUN = 1,
	HARVEST = 2,
	FROST = 3,
}

const STAGE_COUNT: int = 5
const MATURE_STAGE: int = 4

@export var crop_id: StringName = &""
@export var display_name: String = ""
@export var botanical_name: String = ""
@export var seed_item_id: StringName = &""
@export var harvest_item_id: StringName = &""
@export var seasons: PackedInt32Array = PackedInt32Array([Season.BLOOM])
@export var days_to_mature: int = 4
@export var stage_textures: Array[Texture2D] = []
@export var harvest_icon: Texture2D = null
@export var harvest_min_yield: int = 1
@export var harvest_max_yield: int = 1
@export var regrows: bool = false
@export var regrow_days: int = 0


func is_valid_season(season_index: int) -> bool:
	for s: int in seasons:
		if s == season_index:
			return true
	return false


func get_stage_for_days(days_grown: int) -> int:
	assert(days_to_mature > 0, "CropData '%s' requires days_to_mature > 0." % String(crop_id))
	if days_grown <= 0:
		return 0
	if days_grown >= days_to_mature:
		return MATURE_STAGE
	var ratio: float = float(days_grown) / float(days_to_mature)
	return clampi(int(floorf(ratio * float(MATURE_STAGE))), 1, MATURE_STAGE - 1)


func get_texture_for_stage(stage: int) -> Texture2D:
	assert(stage_textures.size() == STAGE_COUNT, "CropData '%s' must have exactly 5 stage textures." % String(crop_id))
	return stage_textures[clampi(stage, 0, MATURE_STAGE)]
