class_name TitleScreen
extends Node2D

## Live scenic Pebblefern Island Title Screen (res://scenes/ui/title_screen.tscn).
## Renders a drifting sunlit camera over the living 96x60 Pebblefern Sanctuary overworld
## with a framed Sunnyside emblem, Continue / New Farm / Load Save / Quit buttons,
## and an interactive 3-slot Sunnyside Save Picker modal (Slot #, Day/Season, Sunbursts, Play/Delete).

const AP := preload("res://scripts/core/asset_paths.gd")
const UiFocusHelperScript := preload("res://scripts/ui/ui_focus_helper.gd")
const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"

const UI_SCALE: float = 0.5
const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.46, 0.34, 0.27, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_ROSE: Color = Color(0.96, 0.45, 0.42, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

# Gentle scenic tour centered over Solstice Farm Bridge, River & Bramblebrook Plaza!
const CAM_CENTER: Vector2 = Vector2(680.0, 446.0)
const CAM_AMP: Vector2 = Vector2(145.0, 46.0)

var _scenic_world: Node2D = null
var _scenic_camera: Camera2D = null
var _pan_time: float = 0.0

var _ui_layer: CanvasLayer = null
var _root_ctrl: Control = null
var _continue_btn: Control = null
var _new_farm_btn: Control = null
var _main_menu_btns: Array[Control] = []
var _continue_sub_label: Label = null
var _load_modal_backdrop: Control = null
var _slot_rows_container: Control = null
var _slot_play_btns: Array[Control] = []
var _tex_coin: Texture2D = null


func _ready() -> void:
	_setup_scenic_background()
	_build_title_ui()
	refresh_menu_state()
	_focus_default_main_button()


func _focus_default_main_button() -> void:
	if SaveManager.has_any_save() and _continue_btn != null:
		_continue_btn.grab_focus()
	elif _new_farm_btn != null:
		_new_farm_btn.grab_focus()


func _setup_scenic_background() -> void:
	# Lock daytime sun cleanly at 10:30 AM for golden cozy title ambience
	TimeManager.set_time(10, 30)
	TimeManager.set_weather(TimeManager.WEATHER_SUNNY)
	TimeManager.set_paused(true)

	var farm_scene: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(farm_scene != null, "TitleScreen missing farm_sanctuary.tscn")
	_scenic_world = farm_scene.instantiate() as Node2D
	_scenic_world.name = "ScenicIslandWorld"
	_scenic_world.set("title_showcase_mode", true)
	add_child(_scenic_world)

	_scenic_camera = Camera2D.new()
	_scenic_camera.name = "ScenicDriftCamera"
	_scenic_camera.position = CAM_CENTER
	_scenic_camera.limit_left = 0
	_scenic_camera.limit_top = 0
	_scenic_camera.limit_right = 1536
	_scenic_camera.limit_bottom = 960
	_scenic_camera.position_smoothing_enabled = false
	add_child(_scenic_camera)
	_scenic_camera.make_current()


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	_pan_time += dt * 0.14
	if _scenic_camera != null:
		_scenic_camera.position = Vector2(
			CAM_CENTER.x + sin(_pan_time) * CAM_AMP.x,
			CAM_CENTER.y + sin(_pan_time * 0.65) * CAM_AMP.y
		)


func _unhandled_input(event: InputEvent) -> void:
	if _load_modal_backdrop != null and _load_modal_backdrop.visible:
		if event.is_action_pressed(&"ui_cancel"):
			set_load_modal_open(false)
			get_viewport().set_input_as_handled()


func is_load_modal_open() -> bool:
	return _load_modal_backdrop != null and _load_modal_backdrop.visible


func set_load_modal_open(open: bool) -> void:
	if _load_modal_backdrop == null:
		return
	_load_modal_backdrop.visible = open
	if open:
		_refresh_save_slots_list()
		if not _slot_play_btns.is_empty():
			_slot_play_btns[0].grab_focus()
	else:
		_focus_default_main_button()


func refresh_menu_state() -> void:
	var has_save: bool = SaveManager.has_any_save()
	var recent_slot: int = SaveManager.get_most_recent_slot()
	if _continue_btn != null:
		_continue_btn.modulate = Color.WHITE if has_save else Color(0.65, 0.60, 0.58, 0.65)
	if _continue_sub_label != null:
		if has_save and recent_slot > 0:
			var sum: Dictionary = SaveManager.get_slot_summary(recent_slot)
			_continue_sub_label.text = "Slot %d · %s · %d G" % [recent_slot, String(sum["formatted_date"]), int(sum["sunbursts"])]
		else:
			_continue_sub_label.text = "No saved sanctuary yet"
	if is_load_modal_open():
		_refresh_save_slots_list()


func trigger_continue(immediate: bool = false) -> bool:
	var recent: int = SaveManager.get_most_recent_slot()
	if recent <= 0:
		AudioManager.play_sfx(&"error", -8.0, 0.03)
		return false
	return SaveManager.load_slot(recent, true, immediate)


func trigger_new_farm(slot_idx: int = -1, immediate: bool = false) -> void:
	SaveManager.start_new_game(slot_idx, true, immediate)


func _build_title_ui() -> void:
	var ts_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	var coin_at: AtlasTexture = AtlasTexture.new()
	coin_at.atlas = ts_tex
	coin_at.region = Rect2(AP.TILE_COIN_PILE.x * 16 + 1, AP.TILE_COIN_PILE.y * 16, 14, 8)
	_tex_coin = coin_at

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "TitleUILayer"
	_ui_layer.layer = 15
	add_child(_ui_layer)

	_root_ctrl = Control.new()
	_root_ctrl.name = "TitleRoot"
	_root_ctrl.anchor_left = 0.0
	_root_ctrl.anchor_top = 0.0
	_root_ctrl.anchor_right = 1.0 / UI_SCALE
	_root_ctrl.anchor_bottom = 1.0 / UI_SCALE
	_root_ctrl.scale = Vector2(UI_SCALE, UI_SCALE)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	_root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ui_layer.add_child(_root_ctrl)

	# 1. Top-Center Sunnyside Emblem Card ("PEBBLEFERN — Solstice Island Sanctuary")
	var emblem: SunnysideBox = SunnysideBox.new()
	emblem.name = "TitleEmblem"
	emblem.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	emblem.anchor_left = 0.5
	emblem.anchor_top = 0.0
	emblem.anchor_right = 0.5
	emblem.anchor_bottom = 0.0
	emblem.offset_left = -152.0
	emblem.offset_top = 24.0
	emblem.offset_right = 152.0
	emblem.offset_bottom = 98.0
	_root_ctrl.add_child(emblem)

	var inner_emblem: SunnysideBox = SunnysideBox.new()
	inner_emblem.set_box_style(SunnysideBox.Style.DARK_TAN)
	inner_emblem.position = Vector2(6.0, 6.0)
	inner_emblem.size = Vector2(292.0, 62.0)
	emblem.add_child(inner_emblem)

	# Flanking real Sunnyside Sunflower icons
	var sun_tex: Texture2D = load(AP.CROPS_ROOT + "/sunflower_05.png") as Texture2D
	for side_x: float in [14.0, 250.0]:
		var ic: TextureRect = TextureRect.new()
		ic.texture = sun_tex
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(side_x, 16.0)
		ic.size = Vector2(28.0, 28.0)
		inner_emblem.add_child(ic)

	var main_title: Label = Label.new()
	main_title.name = "GameTitleLabel"
	main_title.text = "PEBBLEFERN"
	main_title.position = Vector2(46.0, 8.0)
	main_title.size = Vector2(200.0, 28.0)
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_title.add_theme_font_size_override(&"font_size", 22)
	main_title.add_theme_color_override(&"font_color", TEXT_GOLD)
	main_title.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	main_title.add_theme_constant_override(&"outline_size", 4)
	inner_emblem.add_child(main_title)

	var sub_title: Label = Label.new()
	sub_title.name = "SubtitleLabel"
	sub_title.text = "Solstice Island Sanctuary"
	sub_title.position = Vector2(46.0, 38.0)
	sub_title.size = Vector2(200.0, 16.0)
	sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_title.add_theme_font_size_override(&"font_size", 10)
	sub_title.add_theme_color_override(&"font_color", TEXT_CREAM)
	sub_title.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	sub_title.add_theme_constant_override(&"outline_size", 2)
	inner_emblem.add_child(sub_title)

	# 2. Centered Main Menu Card (Continue, New Farm, Load Save, Quit)
	var menu_card: SunnysideBox = SunnysideBox.new()
	menu_card.name = "MainMenuCard"
	menu_card.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	menu_card.anchor_left = 0.5
	menu_card.anchor_top = 0.5
	menu_card.anchor_right = 0.5
	menu_card.anchor_bottom = 0.5
	menu_card.offset_left = -104.0
	menu_card.offset_top = -18.0
	menu_card.offset_right = 104.0
	menu_card.offset_bottom = 132.0
	_root_ctrl.add_child(menu_card)

	_continue_btn = _make_btn("ContinueBtn", Vector2(10.0, 10.0), Vector2(188.0, 34.0), "Continue", TEXT_GOLD, func() -> void:
		trigger_continue(false)
	)
	var cont_lbl: Label = _continue_btn.get_node("BtnLabel") as Label
	cont_lbl.offset_bottom = -12.0
	_continue_sub_label = Label.new()
	_continue_sub_label.name = "ContinueSubLabel"
	_continue_sub_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_continue_sub_label.offset_top = 18.0
	_continue_sub_label.offset_bottom = -2.0
	_continue_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_continue_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_sub_label.add_theme_font_size_override(&"font_size", 7)
	_continue_sub_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	_continue_btn.add_child(_continue_sub_label)
	menu_card.add_child(_continue_btn)

	_new_farm_btn = _make_btn("NewFarmBtn", Vector2(10.0, 49.0), Vector2(188.0, 26.0), "New Farm", TEXT_CREAM, func() -> void:
		trigger_new_farm(-1, false)
	)
	menu_card.add_child(_new_farm_btn)
	var load_btn: Control = _make_btn("LoadSaveBtn", Vector2(10.0, 80.0), Vector2(188.0, 26.0), "Load Save (3 Slots)", TEXT_CREAM, func() -> void:
		set_load_modal_open(true)
	)
	menu_card.add_child(load_btn)
	var quit_btn: Control = _make_btn("QuitBtn", Vector2(10.0, 111.0), Vector2(188.0, 26.0), "Quit", TEXT_CREAM, func() -> void:
		get_tree().quit(0)
	)
	menu_card.add_child(quit_btn)
	_main_menu_btns = [_continue_btn, _new_farm_btn, load_btn, quit_btn]
	UiFocusHelperScript.wire_vertical_list(_main_menu_btns, true)

	# Footer Version Strip
	var ver_lbl: Label = Label.new()
	ver_lbl.text = "Bramblebrook Valley · Sunnyside Sanctuary Edition"
	ver_lbl.anchor_left = 0.5
	ver_lbl.anchor_top = 1.0
	ver_lbl.anchor_right = 0.5
	ver_lbl.anchor_bottom = 1.0
	ver_lbl.offset_left = -160.0
	ver_lbl.offset_top = -20.0
	ver_lbl.offset_right = 160.0
	ver_lbl.offset_bottom = -4.0
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver_lbl.add_theme_font_size_override(&"font_size", 8)
	ver_lbl.add_theme_color_override(&"font_color", TEXT_CREAM)
	ver_lbl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	ver_lbl.add_theme_constant_override(&"outline_size", 2)
	_root_ctrl.add_child(ver_lbl)

	# 3. 3-Slot Sunnyside Load Save Modal Overlay
	_build_load_save_modal()


func _build_load_save_modal() -> void:
	var w_center: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	_load_modal_backdrop = TextureRect.new()
	_load_modal_backdrop.name = "LoadSaveModalOverlay"
	(_load_modal_backdrop as TextureRect).texture = w_center
	_load_modal_backdrop.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_load_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_load_modal_backdrop as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	(_load_modal_backdrop as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	(_load_modal_backdrop as TextureRect).self_modulate = Color(0.05, 0.04, 0.08, 0.55)
	_load_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_modal_backdrop.visible = false
	_root_ctrl.add_child(_load_modal_backdrop)

	var modal: SunnysideBox = SunnysideBox.new()
	modal.name = "SaveSlotsCard"
	modal.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	modal.anchor_left = 0.5
	modal.anchor_top = 0.5
	modal.anchor_right = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -176.0
	modal.offset_top = -92.0
	modal.offset_right = 176.0
	modal.offset_bottom = 92.0
	_load_modal_backdrop.add_child(modal)

	var hdr: SunnysideBox = SunnysideBox.new()
	hdr.set_box_style(SunnysideBox.Style.DARK_TAN)
	hdr.position = Vector2(8.0, 8.0)
	hdr.size = Vector2(308.0, 22.0)
	modal.add_child(hdr)

	var h_lbl: Label = Label.new()
	h_lbl.text = "Select Sanctuary Save Slot"
	h_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	h_lbl.offset_left = 10.0
	h_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_lbl.add_theme_font_size_override(&"font_size", 10)
	h_lbl.add_theme_color_override(&"font_color", TEXT_GOLD)
	h_lbl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	h_lbl.add_theme_constant_override(&"outline_size", 2)
	hdr.add_child(h_lbl)

	modal.add_child(_make_btn("CloseSlotsBtn", Vector2(320.0, 8.0), Vector2(24.0, 22.0), "X", TEXT_CREAM, func() -> void:
		set_load_modal_open(false)
	))

	_slot_rows_container = Control.new()
	_slot_rows_container.name = "SlotRowsContainer"
	_slot_rows_container.position = Vector2(8.0, 36.0)
	_slot_rows_container.size = Vector2(336.0, 140.0)
	modal.add_child(_slot_rows_container)


func _refresh_save_slots_list() -> void:
	if _slot_rows_container == null:
		return
	for c: Node in _slot_rows_container.get_children():
		c.queue_free()
	_slot_play_btns.clear()

	for slot_num: int in range(1, SaveManager.MAX_SLOTS + 1):
		var sum: Dictionary = SaveManager.get_slot_summary(slot_num)
		var exists: bool = bool(sum.get("exists", false))

		var row_box: SunnysideBox = SunnysideBox.new()
		row_box.name = "SaveSlotRow_%d" % slot_num
		row_box.set_box_style(SunnysideBox.Style.WHITE if exists else SunnysideBox.Style.DARK_TAN)
		row_box.position = Vector2(0.0, float(slot_num - 1) * 46.0)
		row_box.size = Vector2(336.0, 42.0)
		_slot_rows_container.add_child(row_box)

		var num_lbl: Label = Label.new()
		num_lbl.text = "Slot %d" % slot_num
		num_lbl.position = Vector2(10.0, 5.0)
		num_lbl.size = Vector2(58.0, 14.0)
		num_lbl.add_theme_font_size_override(&"font_size", 10)
		num_lbl.add_theme_color_override(&"font_color", TEXT_DARK if exists else TEXT_GOLD)
		row_box.add_child(num_lbl)

		var date_lbl: Label = Label.new()
		date_lbl.text = String(sum.get("formatted_date", "Empty Slot"))
		date_lbl.position = Vector2(10.0, 21.0)
		date_lbl.size = Vector2(130.0, 14.0)
		date_lbl.add_theme_font_size_override(&"font_size", 8)
		date_lbl.add_theme_color_override(&"font_color", TEXT_MUTED if exists else TEXT_CREAM)
		row_box.add_child(date_lbl)

		if exists:
			var coin_tr: TextureRect = TextureRect.new()
			coin_tr.texture = _tex_coin
			coin_tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			coin_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			coin_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			coin_tr.position = Vector2(142.0, 17.0)
			coin_tr.size = Vector2(14.0, 8.0)
			row_box.add_child(coin_tr)

			var g_lbl: Label = Label.new()
			g_lbl.text = "%d G" % int(sum.get("sunbursts", 0))
			g_lbl.position = Vector2(158.0, 13.0)
			g_lbl.size = Vector2(58.0, 16.0)
			g_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			g_lbl.add_theme_font_size_override(&"font_size", 9)
			g_lbl.add_theme_color_override(&"font_color", TEXT_DARK)
			row_box.add_child(g_lbl)

		var s_copy: int = slot_num
		var play_lbl: String = "Play" if exists else "New"
		var play_btn: Control = _make_btn("PlaySlot_%d" % slot_num, Vector2(224.0, 9.0), Vector2(52.0, 24.0), play_lbl, TEXT_GOLD if exists else TEXT_CREAM, func() -> void:
			if exists:
				SaveManager.load_slot(s_copy, true, false)
			else:
				SaveManager.start_new_game(s_copy, true, false)
		)
		row_box.add_child(play_btn)
		_slot_play_btns.append(play_btn)

		if exists:
			var del_btn: Control = _make_btn("DeleteSlot_%d" % slot_num, Vector2(280.0, 9.0), Vector2(48.0, 24.0), "Delete", TEXT_ROSE, func() -> void:
				SaveManager.delete_slot(s_copy)
				AudioManager.play_sfx(&"error", -10.0, 0.02)
				refresh_menu_state()
			)
			row_box.add_child(del_btn)
			play_btn.focus_neighbor_right = play_btn.get_path_to(del_btn)
			del_btn.focus_neighbor_left = del_btn.get_path_to(play_btn)
	UiFocusHelperScript.wire_vertical_list(_slot_play_btns, true)


func _make_btn(btn_name: String, pos: Vector2, sz: Vector2, text_str: String, col: Color, cb: Callable) -> Control:
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
	UiFocusHelperScript.make_focusable(btn, cb, 5.0, 1.5)
	var bg: SunnysideBox = SunnysideBox.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_box_style(SunnysideBox.Style.DARK_TAN)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)

	var lbl: Label = Label.new()
	lbl.name = "BtnLabel"
	lbl.text = text_str
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override(&"font_size", 9)
	lbl.add_theme_color_override(&"font_color", col)
	lbl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	lbl.add_theme_constant_override(&"outline_size", 2)
	btn.add_child(lbl)
	return btn
