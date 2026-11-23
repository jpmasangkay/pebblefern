class_name ControlIcons
extends RefCounted

## Verified 16x16 AtlasTexture registry for the Vryell Controllers and Keyboard icon pack.
## Every (col, row) coordinate below was visually verified against labeled 16x16 grid overlays
## of kb_light_all.png, mouse.png, sticks.png, controller_xbox.png, controller_ps.png, and controller_switch.png.

const AP := preload("res://scripts/core/asset_paths.gd")
const CELL_PX: int = 16

# Static texture cache keyed by "sheet_path|col,row" (zero duplicate AtlasTextures in UI hot paths)
static var _sheet_cache: Dictionary = {}
static var _atlas_cache: Dictionary = {}


static func clear_cache() -> void:
	_atlas_cache.clear()
	_sheet_cache.clear()


static func _get_sheet(path: String) -> Texture2D:
	if not _sheet_cache.has(path):
		var tex: Texture2D = load(path) as Texture2D
		assert(tex != null, "ControlIcons missing Vryell PNG spritesheet: %s" % path)
		_sheet_cache[path] = tex
	return _sheet_cache[path] as Texture2D


static func _tight_crop_region(sheet: Texture2D, raw_rect: Rect2i) -> Rect2:
	var img: Image = sheet.get_image()
	if img == null:
		return Rect2(raw_rect)
	var min_x: int = raw_rect.end.x
	var min_y: int = raw_rect.end.y
	var max_x: int = raw_rect.position.x - 1
	var max_y: int = raw_rect.position.y - 1
	var end_x: int = mini(raw_rect.end.x, img.get_width())
	var end_y: int = mini(raw_rect.end.y, img.get_height())
	for py: int in range(maxi(0, raw_rect.position.y), end_y):
		for px: int in range(maxi(0, raw_rect.position.x), end_x):
			if img.get_pixel(px, py).a > 0.01:
				if px < min_x:
					min_x = px
				if py < min_y:
					min_y = py
				if px > max_x:
					max_x = px
				if py > max_y:
					max_y = py
	if max_x < min_x or max_y < min_y:
		return Rect2(raw_rect)
	return Rect2(
		float(min_x),
		float(min_y),
		float(max_x - min_x + 1),
		float(max_y - min_y + 1)
	)


static func get_cell_atlas(sheet_path: String, col: int, row: int, w_cells: int = 1, h_cells: int = 1) -> AtlasTexture:
	var key: String = "%s|%d,%d,%d,%d" % [sheet_path, col, row, w_cells, h_cells]
	if _atlas_cache.has(key):
		return _atlas_cache[key] as AtlasTexture
	var sheet: Texture2D = _get_sheet(sheet_path)
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = sheet
	var raw_rect: Rect2i = Rect2i(col * CELL_PX, row * CELL_PX, w_cells * CELL_PX, h_cells * CELL_PX)
	at.region = _tight_crop_region(sheet, raw_rect)
	_atlas_cache[key] = at
	return at


## Returns the verified Vryell AtlasTexture for any logical game action in the given InputMode & GamepadFamily.
## Returns null in TOUCH mode when `hide_on_touch` is true so world prompts show clean tap-friendly labels.
static func get_action_texture(
	action_name: StringName,
	mode: int,
	gamepad_family: int = 0,
	hide_on_touch: bool = true
) -> AtlasTexture:
	# Always-available device-agnostic sprites for Touch Controls & D-Pad/Stick glyphs
	match action_name:
		&"stick_knob":
			# Exact 10x10 centered neutral thumbstick cap (col 1, row 0 — zero bottom stem distortion!)
			return get_cell_atlas(AP.VRYELL_STICKS, 1, 0)
		&"left_stick":
			return get_cell_atlas(AP.VRYELL_STICKS, 0, 3)
		&"dpad_up":
			return get_cell_atlas(AP.VRYELL_STICKS, 0, 11)
		&"dpad_left":
			return get_cell_atlas(AP.VRYELL_STICKS, 1, 11)
		&"dpad_down":
			return get_cell_atlas(AP.VRYELL_STICKS, 2, 11)
		&"dpad_right":
			return get_cell_atlas(AP.VRYELL_STICKS, 3, 11)
		&"menu_icon":
			return get_cell_atlas(AP.VRYELL_XBOX, 0, 11)

	if mode == InputModeManager.InputMode.TOUCH:
		if hide_on_touch:
			return null
		# Fallback clean gamepad/arrow glyph if explicitly requested in touch reference UI
		return _get_keyboard_texture(action_name)

	if mode == InputModeManager.InputMode.GAMEPAD:
		return _get_gamepad_texture(action_name, gamepad_family)

	return _get_keyboard_texture(action_name)


static func _get_keyboard_texture(action_name: StringName) -> AtlasTexture:
	match action_name:
		&"interact":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 4)   # Key E
		&"use_tool":
			return get_cell_atlas(AP.VRYELL_MOUSE, 1, 1)      # Light Mouse LMB (orange left click)
		&"use_tool_alt":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 8, 8)   # Spacebar
		&"interact_alt":
			return get_cell_atlas(AP.VRYELL_MOUSE, 2, 1)      # Light Mouse RMB
		&"move":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 22)  # Key W (paired with A/S/D or standalone move glyph)
		&"move_w":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 22)  # W
		&"move_a":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 0)   # A
		&"move_s":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 18)  # S
		&"move_d":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 3)   # D
		&"sprint":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 8, 5)   # Shift
		&"toggle_inventory":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 8, 2)   # Tab
		&"toggle_inventory_alt":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 8)   # Key I
		&"toggle_quests":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 16)  # Key Q
		&"pause_menu", &"ui_cancel":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 8, 0)   # Esc
		&"ui_accept":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 8, 25)  # Enter
		&"hotbar_prev", &"hotbar_next", &"hotbar_cycle":
			return get_cell_atlas(AP.VRYELL_MOUSE, 3, 1)      # Mouse Scroll Wheel
		&"slot_1":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 4, 12)  # Key 1
		&"slot_2":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 4, 13)  # Key 2
		&"slot_3":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 4, 14)  # Key 3
		&"slot_4":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 4, 15)  # Key 4
		&"slot_5":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 4, 16)  # Key 5
		&"slot_6":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 4, 17)  # Key 6
		&"slot_7":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 4, 18)  # Key 7
		&"slot_8":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 4, 19)  # Key 8
		&"arrow_up":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 12, 12)
		&"arrow_left":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 12, 13)
		&"arrow_down":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 12, 14)
		&"arrow_right":
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 12, 15)
		_:
			return get_cell_atlas(AP.VRYELL_KB_LIGHT, 0, 4)


static func _get_gamepad_texture(action_name: StringName, family: int) -> AtlasTexture:
	if action_name == &"move":
		return get_cell_atlas(AP.VRYELL_STICKS, 0, 3) # Left Stick (L)
	if action_name == &"sprint":
		return get_cell_atlas(AP.VRYELL_STICKS, 3, 10) # L3

	match family:
		InputModeManager.GamepadFamily.PLAYSTATION:
			match action_name:
				&"interact", &"ui_accept":
					return get_cell_atlas(AP.VRYELL_PS, 0, 4)   # Cross (South)
				&"use_tool":
					return get_cell_atlas(AP.VRYELL_PS, 0, 2)   # Square (West)
				&"toggle_inventory":
					return get_cell_atlas(AP.VRYELL_PS, 0, 0)   # Triangle (North)
				&"ui_cancel":
					return get_cell_atlas(AP.VRYELL_PS, 0, 6)   # Circle (East)
				&"hotbar_prev":
					return get_cell_atlas(AP.VRYELL_PS, 0, 24)  # L1
				&"hotbar_next", &"hotbar_cycle":
					return get_cell_atlas(AP.VRYELL_PS, 0, 30)  # R1
				&"toggle_quests":
					return get_cell_atlas(AP.VRYELL_PS, 0, 21)  # Touchpad / Select
				&"pause_menu":
					return get_cell_atlas(AP.VRYELL_PS, 0, 20)  # Options / Start
				&"dpad":
					return get_cell_atlas(AP.VRYELL_PS, 1, 8)   # PS D-Pad
				_:
					return get_cell_atlas(AP.VRYELL_PS, 0, 4)

		InputModeManager.GamepadFamily.SWITCH:
			match action_name:
				&"interact", &"ui_accept":
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 4)   # B (South)
				&"use_tool":
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 2)   # Y (West)
				&"toggle_inventory":
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 0)   # X (North)
				&"ui_cancel":
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 6)   # A (East)
				&"hotbar_prev":
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 26)  # L
				&"hotbar_next", &"hotbar_cycle":
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 32)  # R
				&"toggle_quests":
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 22)  # Minus (-)
				&"pause_menu":
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 20)  # Plus (+)
				&"dpad":
					return get_cell_atlas(AP.VRYELL_SWITCH, 1, 8)   # Switch D-Pad
				_:
					return get_cell_atlas(AP.VRYELL_SWITCH, 0, 4)

		_: # XBOX (default)
			match action_name:
				&"interact", &"ui_accept":
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 4)   # A (South, green)
				&"use_tool":
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 2)   # X (West, cyan)
				&"toggle_inventory":
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 0)   # Y (North, yellow)
				&"ui_cancel":
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 6)   # B (East, red)
				&"hotbar_prev":
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 16)  # LB
				&"hotbar_next", &"hotbar_cycle":
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 22)  # RB
				&"toggle_quests":
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 13)  # View / Back
				&"pause_menu":
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 11)  # Menu / Start
				&"dpad":
					return get_cell_atlas(AP.VRYELL_XBOX, 1, 8)   # Xbox D-Pad
				_:
					return get_cell_atlas(AP.VRYELL_XBOX, 0, 4)
