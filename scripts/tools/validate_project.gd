extends Node

## Full-project headless compiler & autoload integrity validator.
## Verifies all [autoload] singletons are active in dependency order and loads/compiles
## every .gd, .tscn, and .tres asset across autoload/, resources/, scripts/, and scenes/.

const SCAN_ROOTS: PackedStringArray = [
	"res://autoload",
	"res://resources",
	"res://scripts",
	"res://scenes",
]
const MAX_FILES: int = 1024


func _ready() -> void:
	# 1. Verify all 13 autoloads exist at /root in strict topological dependency order
	var root_node: Window = get_tree().root
	var expected_autoloads: PackedStringArray = [
		"EventBus",
		"InputModeManager",
		"VitalitySystem",
		"InventoryManager",
		"GridStateManager",
		"TimeManager",
		"AudioManager",
		"SceneTransition",
		"EconomyManager",
		"SocialManager",
		"QuestManager",
		"FestivalManager",
		"SaveManager",
	]
	for al_name: String in expected_autoloads:
		var node: Node = root_node.get_node_or_null(al_name)
		assert(node != null, "Missing registered autoload singleton at /root/%s" % al_name)

	# Verify exact dependency order
	var prev_idx: int = -1
	for al_name: String in expected_autoloads:
		var cur_idx: int = root_node.get_node(al_name).get_index()
		assert(cur_idx > prev_idx, "Autoload topological order violation at %s" % al_name)
		prev_idx = cur_idx
	print("[ValidateProject] PASS: All 13 autoloads registered in dependency order.")

	# 2. Recursively collect and load/compile EVERY .gd, .tres, and .tscn file
	var files: PackedStringArray = PackedStringArray()
	for r: String in SCAN_ROOTS:
		_collect_files(r, files, 0)

	var gd_ok: int = 0
	var tscn_ok: int = 0
	var tres_ok: int = 0

	for path: String in files:
		if path.ends_with(".gd"):
			var scr: Script = ResourceLoader.load(path) as Script
			assert(scr != null, "Failed to load GDScript: %s" % path)
			assert(scr.can_instantiate(), "GDScript failed to compile cleanly: %s" % path)
			gd_ok += 1
		elif path.ends_with(".tres"):
			var res: Resource = ResourceLoader.load(path)
			assert(res != null, "Failed to load Resource: %s" % path)
			tres_ok += 1
		elif path.ends_with(".tscn"):
			var packed: PackedScene = ResourceLoader.load(path) as PackedScene
			assert(packed != null, "Failed to load PackedScene: %s" % path)
			assert(packed.can_instantiate(), "PackedScene cannot instantiate: %s" % path)
			tscn_ok += 1

	print("[ValidateProject] PASS: 0 errors across %d GDScripts, %d scenes, and %d resources." % [gd_ok, tscn_ok, tres_ok])
	get_tree().quit(0)


func _collect_files(dir_path: String, out: PackedStringArray, depth: int) -> void:
	assert(depth <= 16, "Directory traversal depth cap exceeded.")
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "" and out.size() < MAX_FILES:
		if not entry.begins_with("."):
			var full: String = dir_path.path_join(entry)
			if d.current_is_dir():
				_collect_files(full, out, depth + 1)
			elif entry.ends_with(".gd") or entry.ends_with(".tscn") or entry.ends_with(".tres"):
				out.append(full)
		entry = d.get_next()
	d.list_dir_end()
