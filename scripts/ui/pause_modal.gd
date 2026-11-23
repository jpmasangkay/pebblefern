class_name PauseModal
extends CanvasLayer

## Gameplay Pause & Save Menu rendered on a crisp 0.5x Sunnyside canvas (2x px on 1280x720).
## Locks movement/tools/time and offers Resume, Save Now, Master SFX Volume,
## persistent Touch Controls (Auto/On/Off) and Controller Icons (Auto/Xbox/PlayStation/Switch) toggles,
## a live Vryell pixel-art Controls Reference that updates instantly on mode/vendor switch,
## and Save & Return to Title.

const AP := preload("res://scripts/core/asset_paths.gd")
const ControlIconsScript := preload("res://scripts/core/control_icons.gd")
const InputPromptBadgeScene := preload("res://scenes/ui/input_prompt_badge.tscn")
const UiFocus := preload("res://scripts/ui/ui_focus_helper.gd")
const TITLE_SCENE_PATH: String = "res://scenes/ui/title_screen.tscn"

signal modal_visibility_changed(is_open: bool)

const UI_SCALE: float = 0.5
const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.46, 0.34, 0.27, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_OK: Color = Color(0.45, 0.96, 0.52, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

var _is_open: bool = false
var _built: bool = false

var _root_ctrl: Control = null
var _slot_badge_label: Label = null
var _save_status_label: Label = null
var _vol_bar: TextureRect = null
var _vol_pct_label: Label = null
var _greenbars: Array[Texture2D] = []

var _resume_btn: Control = null
var _save_btn: Control = null
var _vol_down_btn: Control = null
var _vol_up_btn: Control = null
var _touch_btn: Control = null
var _touch_btn_label: Label = null
var _icons_btn: Control = null
var _icons_btn_label: Label = null
var _icons_preview_tr: TextureRect = null
var _title_btn: Control = null

var _ref_mode_label: Label = null
var _ref_rows_holder: Control = null


func _ready() -> void:
	layer = 28
	_build_ui()
	if not EventBus.input_mode_changed.is_connected(_on_input_settings_changed):
		EventBus.input_mode_changed.connect(_on_input_settings_changed)
	if not EventBus.touch_controls_preference_changed.is_connected(_on_touch_pref_changed):
		EventBus.touch_controls_preference_changed.connect(_on_touch_pref_changed)
	set_open(false)


func _exit_tree() -> void:
	if EventBus.input_mode_changed.is_connected(_on_input_settings_changed):
		EventBus.input_mode_changed.disconnect(_on_input_settings_changed)
	if EventBus.touch_controls_preference_changed.is_connected(_on_touch_pref_changed):
		EventBus.touch_controls_preference_changed.disconnect(_on_touch_pref_changed)


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	set_open(not _is_open)


func set_open(open: bool) -> void:
	_build_ui()
	_is_open = open
	visible = open
	if open:
		_refresh_state()
		AudioManager.play_sfx(&"pickup", -10.0, 0.02)
		if _resume_btn != null:
			_resume_btn.grab_focus()
	modal_visibility_changed.emit(open)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause_menu"):
		set_open(false)
		get_viewport().set_input_as_handled()


func trigger_save_now() -> bool:
	var ok: bool = SaveManager.save_slot(SaveManager.active_slot)
	if ok:
		EventBus.toast_requested.emit("Game Saved! (Slot %d)" % SaveManager.active_slot)
		if _save_status_label != null:
			_save_status_label.text = "Game Saved! (Slot %d)" % SaveManager.active_slot
			_save_status_label.add_theme_color_override(&"font_color", TEXT_OK)
	else:
		AudioManager.play_sfx(&"error", -8.0, 0.03)
		EventBus.toast_requested.emit("Save failed!")
		if _save_status_label != null:
			_save_status_label.text = "Save failed!"
	return ok


func trigger_save_and_return_to_title(immediate: bool = false) -> void:
	SaveManager.save_slot(SaveManager.active_slot)
	set_open(false)
	SceneTransition.transition_to_scene(TITLE_SCENE_PATH, &"from_pause", immediate)


func set_volume_ratio(ratio: float, play_preview: bool = true) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	AudioManager.set_master_volume(clamped)
	InputModeManager.save_settings()
	_refresh_volume_display()
	if play_preview and clamped > 0.01:
		AudioManager.play_sfx(&"pickup", -8.0, 0.02)


func cycle_touch_controls() -> void:
	InputModeManager.cycle_touch_preference()
	AudioManager.play_sfx(&"pickup", -10.0, 0.03)
	_refresh_settings_buttons()


func cycle_controller_icons() -> void:
	InputModeManager.cycle_gamepad_icon_override()
	AudioManager.play_sfx(&"pickup", -10.0, 0.03)
	_refresh_settings_buttons()
	_rebuild_controls_reference()


func _on_input_settings_changed(_mode: int, _family: int) -> void:
	if _built:
		_refresh_settings_buttons()
		_rebuild_controls_reference()


func _on_touch_pref_changed(_pref: int) -> void:
	if _built:
		_refresh_settings_buttons()


func _refresh_state() -> void:
	if not _built:
		return
	if _slot_badge_label != null:
		_slot_badge_label.text = "Slot %d · %s" % [SaveManager.active_slot, TimeManager.get_formatted_date()]
	if _save_status_label != null:
		_save_status_label.text = "Auto-saves every morning"
		_save_status_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	_refresh_volume_display()
	_refresh_settings_buttons()
	_rebuild_controls_reference()


func _refresh_volume_display() -> void:
	var vol: float = AudioManager.get_master_volume()
	if _vol_pct_label != null:
		_vol_pct_label.text = "%d%%" % int(roundf(vol * 100.0))
	if _vol_bar != null and not _greenbars.is_empty():
		var idx: int = clampi(int(roundf(vol * float(_greenbars.size() - 1))), 0, _greenbars.size() - 1)
		_vol_bar.texture = _greenbars[idx]


func _refresh_settings_buttons() -> void:
	if _touch_btn_label != null:
		_touch_btn_label.text = "Touch Controls: %s" % InputModeManager.get_touch_preference_label()
	if _icons_btn_label != null:
		_icons_btn_label.text = "Controller: %s" % InputModeManager.get_gamepad_icon_override_label()
	if _icons_preview_tr != null:
		var fam: int = InputModeManager.get_effective_gamepad_family()
		_icons_preview_tr.texture = ControlIconsScript.get_action_texture(
			&"interact",
			InputModeManager.InputMode.GAMEPAD,
			fam,
			false
		)


func _rebuild_controls_reference() -> void:
	if _ref_rows_holder == null:
		return
	for c: Node in _ref_rows_holder.get_children():
		c.queue_free()

	var mode: int = InputModeManager.current_mode
	var fam: int = InputModeManager.get_effective_gamepad_family()
	var fam_name: String = "Xbox"
	if fam == InputModeManager.GamepadFamily.PLAYSTATION:
		fam_name = "PlayStation"
	elif fam == InputModeManager.GamepadFamily.SWITCH:
		fam_name = "Switch"

	# When user explicitly chooses a Controller Icons override while in Keyboard mode,
	# preview that controller layout if currently in GAMEPAD mode; otherwise show live mode.
	var display_mode: int = mode
	if mode == InputModeManager.InputMode.GAMEPAD:
		_ref_mode_label.text = fam_name
	elif mode == InputModeManager.InputMode.TOUCH:
		_ref_mode_label.text = "Touch"
	else:
		_ref_mode_label.text = "Keyboard"

	var rows: Array[Dictionary] = []
	if display_mode == InputModeManager.InputMode.GAMEPAD:
		rows = [
			{"icons": [&"move", &"dpad"], "desc": "Walk / Navigate"},
			{"icons": [&"use_tool"], "desc": "Use Tool / Sword"},
			{"icons": [&"interact"], "desc": "Interact / Accept"},
			{"icons": [&"hotbar_prev", &"hotbar_next"], "desc": "Hotbar / Menu Tabs"},
			{"icons": [&"toggle_inventory"], "desc": "Pack / Craft / Bio"},
			{"icons": [&"toggle_quests"], "desc": "Quest Tracker"},
			{"icons": [&"pause_menu", &"ui_cancel"], "desc": "Pause / Back"},
		]
	elif display_mode == InputModeManager.InputMode.TOUCH:
		rows = [
			{"icons": [&"stick_knob", &"dpad_up"], "desc": "Left Virtual Stick"},
			{"icons": [&"use_tool"], "desc": "Use Tool / Sword", "icon_path": AP.UI_EXPRESSION_WORKING},
			{"icons": [&"interact"], "desc": "Interact / Talk", "icon_path": AP.UI_HAND_OPEN},
			{"icons": [&"hotbar_cycle"], "desc": "Tap Hotbar Slots", "icon_path": AP.UI_BASKET},
			{"icons": [&"toggle_inventory"], "desc": "Top-Right Pack Btn", "icon_path": AP.UI_BASKET},
			{"icons": [&"toggle_quests"], "desc": "Tap Quest Card", "icon_path": AP.UI_EXPRESSION_CHAT},
			{"icons": [&"menu_icon"], "desc": "Top-Right Pause Btn"},
		]
	else:
		rows = [
			{"icons": [&"move_w", &"move_a", &"move_s", &"move_d"], "desc": "Walk (Shift: Sprint)"},
			{"icons": [&"use_tool", &"use_tool_alt"], "desc": "Use Tool / Sword"},
			{"icons": [&"interact", &"interact_alt"], "desc": "Interact / Harvest"},
			{"icons": [&"slot_1", &"slot_8", &"hotbar_cycle"], "desc": "Switch Hotbar"},
			{"icons": [&"toggle_inventory", &"toggle_inventory_alt"], "desc": "Pack / Craft / Bio"},
			{"icons": [&"toggle_quests"], "desc": "Quest Tracker"},
			{"icons": [&"pause_menu"], "desc": "Pause & Save"},
		]

	for i: int in range(rows.size()):
		var row_data: Dictionary = rows[i]
		var ry: float = float(i) * 22.0
		var icon_x: float = 0.0
		if row_data.has("icon_path"):
			var tr_t: TextureRect = TextureRect.new()
			tr_t.texture = load(String(row_data["icon_path"])) as Texture2D
			tr_t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr_t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr_t.position = Vector2(2.0, ry + 3.0)
			tr_t.size = Vector2(12.0, 12.0)
			_ref_rows_holder.add_child(tr_t)
		else:
			var icon_actions: Array = row_data["icons"] as Array
			for j: int in range(icon_actions.size()):
				var act: StringName = icon_actions[j] as StringName
				var atex: AtlasTexture = ControlIconsScript.get_action_texture(act, display_mode, fam, false)
				var tr: TextureRect = TextureRect.new()
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.texture = atex
				var ih: float = 11.0
				var iw: float = 11.0
				if atex != null and atex.get_width() > atex.get_height() + 1:
					iw = minf(16.0, ceilf(ih * float(atex.get_width()) / maxf(1.0, float(atex.get_height()))))
				tr.position = Vector2(icon_x, ry + 3.5)
				tr.size = Vector2(iw, ih)
				_ref_rows_holder.add_child(tr)
				icon_x += iw + 4.0

		var desc_x: float = 48.0 if display_mode != InputModeManager.InputMode.KEYBOARD_MOUSE else 66.0
		var d_lbl: Label = Label.new()
		d_lbl.text = String(row_data["desc"])
		d_lbl.position = Vector2(desc_x, ry + 2.0)
		d_lbl.size = Vector2(170.0 - desc_x, 14.0)
		d_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		d_lbl.clip_text = true
		d_lbl.add_theme_font_size_override(&"font_size", 7)
		d_lbl.add_theme_color_override(&"font_color", TEXT_DARK)
		_ref_rows_holder.add_child(d_lbl)


func _build_ui() -> void:
	if _built:
		return
	_built = true

	for gp: String in AP.GREENBAR_PATHS:
		var gt: Texture2D = load(gp) as Texture2D
		assert(gt != null, "PauseModal missing greenbar PNG: %s" % gp)
		_greenbars.append(gt)

	_root_ctrl = Control.new()
	_root_ctrl.name = "PauseModalRoot"
	_root_ctrl.anchor_left = 0.0
	_root_ctrl.anchor_top = 0.0
	_root_ctrl.anchor_right = 1.0 / UI_SCALE
	_root_ctrl.anchor_bottom = 1.0 / UI_SCALE
	_root_ctrl.scale = Vector2(UI_SCALE, UI_SCALE)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root_ctrl)

	var w_center: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(w_center != null, "PauseModal missing w_box_9slice_c.png")
	var backdrop: TextureRect = TextureRect.new()
	backdrop.name = "PauseBackdrop"
	backdrop.texture = w_center
	backdrop.modulate = Color(0.04, 0.04, 0.08, 0.50)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_root_ctrl.add_child(backdrop)

	# Centered 384x236 Sunnyside Pause Panel (768x472 physical px on 1280x720)
	var panel: SunnysideBox = SunnysideBox.new()
	panel.name = "PausePanel"
	panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -192.0
	panel.offset_top = -118.0
	panel.offset_right = 192.0
	panel.offset_bottom = 118.0
	_root_ctrl.add_child(panel)

	# Top Title Bar
	var hdr: SunnysideBox = SunnysideBox.new()
	hdr.set_box_style(SunnysideBox.Style.DARK_TAN)
	hdr.position = Vector2(8.0, 8.0)
	hdr.size = Vector2(368.0, 24.0)
	panel.add_child(hdr)

	var title_lbl: Label = Label.new()
	title_lbl.text = "Paused — Pebblefern Sanctuary"
	title_lbl.position = Vector2(10.0, 4.0)
	title_lbl.size = Vector2(220.0, 16.0)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override(&"font_size", 10)
	title_lbl.add_theme_color_override(&"font_color", TEXT_GOLD)
	title_lbl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	title_lbl.add_theme_constant_override(&"outline_size", 2)
	hdr.add_child(title_lbl)

	_slot_badge_label = Label.new()
	_slot_badge_label.name = "SlotBadgeLabel"
	_slot_badge_label.position = Vector2(236.0, 4.0)
	_slot_badge_label.size = Vector2(122.0, 16.0)
	_slot_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_slot_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slot_badge_label.add_theme_font_size_override(&"font_size", 8)
	_slot_badge_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	hdr.add_child(_slot_badge_label)

	# LEFT COLUMN: Actions, Volume Slider & Input Settings
	var resume_badge: InputPromptBadge = InputPromptBadgeScene.instantiate() as InputPromptBadge
	resume_badge.name = "ResumeKeyBadge"
	resume_badge.configure(&"pause_menu", Vector2(10.0, 10.0), true, false, false)
	_resume_btn = _make_btn("ResumeBtn", Vector2(10.0, 38.0), Vector2(172.0, 22.0), "Resume Game", TEXT_CREAM, func() -> void: set_open(false), resume_badge)
	panel.add_child(_resume_btn)

	_save_btn = _make_btn("SaveNowBtn", Vector2(10.0, 63.0), Vector2(172.0, 22.0), "Save Now", TEXT_GOLD, func() -> void: trigger_save_now())
	panel.add_child(_save_btn)

	# Save Status Strip
	var st_box: SunnysideBox = SunnysideBox.new()
	st_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	st_box.position = Vector2(10.0, 88.0)
	st_box.size = Vector2(172.0, 14.0)
	panel.add_child(st_box)

	_save_status_label = Label.new()
	_save_status_label.name = "SaveStatusLabel"
	_save_status_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_status_label.add_theme_font_size_override(&"font_size", 7)
	_save_status_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	st_box.add_child(_save_status_label)

	# Master SFX Volume Card
	var vol_card: SunnysideBox = SunnysideBox.new()
	vol_card.name = "VolumeCard"
	vol_card.set_box_style(SunnysideBox.Style.WHITE)
	vol_card.position = Vector2(10.0, 106.0)
	vol_card.size = Vector2(172.0, 38.0)
	panel.add_child(vol_card)

	var vol_hdr: Label = Label.new()
	vol_hdr.text = "Master SFX Volume"
	vol_hdr.position = Vector2(8.0, 4.0)
	vol_hdr.size = Vector2(114.0, 12.0)
	vol_hdr.add_theme_font_size_override(&"font_size", 8)
	vol_hdr.add_theme_color_override(&"font_color", TEXT_DARK)
	vol_card.add_child(vol_hdr)

	_vol_pct_label = Label.new()
	_vol_pct_label.name = "VolumePctLabel"
	_vol_pct_label.position = Vector2(124.0, 4.0)
	_vol_pct_label.size = Vector2(40.0, 12.0)
	_vol_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vol_pct_label.add_theme_font_size_override(&"font_size", 8)
	_vol_pct_label.add_theme_color_override(&"font_color", TEXT_DARK)
	vol_card.add_child(_vol_pct_label)

	_vol_down_btn = _make_btn("VolDownBtn", Vector2(8.0, 18.0), Vector2(20.0, 15.0), "-", TEXT_CREAM, func() -> void:
		set_volume_ratio(AudioManager.get_master_volume() - 0.15, true)
	)
	vol_card.add_child(_vol_down_btn)

	var slider_hit: Control = Control.new()
	slider_hit.name = "VolumeSliderTrack"
	slider_hit.position = Vector2(32.0, 19.0)
	slider_hit.size = Vector2(108.0, 13.0)
	slider_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	slider_hit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var lx: float = (ev as InputEventMouseButton).position.x
			set_volume_ratio(lx / maxf(1.0, slider_hit.size.x), true)
			slider_hit.accept_event()
		elif ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var lx2: float = (ev as InputEventMouseMotion).position.x
			set_volume_ratio(lx2 / maxf(1.0, slider_hit.size.x), false)
			slider_hit.accept_event()
	)
	vol_card.add_child(slider_hit)

	_vol_bar = TextureRect.new()
	_vol_bar.name = "VolumeBarFill"
	_vol_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vol_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vol_bar.stretch_mode = TextureRect.STRETCH_SCALE
	_vol_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vol_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_hit.add_child(_vol_bar)

	_vol_up_btn = _make_btn("VolUpBtn", Vector2(144.0, 18.0), Vector2(20.0, 15.0), "+", TEXT_CREAM, func() -> void:
		set_volume_ratio(AudioManager.get_master_volume() + 0.15, true)
	)
	vol_card.add_child(_vol_up_btn)

	# Touch Controls: Auto / On / Off toggle
	_touch_btn = _make_btn("TouchControlsBtn", Vector2(10.0, 148.0), Vector2(172.0, 21.0), "Touch Controls: Auto", TEXT_CREAM, func() -> void:
		cycle_touch_controls()
	)
	_touch_btn_label = _touch_btn.find_child("BtnLabel", true, false) as Label
	panel.add_child(_touch_btn)

	# Controller Icons: Auto / Xbox / PlayStation / Switch toggle
	_icons_preview_tr = UiFocus.make_icon_rect(null, Vector2(10.0, 10.0), "ControllerPreviewIcon")
	_icons_btn = _make_btn("ControllerIconsBtn", Vector2(10.0, 173.0), Vector2(172.0, 21.0), "Controller: Auto", TEXT_CREAM, func() -> void:
		cycle_controller_icons()
	, _icons_preview_tr)
	_icons_btn_label = _icons_btn.find_child("BtnLabel", true, false) as Label
	panel.add_child(_icons_btn)

	_title_btn = _make_btn("ReturnTitleBtn", Vector2(10.0, 200.0), Vector2(172.0, 26.0), "Save & Return to Title", TEXT_CREAM, func() -> void:
		trigger_save_and_return_to_title(false)
	)
	panel.add_child(_title_btn)

	# RIGHT COLUMN: Live Vryell Controls Reference Parchment
	var ref_card: SunnysideBox = SunnysideBox.new()
	ref_card.name = "ControlsReferenceCard"
	ref_card.set_box_style(SunnysideBox.Style.WHITE)
	ref_card.position = Vector2(190.0, 38.0)
	ref_card.size = Vector2(184.0, 188.0)
	panel.add_child(ref_card)

	var ref_hdr: Label = Label.new()
	ref_hdr.text = "Controls"
	ref_hdr.position = Vector2(8.0, 6.0)
	ref_hdr.size = Vector2(88.0, 14.0)
	ref_hdr.add_theme_font_size_override(&"font_size", 9)
	ref_hdr.add_theme_color_override(&"font_color", TEXT_DARK)
	ref_card.add_child(ref_hdr)

	var mode_pill: SunnysideBox = SunnysideBox.new()
	mode_pill.set_box_style(SunnysideBox.Style.DARK_TAN)
	mode_pill.position = Vector2(104.0, 5.0)
	mode_pill.size = Vector2(72.0, 14.0)
	ref_card.add_child(mode_pill)

	_ref_mode_label = Label.new()
	_ref_mode_label.name = "ControlsModeLabel"
	_ref_mode_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ref_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ref_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ref_mode_label.add_theme_font_size_override(&"font_size", 7)
	_ref_mode_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	mode_pill.add_child(_ref_mode_label)

	_ref_rows_holder = Control.new()
	_ref_rows_holder.name = "ControlsRowsHolder"
	_ref_rows_holder.position = Vector2(8.0, 24.0)
	_ref_rows_holder.size = Vector2(170.0, 158.0)
	ref_card.add_child(_ref_rows_holder)

	# Wire full controller focus navigation on Left Column
	UiFocus.wire_vertical_list([_resume_btn, _save_btn, _vol_down_btn, _touch_btn, _icons_btn, _title_btn], true)
	_vol_down_btn.focus_neighbor_right = _vol_down_btn.get_path_to(_vol_up_btn)
	_vol_down_btn.focus_neighbor_left = _vol_down_btn.get_path_to(_vol_up_btn)
	_vol_up_btn.focus_neighbor_left = _vol_up_btn.get_path_to(_vol_down_btn)
	_vol_up_btn.focus_neighbor_right = _vol_up_btn.get_path_to(_vol_down_btn)
	_vol_up_btn.focus_neighbor_top = _vol_up_btn.get_path_to(_save_btn)
	_vol_up_btn.focus_neighbor_bottom = _vol_up_btn.get_path_to(_touch_btn)

	_refresh_state()


func _make_btn(btn_name: String, pos: Vector2, sz: Vector2, text_str: String, col: Color, cb: Callable, leading_icon: Control = null) -> Control:
	var btn: Control = Control.new()
	btn.name = btn_name
	btn.position = pos
	btn.size = sz
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			cb.call()
			btn.accept_event()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			cb.call()
			btn.accept_event()
	)
	UiFocus.make_focusable(btn, cb, 5.0, 1.5)

	var bg: SunnysideBox = SunnysideBox.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_box_style(SunnysideBox.Style.DARK_TAN)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)

	var pad_x: int = 2 if sz.x <= 24.0 else 6
	var pad_y: int = 1 if sz.y <= 16.0 else 3
	UiFocus.make_centered_button_content(btn, text_str, 8, col, pad_x, pad_y, 4, leading_icon, OUTLINE_DARK, 2)
	return btn
