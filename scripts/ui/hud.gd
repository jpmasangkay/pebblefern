class_name GameplayHUD
extends CanvasLayer

## Sleek Sunnyside World gameplay HUD rendered on a crisp 0.5x virtual canvas
## (exact 2x integer pixel scale on 1280x720, ~62% of raw 320x180 footprint so >88% stays open world):
## - Compact top-right Day/Season/Time/Weather & Sunbursts corner badge
## - Dead-centered slim bottom 8-slot Hotbar with inside-slot stack counts & top-right Cu/Fe tier badges
## - Compact bottom-right Vitality & Watering Can gauges aligned on the same baseline with wide breathing room

const AP := preload("res://scripts/core/asset_paths.gd")
const InputPromptBadgeScript := preload("res://scripts/ui/input_prompt_badge.gd")

const HUD_SCALE: float = 0.5
const DESKTOP_MARGIN: float = 10.0       # 20px physical margin on desktop 16:9
const MOBILE_MARGIN: float = 12.0        # 24px physical margin (+ safe area) on mobile 20:9 / touch
const CLOCK_WIDTH: float = 120.0         # Matches MobileControls.CLOCK_PANEL_WIDTH
const CLOCK_HEIGHT: float = 60.0
const GAUGES_DESKTOP_WIDTH: float = 108.0
const GAUGES_HEIGHT: float = 40.0
const GAUGES_DOCK_GAP: float = 4.0       # 8px physical gap below Clock/Gold in TOUCH mode
const HOTBAR_WIDTH: float = 252.0
const HOTBAR_HEIGHT: float = 40.0
const QUEST_WIDTH: float = 156.0
const PROMPT_HEIGHT: float = 22.0
const ACT_PROMPT_GAP: float = 6.0        # 12px physical gap centered above ACT button

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.42, 0.30, 0.24, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

var _root_ctrl: Control = null
var _clock_panel: SunnysideBox = null
var _gauges_panel: SunnysideBox = null
var _hotbar_panel: SunnysideBox = null
var _date_label: Label = null
var _time_label: Label = null
var _sunbursts_label: Label = null
var _weather_icon: TextureRect = null
var _vitality_bar: TextureRect = null
var _vitality_icon: TextureRect = null
var _vitality_val_label: Label = null
var _water_bar: TextureRect = null
var _water_val_label: Label = null
var _hotbar_slots: Array[SunnysideSlot] = []
var _toast_panel: SunnysideBox = null
var _toast_label: Label = null
var _toast_tween: Tween = null
var _prompt_panel: SunnysideBox = null
var _prompt_badge: InputPromptBadgeScript = null
var _prompt_label: Label = null
var _raw_prompt_text: String = ""
var _hotbar_lb_badge: InputPromptBadgeScript = null
var _hotbar_rb_badge: InputPromptBadgeScript = null
var _quest_tracker_panel: SunnysideBox = null
var _quest_body_card: SunnysideBox = null
var _quest_key_badge: InputPromptBadgeScript = null
var _quest_header_label: Label = null
var _quest_lines_label: Label = null
var _quest_tracker_expanded: bool = true

var _greenbars: Array[Texture2D] = []
var _redbars: Array[Texture2D] = []
var _bluebars: Array[Texture2D] = []
var _tex_sunny: Texture2D = null
var _tex_rain: Texture2D = null
var _tex_snow: Texture2D = null
var _tex_coin: Texture2D = null
var _tex_heart: Texture2D = null
var _tex_stress: Texture2D = null
var _built: bool = false


func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()
	refresh_all()


func _exit_tree() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	if get_viewport() != null and get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.disconnect(_apply_responsive_layout)
	_disconnect_signals()


func _build_ui() -> void:
	if _built:
		return
	_built = true

	for p: String in AP.GREENBAR_PATHS:
		_greenbars.append(load(p) as Texture2D)
	for p: String in AP.REDBAR_PATHS:
		_redbars.append(load(p) as Texture2D)
	for p: String in AP.BLUEBAR_PATHS:
		_bluebars.append(load(p) as Texture2D)

	_tex_sunny = load(AP.CROPS_ROOT + "/sunflower_05.png") as Texture2D
	_tex_rain = load(AP.ICON_WATERING_CAN) as Texture2D
	var ts_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	var snow_atlas: AtlasTexture = AtlasTexture.new()
	snow_atlas.atlas = ts_tex
	snow_atlas.region = Rect2(11 * 16 + 2, 22 * 16 + 2, 12, 12)
	_tex_snow = snow_atlas

	var coin_atlas: AtlasTexture = AtlasTexture.new()
	coin_atlas.atlas = ts_tex
	# Tight-crop TILE_COIN_PILE (non-transparent pixels sit in x=1..14, y=0..7) so coin centers vertically!
	coin_atlas.region = Rect2(AP.TILE_COIN_PILE.x * 16 + 1, AP.TILE_COIN_PILE.y * 16, 14, 8)
	_tex_coin = coin_atlas

	_tex_heart = load(AP.UI_HEART) as Texture2D
	_tex_stress = load(AP.UI_STRESS) as Texture2D

	# Anchor [0..2] x [0..2] scaled by 0.5 -> crisp 640x360 virtual HUD canvas (exact 2x pixels at 1280x720)
	_root_ctrl = Control.new()
	_root_ctrl.name = "HUDRoot"
	_root_ctrl.anchor_left = 0.0
	_root_ctrl.anchor_top = 0.0
	_root_ctrl.anchor_right = 1.0 / HUD_SCALE
	_root_ctrl.anchor_bottom = 1.0 / HUD_SCALE
	_root_ctrl.offset_left = 0.0
	_root_ctrl.offset_top = 0.0
	_root_ctrl.offset_right = 0.0
	_root_ctrl.offset_bottom = 0.0
	_root_ctrl.scale = Vector2(HUD_SCALE, HUD_SCALE)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root_ctrl)

	_build_clock_panel()
	_build_gauges_panel()
	_build_hotbar_panel()
	_build_quest_tracker_panel()
	_build_toast_and_prompt()
	_apply_responsive_layout()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)


func _is_mobile_edge_layout() -> bool:
	if InputModeManager.should_show_touch_controls():
		return true
	var vp: Viewport = get_viewport()
	if vp != null:
		var vp_sz: Vector2 = vp.get_visible_rect().size
		if vp_sz.y > 0.0 and (vp_sz.x / vp_sz.y) >= 1.95:
			return true
	return false


func _get_edge_margin() -> float:
	return MOBILE_MARGIN if _is_mobile_edge_layout() else DESKTOP_MARGIN


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
		var sx: float = (vp_sz.x / float(win_sz.x)) / HUD_SCALE
		var sy: float = (vp_sz.y / float(win_sz.y)) / HUD_SCALE
		inset_l = clampf(float(maxi(0, safe.position.x)) * sx, 0.0, 28.0)
		inset_t = clampf(float(maxi(0, safe.position.y)) * sy, 0.0, 16.0)
		inset_r = clampf(float(maxi(0, win_sz.x - safe.end.x)) * sx, 0.0, 28.0)
		inset_b = clampf(float(maxi(0, win_sz.y - safe.end.y)) * sy, 0.0, 16.0)
	_root_ctrl.offset_left = inset_l
	_root_ctrl.offset_top = inset_t
	_root_ctrl.offset_right = -inset_r
	_root_ctrl.offset_bottom = -inset_b


func _apply_responsive_layout() -> void:
	_apply_safe_area_insets()
	var m: float = _get_edge_margin()
	var is_touch_ui: bool = InputModeManager.should_show_touch_controls()

	if _clock_panel != null:
		_clock_panel.anchor_left = 1.0
		_clock_panel.anchor_top = 0.0
		_clock_panel.anchor_right = 1.0
		_clock_panel.anchor_bottom = 0.0
		_clock_panel.offset_left = -(m + CLOCK_WIDTH)
		_clock_panel.offset_top = m
		_clock_panel.offset_right = -m
		_clock_panel.offset_bottom = m + CLOCK_HEIGHT

	if _gauges_panel != null:
		if is_touch_ui:
			# Dock Vitality/Watering cleanly under top-right Clock/Gold card (8px physical = 4.0 virtual gap!)
			var g_top: float = m + CLOCK_HEIGHT + GAUGES_DOCK_GAP
			_gauges_panel.anchor_left = 1.0
			_gauges_panel.anchor_top = 0.0
			_gauges_panel.anchor_right = 1.0
			_gauges_panel.anchor_bottom = 0.0
			_gauges_panel.offset_left = -(m + CLOCK_WIDTH)
			_gauges_panel.offset_top = g_top
			_gauges_panel.offset_right = -m
			_gauges_panel.offset_bottom = g_top + GAUGES_HEIGHT
		else:
			# Desktop / Gamepad: restore to bottom-right corner aligned flush with Hotbar
			_gauges_panel.anchor_left = 1.0
			_gauges_panel.anchor_top = 1.0
			_gauges_panel.anchor_right = 1.0
			_gauges_panel.anchor_bottom = 1.0
			_gauges_panel.offset_left = -(m + GAUGES_DESKTOP_WIDTH)
			_gauges_panel.offset_top = -(m + GAUGES_HEIGHT)
			_gauges_panel.offset_right = -m
			_gauges_panel.offset_bottom = -m

	if _hotbar_panel != null:
		_hotbar_panel.anchor_left = 0.5
		_hotbar_panel.anchor_top = 1.0
		_hotbar_panel.anchor_right = 0.5
		_hotbar_panel.anchor_bottom = 1.0
		_hotbar_panel.offset_left = -HOTBAR_WIDTH * 0.5
		_hotbar_panel.offset_top = -(m + HOTBAR_HEIGHT)
		_hotbar_panel.offset_right = HOTBAR_WIDTH * 0.5
		_hotbar_panel.offset_bottom = -m

	if _toast_panel != null:
		_toast_panel.offset_bottom = -(m + HOTBAR_HEIGHT + 6.0)
		_toast_panel.offset_top = _toast_panel.offset_bottom - 20.0

	_refresh_quest_tracker()
	if _prompt_panel != null and _prompt_panel.visible:
		_position_interact_prompt(_prompt_label.text)


func _build_clock_panel() -> void:
	# Top-right Day/Season/Time/Weather & Sunbursts card (120x60 = 240x120 physical px, uniform inner padding!)
	_clock_panel = SunnysideBox.new()
	_clock_panel.name = "ClockPanel"
	_clock_panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_clock_panel.anchor_left = 1.0
	_clock_panel.anchor_top = 0.0
	_clock_panel.anchor_right = 1.0
	_clock_panel.anchor_bottom = 0.0
	_clock_panel.offset_left = -(DESKTOP_MARGIN + CLOCK_WIDTH)
	_clock_panel.offset_top = DESKTOP_MARGIN
	_clock_panel.offset_right = -DESKTOP_MARGIN
	_clock_panel.offset_bottom = DESKTOP_MARGIN + CLOCK_HEIGHT
	_root_ctrl.add_child(_clock_panel)

	var inner_white: SunnysideBox = SunnysideBox.new()
	inner_white.name = "DateTimeCard"
	inner_white.set_box_style(SunnysideBox.Style.WHITE)
	inner_white.position = Vector2(5.0, 5.0)
	inner_white.size = Vector2(110.0, 31.0)
	_clock_panel.add_child(inner_white)

	var dt_margin: MarginContainer = MarginContainer.new()
	dt_margin.name = "DateTimeMargin"
	dt_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dt_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dt_margin.add_theme_constant_override(&"margin_left", 6)
	dt_margin.add_theme_constant_override(&"margin_right", 6)
	dt_margin.add_theme_constant_override(&"margin_top", 3)
	dt_margin.add_theme_constant_override(&"margin_bottom", 3)
	inner_white.add_child(dt_margin)

	var dt_hbox: HBoxContainer = HBoxContainer.new()
	dt_hbox.name = "DateTimeHBox"
	dt_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dt_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dt_hbox.add_theme_constant_override(&"separation", 4)
	dt_margin.add_child(dt_hbox)

	var watch_icon: TextureRect = TextureRect.new()
	watch_icon.name = "StopwatchIcon"
	watch_icon.texture = load(AP.UI_STOPWATCH) as Texture2D
	watch_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	watch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	watch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	watch_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	watch_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	watch_icon.custom_minimum_size = Vector2(12.0, 14.0)
	watch_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dt_hbox.add_child(watch_icon)

	var dt_vbox: VBoxContainer = VBoxContainer.new()
	dt_vbox.name = "DateTimeLabels"
	dt_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dt_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dt_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dt_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dt_vbox.add_theme_constant_override(&"separation", 0)
	dt_hbox.add_child(dt_vbox)

	_date_label = Label.new()
	_date_label.name = "DateLabel"
	_date_label.add_theme_font_size_override(&"font_size", 8)
	_date_label.add_theme_color_override(&"font_color", TEXT_MUTED)
	_date_label.clip_text = true
	_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dt_vbox.add_child(_date_label)

	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.add_theme_font_size_override(&"font_size", 10)
	_time_label.add_theme_color_override(&"font_color", TEXT_DARK)
	_time_label.clip_text = true
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dt_vbox.add_child(_time_label)

	_weather_icon = TextureRect.new()
	_weather_icon.name = "WeatherIcon"
	_weather_icon.texture = _tex_sunny
	_weather_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weather_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weather_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weather_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_weather_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_weather_icon.custom_minimum_size = Vector2(16.0, 16.0)
	_weather_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dt_hbox.add_child(_weather_icon)

	# Bottom Sunbursts gold strip (keeps SunburstIcon directly at y=4, h=8 inside 16px box for crisp centering & test parity!)
	var gold_box: SunnysideBox = SunnysideBox.new()
	gold_box.name = "SunburstsBox"
	gold_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	gold_box.position = Vector2(5.0, 39.0)
	gold_box.size = Vector2(110.0, 16.0)
	_clock_panel.add_child(gold_box)

	var coin_icon: TextureRect = TextureRect.new()
	coin_icon.name = "SunburstIcon"
	coin_icon.texture = _tex_coin
	coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.position = Vector2(6.0, 4.0)
	coin_icon.size = Vector2(14.0, 8.0)
	gold_box.add_child(coin_icon)

	_sunbursts_label = Label.new()
	_sunbursts_label.name = "SunburstsLabel"
	_sunbursts_label.add_theme_font_size_override(&"font_size", 9)
	_sunbursts_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	_sunbursts_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_sunbursts_label.add_theme_constant_override(&"outline_size", 2)
	_sunbursts_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sunbursts_label.offset_left = 22.0
	_sunbursts_label.offset_top = 0.0
	_sunbursts_label.offset_right = -6.0
	_sunbursts_label.offset_bottom = 0.0
	_sunbursts_label.clip_text = true
	_sunbursts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sunbursts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_box.add_child(_sunbursts_label)


func _build_gauges_panel() -> void:
	# Vitality & Watering Can panel with balanced inner MarginContainer padding (12px L/R, 8px T/B physical!)
	# Docks below ClockPanel in TOUCH mode; sits bottom-right on Desktop/Gamepad!
	_gauges_panel = SunnysideBox.new()
	_gauges_panel.name = "GaugesPanel"
	_gauges_panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_gauges_panel.anchor_left = 1.0
	_gauges_panel.anchor_top = 1.0
	_gauges_panel.anchor_right = 1.0
	_gauges_panel.anchor_bottom = 1.0
	_gauges_panel.offset_left = -(DESKTOP_MARGIN + GAUGES_DESKTOP_WIDTH)
	_gauges_panel.offset_top = -(DESKTOP_MARGIN + GAUGES_HEIGHT)
	_gauges_panel.offset_right = -DESKTOP_MARGIN
	_gauges_panel.offset_bottom = -DESKTOP_MARGIN
	_root_ctrl.add_child(_gauges_panel)

	var mc: MarginContainer = MarginContainer.new()
	mc.name = "GaugesMargin"
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_theme_constant_override(&"margin_left", 6)
	mc.add_theme_constant_override(&"margin_right", 6)
	mc.add_theme_constant_override(&"margin_top", 4)
	mc.add_theme_constant_override(&"margin_bottom", 4)
	_gauges_panel.add_child(mc)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "GaugesVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override(&"separation", 3)
	mc.add_child(vbox)

	# Row 1: Vitality bar (greenbar_00..06 / redbar_00..06)
	var row1: HBoxContainer = HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_theme_constant_override(&"separation", 4)
	vbox.add_child(row1)

	_vitality_icon = TextureRect.new()
	_vitality_icon.name = "VitalityIcon"
	_vitality_icon.texture = _tex_heart
	_vitality_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vitality_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vitality_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vitality_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_vitality_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_vitality_icon.custom_minimum_size = Vector2(11.0, 11.0)
	_vitality_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(_vitality_icon)

	_vitality_bar = TextureRect.new()
	_vitality_bar.name = "VitalityBar"
	_vitality_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vitality_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vitality_bar.stretch_mode = TextureRect.STRETCH_SCALE
	_vitality_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vitality_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_vitality_bar.custom_minimum_size = Vector2(44.0, 9.0)
	_vitality_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(_vitality_bar)

	_vitality_val_label = Label.new()
	_vitality_val_label.name = "VitalityValue"
	_vitality_val_label.add_theme_font_size_override(&"font_size", 9)
	_vitality_val_label.add_theme_color_override(&"font_color", TEXT_DARK)
	_vitality_val_label.custom_minimum_size = Vector2(22.0, 12.0)
	_vitality_val_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_vitality_val_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_vitality_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vitality_val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row1.add_child(_vitality_val_label)

	# Row 2: Watering Can gauge (bluebar_00..05)
	var row2: HBoxContainer = HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_theme_constant_override(&"separation", 4)
	vbox.add_child(row2)

	var water_icon: TextureRect = TextureRect.new()
	water_icon.name = "WaterIcon"
	water_icon.texture = _tex_rain
	water_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	water_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	water_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	water_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	water_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	water_icon.custom_minimum_size = Vector2(11.0, 11.0)
	water_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(water_icon)

	_water_bar = TextureRect.new()
	_water_bar.name = "WaterBar"
	_water_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_water_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_water_bar.stretch_mode = TextureRect.STRETCH_SCALE
	_water_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_water_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_water_bar.custom_minimum_size = Vector2(44.0, 9.0)
	_water_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(_water_bar)

	_water_val_label = Label.new()
	_water_val_label.name = "WaterValue"
	_water_val_label.add_theme_font_size_override(&"font_size", 9)
	_water_val_label.add_theme_color_override(&"font_color", TEXT_DARK)
	_water_val_label.custom_minimum_size = Vector2(22.0, 12.0)
	_water_val_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_water_val_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_water_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_water_val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row2.add_child(_water_val_label)


func _build_hotbar_panel() -> void:
	# Dead-centered slim 8-slot Hotbar (252x40 = 504x80 physical px, clean >=20px desktop / >=24px mobile bottom margin!)
	_hotbar_panel = SunnysideBox.new()
	_hotbar_panel.name = "HotbarPanel"
	_hotbar_panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_hotbar_panel.anchor_left = 0.5
	_hotbar_panel.anchor_top = 1.0
	_hotbar_panel.anchor_right = 0.5
	_hotbar_panel.anchor_bottom = 1.0
	_hotbar_panel.offset_left = -HOTBAR_WIDTH * 0.5
	_hotbar_panel.offset_top = -(DESKTOP_MARGIN + HOTBAR_HEIGHT)
	_hotbar_panel.offset_right = HOTBAR_WIDTH * 0.5
	_hotbar_panel.offset_bottom = -DESKTOP_MARGIN
	_root_ctrl.add_child(_hotbar_panel)

	_hotbar_slots.clear()
	for i: int in range(InventoryManager.HOTBAR_SIZE):
		var slot: SunnysideSlot = SunnysideSlot.new()
		slot.name = "HotbarSlot_%d" % i
		slot.configure(i, Vector2(28.0, 28.0), true)
		slot.position = Vector2(7.0 + float(i) * 30.0, 6.0)
		slot.slot_clicked.connect(_on_hotbar_slot_clicked)
		_hotbar_panel.add_child(slot)
		_hotbar_slots.append(slot)

	# Flanking Vryell LB/RB (Xbox), L1/R1 (PS), or L/R (Switch) bumper badges in Gamepad mode!
	_hotbar_lb_badge = InputPromptBadgeScript.new()
	_hotbar_lb_badge.name = "HotbarPrevBadge"
	_hotbar_lb_badge.configure(&"hotbar_prev", Vector2(10.0, 10.0), true, true, false)
	_hotbar_lb_badge.position = Vector2(-21.0, 15.0)
	_hotbar_panel.add_child(_hotbar_lb_badge)

	_hotbar_rb_badge = InputPromptBadgeScript.new()
	_hotbar_rb_badge.name = "HotbarNextBadge"
	_hotbar_rb_badge.configure(&"hotbar_next", Vector2(10.0, 10.0), true, true, false)
	_hotbar_rb_badge.position = Vector2(HOTBAR_WIDTH + 5.0, 15.0)
	_hotbar_panel.add_child(_hotbar_rb_badge)


func _build_quest_tracker_panel() -> void:
	# Clean top-left toggleable Active Quest Tracker (owns top-left corner in ALL modes!)
	_quest_tracker_panel = SunnysideBox.new()
	_quest_tracker_panel.name = "QuestTrackerPanel"
	_quest_tracker_panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_quest_tracker_panel.anchor_left = 0.0
	_quest_tracker_panel.anchor_top = 0.0
	_quest_tracker_panel.anchor_right = 0.0
	_quest_tracker_panel.anchor_bottom = 0.0
	_quest_tracker_panel.offset_left = DESKTOP_MARGIN
	_quest_tracker_panel.offset_top = DESKTOP_MARGIN
	_quest_tracker_panel.offset_right = DESKTOP_MARGIN + QUEST_WIDTH
	_quest_tracker_panel.offset_bottom = DESKTOP_MARGIN + 48.0
	_quest_tracker_panel.visible = false
	_root_ctrl.add_child(_quest_tracker_panel)

	var outer_mc: MarginContainer = MarginContainer.new()
	outer_mc.name = "QuestOuterMargin"
	outer_mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_mc.mouse_filter = Control.MOUSE_FILTER_PASS
	outer_mc.add_theme_constant_override(&"margin_left", 5)
	outer_mc.add_theme_constant_override(&"margin_right", 5)
	outer_mc.add_theme_constant_override(&"margin_top", 4)
	outer_mc.add_theme_constant_override(&"margin_bottom", 4)
	_quest_tracker_panel.add_child(outer_mc)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.name = "QuestVBox"
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	outer_vbox.add_theme_constant_override(&"separation", 3)
	outer_mc.add_child(outer_vbox)

	var hdr_btn: Control = Control.new()
	hdr_btn.name = "QuestTrackerToggle"
	hdr_btn.custom_minimum_size = Vector2(QUEST_WIDTH - 10.0, 18.0)
	hdr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	hdr_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			toggle_quest_tracker()
			hdr_btn.accept_event()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			toggle_quest_tracker()
			hdr_btn.accept_event()
	)
	outer_vbox.add_child(hdr_btn)

	var hdr_bg: SunnysideBox = SunnysideBox.new()
	hdr_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr_bg.set_box_style(SunnysideBox.Style.DARK_TAN)
	hdr_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_btn.add_child(hdr_bg)

	var hdr_mc: MarginContainer = MarginContainer.new()
	hdr_mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr_mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_mc.add_theme_constant_override(&"margin_left", 6)
	hdr_mc.add_theme_constant_override(&"margin_right", 6)
	hdr_mc.add_theme_constant_override(&"margin_top", 3)
	hdr_mc.add_theme_constant_override(&"margin_bottom", 3)
	hdr_btn.add_child(hdr_mc)

	var hdr_hbox: HBoxContainer = HBoxContainer.new()
	hdr_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hdr_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_hbox.add_theme_constant_override(&"separation", 4)
	hdr_mc.add_child(hdr_hbox)

	var q_icon: TextureRect = TextureRect.new()
	q_icon.texture = load(AP.UI_EXPRESSION_CHAT) as Texture2D
	q_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	q_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	q_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	q_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	q_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	q_icon.custom_minimum_size = Vector2(10.0, 10.0)
	q_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_hbox.add_child(q_icon)

	_quest_header_label = Label.new()
	_quest_header_label.name = "QuestHeaderLabel"
	_quest_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_header_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_quest_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quest_header_label.clip_text = true
	_quest_header_label.add_theme_font_size_override(&"font_size", 8)
	_quest_header_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	_quest_header_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_quest_header_label.add_theme_constant_override(&"outline_size", 2)
	hdr_hbox.add_child(_quest_header_label)

	# Tight-cropped Vryell Q / Back-Select keycap vertically dead-centered on header row!
	_quest_key_badge = InputPromptBadgeScript.new()
	_quest_key_badge.name = "QuestToggleKeyBadge"
	_quest_key_badge.configure(&"toggle_quests", Vector2(10.0, 10.0), true, false, false)
	hdr_hbox.add_child(_quest_key_badge)

	_quest_body_card = SunnysideBox.new()
	_quest_body_card.name = "QuestTrackerBody"
	_quest_body_card.set_box_style(SunnysideBox.Style.WHITE)
	_quest_body_card.custom_minimum_size = Vector2(QUEST_WIDTH - 10.0, 18.0)
	_quest_body_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_body_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(_quest_body_card)

	var body_mc: MarginContainer = MarginContainer.new()
	body_mc.name = "QuestBodyMargin"
	body_mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	body_mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_mc.add_theme_constant_override(&"margin_left", 6)
	body_mc.add_theme_constant_override(&"margin_right", 6)
	body_mc.add_theme_constant_override(&"margin_top", 4)
	body_mc.add_theme_constant_override(&"margin_bottom", 4)
	_quest_body_card.add_child(body_mc)

	_quest_lines_label = Label.new()
	_quest_lines_label.name = "QuestLinesLabel"
	_quest_lines_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_lines_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_lines_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quest_lines_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_lines_label.clip_text = true
	_quest_lines_label.add_theme_font_size_override(&"font_size", 7)
	_quest_lines_label.add_theme_color_override(&"font_color", TEXT_DARK)
	body_mc.add_child(_quest_lines_label)


func toggle_quest_tracker() -> void:
	_quest_tracker_expanded = not _quest_tracker_expanded
	_refresh_quest_tracker()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"toggle_quests"):
		if not QuestManager.get_active_quests().is_empty():
			toggle_quest_tracker()
			get_viewport().set_input_as_handled()


func _build_toast_and_prompt() -> void:
	# Floating 1-second validation toast dead-centered cleanly above the hotbar
	_toast_panel = SunnysideBox.new()
	_toast_panel.name = "FloatingToast"
	_toast_panel.set_box_style(SunnysideBox.Style.DARK_TAN)
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_top = 1.0
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_bottom = 1.0
	_toast_panel.offset_left = -96.0
	_toast_panel.offset_top = -70.0
	_toast_panel.offset_right = 96.0
	_toast_panel.offset_bottom = -51.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_panel.modulate.a = 0.0
	_root_ctrl.add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.add_theme_font_size_override(&"font_size", 9)
	_toast_label.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.84, 1.0))
	_toast_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_toast_label.add_theme_constant_override(&"outline_size", 2)
	_toast_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_label.offset_left = 8.0
	_toast_label.offset_top = 1.0
	_toast_label.offset_right = -8.0
	_toast_label.offset_bottom = -1.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.clip_text = true
	_toast_panel.add_child(_toast_label)

	# Contextual world interact prompt pill with centered MarginContainer -> HBoxContainer (badge snug beside label!)
	# Anchored bottom-center on Desktop/Gamepad, and centered directly above ACT button in TOUCH mode!
	_prompt_panel = SunnysideBox.new()
	_prompt_panel.name = "InteractPrompt"
	_prompt_panel.set_box_style(SunnysideBox.Style.WHITE)
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -76.0
	_prompt_panel.offset_top = -(DESKTOP_MARGIN + HOTBAR_HEIGHT + 8.0 + PROMPT_HEIGHT)
	_prompt_panel.offset_right = 76.0
	_prompt_panel.offset_bottom = -(DESKTOP_MARGIN + HOTBAR_HEIGHT + 8.0)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	_root_ctrl.add_child(_prompt_panel)

	var prompt_mc: MarginContainer = MarginContainer.new()
	prompt_mc.name = "PromptMargin"
	prompt_mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt_mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_mc.add_theme_constant_override(&"margin_left", 6)
	prompt_mc.add_theme_constant_override(&"margin_right", 6)
	prompt_mc.add_theme_constant_override(&"margin_top", 3)
	prompt_mc.add_theme_constant_override(&"margin_bottom", 3)
	_prompt_panel.add_child(prompt_mc)

	var prompt_hbox: HBoxContainer = HBoxContainer.new()
	prompt_hbox.name = "PromptHBox"
	prompt_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_hbox.add_theme_constant_override(&"separation", 4)
	prompt_mc.add_child(prompt_hbox)

	_prompt_badge = InputPromptBadgeScript.new()
	_prompt_badge.name = "InteractKeyBadge"
	_prompt_badge.configure(&"interact", Vector2(10.0, 10.0), true, false, false)
	prompt_hbox.add_child(_prompt_badge)

	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.add_theme_font_size_override(&"font_size", 9)
	_prompt_label.add_theme_color_override(&"font_color", TEXT_DARK)
	_prompt_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_hbox.add_child(_prompt_label)


func show_toast(message: String) -> void:
	if _toast_panel == null or _toast_label == null or message.is_empty():
		return
	_toast_label.text = message
	var target_w: float = clampf(float(message.length()) * 6.2 + 28.0, 110.0, 340.0)
	_toast_panel.offset_left = -target_w * 0.5
	_toast_panel.offset_right = target_w * 0.5
	_toast_panel.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.10)
	_toast_tween.tween_interval(0.82)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.20)
	_toast_tween.tween_callback(func() -> void:
		if _toast_panel != null:
			_toast_panel.visible = false
	)


func set_interact_prompt(prompt_text: String) -> void:
	_raw_prompt_text = prompt_text
	if _prompt_panel == null or _prompt_label == null:
		return
	var clean_text: String = _strip_prompt_prefix(prompt_text)
	if clean_text.is_empty():
		_prompt_panel.visible = false
		return
	_prompt_label.text = clean_text
	if _prompt_badge != null:
		_prompt_badge.refresh_icon()
	_position_interact_prompt(clean_text)
	_prompt_panel.visible = true


func _position_interact_prompt(clean_text: String) -> void:
	if _prompt_panel == null:
		return
	var show_badge: bool = _prompt_badge != null and _prompt_badge.visible
	var extra_w: float = 34.0 if show_badge else 22.0
	var target_w: float = clampf(float(clean_text.length()) * 5.6 + extra_w, 86.0, 230.0)
	var m: float = _get_edge_margin()
	if InputModeManager.should_show_touch_controls():
		# Center directly above the mobile ACT button, clamped cleanly inside right screen margin!
		var act_cx: float = MobileControls.ACT_CENTER_OFFSET_X
		var right_x: float = minf(act_cx + target_w * 0.5, -m)
		var left_x: float = right_x - target_w
		var bottom_y: float = MobileControls.ACT_TOP_OFFSET_Y - ACT_PROMPT_GAP
		_prompt_panel.anchor_left = 1.0
		_prompt_panel.anchor_top = 1.0
		_prompt_panel.anchor_right = 1.0
		_prompt_panel.anchor_bottom = 1.0
		_prompt_panel.offset_left = left_x
		_prompt_panel.offset_right = right_x
		_prompt_panel.offset_bottom = bottom_y
		_prompt_panel.offset_top = bottom_y - PROMPT_HEIGHT
	else:
		var bottom_y: float = -(m + HOTBAR_HEIGHT + 8.0)
		_prompt_panel.anchor_left = 0.5
		_prompt_panel.anchor_top = 1.0
		_prompt_panel.anchor_right = 0.5
		_prompt_panel.anchor_bottom = 1.0
		_prompt_panel.offset_left = -target_w * 0.5
		_prompt_panel.offset_right = target_w * 0.5
		_prompt_panel.offset_bottom = bottom_y
		_prompt_panel.offset_top = bottom_y - PROMPT_HEIGHT


static func _strip_prompt_prefix(raw: String) -> String:
	var s: String = raw.strip_edges()
	if s.begins_with("[E] "):
		return s.substr(4)
	if s.begins_with("[E]"):
		return s.substr(3).strip_edges()
	return s


func get_last_toast_text() -> String:
	return _toast_label.text if _toast_label != null else ""


func _connect_signals() -> void:
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.day_started.connect(_on_day_started)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.vitality_changed.connect(_on_vitality_changed)
	EventBus.exhaustion_changed.connect(_on_exhaustion_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
	EventBus.watering_can_changed.connect(_on_watering_can_changed)
	EventBus.toast_requested.connect(show_toast)
	EventBus.interact_prompt_changed.connect(set_interact_prompt)
	EventBus.quests_changed.connect(_refresh_quest_tracker)
	EventBus.input_mode_changed.connect(_on_input_mode_changed)
	EventBus.touch_controls_preference_changed.connect(_on_touch_pref_changed)


func _disconnect_signals() -> void:
	if EventBus.time_ticked.is_connected(_on_time_ticked):
		EventBus.time_ticked.disconnect(_on_time_ticked)
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if EventBus.vitality_changed.is_connected(_on_vitality_changed):
		EventBus.vitality_changed.disconnect(_on_vitality_changed)
	if EventBus.exhaustion_changed.is_connected(_on_exhaustion_changed):
		EventBus.exhaustion_changed.disconnect(_on_exhaustion_changed)
	if EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.disconnect(_on_inventory_changed)
	if EventBus.hotbar_selection_changed.is_connected(_on_hotbar_selection_changed):
		EventBus.hotbar_selection_changed.disconnect(_on_hotbar_selection_changed)
	if EventBus.watering_can_changed.is_connected(_on_watering_can_changed):
		EventBus.watering_can_changed.disconnect(_on_watering_can_changed)
	if EventBus.toast_requested.is_connected(show_toast):
		EventBus.toast_requested.disconnect(show_toast)
	if EventBus.interact_prompt_changed.is_connected(set_interact_prompt):
		EventBus.interact_prompt_changed.disconnect(set_interact_prompt)
	if EventBus.quests_changed.is_connected(_refresh_quest_tracker):
		EventBus.quests_changed.disconnect(_refresh_quest_tracker)
	if EventBus.input_mode_changed.is_connected(_on_input_mode_changed):
		EventBus.input_mode_changed.disconnect(_on_input_mode_changed)
	if EventBus.touch_controls_preference_changed.is_connected(_on_touch_pref_changed):
		EventBus.touch_controls_preference_changed.disconnect(_on_touch_pref_changed)


func _on_input_mode_changed(_mode: int, _family: int) -> void:
	_apply_responsive_layout()
	if _prompt_panel != null and _prompt_panel.visible:
		set_interact_prompt(_raw_prompt_text)


func _on_touch_pref_changed(_pref: int) -> void:
	_apply_responsive_layout()
	if _prompt_panel != null and _prompt_panel.visible:
		set_interact_prompt(_raw_prompt_text)


func refresh_all() -> void:
	_refresh_clock()
	_refresh_weather(TimeManager.current_weather)
	_refresh_sunbursts(EconomyManager.get_sunbursts())
	_refresh_vitality(VitalitySystem.current_vitality, VitalitySystem.MAX_VITALITY)
	_refresh_water_gauge()
	_refresh_hotbar()
	_apply_responsive_layout()


func _refresh_quest_tracker() -> void:
	if _quest_tracker_panel == null or _quest_lines_label == null:
		return
	var active: Array[QuestData] = QuestManager.get_active_quests()
	if active.is_empty():
		_quest_tracker_panel.visible = false
		return
	_quest_tracker_panel.visible = true
	var m: float = _get_edge_margin()
	_quest_tracker_panel.offset_left = m
	_quest_tracker_panel.offset_top = m
	_quest_tracker_panel.offset_right = m + QUEST_WIDTH
	var toggle_tag: String = "▾" if _quest_tracker_expanded else "▸"
	_quest_header_label.text = "Quests (%d) %s" % [active.size(), toggle_tag]
	if _quest_key_badge != null:
		_quest_key_badge.refresh_icon()
	if not _quest_tracker_expanded:
		if _quest_body_card != null:
			_quest_body_card.visible = false
		_quest_tracker_panel.offset_bottom = m + 26.0
		return

	var lines: PackedStringArray = PackedStringArray()
	var shown: int = mini(active.size(), 2)
	for i: int in range(shown):
		var q: QuestData = active[i]
		var have: int = QuestManager.get_quest_progress(q)
		var prof: NpcData = SocialManager.get_npc(q.npc_id)
		var npc_nm: String = prof.display_name if prof != null else String(q.npc_id)
		if have >= q.required_count:
			lines.append("★ %s: Talk to %s!" % [q.required_label, npc_nm])
		else:
			lines.append("• %s: %d/%d (%s)" % [q.required_label, have, q.required_count, npc_nm])
	_quest_lines_label.text = "\n".join(lines)
	var body_h: float = 18.0 if shown == 1 else 30.0
	if _quest_body_card != null:
		_quest_body_card.visible = true
		_quest_body_card.custom_minimum_size = Vector2(QUEST_WIDTH - 10.0, body_h)
	_quest_tracker_panel.offset_bottom = m + 29.0 + body_h


func _refresh_clock() -> void:
	if _date_label != null:
		_date_label.text = TimeManager.get_formatted_date()
	if _time_label != null:
		_time_label.text = TimeManager.get_formatted_time()


func _refresh_weather(weather: StringName) -> void:
	if _weather_icon == null:
		return
	if weather == TimeManager.WEATHER_RAIN:
		_weather_icon.texture = _tex_rain
	elif weather == TimeManager.WEATHER_SNOW:
		_weather_icon.texture = _tex_snow
	else:
		_weather_icon.texture = _tex_sunny


func _refresh_sunbursts(balance: int) -> void:
	if _sunbursts_label != null:
		_sunbursts_label.text = "%d G" % balance


func _refresh_vitality(current_val: float, max_val: float) -> void:
	if _vitality_bar == null:
		return
	var ratio: float = clampf(current_val / maxf(1.0, max_val), 0.0, 1.0)
	var use_red: bool = VitalitySystem.is_exhausted or ratio <= 0.25
	var frames: Array[Texture2D] = _redbars if use_red else _greenbars
	var idx: int = clampi(int(roundf(ratio * float(frames.size() - 1))), 0, frames.size() - 1)
	_vitality_bar.texture = frames[idx]
	_vitality_icon.texture = _tex_stress if VitalitySystem.is_exhausted else _tex_heart
	_vitality_val_label.text = str(int(roundf(current_val)))


func _refresh_water_gauge() -> void:
	if _water_bar == null:
		return
	var can_slot: int = InventoryManager.find_tool_slot(ToolData.ToolKind.WATERING_CAN)
	var charges: int = 0
	var max_charges: int = 40
	if can_slot >= 0:
		charges = InventoryManager.get_slot_charges(can_slot)
		var can_data: ToolData = InventoryManager.get_tool(InventoryManager.get_slot_item_id(can_slot))
		if can_data != null and can_data.max_charges > 0:
			max_charges = can_data.max_charges
	var ratio: float = clampf(float(charges) / float(maxi(1, max_charges)), 0.0, 1.0)
	var idx: int = clampi(int(roundf(ratio * float(_bluebars.size() - 1))), 0, _bluebars.size() - 1)
	_water_bar.texture = _bluebars[idx]
	_water_val_label.text = str(charges)


func _refresh_hotbar() -> void:
	var sel: int = InventoryManager.selected_hotbar_index
	for i: int in range(_hotbar_slots.size()):
		var item_id: StringName = InventoryManager.get_slot_item_id(i)
		var item_data: ItemData = InventoryManager.get_item(item_id) if item_id != &"" else null
		var cnt: int = InventoryManager.get_slot_count(i)
		var chg: int = InventoryManager.get_slot_charges(i)
		_hotbar_slots[i].set_item_display(item_data, cnt, chg)
		_hotbar_slots[i].set_selected(i == sel, false, false)


func _on_hotbar_slot_clicked(slot_idx: int) -> void:
	InventoryManager.select_hotbar_slot(slot_idx)


func _on_time_ticked(_day: int, _season_idx: int, _hour: int, _minute: int) -> void:
	_refresh_clock()


func _on_day_started(_day: int, _season_idx: int, _year: int, weather: StringName) -> void:
	_refresh_clock()
	_refresh_weather(weather)


func _on_weather_changed(weather: StringName) -> void:
	_refresh_weather(weather)


func _on_currency_changed(new_balance: int, _delta: int) -> void:
	_refresh_sunbursts(new_balance)


func _on_vitality_changed(current_val: float, max_val: float) -> void:
	_refresh_vitality(current_val, max_val)


func _on_exhaustion_changed(_is_exhausted: bool) -> void:
	_refresh_vitality(VitalitySystem.current_vitality, VitalitySystem.MAX_VITALITY)


func _on_inventory_changed() -> void:
	_refresh_hotbar()
	_refresh_water_gauge()
	_refresh_quest_tracker()


func _on_hotbar_selection_changed(_slot_index: int) -> void:
	_refresh_hotbar()


func _on_watering_can_changed(_charges: int, _max_charges: int) -> void:
	_refresh_water_gauge()
	_refresh_hotbar()
