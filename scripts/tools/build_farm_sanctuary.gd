extends Node

## Compiles Pebblefern's expanded 96x60 tile (1536x960 px) 5-district island world
## (res://scenes/world/farm_sanctuary.tscn) via IslandWorldBuilder and verified .tscn prefabs.
## Run via: Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/tools/build_farm_sanctuary.tscn

const FARM_SCRIPT_PATH: String = "res://scripts/world/farm_sanctuary.gd"


func _ready() -> void:
	var root: Node2D = Node2D.new()
	root.name = "FarmSanctuary"
	root.script = load(FARM_SCRIPT_PATH) as Script

	var compiled: IslandWorldBuilder.BuildResult = IslandWorldBuilder.compile_island_into_root(root, true)
	root.set("world_bounds_px", compiled.world_rect_px)

	_set_owner_recursive(root, root)
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	assert(pack_err == OK, "Failed to pack farm_sanctuary.tscn: %d" % pack_err)
	var save_err: Error = ResourceSaver.save(packed, "res://scenes/world/farm_sanctuary.tscn")
	assert(save_err == OK, "Failed to save farm_sanctuary.tscn: %d" % save_err)

	print("[BuildFarm] Compiled 96x60 island farm_sanctuary.tscn (%dx%d tiles, %d garden cells, %d freshwater cells, spawn=%s)" % [
		compiled.map_size_tiles.x,
		compiled.map_size_tiles.y,
		compiled.garden_cells.size(),
		compiled.water_cells.size(),
		str(compiled.player_spawn_px),
	])
	root.free()
	get_tree().quit(0)


func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_root
		# Do NOT recurse into instantiated PackedScene prefabs so they stay linked as clean scene instances!
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, owner_root)
