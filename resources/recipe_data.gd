class_name RecipeData
extends Resource

## Crafting recipe definition mapping bounded input ingredients to a crafted output item.

const MAX_INGREDIENTS: int = 4

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var output_item_id: StringName = &""
@export var output_count: int = 1
@export var ingredient_ids: Array[StringName] = []
@export var ingredient_counts: PackedInt32Array = PackedInt32Array()


func get_ingredient_count() -> int:
	assert(ingredient_ids.size() == ingredient_counts.size(), "Recipe '%s' ingredient array mismatch." % String(id))
	return mini(ingredient_ids.size(), MAX_INGREDIENTS)
