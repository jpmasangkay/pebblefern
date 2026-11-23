class_name NpcInterior
extends Node2D

## Dedicated themed NPC house interior (res://scenes/world/npc_interior.tscn).
## Clean straight timber cabin walls over dark backdrop with unique furniture per resident:
##   - &"maren"  : Maren's Botanist Cottage (potted plants, bookshelves, seed crates, warm rug)
##   - &"kaelen" : Kaelen's Forge Home (stone hearth/furnace, heavy table, iron/stone crates, workbench)
##   - &"aldric" : Aldric's Village Hall (long wooden desk, bookshelves, framed paintings, grand red carpet)
##   - &"bram"   : Bram's Coastal Cabin (nautical barrels, blue accents, cozy bed & hearth)
##   - &"lyra"   : Lyra's Woodland Cabin (flowers on real wooden tables, rustic bookshelves, warm fireplace)
## Strictly blocks all outdoor farming/foraging/fishing tools via ActionValidator,
## and returns smoothly to the exact house's doorstep via SceneTransition.exit_interior().

const AP := preload("res://scripts/core/asset_paths.gd")
const FARMHOUSE_INTERIOR_PATH: String = "res://scenes/world/farmhouse_interior.tscn"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"
const INVENTORY_MODAL_SCENE_PATH: String = "res://scenes/ui/inventory_modal.tscn"
const PAUSE_MODAL_SCENE_PATH: String = "res://scenes/ui/pause_modal.tscn"
const MOBILE_CONTROLS_SCENE_PATH: String = "res://scenes/ui/mobile_controls.tscn"
const PauseModalScript := preload("res://scripts/ui/pause_modal.gd")
const MobileControlsScript := preload("res://scripts/ui/mobile_controls.gd")

@export var room_bounds_px: Rect2i = Rect2i(-48, -16, 320, 212)
@export var active_theme_id: StringName = &"maren"

@onready var player: Player = $WorldEntities/Player
@onready var exit_portal: Area2D = $ExitDoorPortal
@onready var rug_layer: TileMapLayer = $InteriorRugs
@onready var furn_layer: TileMapLayer = $InteriorFurniture
@onready var details_root: Node2D = $InteriorDetails
@onready var furn_body: StaticBody2D = $FurnitureCollisions
@onready var hearth_light: PointLight2D = get_node_or_null("HearthLight") as PointLight2D
@onready var room_modulate: CanvasModulate = get_node_or_null("InteriorModulate") as CanvasModulate

var hud: GameplayHUD = null
var inventory_modal: InventoryModal = null
var pause_modal: PauseModalScript = null
var mobile_controls: MobileControlsScript = null

var _tileset_tex: Texture2D = null
var _strip_sprite_script: Script = null
var _is_player_at_exit: bool = false
var _flicker_time: float = 0.0
var _hud_user_visible: bool = true
var _theme_title: String = "Cottage"


func _ready() -> void:
	assert(player != null, "NpcInterior requires WorldEntities/Player.")
	assert(exit_portal != null, "NpcInterior requires ExitDoorPortal Area2D.")
	assert(rug_layer != null and furn_layer != null and details_root != null and furn_body != null, "NpcInterior missing theme containers.")

	_tileset_tex = load(AP.TILESET_16PX) as Texture2D
	_strip_sprite_script = load("res://scripts/world/strip_sprite_2d.gd") as Script
	assert(_tileset_tex != null and _strip_sprite_script != null, "NpcInterior missing tileset or strip script.")

	player.set_camera_bounds(room_bounds_px)
	player.camera.position = Vector2.ZERO
	player.set_action_handlers(_validate_indoor_action, _execute_indoor_action)

	var loaded_state: Dictionary = SaveManager.consume_loaded_player_state()
	var incoming_id: StringName = SceneTransition.consume_interior_id()
	if incoming_id != &"":
		active_theme_id = incoming_id
	elif bool(loaded_state.get("valid", false)) and StringName(loaded_state.get("interior_id", &"")) != &"":
		active_theme_id = loaded_state["interior_id"] as StringName
	configure_theme(active_theme_id)

	if bool(loaded_state.get("valid", false)):
		player.global_position = loaded_state["position"] as Vector2
	else:
		player.global_position = get_entry_spawn_world_position()
	player.set_facing_cardinal(Vector2i(0, -1))

	exit_portal.body_entered.connect(_on_exit_entered)
	exit_portal.body_exited.connect(_on_exit_exited)

	_setup_ui()

	EventBus.player_interacted.connect(_on_player_interacted)
	EventBus.pass_out_triggered.connect(_on_pass_out_triggered)
	EventBus.interior_entered.emit(active_theme_id)
	_refresh_interior_lighting()


func _exit_tree() -> void:
	if EventBus.player_interacted.is_connected(_on_player_interacted):
		EventBus.player_interacted.disconnect(_on_player_interacted)
	if EventBus.pass_out_triggered.is_connected(_on_pass_out_triggered):
		EventBus.pass_out_triggered.disconnect(_on_pass_out_triggered)
	EventBus.interact_prompt_changed.emit("")
	EventBus.interior_exited.emit(active_theme_id)


func configure_theme(theme_id: StringName) -> void:
	active_theme_id = theme_id
	rug_layer.clear()
	furn_layer.clear()
	for c: Node in details_root.get_children():
		c.queue_free()
	for c: Node in furn_body.get_children():
		c.queue_free()

	# Always draw the crisp red woven exit doormat on the dark-oak vestibule (x=6..7, y=7)
	rug_layer.set_cell(Vector2i(6, 7), 0, Vector2i(47, 36))
	rug_layer.set_cell(Vector2i(7, 7), 0, Vector2i(47, 36))

	match theme_id:
		&"maren":
			_theme_title = "Maren's Cottage"
			_build_theme_maren()
		&"kaelen":
			_theme_title = "Kaelen's Forge"
			_build_theme_kaelen()
		&"aldric":
			_theme_title = "Village Hall"
			_build_theme_aldric()
		&"bram":
			_theme_title = "Bram's Cabin"
			_build_theme_bram()
		&"lyra":
			_theme_title = "Lyra's Cabin"
			_build_theme_lyra()
		_:
			_theme_title = "Maren's Cottage"
			_build_theme_maren()


func get_theme_title() -> String:
	return _theme_title


func _build_theme_maren() -> void:
	# Warm 3x3 patterned center rug (x=5..7, y=3..5) + bedside rug (x=2, y=3)
	rug_layer.set_cell(Vector2i(2, 3), 0, Vector2i(47, 36))
	for ry: int in range(3):
		for rx: int in range(3):
			rug_layer.set_cell(Vector2i(5 + rx, 3 + ry), 0, Vector2i(40 + rx, 35 + ry))

	# Cozy Red Bed (x=1, y=2..3) + Twin Botanist Bookshelves (x=2, x=8, y=1..2) + Real Wooden End Tables (x=3, x=9)
	furn_layer.set_cell(Vector2i(1, 2), 0, Vector2i(39, 33))
	furn_layer.set_cell(Vector2i(1, 3), 0, Vector2i(39, 34))
	furn_layer.set_cell(Vector2i(2, 1), 0, Vector2i(45, 33))
	furn_layer.set_cell(Vector2i(2, 2), 0, Vector2i(45, 34))
	furn_layer.set_cell(Vector2i(3, 1), 0, Vector2i(49, 33))
	furn_layer.set_cell(Vector2i(3, 2), 0, Vector2i(49, 34))
	furn_layer.set_cell(Vector2i(8, 1), 0, Vector2i(42, 33))
	furn_layer.set_cell(Vector2i(8, 2), 0, Vector2i(42, 34))
	furn_layer.set_cell(Vector2i(9, 1), 0, Vector2i(49, 33))
	furn_layer.set_cell(Vector2i(9, 2), 0, Vector2i(49, 34))
	_place_stone_hearth(10, 0)

	# Potted Sunflower & White Daisies resting cleanly ON TOP of wooden end tables!
	_add_atlas_sprite("MarenDaisies", 53, 32, 1, 1, Vector2(3 * 16, 1 * 16 + 5))
	_add_atlas_sprite("MarenSunflower", 52, 32, 1, 1, Vector2(9 * 16, 1 * 16 + 5))

	# Seed & Harvest Crates tucked neatly along right wall (x=11..12, y=5..6)
	_add_atlas_sprite("SeedCrateBack", 39, 10, 1, 1, Vector2(11 * 16 + 4, 4 * 16 + 10))
	_add_atlas_sprite("SeedCrateFront", 39, 9, 1, 1, Vector2(11 * 16 + 4, 5 * 16 + 8))
	_add_atlas_sprite("SeedCrateSide", 40, 10, 1, 1, Vector2(10 * 16 + 4, 5 * 16 + 10))
	_add_atlas_sprite("HerbJar", 47, 32, 1, 1, Vector2(2 * 16 + 1, 1 * 16 + 2))

	# Botanical sorting table in center over warm rug with potted sunflower resting ON TOP!
	_add_atlas_sprite("BotanistStoolL", 50, 33, 1, 2, Vector2(5 * 16 + 3, 3 * 16 + 13))
	_add_atlas_sprite("BotanistStoolR", 50, 33, 1, 2, Vector2(7 * 16 - 3, 3 * 16 + 13))
	_add_atlas_sprite("BotanistTable", 50, 36, 1, 2, Vector2(6 * 16, 3 * 16 + 10))
	_add_atlas_sprite("MarenSunTable", 51, 32, 1, 1, Vector2(6 * 16, 3 * 16 + 4))

	_add_collider(Vector2(24.0, 48.0), Vector2(14.0, 26.0), "BedCol")
	_add_collider(Vector2(48.0, 36.0), Vector2(32.0, 14.0), "LeftShelfCol")
	_add_collider(Vector2(104.0, 68.0), Vector2(18.0, 18.0), "CenterTableCol")
	_add_collider(Vector2(160.0, 36.0), Vector2(64.0, 16.0), "RightHearthCol")
	_add_collider(Vector2(180.0, 92.0), Vector2(30.0, 22.0), "CratesCol")


func _build_theme_kaelen() -> void:
	# Compact sturdy dark-red rug in front of heavy workbench (x=5..6, y=4..5)
	for ry: int in range(2):
		for rx: int in range(2):
			rug_layer.set_cell(Vector2i(5 + rx, 4 + ry), 0, Vector2i(44 + rx, 36 + ry))

	# Left sleeping alcove: Bed (x=1, y=2..3) + Heavy Wooden Cabinet (x=2, y=1..2)
	furn_layer.set_cell(Vector2i(1, 2), 0, Vector2i(39, 33))
	furn_layer.set_cell(Vector2i(1, 3), 0, Vector2i(39, 34))
	furn_layer.set_cell(Vector2i(2, 1), 0, Vector2i(47, 33))
	furn_layer.set_cell(Vector2i(2, 2), 0, Vector2i(47, 34))
	furn_layer.set_cell(Vector2i(3, 1), 0, Vector2i(44, 33))
	furn_layer.set_cell(Vector2i(3, 2), 0, Vector2i(44, 34))

	# Stone Furnace + Chunky 2-tile Stone Hearth Fireplace on top-right!
	_add_atlas_sprite("IndoorFurnace", 39, 17, 2, 2, Vector2(8 * 16, 1 * 16 + 4))
	_place_stone_hearth(10, 0)

	# Heavy Blacksmith Workbench Table + Anvil + Water Quench Barrel + Iron/Stone Crates!
	_add_atlas_sprite("ForgeWorkbenchL", 50, 36, 1, 2, Vector2(5 * 16 + 8, 3 * 16 + 8))
	_add_atlas_sprite("ForgeWorkbenchR", 50, 36, 1, 2, Vector2(6 * 16 + 8, 3 * 16 + 8))
	_add_atlas_sprite("WorkbenchIngot", 55, 30, 1, 1, Vector2(6 * 16 + 8, 3 * 16 + 8))
	_add_atlas_sprite("WorkbenchCopper", 55, 28, 1, 1, Vector2(5 * 16 + 10, 3 * 16 + 8))
	_add_atlas_sprite("QuenchBarrel", 38, 16, 1, 1, Vector2(11 * 16 + 2, 3 * 16 + 10))
	_add_atlas_sprite("IronCrate1", 40, 10, 1, 1, Vector2(11 * 16 + 2, 5 * 16 + 2))
	_add_atlas_sprite("IronCrate2", 39, 10, 1, 1, Vector2(10 * 16 + 2, 5 * 16 + 10))
	_add_atlas_sprite("IndoorAnvil", 37, 18, 2, 1, Vector2(1 * 16 + 8, 5 * 16 + 10))

	_add_collider(Vector2(24.0, 48.0), Vector2(14.0, 26.0), "BedCol")
	_add_collider(Vector2(48.0, 36.0), Vector2(32.0, 14.0), "CabinetCol")
	_add_collider(Vector2(104.0, 66.0), Vector2(34.0, 18.0), "WorkbenchCol")
	_add_collider(Vector2(160.0, 36.0), Vector2(64.0, 16.0), "ForgeHearthCol")
	_add_collider(Vector2(178.0, 84.0), Vector2(32.0, 30.0), "IronCratesCol")
	_add_collider(Vector2(38.0, 92.0), Vector2(28.0, 14.0), "AnvilCol")


func _build_theme_aldric() -> void:
	# Grand Red/Gold Carpet filling the hall center (x=5..7, y=3..5) + entry runner (x=6..7, y=6)
	for ry: int in range(3):
		for rx: int in range(3):
			rug_layer.set_cell(Vector2i(5 + rx, 3 + ry), 0, Vector2i(40 + rx, 35 + ry))
	rug_layer.set_cell(Vector2i(6, 6), 0, Vector2i(47, 36))
	rug_layer.set_cell(Vector2i(7, 6), 0, Vector2i(47, 36))

	# Symmetrical Wall Bookshelves & Cabinets flanking the framed paintings!
	furn_layer.set_cell(Vector2i(1, 1), 0, Vector2i(45, 33))
	furn_layer.set_cell(Vector2i(1, 2), 0, Vector2i(45, 34))
	furn_layer.set_cell(Vector2i(2, 1), 0, Vector2i(42, 33))
	furn_layer.set_cell(Vector2i(2, 2), 0, Vector2i(42, 34))
	furn_layer.set_cell(Vector2i(3, 1), 0, Vector2i(49, 33))
	furn_layer.set_cell(Vector2i(3, 2), 0, Vector2i(49, 34))

	furn_layer.set_cell(Vector2i(8, 1), 0, Vector2i(42, 33))
	furn_layer.set_cell(Vector2i(8, 2), 0, Vector2i(42, 34))
	furn_layer.set_cell(Vector2i(9, 1), 0, Vector2i(45, 33))
	furn_layer.set_cell(Vector2i(9, 2), 0, Vector2i(45, 34))
	_place_stone_hearth(10, 0)

	# Framed Paintings mounted cleanly on the smooth back timber wall (y=1)!
	_add_atlas_sprite("WallPaintingLeft", 53, 33, 1, 1, Vector2(5 * 16 + 2, 1 * 16 + 1))
	_add_atlas_sprite("WallPaintingRight", 54, 33, 1, 1, Vector2(6 * 16 + 10, 1 * 16 + 1))
	_add_atlas_sprite("HallFlowers", 53, 32, 1, 1, Vector2(3 * 16, 1 * 16 + 5))

	# Long Mayor's Wooden Desk (3 joined segments centered at x=5..7, y=3..4) with ledger & books!
	_add_atlas_sprite("MayorDeskL", 50, 36, 1, 2, Vector2(5 * 16, 3 * 16 + 4))
	_add_atlas_sprite("MayorDeskM", 50, 36, 1, 2, Vector2(6 * 16, 3 * 16 + 4))
	_add_atlas_sprite("MayorDeskR", 50, 36, 1, 2, Vector2(7 * 16, 3 * 16 + 4))
	_add_atlas_sprite("MayorLedger", 53, 34, 1, 1, Vector2(6 * 16, 3 * 16 + 5))
	_add_atlas_sprite("MayorBookGreen", 52, 33, 1, 1, Vector2(5 * 16 + 2, 3 * 16 + 4))
	_add_atlas_sprite("MayorChair", 50, 33, 1, 2, Vector2(6 * 16, 2 * 16 + 12))

	_add_collider(Vector2(40.0, 36.0), Vector2(48.0, 14.0), "LeftShelvesCol")
	_add_collider(Vector2(104.0, 60.0), Vector2(48.0, 18.0), "MayorDeskCol")
	_add_collider(Vector2(160.0, 36.0), Vector2(64.0, 16.0), "RightHearthCol")


func _build_theme_bram() -> void:
	# Cozy fisherman 2x2 rug (x=5..6, y=4..5) + bedside mat
	rug_layer.set_cell(Vector2i(2, 3), 0, Vector2i(47, 36))
	for ry: int in range(2):
		for rx: int in range(2):
			rug_layer.set_cell(Vector2i(5 + rx, 4 + ry), 0, Vector2i(44 + rx, 36 + ry))

	# Cozy Red Bed (x=1, y=2..3) + Sea Chest Cabinet (x=2, y=1..2) + End Table (x=3, y=1..2)
	furn_layer.set_cell(Vector2i(1, 2), 0, Vector2i(39, 33))
	furn_layer.set_cell(Vector2i(1, 3), 0, Vector2i(39, 34))
	furn_layer.set_cell(Vector2i(2, 1), 0, Vector2i(47, 33))
	furn_layer.set_cell(Vector2i(2, 2), 0, Vector2i(47, 34))
	furn_layer.set_cell(Vector2i(3, 1), 0, Vector2i(49, 33))
	furn_layer.set_cell(Vector2i(3, 2), 0, Vector2i(49, 34))
	_place_stone_hearth(10, 0)

	# Blue coastal ceramic jars, nautical barrels, water barrels & starfish/fish accents!
	_add_atlas_sprite("BlueCoastalJar1", 46, 32, 1, 1, Vector2(3 * 16, 1 * 16 + 4))
	_add_atlas_sprite("BlueCoastalBowl", 50, 32, 1, 1, Vector2(6 * 16, 3 * 16 + 9))
	_add_atlas_sprite("SeaPainting", 54, 33, 1, 1, Vector2(6 * 16, 1 * 16 + 1))
	_add_atlas_sprite("BramTable", 50, 36, 1, 2, Vector2(6 * 16, 3 * 16 + 10))
	_add_atlas_sprite("BramStool", 50, 33, 1, 2, Vector2(5 * 16 + 3, 3 * 16 + 13))
	_add_atlas_sprite("StarfishDecor", 58, 19, 1, 1, Vector2(2 * 16, 1 * 16 + 4))

	# Nautical barrels along right & bottom-left walls
	_add_atlas_sprite("WaterBarrel1", 38, 16, 1, 1, Vector2(8 * 16 + 6, 1 * 16 + 14))
	_add_atlas_sprite("ClosedBarrel1", 39, 16, 1, 1, Vector2(11 * 16 + 2, 4 * 16 + 14))
	_add_atlas_sprite("ClosedBarrel2", 40, 16, 1, 1, Vector2(10 * 16 + 2, 5 * 16 + 10))
	_add_atlas_sprite("WaterBarrel2", 38, 16, 1, 1, Vector2(1 * 16 + 6, 5 * 16 + 12))

	_add_collider(Vector2(24.0, 48.0), Vector2(14.0, 26.0), "BedCol")
	_add_collider(Vector2(48.0, 36.0), Vector2(32.0, 14.0), "DresserCol")
	_add_collider(Vector2(104.0, 68.0), Vector2(18.0, 18.0), "TableCol")
	_add_collider(Vector2(164.0, 36.0), Vector2(56.0, 16.0), "HearthBarrelCol")
	_add_collider(Vector2(178.0, 90.0), Vector2(30.0, 24.0), "RightBarrelsCol")
	_add_collider(Vector2(28.0, 96.0), Vector2(16.0, 14.0), "LeftBarrelCol")


func _build_theme_lyra() -> void:
	# Rustic woodland 2x2 rug (x=5..6, y=4..5) + bedside mat
	rug_layer.set_cell(Vector2i(2, 3), 0, Vector2i(47, 36))
	for ry: int in range(2):
		for rx: int in range(2):
			rug_layer.set_cell(Vector2i(5 + rx, 4 + ry), 0, Vector2i(44 + rx, 36 + ry))

	# Bed (x=1, y=2..3) + Rustic Bookshelves (x=2, x=8) + Two Real Wooden End Tables with Flowers (x=3, x=9)!
	furn_layer.set_cell(Vector2i(1, 2), 0, Vector2i(39, 33))
	furn_layer.set_cell(Vector2i(1, 3), 0, Vector2i(39, 34))
	furn_layer.set_cell(Vector2i(2, 1), 0, Vector2i(43, 33))
	furn_layer.set_cell(Vector2i(2, 2), 0, Vector2i(43, 34))
	furn_layer.set_cell(Vector2i(3, 1), 0, Vector2i(49, 33))
	furn_layer.set_cell(Vector2i(3, 2), 0, Vector2i(49, 34))
	furn_layer.set_cell(Vector2i(8, 1), 0, Vector2i(45, 33))
	furn_layer.set_cell(Vector2i(8, 2), 0, Vector2i(45, 34))
	furn_layer.set_cell(Vector2i(9, 1), 0, Vector2i(49, 33))
	furn_layer.set_cell(Vector2i(9, 2), 0, Vector2i(49, 34))
	_place_stone_hearth(10, 0)

	# Flowers seated cleanly ON TOP of real wooden tables!
	_add_atlas_sprite("LyraSunflower", 51, 32, 1, 1, Vector2(3 * 16, 1 * 16 + 5))
	_add_atlas_sprite("LyraWildflowers", 54, 32, 1, 1, Vector2(9 * 16, 1 * 16 + 5))
	_add_atlas_sprite("LyraTable", 50, 36, 1, 2, Vector2(6 * 16, 3 * 16 + 10))
	_add_atlas_sprite("LyraTableDaisies", 53, 32, 1, 1, Vector2(6 * 16, 3 * 16 + 7))
	_add_atlas_sprite("LyraStoolL", 50, 33, 1, 2, Vector2(5 * 16 + 3, 3 * 16 + 13))
	_add_atlas_sprite("WoodlandJugs", 51, 19, 2, 2, Vector2(10 * 16 + 8, 4 * 16 + 14))

	_add_collider(Vector2(24.0, 48.0), Vector2(14.0, 26.0), "BedCol")
	_add_collider(Vector2(48.0, 36.0), Vector2(32.0, 14.0), "LeftShelfCol")
	_add_collider(Vector2(104.0, 68.0), Vector2(18.0, 18.0), "CenterTableCol")
	_add_collider(Vector2(160.0, 36.0), Vector2(64.0, 16.0), "RightHearthCol")
	_add_collider(Vector2(184.0, 88.0), Vector2(24.0, 20.0), "JugsCol")


func _place_stone_hearth(col_x: int, row_y: int) -> void:
	furn_layer.set_cell(Vector2i(col_x, row_y), 0, Vector2i(46, 19))
	furn_layer.set_cell(Vector2i(col_x + 1, row_y), 0, Vector2i(47, 19))
	furn_layer.set_cell(Vector2i(col_x, row_y + 1), 0, Vector2i(46, 20))
	furn_layer.set_cell(Vector2i(col_x + 1, row_y + 1), 0, Vector2i(47, 20))
	furn_layer.set_cell(Vector2i(col_x, row_y + 2), 0, Vector2i(46, 21))
	furn_layer.set_cell(Vector2i(col_x + 1, row_y + 2), 0, Vector2i(47, 21))

	var hearth_fire: Sprite2D = Sprite2D.new()
	hearth_fire.name = "HearthFire"
	hearth_fire.script = _strip_sprite_script
	hearth_fire.texture = load(AP.FIRE_02_STRIP4) as Texture2D
	hearth_fire.hframes = 4
	hearth_fire.vframes = 1
	hearth_fire.centered = true
	hearth_fire.scale = Vector2(0.75, 0.65)
	hearth_fire.set("frame_rate", 7.0)
	hearth_fire.position = Vector2(float(col_x + 1) * 16.0, float(row_y + 2) * 16.0 + 4.0)
	details_root.add_child(hearth_fire)


func _add_atlas_sprite(spr_name: String, col: int, row: int, w_tiles: int, h_tiles: int, pos: Vector2) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.name = spr_name
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = _tileset_tex
	at.region = Rect2(col * 16, row * 16, w_tiles * 16, h_tiles * 16)
	spr.texture = at
	spr.centered = false
	spr.position = pos
	details_root.add_child(spr)


func _add_collider(pos: Vector2, size: Vector2, col_name: String) -> void:
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = col_name
	cs.position = pos
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	furn_body.add_child(cs)


func _setup_ui() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var inv_scene: PackedScene = load(INVENTORY_MODAL_SCENE_PATH) as PackedScene
	assert(hud_scene != null and inv_scene != null, "Missing UI scenes in NpcInterior.")

	hud = hud_scene.instantiate() as GameplayHUD
	add_child(hud)

	inventory_modal = inv_scene.instantiate() as InventoryModal
	add_child(inventory_modal)
	inventory_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	var pause_scene: PackedScene = load(PAUSE_MODAL_SCENE_PATH) as PackedScene
	if pause_scene != null:
		pause_modal = pause_scene.instantiate() as PauseModalScript
		add_child(pause_modal)
		pause_modal.modal_visibility_changed.connect(_on_ui_modal_state_changed)

	var mob_scene: PackedScene = load(MOBILE_CONTROLS_SCENE_PATH) as PackedScene
	if mob_scene != null:
		mobile_controls = mob_scene.instantiate() as MobileControlsScript
		add_child(mobile_controls)
		mobile_controls.bind_scene(
			player,
			func() -> void:
				if pause_modal != null and pause_modal.is_open():
					return
				if inventory_modal != null:
					inventory_modal.toggle(),
			func() -> void:
				if inventory_modal != null and inventory_modal.is_open():
					return
				if pause_modal != null:
					pause_modal.toggle()
		)


func _process(delta: float) -> void:
	_flicker_time += minf(delta, 0.1)
	_refresh_interior_lighting()


func _physics_process(_delta: float) -> void:
	if not _is_player_at_exit:
		return
	if SceneTransition.is_portal_on_cooldown():
		return
	if TimeManager.is_paused():
		return
	if Input.is_action_pressed(&"move_down") or InputModeManager.virtual_move_vector.y > 0.35:
		exit_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_menu") or event.is_action_pressed(&"ui_cancel"):
		if inventory_modal != null and inventory_modal.is_open():
			inventory_modal.set_open(false)
			get_viewport().set_input_as_handled()
			return
		if pause_modal != null:
			pause_modal.toggle()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_inventory"):
		if pause_modal != null and pause_modal.is_open():
			return
		if inventory_modal != null:
			inventory_modal.toggle()
			get_viewport().set_input_as_handled()


func get_entry_spawn_world_position() -> Vector2:
	return Vector2(112.0, 108.0)


func is_player_at_exit() -> bool:
	return _is_player_at_exit


func set_hud_visible(show_hud: bool) -> void:
	_hud_user_visible = show_hud
	if hud != null:
		var inv_open: bool = inventory_modal != null and inventory_modal.is_open()
		hud.visible = _hud_user_visible and not inv_open
	if mobile_controls != null:
		mobile_controls.set_force_hidden(not _hud_user_visible)


func exit_to_world(immediate: bool = false) -> bool:
	if SceneTransition.is_transitioning():
		return false
	EventBus.door_transition_requested.emit(SceneTransition.active_return_scene, &"from_interior")
	return SceneTransition.exit_interior(&"from_interior", immediate)


func _validate_indoor_action(item: ItemData, target_cell: Vector2i) -> ActionValidator.ActionResult:
	var ctx: ActionValidator.ValidationContext = ActionValidator.ValidationContext.new()
	ctx.is_indoors = true
	ctx.target_cell = target_cell
	return ActionValidator.validate_use(item, ctx)


func _execute_indoor_action(action: ActionValidator.ActionResult) -> void:
	if action.kind == ActionValidator.ActionKind.EAT_ITEM and action.item != null:
		if InventoryManager.remove_from_slot(InventoryManager.selected_hotbar_index, 1):
			VitalitySystem.restore(action.item.vitality_restore)


func _on_player_interacted(_target_cell: Vector2i) -> void:
	if _is_player_at_exit:
		exit_to_world()


func _on_pass_out_triggered() -> void:
	if inventory_modal != null and inventory_modal.is_open():
		inventory_modal.set_open(false)
	SceneTransition.transition_to_scene(FARMHOUSE_INTERIOR_PATH, &"bed_wake", false)


func _refresh_interior_lighting() -> void:
	var hour_f: float = TimeManager.get_hour_float()
	var night_factor: float = clampf((hour_f - 17.5) / 3.0, 0.0, 1.0)
	if room_modulate != null:
		room_modulate.color = Color(1.0, 0.98, 0.95, 1.0).lerp(Color(0.56, 0.50, 0.58, 1.0), night_factor)
	if hearth_light != null:
		var base_e: float = lerpf(0.42, 1.15, night_factor)
		hearth_light.energy = base_e * (0.94 + 0.06 * sin(_flicker_time * 9.2))


func _on_exit_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_player_at_exit = true
		EventBus.interact_prompt_changed.emit("[E] Exit %s" % _theme_title)


func _on_exit_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_is_player_at_exit = false
		EventBus.interact_prompt_changed.emit("")


func _on_ui_modal_state_changed(_open_state: bool) -> void:
	var inv_open: bool = inventory_modal != null and inventory_modal.is_open()
	var pause_open: bool = pause_modal != null and pause_modal.is_open()
	var blocking: bool = inv_open or pause_open
	TimeManager.set_paused(blocking)
	if player != null:
		player.set_controls_locked(blocking)
	if hud != null:
		hud.visible = not blocking and _hud_user_visible
	if mobile_controls != null:
		mobile_controls.set_modal_hidden(blocking)
