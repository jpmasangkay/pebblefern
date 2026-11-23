class_name ItemData
extends Resource

## Base inventory item resource for tools, seeds, crops, resources, forage, and craftables.

enum Category {
	TOOL = 0,
	SEED = 1,
	CROP = 2,
	RESOURCE = 3,
	FORAGE = 4,
	CRAFTABLE = 5,
	CONSUMABLE = 6,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.RESOURCE
@export var icon: Texture2D = null
@export var icon_tint: Color = Color.WHITE
@export var overlay_icon: Texture2D = null
@export var max_stack: int = 99
@export var buy_price: int = 0
@export var sell_price: int = 0
@export var vitality_restore: float = 0.0
@export var crop_id: StringName = &""
@export var placeable_object_id: StringName = &""


func is_stackable() -> bool:
	return max_stack > 1


func is_edible() -> bool:
	return vitality_restore > 0.0


func is_placeable() -> bool:
	return category == Category.CRAFTABLE and placeable_object_id != &""


func is_sellable() -> bool:
	return sell_price > 0 and category != Category.TOOL
