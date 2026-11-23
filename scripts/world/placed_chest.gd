class_name PlacedChest
extends StaticBody2D

## Interactive 16-slot persistent Storage Chest (res://scenes/props/placed_chest.tscn).
## Stores and loads its 16 item slots directly inside GridStateManager.custom_data["slots"]
## so chest contents persist seamlessly across scene transitions and overnight sleep.

const AP := preload("res://scripts/core/asset_paths.gd")
const CHEST_SLOT_COUNT: int = 16

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea

var scene_id: StringName = &"farm_sanctuary"
var grid_cell: Vector2i = Vector2i.ZERO

var _closed_tex: AtlasTexture = null
var _open_tex: AtlasTexture = null
var _player_nearby: bool = false
var _lid_open: bool = false


func _ready() -> void:
	add_to_group(&"placed_chests")
	assert(sprite != null and interact_area != null, "PlacedChest requires Sprite2D & InteractArea.")
	var ts_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	assert(ts_tex != null, "Missing Sunnyside tileset PNG.")

	_closed_tex = AtlasTexture.new()
	_closed_tex.atlas = ts_tex
	_closed_tex.region = Rect2(AP.TILE_CHEST_CLOSED.x * 16, AP.TILE_CHEST_CLOSED.y * 16, 16, 16)

	_open_tex = AtlasTexture.new()
	_open_tex.atlas = ts_tex
	_open_tex.region = Rect2(AP.TILE_CHEST_OPEN.x * 16, AP.TILE_CHEST_OPEN.y * 16, 16, 16)

	sprite.texture = _closed_tex
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


func bind_cell(p_scene_id: StringName, p_cell: Vector2i) -> void:
	scene_id = p_scene_id
	grid_cell = p_cell
	_ensure_slots_initialized()


func is_player_nearby() -> bool:
	return _player_nearby


func set_lid_open(is_open: bool) -> void:
	_lid_open = is_open
	if sprite != null:
		sprite.texture = _open_tex if _lid_open else _closed_tex


func trigger_interact() -> void:
	_ensure_slots_initialized()
	EventBus.chest_interacted.emit(scene_id, grid_cell)


func _ensure_slots_initialized() -> void:
	var data: Dictionary = GridStateManager.get_placed_object_data(scene_id, grid_cell)
	var existing: Array = data.get("slots", []) as Array if data.has("slots") and data["slots"] is Array else []
	if existing.size() != CHEST_SLOT_COUNT:
		var slots: Array[Dictionary] = []
		for i: int in range(CHEST_SLOT_COUNT):
			if i < existing.size() and existing[i] is Dictionary:
				var entry: Dictionary = existing[i] as Dictionary
				slots.append({
					"id": String(entry.get("id", "")),
					"count": int(entry.get("count", 0)),
					"charges": int(entry.get("charges", 0)),
				})
			else:
				slots.append({"id": "", "count": 0, "charges": 0})
		data["slots"] = slots
		GridStateManager.set_placed_object_data(scene_id, grid_cell, data)


static func get_chest_slots(p_scene_id: StringName, p_cell: Vector2i) -> Array[Dictionary]:
	var data: Dictionary = GridStateManager.get_placed_object_data(p_scene_id, p_cell)
	var out: Array[Dictionary] = []
	var raw: Array = data.get("slots", []) as Array
	for i: int in range(CHEST_SLOT_COUNT):
		if i < raw.size() and raw[i] is Dictionary:
			var d: Dictionary = raw[i] as Dictionary
			out.append({
				"id": String(d.get("id", "")),
				"count": int(d.get("count", 0)),
				"charges": int(d.get("charges", 0)),
			})
		else:
			out.append({"id": "", "count": 0, "charges": 0})
	return out


static func save_chest_slots(p_scene_id: StringName, p_cell: Vector2i, slots: Array[Dictionary]) -> void:
	var data: Dictionary = GridStateManager.get_placed_object_data(p_scene_id, p_cell)
	data["slots"] = slots.duplicate(true)
	GridStateManager.set_placed_object_data(p_scene_id, p_cell, data)


static func deposit_from_inventory_slot(p_scene_id: StringName, p_cell: Vector2i, inv_slot: int) -> bool:
	var item_id: StringName = InventoryManager.get_slot_item_id(inv_slot)
	var count: int = InventoryManager.get_slot_count(inv_slot)
	var charges: int = InventoryManager.get_slot_charges(inv_slot)
	if item_id == &"" or count <= 0:
		return false
	var item_data: ItemData = InventoryManager.get_item(item_id)
	if item_data == null:
		return false

	var slots: Array[Dictionary] = get_chest_slots(p_scene_id, p_cell)
	var max_stk: int = maxi(1, item_data.max_stack)
	var remaining: int = count

	# Pass 1: Merge into existing matching stacks inside chest
	if max_stk > 1:
		for i: int in range(CHEST_SLOT_COUNT):
			if StringName(String(slots[i]["id"])) == item_id and int(slots[i]["count"]) < max_stk:
				var space: int = max_stk - int(slots[i]["count"])
				var add_n: int = mini(space, remaining)
				slots[i]["count"] = int(slots[i]["count"]) + add_n
				remaining -= add_n
				if remaining == 0:
					break

	# Pass 2: Place into empty chest slots
	if remaining > 0:
		for i: int in range(CHEST_SLOT_COUNT):
			if String(slots[i]["id"]).is_empty():
				var add_n: int = mini(max_stk, remaining)
				slots[i]["id"] = String(item_id)
				slots[i]["count"] = add_n
				slots[i]["charges"] = charges
				remaining -= add_n
				if remaining == 0:
					break

	var moved: int = count - remaining
	if moved <= 0:
		return false
	InventoryManager.remove_from_slot(inv_slot, moved)
	save_chest_slots(p_scene_id, p_cell, slots)
	return true


static func withdraw_to_inventory(p_scene_id: StringName, p_cell: Vector2i, chest_slot: int) -> bool:
	assert(chest_slot >= 0 and chest_slot < CHEST_SLOT_COUNT, "Chest slot out of bounds.")
	var slots: Array[Dictionary] = get_chest_slots(p_scene_id, p_cell)
	var id_str: String = String(slots[chest_slot]["id"])
	var cnt: int = int(slots[chest_slot]["count"])
	if id_str.is_empty() or cnt <= 0:
		return false
	var item_id: StringName = StringName(id_str)
	var leftover: int = InventoryManager.add_item(item_id, cnt)
	var moved: int = cnt - leftover
	if moved <= 0:
		return false
	slots[chest_slot]["count"] = leftover
	if leftover <= 0:
		slots[chest_slot]["id"] = ""
		slots[chest_slot]["count"] = 0
		slots[chest_slot]["charges"] = 0
	save_chest_slots(p_scene_id, p_cell, slots)
	return true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = true
		EventBus.interact_prompt_changed.emit("[E] Open Storage Chest")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = false
		EventBus.interact_prompt_changed.emit("")
