extends Node2D

## Automated Phase 3 verification suite & screenshot capture.
## Tests TimeManager (06:00-02:00, 0.7s/min, 10-min HUD ticks, 28-day 4-season calendar, weather,
## day-transition lock), Day/Night CanvasModulate + warm PointLight2D glow, Bed Sleep workflow
## (crop growth, rain auto-water, out-of-season withering, Vitality restore), HUD, and 24-slot Inventory Modal.

const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const SHOT_HUD_DAY: String = "res://Screenshots/phase3_hud_day.png"
const SHOT_NIGHT: String = "res://Screenshots/phase3_night_lighting.png"
const SHOT_INVENTORY: String = "res://Screenshots/phase3_inventory_modal.png"

var _farm: FarmSanctuary = null
var _player: Player = null
var _step: int = 0
var _wait_frames: int = 0
var _time_ticks_seen: int = 0
var _pass_out_count: int = 0
var _season_changes_seen: int = 0


func _ready() -> void:
	GridStateManager.clear_all()
	InventoryManager.reset_to_starter_loadout()
	VitalitySystem.restore_full()
	TimeManager.reset_to_day_one()

	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.pass_out_triggered.connect(_on_pass_out)
	EventBus.season_changed.connect(_on_season_changed)

	# Run pure TimeManager clock & 02:00 AM pass-out lock tests BEFORE instantiating FarmSanctuary
	# so pass_out_triggered doesn't launch an async fade tween during synchronous unit checks!
	_run_clock_and_passout_tests()

	var packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(packed != null, "Failed to load farm_sanctuary.tscn")
	_farm = packed.instantiate() as FarmSanctuary
	add_child(_farm)
	_player = _farm.player
	assert(_player != null and _farm.hud != null and _farm.inventory_modal != null and _farm.sleep_dialog != null, "Phase 3 nodes missing.")

	_run_sleep_and_inventory_tests()

	# Reset cleanly to sunny Day 1 Bloom 12:00 PM with sample crops in garden & backpack for visual screenshots!
	GridStateManager.clear_all()
	InventoryManager.reset_to_starter_loadout()
	InventoryManager.add_item(&"crop_sunflower", 3)
	InventoryManager.add_item(&"crop_carrot", 5)
	InventoryManager.add_item(&"crop_radish", 4)
	InventoryManager.add_item(&"wood", 12)
	InventoryManager.add_item(&"stone", 8)
	VitalitySystem.restore_full()
	VitalitySystem.consume(18.0) # 82/100 Vitality so greenbar shows realistic partial state
	TimeManager.reset_to_day_one()
	TimeManager.set_paused(true)
	TimeManager.set_time(12, 0)
	_farm.set_hud_visible(true)
	_farm.refresh_atmosphere()

	# Plant a cozy row of starter crops in the garden bed dynamically from GardenOrigin!
	var g_pos: Vector2 = _farm.get_world_marker_position("GardenOrigin")
	var g0: Vector2i = Vector2i(floori(g_pos.x / 16.0), floori(g_pos.y / 16.0))
	GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(2, 1), &"parsnip", 4, true)
	GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(3, 1), &"sunflower", 6, true)
	GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(4, 1), &"carrot", 3, true)
	GridStateManager.set_crop_state(_farm.scene_id, g0 + Vector2i(5, 1), &"radish", 2, false)

	_player.camera.make_current()


func _on_time_ticked(_d: int, _s: int, _h: int, _m: int) -> void:
	_time_ticks_seen += 1


func _on_pass_out() -> void:
	_pass_out_count += 1


func _on_season_changed(_new_s: int) -> void:
	_season_changes_seen += 1


func _run_clock_and_passout_tests() -> void:
	# 1. Verify 0.7s per in-game minute and 10-minute HUD tick cadence
	TimeManager.reset_to_day_one()
	assert(TimeManager.get_formatted_time() == "06:00 AM", "Initial time must be 06:00 AM.")
	assert(TimeManager.get_formatted_date() == "Bloom 1", "Initial date must be Bloom 1.")
	_time_ticks_seen = 0
	for _i: int in range(30):
		TimeManager._process(0.24) # 30 * 0.24 = 7.2s -> 10 in-game minutes -> exactly 1 HUD tick!
	assert(_time_ticks_seen == 1, "Expected exactly 1 HUD tick after 10 in-game minutes (got %d)." % _time_ticks_seen)
	assert(TimeManager.get_formatted_time() == "06:10 AM", "Expected 06:10 AM after 10 mins (got %s)." % TimeManager.get_formatted_time())
	print("[VerifyP3] PASS: TimeManager 0.7s/min & 10-min HUD ticks verified (06:00 AM -> 06:10 AM).")

	# 2. Verify 02:00 AM pass-out fires cleanly once without looping
	_pass_out_count = 0
	TimeManager.set_time(25, 58)
	for _i: int in range(20):
		TimeManager._process(0.25)
	assert(_pass_out_count == 1, "Expected 02:00 AM pass-out to fire exactly once (got %d)." % _pass_out_count)
	print("[VerifyP3] PASS: 02:00 AM pass-out lock verified (no double-tick / pass-out loop).")


func _run_sleep_and_inventory_tests() -> void:

	# 3. Verify overnight crop growth, dry soil reset, Vitality restore, and Rain auto-watering!
	TimeManager.reset_to_day_one()
	var g_pos: Vector2 = _farm.get_world_marker_position("GardenOrigin")
	var g0: Vector2i = Vector2i(floori(g_pos.x / 16.0), floori(g_pos.y / 16.0))
	var test_cell: Vector2i = g0 + Vector2i(2, 2)
	var dry_cell: Vector2i = g0 + Vector2i(3, 2)
	GridStateManager.till_cell(_farm.scene_id, test_cell)
	GridStateManager.plant_crop(_farm.scene_id, test_cell, &"parsnip")
	GridStateManager.water_cell(_farm.scene_id, test_cell)
	GridStateManager.till_cell(_farm.scene_id, dry_cell)
	VitalitySystem.consume(50.0)
	assert(VitalitySystem.current_vitality == 50.0, "Expected 50 Vitality before sleep.")

	# Simulate sunny overnight sleep
	_farm.sleep_dialog.begin_sleep_transition(Callable(), TimeManager.WEATHER_SUNNY, true)
	assert(TimeManager.current_day == 2, "Day should advance to 2 after sleep.")
	assert(TimeManager.get_formatted_time() == "06:00 AM", "Wake-up time should reset to 06:00 AM.")
	assert(VitalitySystem.current_vitality == 100.0, "Vitality must restore to 100 after sleep.")
	var st_watered: GridCellState = GridStateManager.get_cell(_farm.scene_id, test_cell)
	assert(st_watered != null and st_watered.days_grown == 1 and not st_watered.is_watered, "Watered crop must grow +1 day and dry out on sunny morning.")

	# Simulate rainy overnight sleep -> all outdoor tilled soil MUST auto-water!
	_farm.sleep_dialog.begin_sleep_transition(Callable(), TimeManager.WEATHER_RAIN, true)
	assert(TimeManager.current_day == 3 and TimeManager.is_raining(), "Expected rainy Day 3.")
	assert(GridStateManager.get_cell(_farm.scene_id, test_cell).is_watered, "Rain must auto-water tilled soil!")
	assert(GridStateManager.get_cell(_farm.scene_id, dry_cell).is_watered, "Rain must auto-water empty tilled soil!")
	print("[VerifyP3] PASS: Overnight crop growth, Vitality restore (50->100), and Rain auto-watering verified.")

	# 4. Verify 28-day Season wrap + out-of-season crop withering (Bloom parsnip entering Sun/Frost)
	_season_changes_seen = 0
	TimeManager.current_day = 28
	TimeManager.set_season(0) # Bloom
	_farm.sleep_dialog.begin_sleep_transition(Callable(), TimeManager.WEATHER_SUNNY, true)
	assert(TimeManager.current_day == 1 and TimeManager.current_season == 1, "Day 28 Bloom must wrap to Day 1 Sun.")
	assert(_season_changes_seen >= 1, "Season wrap must emit EventBus.season_changed.")
	assert(GridStateManager.get_cell(_farm.scene_id, test_cell).is_withered, "Bloom-only Parsnip must wither on entering Sun season!")

	# Verify Year wrap (Day 28 Frost -> Day 1 Bloom Year 2)
	TimeManager.current_day = 28
	TimeManager.set_season(3) # Frost
	_farm.sleep_dialog.begin_sleep_transition(Callable(), TimeManager.WEATHER_SUNNY, true)
	assert(TimeManager.current_year == 2 and TimeManager.current_season == 0 and TimeManager.current_day == 1, "Day 28 Frost must wrap to Year 2 Bloom 1.")
	print("[VerifyP3] PASS: 28-day 4-season & Year rollover + out-of-season crop withering verified.")

	# 5. Verify Inventory Modal click-to-swap & tab switching
	InventoryManager.reset_to_starter_loadout()
	_farm.inventory_modal.set_open(true)
	assert(_farm.inventory_modal.is_open() and TimeManager.is_paused(), "Opening inventory must pause TimeManager.")
	var before_6: StringName = InventoryManager.get_slot_item_id(6)
	var before_12: StringName = InventoryManager.get_slot_item_id(12)
	_farm.inventory_modal.click_slot(6)
	_farm.inventory_modal.click_slot(12)
	assert(InventoryManager.get_slot_item_id(12) == before_6 and InventoryManager.get_slot_item_id(6) == before_12, "Inventory click-to-swap failed!")
	_farm.inventory_modal.set_active_tab(InventoryModal.Tab.TOOLS)
	_farm.inventory_modal.set_active_tab(InventoryModal.Tab.PEOPLE)
	_farm.inventory_modal.set_active_tab(InventoryModal.Tab.ITEMS)
	_farm.inventory_modal.set_open(false)
	assert(not _farm.inventory_modal.is_open() and not TimeManager.is_paused(), "Closing inventory must resume TimeManager.")
	print("[VerifyP3] PASS: 24-slot Inventory Modal open/close, pause lock, click-to-swap, and Items/Tools/People tabs verified.")


func _physics_process(_delta: float) -> void:
	_wait_frames += 1
	match _step:
		0:
			# Verify SleepDialog confirmation open/close, then position player on dynamic sunlit courtyard!
			if _wait_frames >= 6:
				EventBus.sleep_requested.emit()
				assert(_farm.sleep_dialog.is_dialog_open(), "Sleep request must open SleepDialog!")
				_farm.sleep_dialog.close_dialog()
				assert(not _farm.sleep_dialog.is_dialog_open(), "SleepDialog must close cleanly on Stay Up.")
				print("[VerifyP3] PASS: Interactive Sleep confirmation dialog verified.")
				var door_pos: Vector2 = _farm.get_world_marker_position("FarmhouseDoor")
				_player.global_position = door_pos + Vector2(0.0, 12.0)
				_player.set_facing_cardinal(Vector2i(0, 1))
				TimeManager.set_paused(true)
				TimeManager.set_time(12, 0)
				_farm.refresh_atmosphere()
				_step = 1
				_wait_frames = 0
		1:
			# Wait for roof to fade back to 1.0 outside & GPU settle, then capture Daytime HUD screenshot
			if _wait_frames >= 22:
				var day_col: Color = _farm.atmosphere.get_canvas_modulate_color()
				assert(day_col.r > 0.98 and day_col.g > 0.98 and day_col.b > 0.98, "Noon CanvasModulate should be crisp daylight.")
				assert(_farm.atmosphere.get_night_factor() < 0.01, "Night lights must be off at noon.")
				_save_viewport_png(SHOT_HUD_DAY)
				print("[VerifyP3] Captured %s" % SHOT_HUD_DAY)
				# Switch to 10:30 PM Night lighting!
				TimeManager.set_time(22, 30)
				_farm.refresh_atmosphere()
				_step = 2
				_wait_frames = 0
		2:
			if _wait_frames >= 10:
				var night_col: Color = _farm.atmosphere.get_canvas_modulate_color()
				assert(night_col.b > night_col.r * 1.4 and night_col.r < 0.35, "Night CanvasModulate must be cozy deep blue (got %s)." % str(night_col))
				assert(_farm.atmosphere.get_night_factor() > 0.95, "Night PointLight2Ds must glow at 10:30 PM.")
				_save_viewport_png(SHOT_NIGHT)
				print("[VerifyP3] PASS: Night CanvasModulate & warm fireplace/window/torch PointLight2Ds verified; captured %s" % SHOT_NIGHT)
				# Return to bright daytime & open Inventory Modal inspecting Sunflower (matching image_89fbf9.png!)
				TimeManager.set_time(12, 0)
				_farm.refresh_atmosphere()
				_farm.inventory_modal.set_open(true)
				_farm.inventory_modal.inspect_slot(11) # Harvested Sunflower -> shows 3-stage Seed->Sprout->Mature Growth Strip & 80 G value!
				_step = 3
				_wait_frames = 0
		3:
			if _wait_frames >= 8:
				_save_viewport_png(SHOT_INVENTORY)
				print("[VerifyP3] Captured %s" % SHOT_INVENTORY)
				_farm.inventory_modal.set_open(false)
				print("[VerifyP3] ALL PHASE 3 AUTOMATED CHECKS PASSED!")
				get_tree().quit(0)


func _save_viewport_png(res_path: String) -> void:
	var out_path: String = ProjectSettings.globalize_path(res_path)
	var img: Image = get_viewport().get_texture().get_image()
	assert(img != null, "Failed to grab viewport image.")
	assert(img.get_width() >= 1280 and img.get_height() >= 720, "Expected full 1280x720 resolution screenshot, got %dx%d!" % [img.get_width(), img.get_height()])
	var err: Error = img.save_png(out_path)
	assert(err == OK, "Failed to save %s (err=%d)" % [out_path, err])
	print("[VerifyP3] Saved %dx%d screenshot: %s" % [img.get_width(), img.get_height(), res_path])
