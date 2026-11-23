class_name MobileControls
extends CanvasLayer

## Multi-Touch Mobile Controls Overlay (scenes/ui/mobile_controls.tscn).
## Rendered on a crisp 0.5x virtual canvas (exact 2x px on 1280x720 and 1600x720) with safe-area insets.
## Tracks independent finger indices (InputEventScreenTouch + InputEventScreenDrag) so the player can
## walk with the bottom-left virtual thumbstick while simultaneously tapping Use Tool or Interact!
## Uses ONLY real Vryell Controllers and Keyboard sprites + Sunnyside World UI PNGs.

const AP := preload("res://scripts/core/asset_paths.gd")
const ControlIconsScript := preload("res://scripts/core/control_icons.gd")

const UI_SCALE: float = 0.5
const MOBILE_EDGE_MARGIN: float = 12.0   # 24px physical (+ safe area)
const TOUCH_CORNER_INSET: float = 13.0   # 26px physical (+ safe area)
const CLOCK_PANEL_WIDTH: float = 120.0   # Matches GameplayHUD.CLOCK_WIDTH
const UTIL_BTN_SIZE: float = 28.0        # 56x56 physical px
const UTIL_BTN_GAP: float = 4.0          # 8px physical gap between Backpack & Pause
const UTIL_CLOCK_GAP: float = 6.0        # 12px physical gap left of Clock/Gold

const STICK_PAD_SIZE: float = 68.0       # 136x136 physical px (tight ergonomic footprint)
const STICK_KNOB_SIZE: float = 20.0      # 40x40 physical px = exact 2x integer 1:1 scale of 10x10 neutral cap
const STICK_MAX_RADIUS: float = 19.0
const STICK_DEADZONE: float = 0.15
const STICK_HIT_MARGIN: float = 12.0

const USE_BTN_SIZE: float = 46.0         # 92x92 physical px
const ACT_BTN_SIZE: float = 38.0         # 76x76 physical px
const ACT_USE_GAP: float = 7.0           # 14px physical gap between ACT and USE
const ACT_DIAG_LIFT: float = 14.0        # 28px physical diagonal thumb arc above USE bottom
const BTN_HIT_MARGIN: float = 4.0

# Shared right-anchored coordinates so GameplayHUD centers the active interact pill directly above ACT!
const ACT_RIGHT_OFFSET_X: float = -(TOUCH_CORNER_INSET + USE_BTN_SIZE + ACT_USE_GAP) # -66.0
const ACT_CENTER_OFFSET_X: float = ACT_RIGHT_OFFSET_X - (ACT_BTN_SIZE * 0.5)         # -85.0
const ACT_TOP_OFFSET_Y: float = -(TOUCH_CORNER_INSET + ACT_DIAG_LIFT + ACT_BTN_SIZE) # -65.0

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.90, 0.45, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

const USE_IDLE_TINT: Color = Color(1.0, 1.0, 1.0, 0.94)
const USE_PRESSED_TINT: Color = Color(0.86, 0.86, 0.86, 1.0)
const ACT_IDLE_TINT: Color = Color(0.95, 0.94, 0.92, 0.88)
const ACT_ACTIVE_TINT: Color = Color(1.05, 1.02, 0.86, 0.98)
const ACT_PRESSED_TINT: Color = Color(0.86, 0.86, 0.86, 1.0)

var _built: bool = false
var _modal_hidden: bool = false
var _force_hidden: bool = false
var _has_interact_prompt: bool = false

var _player: Player = null
var _inventory_cb: Callable = Callable()
var _pause_cb: Callable = Callable()

var _root_ctrl: Control = null
var _stick_pad: SunnysideBox = null
var _stick_knob: TextureRect = null
var _use_btn: Control = null
var _use_box: SunnysideBox = null
var _use_icon: TextureRect = null
var _use_label: Label = null
var _interact_btn: Control = null
var _interact_box: SunnysideBox = null
var _interact_icon: TextureRect = null
var _interact_label: Label = null
var _pack_btn: Control = null
var _pause_btn: Control = null

var _stick_finger: int = -1
var _use_finger: int = -1
var _interact_finger: int = -1
var _use_hold_active: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	layer = 14
	_build_ui()
	_connect_signals()
	_refresh_equipped_tool_icon()
	_refresh_visibility()


func _exit_tree() -> void:
	_reset_touch_state()
	_disconnect_signals()


func bind_scene(p_player: Player, on_toggle_inventory: Callable, on_toggle_pause: Callable) -> void:
	_player = p_player
	_inventory_cb = on_toggle_inventory
	_pause_cb = on_toggle_pause
	_refresh_equipped_tool_icon()
	_refresh_visibility()


func set_modal_hidden(hidden: bool) -> void:
	_modal_hidden = hidden
	_refresh_visibility()


func set_force_hidden(hidden: bool) -> void:
	_force_hidden = hidden
	_refresh_visibility()


func is_overlay_visible() -> bool:
	return visible


func get_stick_center_viewport_pos() -> Vector2:
	if _stick_pad == null:
		return Vector2.ZERO
	return _stick_pad.get_global_transform_with_canvas() * (_stick_pad.size * 0.5)


func get_use_button_viewport_pos() -> Vector2:
	if _use_btn == null:
		return Vector2.ZERO
	return _use_btn.get_global_transform_with_canvas() * (_use_btn.size * 0.5)


func get_interact_button_viewport_pos() -> Vector2:
	if _interact_btn == null:
		return Vector2.ZERO
	return _interact_btn.get_global_transform_with_canvas() * (_interact_btn.size * 0.5)


func get_pack_button_viewport_pos() -> Vector2:
	if _pack_btn == null:
		return Vector2.ZERO
	return _pack_btn.get_global_transform_with_canvas() * (_pack_btn.size * 0.5)


func get_pause_button_viewport_pos() -> Vector2:
	if _pause_btn == null:
		return Vector2.ZERO
	return _pause_btn.get_global_transform_with_canvas() * (_pause_btn.size * 0.5)


func _connect_signals() -> void:
	if not EventBus.input_mode_changed.is_connected(_on_input_mode_changed):
		EventBus.input_mode_changed.connect(_on_input_mode_changed)
	if not EventBus.touch_controls_preference_changed.is_connected(_on_touch_pref_changed):
		EventBus.touch_controls_preference_changed.connect(_on_touch_pref_changed)
	if not EventBus.hotbar_selection_changed.is_connected(_on_hotbar_changed):
		EventBus.hotbar_selection_changed.connect(_on_hotbar_changed)
	if not EventBus.inventory_changed.is_connected(_refresh_equipped_tool_icon):
		EventBus.inventory_changed.connect(_refresh_equipped_tool_icon)
	if not EventBus.interact_prompt_changed.is_connected(_on_interact_prompt_changed):
		EventBus.interact_prompt_changed.connect(_on_interact_prompt_changed)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_safe_area_insets):
		get_viewport().size_changed.connect(_apply_safe_area_insets)


func _disconnect_signals() -> void:
	if EventBus.input_mode_changed.is_connected(_on_input_mode_changed):
		EventBus.input_mode_changed.disconnect(_on_input_mode_changed)
	if EventBus.touch_controls_preference_changed.is_connected(_on_touch_pref_changed):
		EventBus.touch_controls_preference_changed.disconnect(_on_touch_pref_changed)
	if EventBus.hotbar_selection_changed.is_connected(_on_hotbar_changed):
		EventBus.hotbar_selection_changed.disconnect(_on_hotbar_changed)
	if EventBus.inventory_changed.is_connected(_refresh_equipped_tool_icon):
		EventBus.inventory_changed.disconnect(_refresh_equipped_tool_icon)
	if EventBus.interact_prompt_changed.is_connected(_on_interact_prompt_changed):
		EventBus.interact_prompt_changed.disconnect(_on_interact_prompt_changed)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_apply_safe_area_insets):
		get_viewport().size_changed.disconnect(_apply_safe_area_insets)


func _on_input_mode_changed(_mode: int, _family: int) -> void:
	_refresh_visibility()


func _on_touch_pref_changed(_pref: int) -> void:
	_refresh_visibility()


func _on_hotbar_changed(_idx: int) -> void:
	_refresh_equipped_tool_icon()


func _on_interact_prompt_changed(prompt_text: String) -> void:
	_has_interact_prompt = not prompt_text.strip_edges().is_empty()
	_refresh_interact_highlight()


func _refresh_visibility() -> void:
	var show_now: bool = (
		not _force_hidden
		and not _modal_hidden
		and InputModeManager.should_show_touch_controls()
	)
	visible = show_now
	if show_now:
		_apply_safe_area_insets()
	else:
		_reset_touch_state()


func _reset_touch_state() -> void:
	_stick_finger = -1
	_use_finger = -1
	_interact_finger = -1
	_use_hold_active = false
	if InputModeManager != null:
		InputModeManager.set_virtual_move_vector(Vector2.ZERO)
	_center_stick_knob()
	if _use_box != null:
		_use_box.modulate = USE_IDLE_TINT
	_refresh_interact_highlight()


func _process(delta: float) -> void:
	if not visible:
		return
	var dt: float = minf(delta, 0.05)
	_pulse_time += dt

	# Subtle warm highlight pulse on ACT (same Sunnyside frame style!) when near an interactable
	if _has_interact_prompt and _interact_box != null and _interact_finger == -1:
		var pulse: float = 0.99 + 0.05 * sin(_pulse_time * 6.0)
		_interact_box.modulate = Color(1.04 * pulse, 1.00 * pulse, 0.84, 0.98)

	# Dynamic Use label while fishing bite window is live
	if _player != null and is_instance_valid(_player) and _use_label != null:
		if _player.is_fishing():
			_use_label.text = "REEL!" if _player.get_fish_phase() == Player.FishPhase.BITE_WINDOW else "WAIT"
		else:
			_use_label.text = "USE"

	# Continuous hold-to-use (tilled rows / watering / chopping) while finger holds Use button
	if _use_hold_active and _player != null and is_instance_valid(_player):
		if not _player.is_controls_locked() and not _player.is_fishing() and not _player.is_busy():
			_player.use_selected_item(false, true)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func _handle_screen_touch(ev: InputEventScreenTouch) -> void:
	var vp_pos: Vector2 = ev.position
	if ev.pressed:
		# 1. Bottom-Left Virtual Thumbstick
		if _stick_finger == -1 and _hit_control(_stick_pad, vp_pos, STICK_HIT_MARGIN):
			_stick_finger = ev.index
			_update_stick_from_viewport_pos(vp_pos)
			get_viewport().set_input_as_handled()
			return

		# 2. Primary Use Tool / Sword / Fish button
		if _use_finger == -1 and _hit_control(_use_btn, vp_pos, BTN_HIT_MARGIN):
			_use_finger = ev.index
			_use_hold_active = true
			if _use_box != null:
				_use_box.modulate = USE_PRESSED_TINT
			_trigger_use_tool()
			get_viewport().set_input_as_handled()
			return

		# 3. Secondary Contextual Interact button
		if _interact_finger == -1 and _hit_control(_interact_btn, vp_pos, BTN_HIT_MARGIN):
			_interact_finger = ev.index
			if _interact_box != null:
				_interact_box.modulate = ACT_PRESSED_TINT
			_trigger_interact()
			get_viewport().set_input_as_handled()
			return

		# 4. Top-Right Pack button (left of Clock/Gold)
		if _hit_control(_pack_btn, vp_pos, BTN_HIT_MARGIN):
			if _inventory_cb.is_valid():
				_inventory_cb.call()
			get_viewport().set_input_as_handled()
			return

		# 5. Top-Right Pause button (left of Clock/Gold)
		if _hit_control(_pause_btn, vp_pos, BTN_HIT_MARGIN):
			if _pause_cb.is_valid():
				_pause_cb.call()
			get_viewport().set_input_as_handled()
			return
	else:
		if ev.index == _stick_finger:
			_stick_finger = -1
			_center_stick_knob()
			InputModeManager.set_virtual_move_vector(Vector2.ZERO)
			get_viewport().set_input_as_handled()
			return
		if ev.index == _use_finger:
			_use_finger = -1
			_use_hold_active = false
			if _use_box != null:
				_use_box.modulate = USE_IDLE_TINT
			get_viewport().set_input_as_handled()
			return
		if ev.index == _interact_finger:
			_interact_finger = -1
			_refresh_interact_highlight()
			get_viewport().set_input_as_handled()
			return


func _handle_screen_drag(ev: InputEventScreenDrag) -> void:
	if ev.index == _stick_finger:
		_update_stick_from_viewport_pos(ev.position)
		get_viewport().set_input_as_handled()


func _hit_control(ctrl: Control, vp_pos: Vector2, margin: float) -> bool:
	if ctrl == null or not ctrl.visible:
		return false
	var local_pt: Vector2 = ctrl.get_global_transform_with_canvas().affine_inverse() * vp_pos
	return Rect2(Vector2.ZERO, ctrl.size).grow(margin).has_point(local_pt)


func _update_stick_from_viewport_pos(vp_pos: Vector2) -> void:
	if _stick_pad == null or _stick_knob == null:
		return
	var local_pt: Vector2 = _stick_pad.get_global_transform_with_canvas().affine_inverse() * vp_pos
	var center: Vector2 = _stick_pad.size * 0.5
	var delta: Vector2 = local_pt - center
	var dist: float = delta.length()
	var clamped_delta: Vector2 = delta if dist <= STICK_MAX_RADIUS else (delta / dist) * STICK_MAX_RADIUS
	_stick_knob.position = center + clamped_delta - (_stick_knob.size * 0.5)

	var norm_mag: float = clampf(dist / STICK_MAX_RADIUS, 0.0, 1.0)
	if norm_mag < STICK_DEADZONE:
		InputModeManager.set_virtual_move_vector(Vector2.ZERO)
		return
	var scaled_mag: float = (norm_mag - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
	var dir: Vector2 = delta / maxf(dist, 0.0001)
	InputModeManager.set_virtual_move_vector(dir * scaled_mag)


func _center_stick_knob() -> void:
	if _stick_pad != null and _stick_knob != null:
		_stick_knob.position = (_stick_pad.size * 0.5) - (_stick_knob.size * 0.5)


func _trigger_use_tool() -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_controls_locked():
		return
	if _player.is_fishing():
		_player.handle_fishing_action_input()
		return
	if not _player.is_busy():
		_player.use_selected_item(true, false)


func _trigger_interact() -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_controls_locked():
		return
	if _player.is_fishing():
		_player.handle_fishing_action_input()
		return
	if not _player.is_busy():
		EventBus.player_interacted.emit(_player.get_target_cell())


func _refresh_equipped_tool_icon() -> void:
	if _use_icon == null:
		return
	var item: ItemData = InventoryManager.get_selected_item_data()
	if item != null and item.icon != null:
		_use_icon.texture = item.icon
		_use_icon.modulate = item.icon_tint
	else:
		_use_icon.texture = load(AP.UI_HAND_OPEN) as Texture2D
		_use_icon.modulate = Color.WHITE


func _refresh_interact_highlight() -> void:
	if _interact_box == null or _interact_label == null:
		return
	# Keep EXACT same clean Sunnyside LIGHT_TAN frame on both USE and ACT; subtly warm-highlight ACT when near an interactable!
	_interact_box.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_interact_box.modulate = ACT_ACTIVE_TINT if _has_interact_prompt else ACT_IDLE_TINT
	_interact_label.add_theme_color_override(&"font_color", TEXT_DARK)
	_interact_label.add_theme_constant_override(&"outline_size", 0)


func _apply_safe_area_insets() -> void:
	if _root_ctrl == null or get_viewport() == null:
		return
	var win_sz: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var inset_l: float = 0.0
	var inset_r: float = 0.0
	var inset_t: float = 0.0
	var inset_b: float = 0.0
	if win_sz.x > 0 and win_sz.y > 0 and safe.size.x > 0 and safe.size.y > 0:
		var vp_sz: Vector2 = get_viewport().get_visible_rect().size
		var sx: float = (vp_sz.x / float(win_sz.x)) / UI_SCALE
		var sy: float = (vp_sz.y / float(win_sz.y)) / UI_SCALE
		inset_l = clampf(float(maxi(0, safe.position.x)) * sx, 0.0, 28.0)
		inset_t = clampf(float(maxi(0, safe.position.y)) * sy, 0.0, 16.0)
		inset_r = clampf(float(maxi(0, win_sz.x - safe.end.x)) * sx, 0.0, 28.0)
		inset_b = clampf(float(maxi(0, win_sz.y - safe.end.y)) * sy, 0.0, 16.0)
	_root_ctrl.offset_left = inset_l
	_root_ctrl.offset_top = inset_t
	_root_ctrl.offset_right = -inset_r
	_root_ctrl.offset_bottom = -inset_b


func _build_ui() -> void:
	if _built:
		return
	_built = true

	_root_ctrl = Control.new()
	_root_ctrl.name = "MobileControlsRoot"
	_root_ctrl.anchor_left = 0.0
	_root_ctrl.anchor_top = 0.0
	_root_ctrl.anchor_right = 1.0 / UI_SCALE
	_root_ctrl.anchor_bottom = 1.0 / UI_SCALE
	_root_ctrl.scale = Vector2(UI_SCALE, UI_SCALE)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root_ctrl)

	# 1. BOTTOM-LEFT VIRTUAL THUMBSTICK (68x68 = 136x136 physical px, inset 26px from bottom-left corner!)
	_stick_pad = SunnysideBox.new()
	_stick_pad.name = "VirtualThumbstickPad"
	_stick_pad.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_stick_pad.modulate = Color(1.0, 1.0, 1.0, 0.88)
	_stick_pad.anchor_left = 0.0
	_stick_pad.anchor_top = 1.0
	_stick_pad.anchor_right = 0.0
	_stick_pad.anchor_bottom = 1.0
	_stick_pad.offset_left = TOUCH_CORNER_INSET
	_stick_pad.offset_top = -(TOUCH_CORNER_INSET + STICK_PAD_SIZE)
	_stick_pad.offset_right = TOUCH_CORNER_INSET + STICK_PAD_SIZE
	_stick_pad.offset_bottom = -TOUCH_CORNER_INSET
	_stick_pad.size = Vector2(STICK_PAD_SIZE, STICK_PAD_SIZE)
	_stick_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_stick_pad)

	var stick_well: SunnysideBox = SunnysideBox.new()
	stick_well.set_box_style(SunnysideBox.Style.DARK_TAN)
	stick_well.position = Vector2(6.0, 6.0)
	stick_well.size = Vector2(STICK_PAD_SIZE - 12.0, STICK_PAD_SIZE - 12.0)
	stick_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_pad.add_child(stick_well)

	# 4 tight-cropped Vryell directional arrows at exact 1:1 pixel ratio symmetrically centered inside the stick well!
	var pad_c: float = STICK_PAD_SIZE * 0.5
	var arrow_inset: float = 11.0
	var arrow_specs: Array[Array] = [
		[&"dpad_up", Vector2(pad_c - 3.0, arrow_inset), Vector2(6.0, 3.0)],
		[&"dpad_down", Vector2(pad_c - 3.0, STICK_PAD_SIZE - arrow_inset - 3.0), Vector2(6.0, 3.0)],
		[&"dpad_left", Vector2(arrow_inset, pad_c - 3.0), Vector2(3.0, 6.0)],
		[&"dpad_right", Vector2(STICK_PAD_SIZE - arrow_inset - 3.0, pad_c - 3.0), Vector2(3.0, 6.0)],
	]
	for spec: Array in arrow_specs:
		var arr: TextureRect = TextureRect.new()
		arr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arr.modulate = Color(1.0, 1.0, 1.0, 0.78)
		arr.position = spec[1] as Vector2
		arr.size = spec[2] as Vector2
		arr.texture = ControlIconsScript.get_action_texture(spec[0] as StringName, InputModeManager.InputMode.TOUCH, 0, false)
		_stick_pad.add_child(arr)

	_stick_knob = TextureRect.new()
	_stick_knob.name = "ThumbstickKnob"
	_stick_knob.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stick_knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stick_knob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_knob.size = Vector2(STICK_KNOB_SIZE, STICK_KNOB_SIZE)
	_stick_knob.texture = ControlIconsScript.get_action_texture(&"stick_knob", InputModeManager.InputMode.TOUCH, 0, false)
	_stick_pad.add_child(_stick_knob)
	_center_stick_knob()

	# 2. BOTTOM-RIGHT PRIMARY USE BUTTON (46x46 = 92x92 physical px, inset 26px from bottom-right corner!)
	# Clean unified Sunnyside LIGHT_TAN frame (zero cramped inner sub-box!) with MarginContainer(12px) -> VBoxContainer(sep=4px)!
	_use_btn = Control.new()
	_use_btn.name = "TouchUseButton"
	_use_btn.anchor_left = 1.0
	_use_btn.anchor_top = 1.0
	_use_btn.anchor_right = 1.0
	_use_btn.anchor_bottom = 1.0
	_use_btn.offset_left = -(TOUCH_CORNER_INSET + USE_BTN_SIZE)
	_use_btn.offset_top = -(TOUCH_CORNER_INSET + USE_BTN_SIZE)
	_use_btn.offset_right = -TOUCH_CORNER_INSET
	_use_btn.offset_bottom = -TOUCH_CORNER_INSET
	_use_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_use_btn)

	_use_box = SunnysideBox.new()
	_use_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_use_box.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_use_box.modulate = USE_IDLE_TINT
	_use_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use_btn.add_child(_use_box)

	var use_parts: Dictionary = _build_action_btn_interior(
		_use_btn,
		"EquippedToolIcon",
		Vector2(18.0, 18.0), # 36x36 physical px
		"UseBtnLabel",
		"USE",
		7,
		6 # 12px physical margin all around
	)
	_use_icon = use_parts["icon"] as TextureRect
	_use_label = use_parts["label"] as Label

	# 3. DIAGONAL LEFT CONTEXTUAL ACT BUTTON (38x38 = 76x76 physical px, 14px gap left of USE, clear of Hotbar!)
	# EXACT same clean Sunnyside LIGHT_TAN frame style with MarginContainer(12px) -> VBoxContainer(sep=4px)!
	_interact_btn = Control.new()
	_interact_btn.name = "TouchInteractButton"
	_interact_btn.anchor_left = 1.0
	_interact_btn.anchor_top = 1.0
	_interact_btn.anchor_right = 1.0
	_interact_btn.anchor_bottom = 1.0
	_interact_btn.offset_left = ACT_RIGHT_OFFSET_X - ACT_BTN_SIZE
	_interact_btn.offset_top = ACT_TOP_OFFSET_Y
	_interact_btn.offset_right = ACT_RIGHT_OFFSET_X
	_interact_btn.offset_bottom = ACT_TOP_OFFSET_Y + ACT_BTN_SIZE
	_interact_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_interact_btn)

	_interact_box = SunnysideBox.new()
	_interact_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_interact_box.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_interact_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_btn.add_child(_interact_box)

	var act_parts: Dictionary = _build_action_btn_interior(
		_interact_btn,
		"InteractIcon",
		Vector2(15.0, 15.0), # 30x30 physical px
		"InteractBtnLabel",
		"ACT",
		6,
		6 # 12px physical margin all around
	)
	_interact_icon = act_parts["icon"] as TextureRect
	_interact_icon.texture = load(AP.UI_HAND_OPEN) as Texture2D
	_interact_label = act_parts["label"] as Label
	_refresh_interact_highlight()

	# 4. TOP-RIGHT UTILITY PAIR (Backpack & Pause ||) neatly placed left of the top-right Clock/Gold card!
	# Leaves the top-left corner 100% open for the Quest Tracker!
	var pause_right_x: float = -(MOBILE_EDGE_MARGIN + CLOCK_PANEL_WIDTH + UTIL_CLOCK_GAP)
	var pack_right_x: float = pause_right_x - UTIL_BTN_SIZE - UTIL_BTN_GAP

	_pack_btn = _make_top_right_util_btn("TouchPackButton", pack_right_x, MOBILE_EDGE_MARGIN)
	var pack_ic: TextureRect = TextureRect.new()
	pack_ic.name = "PackIcon"
	pack_ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pack_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pack_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pack_ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pack_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pack_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_ic.custom_minimum_size = Vector2(14.0, 14.0)
	pack_ic.texture = load(AP.UI_BASKET) as Texture2D
	_pack_btn.get_node("UtilMargin").add_child(pack_ic)
	_root_ctrl.add_child(_pack_btn)

	_pause_btn = _make_top_right_util_btn("TouchPauseButton", pause_right_x, MOBILE_EDGE_MARGIN)
	_pause_btn.get_node("UtilMargin").add_child(_make_pause_bars_icon())
	_root_ctrl.add_child(_pause_btn)

	_apply_safe_area_insets()


func _build_action_btn_interior(
	parent: Control,
	icon_name: String,
	icon_min_sz: Vector2,
	label_name: String,
	label_text: String,
	font_size: int,
	margin_px: int
) -> Dictionary:
	var mc: MarginContainer = MarginContainer.new()
	mc.name = "BtnMargin"
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_theme_constant_override(&"margin_left", margin_px)
	mc.add_theme_constant_override(&"margin_right", margin_px)
	mc.add_theme_constant_override(&"margin_top", margin_px)
	mc.add_theme_constant_override(&"margin_bottom", margin_px)
	parent.add_child(mc)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "BtnVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override(&"separation", 2) # 4px physical separation
	mc.add_child(vbox)

	var ic: TextureRect = TextureRect.new()
	ic.name = icon_name
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.custom_minimum_size = icon_min_sz
	vbox.add_child(ic)

	var lbl: Label = Label.new()
	lbl.name = label_name
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override(&"font_size", font_size)
	lbl.add_theme_color_override(&"font_color", TEXT_DARK)
	vbox.add_child(lbl)

	return {"icon": ic, "label": lbl}


func _make_top_right_util_btn(bname: String, right_offset_x: float, top_offset_y: float) -> Control:
	var btn: Control = Control.new()
	btn.name = bname
	btn.anchor_left = 1.0
	btn.anchor_top = 0.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 0.0
	btn.offset_left = right_offset_x - UTIL_BTN_SIZE
	btn.offset_top = top_offset_y
	btn.offset_right = right_offset_x
	btn.offset_bottom = top_offset_y + UTIL_BTN_SIZE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box: SunnysideBox = SunnysideBox.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	box.modulate = Color(1.0, 1.0, 1.0, 0.94)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	var mc: MarginContainer = MarginContainer.new()
	mc.name = "UtilMargin"
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_theme_constant_override(&"margin_left", 6)
	mc.add_theme_constant_override(&"margin_right", 6)
	mc.add_theme_constant_override(&"margin_top", 6)
	mc.add_theme_constant_override(&"margin_bottom", 6)
	btn.add_child(mc)
	return btn


## Builds an unmistakable crisp pixel-art Pause (||) glyph using Sunnyside's real 9-slice fill texture.
func _make_pause_bars_icon() -> Control:
	var fill_tex: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(fill_tex != null, "MobileControls missing w_box_9slice_c.png for Pause icon.")

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "PauseBarsIcon"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override(&"separation", 3) # 6px physical gap between the two bars

	for idx: int in range(2):
		var bar_outer: TextureRect = TextureRect.new()
		bar_outer.name = "PauseBar_%d" % idx
		bar_outer.texture = fill_tex
		bar_outer.self_modulate = OUTLINE_DARK
		bar_outer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bar_outer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar_outer.stretch_mode = TextureRect.STRETCH_SCALE
		bar_outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar_outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar_outer.custom_minimum_size = Vector2(4.0, 12.0) # 8x24 physical px crisp vertical bar
		bar_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var bar_inner: TextureRect = TextureRect.new()
		bar_inner.texture = fill_tex
		bar_inner.modulate = Color(0.36, 0.22, 0.16, 1.0)
		bar_inner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bar_inner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar_inner.stretch_mode = TextureRect.STRETCH_SCALE
		bar_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar_inner.offset_left = 1.0
		bar_inner.offset_top = 1.0
		bar_inner.offset_right = -1.0
		bar_inner.offset_bottom = -1.0
		bar_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_outer.add_child(bar_inner)
		hbox.add_child(bar_outer)
	return hbox
