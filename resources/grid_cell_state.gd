class_name GridCellState
extends RefCounted

## Typed persistent state for a single farm/world grid cell (soil, water, crop, or placed object).
## Extracted as a standalone class_name so scripts never reference an autoload inside type annotations.

var is_tilled: bool = false
var is_watered: bool = false
var crop_id: StringName = &""
var days_grown: int = 0
var is_withered: bool = false
var placed_object_id: StringName = &""
var custom_data: Dictionary = {}


func is_empty() -> bool:
	return (
		not is_tilled
		and not is_watered
		and crop_id == &""
		and placed_object_id == &""
	)


func to_dict() -> Dictionary:
	return {
		"tilled": is_tilled,
		"watered": is_watered,
		"crop": String(crop_id),
		"days": days_grown,
		"withered": is_withered,
		"obj": String(placed_object_id),
		"meta": custom_data.duplicate(true),
	}


static func from_dict(d: Dictionary) -> GridCellState:
	var st: GridCellState = GridCellState.new()
	st.is_tilled = bool(d.get("tilled", false))
	st.is_watered = bool(d.get("watered", false))
	st.crop_id = StringName(String(d.get("crop", "")))
	st.days_grown = maxi(0, int(d.get("days", 0)))
	st.is_withered = bool(d.get("withered", false))
	st.placed_object_id = StringName(String(d.get("obj", "")))
	var meta: Variant = d.get("meta", {})
	if meta is Dictionary:
		st.custom_data = (meta as Dictionary).duplicate(true)
	return st
