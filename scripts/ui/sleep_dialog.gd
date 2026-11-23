class_name SleepDialog
extends CanvasLayer

## Sunnyside World interactive Bed Sleep confirmation dialog & overnight fade-to-black transition.
## Guards against double-clicks/double-ticks and coordinates TimeManager.sleep_to_next_day().

const AP := preload("res://scripts/core/asset_paths.gd")
const UiFocus := preload("res://scripts/ui/ui_focus_helper.gd")
const DAY_SUMMARY_SCENE_PATH: String = "res://scenes/ui/day_summary_modal.tscn"

signal sleep_flow_started()
signal sleep_flow_completed()
signal dialog_visibility_changed(is_open: bool)

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.45, 0.35, 0.30, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)

const FADE_OUT_SEC: float = 0.32
const HOLD_BLACK_SEC: float = 0.14
const FADE_IN_SEC: float = 0.32

var _is_dialog_open: bool = false
var _is_transitioning: bool = false

var _fade_overlay: TextureRect = null
var _dialog_backdrop: TextureRect = null
var _dialog_panel: SunnysideBox = null
var _subtitle_label: Label = null
var _fade_tween: Tween = null
var _wake_callback: Callable = Callable()
var _day_summary: DaySummaryModal = null
var _pending_forced_weather: StringName = &""
var _pending_midnight_cb: Callable = Callable()
var _built: bool = false
var _yes_btn: Control = null
var _no_btn: Control = null


func set_wake_callback(cb: Callable) -> void:
	_wake_callback = cb


func _ready() -> void:
	layer = 30
	_build_ui()
	_dialog_backdrop.visible = false
	_dialog_panel.visible = false
	_fade_overlay.modulate = Color(0.02, 0.02, 0.06, 0.0)


func is_dialog_open() -> bool:
	return _is_dialog_open or (_day_summary != null and _day_summary.is_open())


func is_transitioning() -> bool:
	return _is_transitioning


func open_dialog() -> void:
	_build_ui()
	if _is_transitioning or _is_dialog_open:
		return
	_is_dialog_open = true
	var next_day: int = TimeManager.current_day + 1
	var next_season_idx: int = TimeManager.current_season
	if next_day > TimeManager.DAYS_PER_SEASON:
		next_day = 1
		next_season_idx = (next_season_idx + 1) % TimeManager.SEASONS_PER_YEAR
	_subtitle_label.text = "%s %d -> %s %d • Restores Vitality" % [
		TimeManager.get_season_name(),
		TimeManager.current_day,
		TimeManager.get_season_name(next_season_idx),
		next_day,
	]
	_dialog_backdrop.visible = true
	_dialog_panel.visible = true
	if _yes_btn != null:
		_yes_btn.grab_focus()
	dialog_visibility_changed.emit(true)


func close_dialog() -> void:
	if not _is_dialog_open:
		return
	_is_dialog_open = false
	_dialog_backdrop.visible = false
	_dialog_panel.visible = false
	dialog_visibility_changed.emit(false)


func get_day_summary_modal() -> DaySummaryModal:
	_build_ui()
	return _day_summary


## Triggers the overnight fade-to-black transition (or immediate path for deterministic headless testing).
## If items were shipped in the Sanctuary Shipping Chest, displays DaySummaryModal before crediting gold & waking!
func begin_sleep_transition(on_midnight_callback: Callable = Callable(), forced_weather: StringName = &"", immediate: bool = false) -> void:
	_build_ui()
	if _is_transitioning:
		return
	close_dialog()
	_is_transitioning = true
	sleep_flow_started.emit()

	var midnight_cb: Callable = on_midnight_callback if on_midnight_callback.is_valid() else _wake_callback
	var completed_day: int = TimeManager.current_day
	var completed_season: int = TimeManager.current_season
	var completed_year: int = TimeManager.current_year

	if immediate:
		if EconomyManager.has_pending_shipments():
			EconomyManager.commit_overnight_shipping(completed_day, completed_season, completed_year)
		TimeManager.sleep_to_next_day(forced_weather)
		if midnight_cb.is_valid():
			midnight_cb.call()
		SaveManager.auto_save_morning()
		_is_transitioning = false
		sleep_flow_completed.emit()
		return

	_pending_forced_weather = forced_weather
	_pending_midnight_cb = midnight_cb

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "modulate:a", 1.0, FADE_OUT_SEC)
	_fade_tween.tween_callback(func() -> void:
		if EconomyManager.has_pending_shipments() and _day_summary != null:
			var ledger: Dictionary = EconomyManager.build_pending_ledger(completed_day, completed_season, completed_year)
			_day_summary.open_summary(ledger, true)
		else:
			_finish_wake_up_fade()
	)


func _exit_tree() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()


func _on_day_summary_continued() -> void:
	if _is_transitioning:
		_finish_wake_up_fade()


func _finish_wake_up_fade() -> void:
	TimeManager.sleep_to_next_day(_pending_forced_weather)
	if _pending_midnight_cb.is_valid():
		_pending_midnight_cb.call()
	SaveManager.auto_save_morning()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_interval(HOLD_BLACK_SEC)
	_fade_tween.tween_property(_fade_overlay, "modulate:a", 0.0, FADE_IN_SEC)
	_fade_tween.tween_callback(func() -> void:
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_transitioning = false
		sleep_flow_completed.emit()
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_dialog_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_inventory"):
		close_dialog()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		begin_sleep_transition()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var w_center: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(w_center != null, "Missing Sunnyside w_box_9slice_c.png")

	# Textured dim dialog backdrop using Sunnyside 9-slice center PNG
	_dialog_backdrop = TextureRect.new()
	_dialog_backdrop.name = "DialogBackdrop"
	_dialog_backdrop.texture = w_center
	_dialog_backdrop.modulate = Color(0.04, 0.04, 0.08, 0.45)
	_dialog_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialog_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_dialog_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dialog_backdrop)

	# Centered 168x74 Sunnyside Confirmation Dialog
	_dialog_panel = SunnysideBox.new()
	_dialog_panel.name = "SleepConfirmPanel"
	_dialog_panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_dialog_panel.anchor_left = 0.5
	_dialog_panel.anchor_top = 0.5
	_dialog_panel.anchor_right = 0.5
	_dialog_panel.anchor_bottom = 0.5
	_dialog_panel.offset_left = -84.0
	_dialog_panel.offset_top = -37.0
	_dialog_panel.offset_right = 84.0
	_dialog_panel.offset_bottom = 37.0
	_dialog_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_dialog_panel)

	var msg_card: SunnysideBox = SunnysideBox.new()
	msg_card.set_box_style(SunnysideBox.Style.WHITE)
	msg_card.position = Vector2(6.0, 6.0)
	msg_card.size = Vector2(156.0, 38.0)
	_dialog_panel.add_child(msg_card)

	var title_lbl: Label = Label.new()
	title_lbl.add_theme_font_size_override(&"font_size", 8)
	title_lbl.add_theme_color_override(&"font_color", TEXT_DARK)
	title_lbl.clip_text = true
	title_lbl.position = Vector2(4.0, 5.0)
	title_lbl.size = Vector2(148.0, 12.0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.text = "Sleep until tomorrow?"
	msg_card.add_child(title_lbl)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override(&"font_size", 6)
	_subtitle_label.add_theme_color_override(&"font_color", TEXT_MUTED)
	_subtitle_label.clip_text = true
	_subtitle_label.position = Vector2(4.0, 20.0)
	_subtitle_label.size = Vector2(148.0, 12.0)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_card.add_child(_subtitle_label)

	# Yes / No Sunnyside Buttons
	_yes_btn = _make_button(_dialog_panel, "YesSleepBtn", "Sleep", AP.UI_CONFIRM, Vector2(10.0, 48.0), Vector2(70.0, 20.0), func() -> void:
		begin_sleep_transition()
	)
	_no_btn = _make_button(_dialog_panel, "NoStayBtn", "Stay Up", AP.UI_CANCEL, Vector2(88.0, 48.0), Vector2(70.0, 20.0), func() -> void:
		close_dialog()
	)
	UiFocus.wire_horizontal_list([_yes_btn, _no_btn], true)

	# Full-screen midnight fade overlay (on top of everything in this CanvasLayer)
	_fade_overlay = TextureRect.new()
	_fade_overlay.name = "MidnightFadeOverlay"
	_fade_overlay.texture = w_center
	_fade_overlay.modulate = Color(0.02, 0.02, 0.06, 0.0)
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fade_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)

	# Overnight Shipping Revenue Summary Modal (shown above black fade when items were shipped!)
	var summary_scene: PackedScene = load(DAY_SUMMARY_SCENE_PATH) as PackedScene
	if summary_scene != null:
		_day_summary = summary_scene.instantiate() as DaySummaryModal
		add_child(_day_summary)
		_day_summary.summary_continued.connect(_on_day_summary_continued)
		_day_summary.modal_visibility_changed.connect(func(is_open: bool) -> void:
			dialog_visibility_changed.emit(is_open)
		)


func _make_button(parent: Control, btn_name: String, text_str: String, icon_path: String, pos: Vector2, btn_size: Vector2, on_press: Callable) -> Control:
	var btn: Control = Control.new()
	btn.name = btn_name
	btn.position = pos
	btn.size = btn_size
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_press.call()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			on_press.call()
	)
	parent.add_child(btn)
	UiFocus.make_focusable(btn, on_press, 5.0, 1.5)

	var box: SunnysideBox = SunnysideBox.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.set_box_style(SunnysideBox.Style.DARK_TAN)
	btn.add_child(box)

	var icon_tr: TextureRect = UiFocus.make_icon_rect(load(icon_path) as Texture2D, Vector2(9.0, 9.0), "BtnIcon")
	UiFocus.make_centered_button_content(btn, text_str, 7, TEXT_CREAM, 3, 2, 2, icon_tr)
	return btn
