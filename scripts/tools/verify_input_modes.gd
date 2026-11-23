extends Node

## Automated verification & screenshot suite for Unified Input & Vryell Control Prompts Pass.
## Verifies:
##  1. Live InputModeManager switching (KEYBOARD_MOUSE <-> GAMEPAD Xbox/PS/Switch <-> TOUCH) + vendor detection.
##  2. Verified Vryell 16x16 AtlasTexture regions on InputPromptBadge across Keyboard, Xbox, PS, Switch, Touch.
##  3. Gamepad LB/RB hotbar cycling, gamepad movement, and controller focus navigation across modals.
##  4. Multi-touch virtual thumbstick + simultaneous Use Tool + contextual Interact + modal auto-hide.
##  5. Persistent user://settings.json round-trip for Touch Controls & Controller Icons toggles.
##  6. Captures 4 inspection screenshots (1280x720 Keyboard, 1280x720 Gamepad, 1280x720 Pause, 1600x720 Mobile 20:9).

const AP := preload("res://scripts/core/asset_paths.gd")
const ControlIconsScript := preload("res://scripts/core/control_icons.gd")
const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const TITLE_SCENE_PATH: String = "res://scenes/ui/title_screen.tscn"

var _failed: bool = false
var _mode_signal_count: int = 0
var _last_sig_mode: int = -1
var _last_sig_family: int = -1


func _ready() -> void:
	call_deferred(&"_run_verification")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[VerifyInputModes] PASS: %s" % msg)
	else:
		_failed = true
		push_error("[VerifyInputModes] FAIL: %s" % msg)


func _on_mode_signal(mode: int, family: int) -> void:
	_mode_signal_count += 1
	_last_sig_mode = mode
	_last_sig_family = family


func _wait_frames(n: int = 3) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _wait_physics(n: int = 4) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _capture_screenshot(rel_path: String) -> void:
	await _wait_frames(3)
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		_check(false, "Viewport image null for %s" % rel_path)
		return
	var abs_dir: String = ProjectSettings.globalize_path("res://Screenshots")
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var abs_path: String = ProjectSettings.globalize_path("res://%s" % rel_path)
	var err: Error = img.save_png(abs_path)
	_check(err == OK, "Saved screenshot %s (%dx%d)" % [rel_path, img.get_width(), img.get_height()])


func _run_verification() -> void:
	EventBus.input_mode_changed.connect(_on_mode_signal)

	# Reset clean sandbox state
	GridStateManager.clear_all()
	InventoryManager.reset_to_starter_loadout()
	InventoryManager.select_hotbar_slot(0)
	EconomyManager.reset_economy()
	VitalitySystem.restore_full()
	TimeManager.reset_to_day_one()
	TimeManager.set_time(10, 0)
	TimeManager.set_weather(TimeManager.WEATHER_SUNNY)
	SocialManager.reset_social()
	QuestManager.reset_quests()
	FestivalManager.reset_festivals()
	QuestManager.refresh_daily_board(1, 0, 1)
	var board_qs: Array[QuestData] = QuestManager.get_board_quests()
	if not board_qs.is_empty():
		QuestManager.accept_quest(board_qs[0].quest_id)
	InputModeManager.set_touch_preference(InputModeManager.TouchPreference.AUTO, false)
	InputModeManager.set_gamepad_icon_override(InputModeManager.GamepadIconOverride.AUTO, false)
	InputModeManager.set_input_mode(InputModeManager.InputMode.KEYBOARD_MOUSE, InputModeManager.GamepadFamily.XBOX)

	# 1. Verify Controller Vendor Detection Strings
	_check(
		InputModeManager.detect_gamepad_family_from_name("Xbox Wireless Controller") == InputModeManager.GamepadFamily.XBOX,
		"Vendor detection: Xbox Wireless Controller -> XBOX"
	)
	_check(
		InputModeManager.detect_gamepad_family_from_name("DualSense Wireless Controller") == InputModeManager.GamepadFamily.PLAYSTATION,
		"Vendor detection: DualSense -> PLAYSTATION"
	)
	_check(
		InputModeManager.detect_gamepad_family_from_name("PS4 Controller") == InputModeManager.GamepadFamily.PLAYSTATION,
		"Vendor detection: PS4 Controller -> PLAYSTATION"
	)
	_check(
		InputModeManager.detect_gamepad_family_from_name("Nintendo Switch Pro Controller") == InputModeManager.GamepadFamily.SWITCH,
		"Vendor detection: Switch Pro Controller -> SWITCH"
	)

	# 2. Verify TitleScreen never shows MobileControls (even when TouchPreference.ON) and gives initial focus
	InputModeManager.set_touch_preference(InputModeManager.TouchPreference.ON, false)
	var title_scene: PackedScene = load(TITLE_SCENE_PATH) as PackedScene
	var title_inst: Node = title_scene.instantiate()
	add_child(title_inst)
	await _wait_frames(3)
	var title_focus: Control = get_viewport().gui_get_focus_owner()
	_check(title_focus != null, "TitleScreen assigns initial controller focus (%s)" % (title_focus.name if title_focus != null else "null"))
	var title_mob: CanvasLayer = title_inst.find_child("MobileControls", true, false) as CanvasLayer
	_check(title_mob == null or not title_mob.visible, "TitleScreen keeps MobileControls hidden even with TouchPreference.ON")
	InputModeManager.set_touch_preference(InputModeManager.TouchPreference.AUTO, false)
	title_inst.queue_free()
	await _wait_frames(2)

	# 3. Load FarmSanctuary gameplay scene at 1280x720
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _wait_frames(3)

	var farm_scene: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	var farm: FarmSanctuary = farm_scene.instantiate() as FarmSanctuary
	add_child(farm)
	await _wait_frames(4)

	_check(farm.hud != null and farm.mobile_controls != null, "FarmSanctuary instantiated GameplayHUD & MobileControls")

	# Position player cleanly near ShippingBin so contextual world interact prompt is visible!
	var bin_pos: Vector2 = farm.shipping_bin.global_position
	farm.player.global_position = bin_pos + Vector2(-18.0, 4.0)
	farm.player.set_facing_cardinal(Vector2i(1, 0))
	EventBus.interact_prompt_changed.emit("[E] Shipping Chest")
	await _wait_frames(3)

	# 4. Verify KEYBOARD_MOUSE Mode & Vryell Badges + Capture Screenshot 1
	var ev_key: InputEventKey = InputEventKey.new()
	ev_key.keycode = KEY_W
	ev_key.physical_keycode = KEY_W
	ev_key.pressed = true
	InputModeManager._input(ev_key)
	await _wait_frames(2)

	var prompt_badge: TextureRect = farm.hud.find_child("InteractKeyBadge", true, false) as TextureRect
	var prompt_lbl: Label = farm.hud.find_child("PromptLabel", true, false) as Label
	var quest_badge: TextureRect = farm.hud.find_child("QuestToggleKeyBadge", true, false) as TextureRect
	var lb_badge: TextureRect = farm.hud.find_child("HotbarPrevBadge", true, false) as TextureRect
	var rb_badge: TextureRect = farm.hud.find_child("HotbarNextBadge", true, false) as TextureRect
	var slot0_badge: TextureRect = farm.hud.find_child("HotbarSlot_0", true, false).find_child("KeyHintBadge", true, false) as TextureRect

	_check(prompt_badge != null and prompt_badge.visible and prompt_badge.texture is AtlasTexture, "Keyboard InteractKeyBadge visible with Vryell AtlasTexture")
	_check((prompt_badge.texture as AtlasTexture).atlas.resource_path == AP.VRYELL_KB_LIGHT, "Keyboard InteractKeyBadge uses kb_light_all.png")
	_check(prompt_lbl != null and prompt_lbl.text == "Shipping Chest" and not ("[E]" in prompt_lbl.text), "World interact prompt strips raw [E] brackets cleanly")
	_check(quest_badge != null and quest_badge.visible and (quest_badge.texture as AtlasTexture).atlas.resource_path == AP.VRYELL_KB_LIGHT, "Keyboard QuestToggleKeyBadge uses Vryell Q keycap")
	_check(slot0_badge != null and slot0_badge.visible, "Keyboard mode shows Vryell 1-8 hotbar keycaps")
	_check(lb_badge != null and not lb_badge.visible and rb_badge != null and not rb_badge.visible, "Keyboard mode hides Gamepad LB/RB shoulder badges")
	_check(not farm.mobile_controls.is_overlay_visible(), "Keyboard mode hides MobileControls overlay in Auto")

	await _capture_screenshot("Screenshots/controls_keyboard_vryell.png")

	# 5. Verify GAMEPAD Mode (Xbox -> PlayStation -> Switch) + Capture Screenshot 2 (Xbox)
	var sig_before: int = _mode_signal_count
	var ev_joy: InputEventJoypadButton = InputEventJoypadButton.new()
	ev_joy.button_index = JOY_BUTTON_A
	ev_joy.pressed = true
	InputModeManager._input(ev_joy)
	InputModeManager.set_detected_gamepad_family(InputModeManager.GamepadFamily.XBOX)
	await _wait_frames(3)

	_check(InputModeManager.is_gamepad_mode() and _mode_signal_count > sig_before, "InputEventJoypadButton transitions live to GAMEPAD & emits input_mode_changed")
	_check((prompt_badge.texture as AtlasTexture).atlas.resource_path == AP.VRYELL_XBOX, "Xbox mode swaps InteractKeyBadge to controller_xbox.png")
	_check(lb_badge.visible and rb_badge.visible and (lb_badge.texture as AtlasTexture).atlas.resource_path == AP.VRYELL_XBOX, "Xbox mode shows LB/RB shoulder icons flanking Hotbar")
	_check(not slot0_badge.visible, "Gamepad mode hides 1-8 keyboard keycaps on Hotbar")

	await _capture_screenshot("Screenshots/controls_gamepad_xbox_ps.png")

	# Verify PlayStation & Switch live AtlasTexture swaps
	InputModeManager.set_detected_gamepad_family(InputModeManager.GamepadFamily.PLAYSTATION)
	await _wait_frames(2)
	_check((prompt_badge.texture as AtlasTexture).atlas.resource_path == AP.VRYELL_PS, "PlayStation mode swaps InteractKeyBadge to controller_ps.png (Cross)")
	_check((lb_badge.texture as AtlasTexture).atlas.resource_path == AP.VRYELL_PS, "PlayStation mode swaps hotbar bumper to L1/R1")

	InputModeManager.set_detected_gamepad_family(InputModeManager.GamepadFamily.SWITCH)
	await _wait_frames(2)
	_check((prompt_badge.texture as AtlasTexture).atlas.resource_path == AP.VRYELL_SWITCH, "Switch mode swaps InteractKeyBadge to controller_switch.png (B)")
	_check((lb_badge.texture as AtlasTexture).atlas.resource_path == AP.VRYELL_SWITCH, "Switch mode swaps hotbar bumper to L/R")

	# 6. Verify Gamepad LB/RB Hotbar Cycling + Gamepad Movement
	InventoryManager.select_hotbar_slot(0)
	var rb_ev: InputEventJoypadButton = InputEventJoypadButton.new()
	rb_ev.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb_ev.pressed = true
	farm.player._unhandled_input(rb_ev)
	_check(InventoryManager.selected_hotbar_index == 1, "Gamepad RB cycles hotbar forward (0 -> 1)")
	var lb_ev: InputEventJoypadButton = InputEventJoypadButton.new()
	lb_ev.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb_ev.pressed = true
	farm.player._unhandled_input(lb_ev)
	_check(InventoryManager.selected_hotbar_index == 0, "Gamepad LB cycles hotbar backward (1 -> 0)")

	var start_x: float = farm.player.global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_release(&"move_right")
	_check(farm.player.global_position.x > start_x + 4.0, "Gamepad directional input moves Player smoothly (dx=%.1f)" % (farm.player.global_position.x - start_x))

	# 7. Verify Full Controller UI Focus Navigation across InventoryModal, ShopModal & PauseModal
	farm.inventory_modal.set_open(true)
	await _wait_frames(2)
	var inv_focus: Control = get_viewport().gui_get_focus_owner()
	_check(inv_focus != null, "InventoryModal assigns valid controller focus (%s)" % (inv_focus.name if inv_focus != null else "null"))
	farm.inventory_modal._unhandled_input(rb_ev)
	await _wait_frames(2)
	_check(farm.inventory_modal._active_tab == InventoryModal.Tab.CRAFT, "InventoryModal RB switches tab ITEMS -> CRAFT")
	var b_cancel: InputEventJoypadButton = InputEventJoypadButton.new()
	b_cancel.button_index = JOY_BUTTON_B
	b_cancel.pressed = true
	farm.inventory_modal._unhandled_input(b_cancel)
	await _wait_frames(2)
	_check(not farm.inventory_modal.is_open(), "InventoryModal closes cleanly on Gamepad B (ui_cancel)")

	farm.shop_modal.set_open(true, ShopModal.Tab.SEEDS)
	await _wait_frames(2)
	var shop_focus: Control = get_viewport().gui_get_focus_owner()
	_check(shop_focus != null, "ShopModal assigns valid controller focus (%s)" % (shop_focus.name if shop_focus != null else "null"))
	farm.shop_modal._unhandled_input(rb_ev)
	await _wait_frames(2)
	_check(farm.shop_modal._active_tab == ShopModal.Tab.SELL, "ShopModal RB switches tab SEEDS -> SELL")
	farm.shop_modal._unhandled_input(b_cancel)
	await _wait_frames(2)
	_check(not farm.shop_modal.is_open(), "ShopModal closes cleanly on Gamepad B (ui_cancel)")

	# 8. Open PauseModal, test Settings Toggles + Persistence, & Capture Screenshot 3 (PlayStation Controls Reference!)
	InputModeManager.set_gamepad_icon_override(InputModeManager.GamepadIconOverride.PLAYSTATION, true)
	InputModeManager.set_touch_preference(InputModeManager.TouchPreference.AUTO, true)
	farm.pause_modal.set_open(true)
	await _wait_frames(3)
	var pause_focus: Control = get_viewport().gui_get_focus_owner()
	_check(pause_focus != null and pause_focus.name == "ResumeBtn", "PauseModal focuses ResumeBtn on open")

	await _capture_screenshot("Screenshots/controls_pause_reference.png")

	# Test user://settings.json round-trip persistence
	farm.pause_modal.cycle_touch_controls() # AUTO -> ON
	farm.pause_modal.cycle_controller_icons() # PLAYSTATION -> SWITCH
	_check(InputModeManager.touch_preference == InputModeManager.TouchPreference.ON, "PauseModal Touch Controls toggle cycles AUTO -> ON")
	_check(InputModeManager.gamepad_icon_override == InputModeManager.GamepadIconOverride.SWITCH, "PauseModal Controller Icons toggle cycles PLAYSTATION -> SWITCH")
	InputModeManager.touch_preference = InputModeManager.TouchPreference.AUTO
	InputModeManager.gamepad_icon_override = InputModeManager.GamepadIconOverride.AUTO
	InputModeManager.load_settings()
	_check(
		InputModeManager.touch_preference == InputModeManager.TouchPreference.ON
		and InputModeManager.gamepad_icon_override == InputModeManager.GamepadIconOverride.SWITCH,
		"user://settings.json persists & reloads Touch Controls and Controller Icons settings"
	)

	# Reset back to Auto defaults & close PauseModal via Gamepad Start (pause_menu)
	InputModeManager.set_touch_preference(InputModeManager.TouchPreference.AUTO, true)
	InputModeManager.set_gamepad_icon_override(InputModeManager.GamepadIconOverride.AUTO, true)
	var start_ev: InputEventJoypadButton = InputEventJoypadButton.new()
	start_ev.button_index = JOY_BUTTON_START
	start_ev.pressed = true
	farm.pause_modal._unhandled_input(start_ev)
	await _wait_frames(2)
	_check(not farm.pause_modal.is_open(), "PauseModal closes cleanly on Gamepad Start (pause_menu)")

	# 9. Verify Multi-Touch Mobile Mode + 20:9 Aspect Ratio + Capture Screenshot 4
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1600, 720))
		await _wait_frames(5)

	var t_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	t_touch.index = 9
	t_touch.pressed = true
	t_touch.position = Vector2(200.0, 90.0)
	InputModeManager._input(t_touch)

	# Confirm Godot touch-emulated mouse events do NOT knock mode back to KEYBOARD_MOUSE!
	var emu_mb: InputEventMouseButton = InputEventMouseButton.new()
	emu_mb.device = InputEvent.DEVICE_ID_EMULATION
	emu_mb.button_index = MOUSE_BUTTON_LEFT
	emu_mb.pressed = true
	InputModeManager._input(emu_mb)
	await _wait_frames(3)

	_check(InputModeManager.is_touch_mode(), "ScreenTouch transitions to TOUCH and ignores DEVICE_ID_EMULATION mouse event")
	_check(farm.mobile_controls.is_overlay_visible(), "MobileControls overlay shows automatically in TOUCH mode")
	_check(not prompt_badge.visible and not quest_badge.visible, "TOUCH mode hides keyboard/gamepad prompt badges cleanly")

	# Ensure interact prompt is active so Interact button glows gold in 20:9 screenshot
	EventBus.interact_prompt_changed.emit("[E] Shipping Chest")
	await _wait_frames(3)
	await _capture_screenshot("Screenshots/controls_mobile_20x9.png")

	# Move player onto open tillable farm soil & test SIMULTANEOUS Multi-Touch (Stick Finger 0 + Use Tool Finger 1!)
	farm.player.global_position = Vector2(360.0, 412.0)
	farm.player.set_facing_cardinal(Vector2i(1, 0))
	InventoryManager.select_hotbar_slot(0) # Hoe
	await _wait_frames(2)

	var stick_center: Vector2 = farm.mobile_controls.get_stick_center_viewport_pos()
	var use_center: Vector2 = farm.mobile_controls.get_use_button_viewport_pos()
	var interact_center: Vector2 = farm.mobile_controls.get_interact_button_viewport_pos()

	var f0_down: InputEventScreenTouch = InputEventScreenTouch.new()
	f0_down.index = 0
	f0_down.pressed = true
	f0_down.position = stick_center
	farm.mobile_controls._input(f0_down)

	var f0_drag: InputEventScreenDrag = InputEventScreenDrag.new()
	f0_drag.index = 0
	f0_drag.position = stick_center + Vector2(18.0, 0.0)
	farm.mobile_controls._input(f0_drag)
	_check(InputModeManager.virtual_move_vector.x > 0.7, "Virtual thumbstick drag drives virtual_move_vector (x=%.2f)" % InputModeManager.virtual_move_vector.x)

	var touch_start_x: float = farm.player.global_position.x
	await _wait_physics(6)
	_check(farm.player.global_position.x > touch_start_x + 3.0, "Player walks east via virtual thumbstick (dx=%.1f)" % (farm.player.global_position.x - touch_start_x))

	# Simultaneous finger 1 presses Use Tool while finger 0 is STILL holding stick!
	var f1_down: InputEventScreenTouch = InputEventScreenTouch.new()
	f1_down.index = 1
	f1_down.pressed = true
	f1_down.position = use_center
	farm.mobile_controls._input(f1_down)
	_check(farm.player.is_busy() and InputModeManager.virtual_move_vector.x > 0.7, "Simultaneous multi-touch: Finger 1 triggers Use Tool while Finger 0 holds stick!")

	var f1_up: InputEventScreenTouch = InputEventScreenTouch.new()
	f1_up.index = 1
	f1_up.pressed = false
	f1_up.position = use_center
	farm.mobile_controls._input(f1_up)

	var f0_up: InputEventScreenTouch = InputEventScreenTouch.new()
	f0_up.index = 0
	f0_up.pressed = false
	f0_up.position = stick_center
	farm.mobile_controls._input(f0_up)
	_check(InputModeManager.virtual_move_vector == Vector2.ZERO, "Releasing thumbstick resets virtual_move_vector to ZERO")

	# Wait for tool swing to finish, step beside ShippingBin, tap Interact -> opens ShippingModal & auto-hides MobileControls!
	await _wait_physics(35)
	farm.player.global_position = farm.shipping_bin.global_position + Vector2(-14.0, 6.0)
	await _wait_physics(4)
	var f2_down: InputEventScreenTouch = InputEventScreenTouch.new()
	f2_down.index = 2
	f2_down.pressed = true
	f2_down.position = interact_center
	farm.mobile_controls._input(f2_down)
	await _wait_frames(3)
	_check(farm.shipping_modal.is_open(), "Touch Interact button triggers ShippingBin -> opens ShippingModal")
	_check(not farm.mobile_controls.is_overlay_visible(), "MobileControls auto-hides while ShippingModal is open")
	farm.shipping_modal.set_open(false)
	await _wait_frames(2)
	_check(farm.mobile_controls.is_overlay_visible(), "MobileControls restores automatically when ShippingModal closes")

	# Clean reset back to Desktop Keyboard defaults before exit
	InputModeManager.set_touch_preference(InputModeManager.TouchPreference.AUTO, true)
	InputModeManager.set_gamepad_icon_override(InputModeManager.GamepadIconOverride.AUTO, true)
	InputModeManager.set_input_mode(InputModeManager.InputMode.KEYBOARD_MOUSE, InputModeManager.GamepadFamily.XBOX)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))

	if _failed:
		print("[VerifyInputModes] RESULT: FAILED")
		get_tree().quit(1)
	else:
		print("[VerifyInputModes] RESULT: ALL CHECKS PASSED")
		get_tree().quit(0)
