extends Node

## Tracks the active player input mode (Keyboard/Mouse, Gamepad, or Mobile Touch),
## auto-detects controller vendor family (Xbox / PlayStation / Nintendo Switch),
## persists user settings (Touch Controls Auto/On/Off + Controller Icons override) in user://settings.json,
## and holds the analog virtual thumbstick vector for multi-touch mobile locomotion.

const ControlIconsScript := preload("res://scripts/core/control_icons.gd")
const UiFocusScript := preload("res://scripts/ui/ui_focus_helper.gd")
const SETTINGS_PATH: String = "user://settings.json"
const STICK_DEADZONE: float = 0.25

enum InputMode {
	KEYBOARD_MOUSE = 0,
	GAMEPAD = 1,
	TOUCH = 2,
}

enum GamepadFamily {
	XBOX = 0,
	PLAYSTATION = 1,
	SWITCH = 2,
}

enum TouchPreference {
	AUTO = 0,
	ON = 1,
	OFF = 2,
}

enum GamepadIconOverride {
	AUTO = 0,
	XBOX = 1,
	PLAYSTATION = 2,
	SWITCH = 3,
}

var current_mode: int = InputMode.KEYBOARD_MOUSE
var detected_gamepad_family: int = GamepadFamily.XBOX
var touch_preference: int = TouchPreference.AUTO
var gamepad_icon_override: int = GamepadIconOverride.AUTO
var virtual_move_vector: Vector2 = Vector2.ZERO
var _pending_saved_volume: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_gamepad_ui_actions()
	load_settings()
	if _pending_saved_volume >= 0.0:
		call_deferred(&"_apply_saved_audio_volume")
	if DisplayServer.is_touchscreen_available():
		current_mode = InputMode.TOUCH
	var pads: PackedInt32Array = Input.get_connected_joypads()
	if not pads.is_empty():
		detected_gamepad_family = detect_gamepad_family_from_name(Input.get_joy_name(pads[0]))
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _ensure_gamepad_ui_actions() -> void:
	_add_joy_btn_if_missing(&"ui_accept", JOY_BUTTON_A)
	_add_joy_btn_if_missing(&"ui_cancel", JOY_BUTTON_B)
	_add_joy_btn_if_missing(&"ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_btn_if_missing(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_btn_if_missing(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_btn_if_missing(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis_if_missing(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_if_missing(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis_if_missing(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_if_missing(&"ui_right", JOY_AXIS_LEFT_X, 1.0)


func _add_joy_btn_if_missing(action: StringName, btn_idx: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == btn_idx:
			return
	var jb: InputEventJoypadButton = InputEventJoypadButton.new()
	jb.device = -1
	jb.button_index = btn_idx
	InputMap.action_add_event(action, jb)


func _add_joy_axis_if_missing(action: StringName, axis: JoyAxis, axis_val: float) -> void:
	if not InputMap.has_action(action):
		return
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
			if jm.axis == axis and signf(jm.axis_value) == signf(axis_val):
				return
	var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
	m.device = -1
	m.axis = axis
	m.axis_value = axis_val
	InputMap.action_add_event(action, m)


func _apply_saved_audio_volume() -> void:
	if _pending_saved_volume < 0.0:
		return
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("set_master_volume"):
		am.call("set_master_volume", _pending_saved_volume)
	_pending_saved_volume = -1.0


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	ControlIconsScript.clear_cache()
	UiFocusScript.clear_cache()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		var fam: int = detect_gamepad_family_from_name(Input.get_joy_name(device))
		if fam != detected_gamepad_family:
			detected_gamepad_family = fam
			if current_mode == InputMode.GAMEPAD:
				_emit_mode_changed()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		set_input_mode(InputMode.TOUCH)
		return

	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event as InputEventJoypadButton
		if jb.pressed:
			var fam: int = detect_gamepad_family_from_name(Input.get_joy_name(jb.device))
			set_input_mode(InputMode.GAMEPAD, fam)
		return

	if event is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = event as InputEventJoypadMotion
		if absf(jm.axis_value) > STICK_DEADZONE:
			var fam: int = detect_gamepad_family_from_name(Input.get_joy_name(jm.device))
			set_input_mode(InputMode.GAMEPAD, fam)
		return

	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			set_input_mode(InputMode.KEYBOARD_MOUSE)
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		# Ignore Godot's touch-emulated mouse events so tapping the screen stays in TOUCH mode!
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.pressed:
			set_input_mode(InputMode.KEYBOARD_MOUSE)


static func detect_gamepad_family_from_name(joy_name: String) -> int:
	var low: String = joy_name.to_lower()
	if (
		"ps4" in low
		or "ps5" in low
		or "dualsense" in low
		or "dualshock" in low
		or "playstation" in low
		or "sony" in low
	):
		return GamepadFamily.PLAYSTATION
	if (
		"switch" in low
		or "nintendo" in low
		or "joy-con" in low
		or "joycon" in low
		or "pro controller" in low
	):
		return GamepadFamily.SWITCH
	return GamepadFamily.XBOX


func set_input_mode(mode: int, detected_family: int = -1) -> void:
	var clamped_mode: int = clampi(mode, InputMode.KEYBOARD_MOUSE, InputMode.TOUCH)
	var changed: bool = (clamped_mode != current_mode)
	current_mode = clamped_mode
	if detected_family >= GamepadFamily.XBOX and detected_family <= GamepadFamily.SWITCH:
		if detected_family != detected_gamepad_family:
			detected_gamepad_family = detected_family
			changed = true
	if current_mode != InputMode.TOUCH:
		virtual_move_vector = Vector2.ZERO
	if changed:
		_emit_mode_changed()


func set_detected_gamepad_family(family: int) -> void:
	var clamped: int = clampi(family, GamepadFamily.XBOX, GamepadFamily.SWITCH)
	if clamped == detected_gamepad_family:
		return
	detected_gamepad_family = clamped
	_emit_mode_changed()


func get_effective_gamepad_family() -> int:
	match gamepad_icon_override:
		GamepadIconOverride.XBOX:
			return GamepadFamily.XBOX
		GamepadIconOverride.PLAYSTATION:
			return GamepadFamily.PLAYSTATION
		GamepadIconOverride.SWITCH:
			return GamepadFamily.SWITCH
		_:
			return detected_gamepad_family


func is_gamepad_mode() -> bool:
	return current_mode == InputMode.GAMEPAD


func is_touch_mode() -> bool:
	return current_mode == InputMode.TOUCH


func is_keyboard_mode() -> bool:
	return current_mode == InputMode.KEYBOARD_MOUSE


func should_show_touch_controls() -> bool:
	match touch_preference:
		TouchPreference.ON:
			return true
		TouchPreference.OFF:
			return false
		_:
			return current_mode == InputMode.TOUCH


func set_touch_preference(pref: int, persist: bool = true) -> void:
	var clamped: int = clampi(pref, TouchPreference.AUTO, TouchPreference.OFF)
	touch_preference = clamped
	if touch_preference == TouchPreference.OFF:
		virtual_move_vector = Vector2.ZERO
	if persist:
		save_settings()
	EventBus.touch_controls_preference_changed.emit(touch_preference)


func cycle_touch_preference() -> int:
	var next_pref: int = (touch_preference + 1) % 3
	set_touch_preference(next_pref, true)
	return next_pref


func get_touch_preference_label() -> String:
	match touch_preference:
		TouchPreference.ON:
			return "On"
		TouchPreference.OFF:
			return "Off"
		_:
			return "Auto"


func set_gamepad_icon_override(override_val: int, persist: bool = true) -> void:
	var clamped: int = clampi(override_val, GamepadIconOverride.AUTO, GamepadIconOverride.SWITCH)
	gamepad_icon_override = clamped
	if persist:
		save_settings()
	_emit_mode_changed()


func cycle_gamepad_icon_override() -> int:
	var next_ov: int = (gamepad_icon_override + 1) % 4
	set_gamepad_icon_override(next_ov, true)
	return next_ov


func get_gamepad_icon_override_label() -> String:
	match gamepad_icon_override:
		GamepadIconOverride.XBOX:
			return "Xbox"
		GamepadIconOverride.PLAYSTATION:
			return "PlayStation"
		GamepadIconOverride.SWITCH:
			return "Switch"
		_:
			return "Auto"


func set_virtual_move_vector(vec: Vector2) -> void:
	if vec.length_squared() > 1.0:
		virtual_move_vector = vec.normalized()
	else:
		virtual_move_vector = vec


func _emit_mode_changed() -> void:
	var eff_family: int = get_effective_gamepad_family()
	EventBus.input_device_changed.emit(current_mode)
	EventBus.input_mode_changed.emit(current_mode, eff_family)


func save_settings() -> bool:
	var payload: Dictionary = {
		"touch_preference": touch_preference,
		"gamepad_icon_override": gamepad_icon_override,
		"master_volume": AudioManager.get_master_volume() if get_node_or_null("/root/AudioManager") != null else 1.0,
	}
	var tmp_path: String = SETTINGS_PATH + ".tmp"
	var fa: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if fa == null:
		return false
	fa.store_string(JSON.stringify(payload, "\t"))
	fa.flush()
	fa.close()

	var abs_tmp: String = ProjectSettings.globalize_path(tmp_path)
	var abs_final: String = ProjectSettings.globalize_path(SETTINGS_PATH)
	var err: Error = DirAccess.rename_absolute(abs_tmp, abs_final)
	if err != OK:
		if FileAccess.file_exists(SETTINGS_PATH):
			DirAccess.remove_absolute(abs_final)
			err = DirAccess.rename_absolute(abs_tmp, abs_final)
	return err == OK


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var fa: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if fa == null:
		return
	var raw: String = fa.get_as_text()
	fa.close()
	if raw.is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed as Dictionary
	touch_preference = clampi(int(d.get("touch_preference", TouchPreference.AUTO)), TouchPreference.AUTO, TouchPreference.OFF)
	gamepad_icon_override = clampi(int(d.get("gamepad_icon_override", GamepadIconOverride.AUTO)), GamepadIconOverride.AUTO, GamepadIconOverride.SWITCH)
	if d.has("master_volume"):
		var vol: float = clampf(float(d["master_volume"]), 0.0, 1.0)
		var am: Node = get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("set_master_volume"):
			am.call("set_master_volume", vol)
		else:
			_pending_saved_volume = vol
