extends Node

## Persistent grid state across all scenes tracking tilled soil, watering, planted crops,
## growth stages, withering, and placed craftable objects so crops grow overnight even when unloaded.

const MAX_CELLS_PER_SCENE: int = 16384

var _scene_grids: Dictionary = {} # StringName -> Dictionary[Vector2i, GridCellState]
var _destroyed_resources: Dictionary = {} # StringName -> Dictionary[Vector2i, bool]
var _harvested_bushes: Dictionary = {} # StringName -> Dictionary[Vector2i, bool]
var _harvest_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_harvest_rng.seed = 20260407


func seed_rng(new_seed: int) -> void:
	_harvest_rng.seed = new_seed


func _get_or_create_scene(scene_id: StringName) -> Dictionary:
	if not _scene_grids.has(scene_id):
		_scene_grids[scene_id] = {}
	return _scene_grids[scene_id] as Dictionary


func get_scene_cells(scene_id: StringName) -> Dictionary:
	return _scene_grids.get(scene_id, {}) as Dictionary


func get_cell(scene_id: StringName, cell: Vector2i) -> GridCellState:
	var grid: Dictionary = _scene_grids.get(scene_id, {}) as Dictionary
	return grid.get(cell, null) as GridCellState


func has_cell(scene_id: StringName, cell: Vector2i) -> bool:
	var grid: Dictionary = _scene_grids.get(scene_id, {}) as Dictionary
	return grid.has(cell)


func till_cell(scene_id: StringName, cell: Vector2i) -> bool:
	var grid: Dictionary = _get_or_create_scene(scene_id)
	assert(grid.size() < MAX_CELLS_PER_SCENE, "GridStateManager cell cap exceeded for %s" % String(scene_id))
	var st: GridCellState = grid.get(cell, null) as GridCellState
	if st != null:
		if st.is_tilled or st.placed_object_id != &"":
			return false
	else:
		st = GridCellState.new()
		grid[cell] = st
	st.is_tilled = true
	st.is_watered = false
	EventBus.grid_cell_changed.emit(scene_id, cell)
	return true


func plant_crop(scene_id: StringName, cell: Vector2i, crop_id: StringName) -> bool:
	var crop_data: CropData = InventoryManager.get_crop(crop_id)
	if crop_data == null:
		return false
	var st: GridCellState = get_cell(scene_id, cell)
	if st == null or not st.is_tilled or st.crop_id != &"" or st.placed_object_id != &"":
		return false
	st.crop_id = crop_id
	st.days_grown = 0
	st.is_withered = false
	EventBus.grid_cell_changed.emit(scene_id, cell)
	return true


func water_cell(scene_id: StringName, cell: Vector2i) -> bool:
	var st: GridCellState = get_cell(scene_id, cell)
	if st == null or not st.is_tilled:
		return false
	if st.is_watered:
		return true
	st.is_watered = true
	EventBus.grid_cell_changed.emit(scene_id, cell)
	return true


func get_crop_stage(scene_id: StringName, cell: Vector2i) -> int:
	var st: GridCellState = get_cell(scene_id, cell)
	if st == null or st.crop_id == &"":
		return -1
	var crop_data: CropData = InventoryManager.get_crop(st.crop_id)
	if crop_data == null:
		return -1
	return crop_data.get_stage_for_days(st.days_grown)


func is_crop_mature(scene_id: StringName, cell: Vector2i) -> bool:
	var st: GridCellState = get_cell(scene_id, cell)
	if st == null or st.crop_id == &"" or st.is_withered:
		return false
	var crop_data: CropData = InventoryManager.get_crop(st.crop_id)
	if crop_data == null:
		return false
	return st.days_grown >= crop_data.days_to_mature


## Harvests a mature crop and returns { "item_id": StringName, "count": int, "crop_id": StringName } or empty Dict.
func harvest_cell(scene_id: StringName, cell: Vector2i) -> Dictionary:
	if not is_crop_mature(scene_id, cell):
		return {}
	var st: GridCellState = get_cell(scene_id, cell)
	var crop_data: CropData = InventoryManager.get_crop(st.crop_id)
	assert(crop_data != null, "Missing CropData during harvest: %s" % String(st.crop_id))

	var yield_count: int = crop_data.harvest_min_yield
	if crop_data.harvest_max_yield > crop_data.harvest_min_yield:
		yield_count = _harvest_rng.randi_range(crop_data.harvest_min_yield, crop_data.harvest_max_yield)

	var result: Dictionary = {
		"item_id": crop_data.harvest_item_id,
		"count": yield_count,
		"crop_id": crop_data.crop_id,
	}

	if crop_data.regrows and crop_data.regrow_days > 0:
		st.days_grown = maxi(0, crop_data.days_to_mature - crop_data.regrow_days)
	else:
		st.crop_id = &""
		st.days_grown = 0
		st.is_withered = false

	EventBus.grid_cell_changed.emit(scene_id, cell)
	return result


func clear_crop(scene_id: StringName, cell: Vector2i) -> bool:
	var st: GridCellState = get_cell(scene_id, cell)
	if st == null or st.crop_id == &"":
		return false
	st.crop_id = &""
	st.days_grown = 0
	st.is_withered = false
	EventBus.grid_cell_changed.emit(scene_id, cell)
	return true


func place_object(scene_id: StringName, cell: Vector2i, object_id: StringName, initial_data: Dictionary = {}) -> bool:
	assert(object_id != &"", "place_object requires non-empty object_id.")
	var grid: Dictionary = _get_or_create_scene(scene_id)
	assert(grid.size() < MAX_CELLS_PER_SCENE, "GridStateManager cell cap exceeded for %s" % String(scene_id))
	var st: GridCellState = grid.get(cell, null) as GridCellState
	if st != null:
		if st.placed_object_id != &"" or st.crop_id != &"" or st.is_tilled:
			return false
	else:
		st = GridCellState.new()
		grid[cell] = st
	st.placed_object_id = object_id
	st.custom_data = initial_data.duplicate(true)
	EventBus.object_placed.emit(scene_id, cell, object_id)
	EventBus.grid_cell_changed.emit(scene_id, cell)
	return true


func remove_object(scene_id: StringName, cell: Vector2i) -> StringName:
	var st: GridCellState = get_cell(scene_id, cell)
	if st == null or st.placed_object_id == &"":
		return &""
	var removed_id: StringName = st.placed_object_id
	st.placed_object_id = &""
	st.custom_data.clear()
	EventBus.object_removed.emit(scene_id, cell)
	EventBus.grid_cell_changed.emit(scene_id, cell)
	return removed_id


func get_placed_object_id(scene_id: StringName, cell: Vector2i) -> StringName:
	var st: GridCellState = get_cell(scene_id, cell)
	return st.placed_object_id if st != null else &""


func get_placed_object_data(scene_id: StringName, cell: Vector2i) -> Dictionary:
	var st: GridCellState = get_cell(scene_id, cell)
	return st.custom_data if st != null else {}


func set_placed_object_data(scene_id: StringName, cell: Vector2i, custom_data: Dictionary) -> void:
	var st: GridCellState = get_cell(scene_id, cell)
	if st == null or st.placed_object_id == &"":
		return
	st.custom_data = custom_data.duplicate(true)


func get_all_placed_objects(scene_id: StringName) -> Dictionary:
	var grid: Dictionary = _scene_grids.get(scene_id, {}) as Dictionary
	var out: Dictionary = {}
	for cell_key: Variant in grid.keys():
		var st: GridCellState = grid[cell_key] as GridCellState
		if st != null and st.placed_object_id != &"":
			out[cell_key] = st
	return out


func is_cell_protected_by_scarecrow(scene_id: StringName, cell: Vector2i, radius: int = 5) -> bool:
	var grid: Dictionary = _scene_grids.get(scene_id, {}) as Dictionary
	for cell_key: Variant in grid.keys():
		var st: GridCellState = grid[cell_key] as GridCellState
		if st != null and st.placed_object_id == &"scarecrow":
			var sc_cell: Vector2i = cell_key as Vector2i
			if absi(sc_cell.x - cell.x) <= radius and absi(sc_cell.y - cell.y) <= radius:
				return true
	return false


## Directly sets a cell's crop growth state (useful for deterministic overnight tests and demos).
func set_crop_state(scene_id: StringName, cell: Vector2i, crop_id: StringName, days_grown: int, watered: bool) -> void:
	var grid: Dictionary = _get_or_create_scene(scene_id)
	var st: GridCellState = grid.get(cell, null) as GridCellState
	if st == null:
		st = GridCellState.new()
		grid[cell] = st
	st.is_tilled = true
	st.is_watered = watered
	st.crop_id = crop_id
	st.days_grown = maxi(0, days_grown)
	st.is_withered = false
	EventBus.grid_cell_changed.emit(scene_id, cell)


## Advances every scene's crops by 1 day (grows watered crops, withers out-of-season crops, handles rain).
func advance_day(new_season_index: int, is_raining: bool) -> void:
	for scene_key: Variant in _scene_grids.keys():
		var scene_id: StringName = scene_key as StringName
		var grid: Dictionary = _scene_grids[scene_id] as Dictionary
		var changed_cells: Array[Vector2i] = []
		for cell_key: Variant in grid.keys():
			var cell: Vector2i = cell_key as Vector2i
			var st: GridCellState = grid[cell] as GridCellState
			var modified: bool = false
			if st.crop_id != &"":
				var crop_data: CropData = InventoryManager.get_crop(st.crop_id)
				if crop_data != null:
					if not crop_data.is_valid_season(new_season_index):
						if not st.is_withered:
							st.is_withered = true
							modified = true
					elif st.is_watered and not st.is_withered:
						if st.days_grown < crop_data.days_to_mature:
							st.days_grown += 1
							modified = true
			var next_watered: bool = is_raining and st.is_tilled
			if st.is_watered != next_watered:
				st.is_watered = next_watered
				modified = true
			if modified:
				changed_cells.append(cell)
		for cell: Vector2i in changed_cells:
			EventBus.grid_cell_changed.emit(scene_id, cell)
	# Wild berry bushes regrow fresh berries every morning!
	_harvested_bushes.clear()


func mark_resource_destroyed(scene_id: StringName, cell: Vector2i) -> void:
	if not _destroyed_resources.has(scene_id):
		_destroyed_resources[scene_id] = {}
	var bucket: Dictionary = _destroyed_resources[scene_id] as Dictionary
	if bucket.size() < MAX_CELLS_PER_SCENE:
		bucket[cell] = true


func is_resource_destroyed(scene_id: StringName, cell: Vector2i) -> bool:
	var bucket: Dictionary = _destroyed_resources.get(scene_id, {}) as Dictionary
	return bucket.has(cell)


func mark_bush_harvested(scene_id: StringName, cell: Vector2i) -> void:
	if not _harvested_bushes.has(scene_id):
		_harvested_bushes[scene_id] = {}
	var bucket: Dictionary = _harvested_bushes[scene_id] as Dictionary
	if bucket.size() < MAX_CELLS_PER_SCENE:
		bucket[cell] = true


func is_bush_harvested(scene_id: StringName, cell: Vector2i) -> bool:
	var bucket: Dictionary = _harvested_bushes.get(scene_id, {}) as Dictionary
	return bucket.has(cell)


func clear_scene(scene_id: StringName) -> void:
	_scene_grids.erase(scene_id)
	_destroyed_resources.erase(scene_id)
	_harvested_bushes.erase(scene_id)


func clear_all() -> void:
	_scene_grids.clear()
	_destroyed_resources.clear()
	_harvested_bushes.clear()


func serialize_all() -> Dictionary:
	var out: Dictionary = {}
	for scene_key: Variant in _scene_grids.keys():
		var scene_name: String = String(scene_key)
		var grid: Dictionary = _scene_grids[scene_key] as Dictionary
		var cells_dict: Dictionary = {}
		for cell_key: Variant in grid.keys():
			var c: Vector2i = cell_key as Vector2i
			var st: GridCellState = grid[cell_key] as GridCellState
			if not st.is_empty():
				cells_dict["%d,%d" % [c.x, c.y]] = st.to_dict()
		out[scene_name] = cells_dict
	return out


func deserialize_all(data: Dictionary) -> void:
	_scene_grids.clear()
	for scene_name_var: Variant in data.keys():
		var scene_id: StringName = StringName(String(scene_name_var))
		var grid: Dictionary = _get_or_create_scene(scene_id)
		var cells_dict: Dictionary = data[scene_name_var] as Dictionary
		var loaded: int = 0
		for coord_key: Variant in cells_dict.keys():
			if loaded >= MAX_CELLS_PER_SCENE:
				break
			var parts: PackedStringArray = String(coord_key).split(",")
			if parts.size() == 2:
				var cell: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
				grid[cell] = GridCellState.from_dict(cells_dict[coord_key] as Dictionary)
				loaded += 1


func serialize_world_state() -> Dictionary:
	return {
		"grids": serialize_all(),
		"destroyed_resources": _serialize_cell_set_map(_destroyed_resources),
		"harvested_bushes": _serialize_cell_set_map(_harvested_bushes),
	}


func deserialize_world_state(data: Dictionary) -> void:
	clear_all()
	if data.has("grids"):
		deserialize_all(data["grids"] as Dictionary)
	else:
		deserialize_all(data)
	_destroyed_resources = _deserialize_cell_set_map(data.get("destroyed_resources", {}) as Dictionary)
	_harvested_bushes = _deserialize_cell_set_map(data.get("harvested_bushes", {}) as Dictionary)


func _serialize_cell_set_map(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for scene_key: Variant in src.keys():
		var bucket: Dictionary = src[scene_key] as Dictionary
		var coords: Array[String] = []
		for cell_key: Variant in bucket.keys():
			var c: Vector2i = cell_key as Vector2i
			coords.append("%d,%d" % [c.x, c.y])
		out[String(scene_key)] = coords
	return out


func _deserialize_cell_set_map(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for scene_name_var: Variant in src.keys():
		var scene_id: StringName = StringName(String(scene_name_var))
		var bucket: Dictionary = {}
		var arr: Array = src[scene_name_var] as Array
		var limit: int = mini(arr.size(), MAX_CELLS_PER_SCENE)
		for i: int in range(limit):
			var parts: PackedStringArray = String(arr[i]).split(",")
			if parts.size() == 2:
				bucket[Vector2i(int(parts[0]), int(parts[1]))] = true
		out[scene_id] = bucket
	return out
