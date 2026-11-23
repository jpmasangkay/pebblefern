class_name FurnaceModal
extends CanvasLayer

## Compact Stone Furnace Smelting Modal (res://scenes/ui/furnace_modal.tscn).
## Smelts gathered Rock + Wood into Copper Bars (5 Rock + 2 Wood) and Iron Bars (8 Rock + 3 Wood).

const AP := preload("res://scripts/core/asset_paths.gd")
const UiFocus := preload("res://scripts/ui/ui_focus_helper.gd")

signal modal_visibility_changed(is_open: bool)

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_OK: Color = Color(0.65, 1.0, 0.65, 1.0)
const TEXT_NO: Color = Color(1.0, 0.60, 0.55, 1.0)

var _is_open: bool = false
var _built: bool = false
var _furnace_ref: PlacedWorldObject = null

var _copper_status: Label = null
var _iron_status: Label = null
var _stock_label: Label = null
var _copper_row: Control = null
var _iron_row: Control = null
var _close_btn: Control = null


func _ready() -> void:
	layer = 24
	_build_ui()
	EventBus.inventory_changed.connect(_on_inventory_changed)
	visible = false


func _exit_tree() -> void:
	if EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.disconnect(_on_inventory_changed)


func is_open() -> bool:
	return _is_open


func open_furnace(p_furnace: PlacedWorldObject = null) -> void:
	_build_ui()
	_furnace_ref = p_furnace
	_is_open = true
	visible = true
	refresh_all()
	if _copper_row != null:
		_copper_row.grab_focus()
	modal_visibility_changed.emit(true)


func close_furnace() -> void:
	if not _is_open:
		return
	_furnace_ref = null
	_is_open = false
	visible = false
	modal_visibility_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_inventory"):
		close_furnace()
		get_viewport().set_input_as_handled()


func smelt_bar(bar_id: StringName) -> bool:
	var ore_id: StringName = &"copper_ore" if bar_id == &"copper_bar" else &"iron_ore"
	var use_ore: bool = InventoryManager.count_item(ore_id) >= 3 and InventoryManager.count_item(&"wood") >= 1
	var req_rock: int = 5 if bar_id == &"copper_bar" else 8
	var req_wood: int = 2 if bar_id == &"copper_bar" else 3
	if not use_ore:
		if InventoryManager.count_item(&"stone") < req_rock or InventoryManager.count_item(&"wood") < req_wood:
			AudioManager.play_sfx(&"error", -8.0, 0.03)
			EventBus.toast_requested.emit("Need 3 Ore+1 Wood or %d Rock+%d Wood" % [req_rock, req_wood])
			return false
	if not InventoryManager.can_fit_item(bar_id, 1):
		AudioManager.play_sfx(&"error", -8.0, 0.03)
		EventBus.toast_requested.emit("Backpack is full!")
		return false
	if use_ore:
		InventoryManager.remove_item(ore_id, 3)
		InventoryManager.remove_item(&"wood", 1)
	else:
		InventoryManager.remove_item(&"stone", req_rock)
		InventoryManager.remove_item(&"wood", req_wood)
	InventoryManager.add_item(bar_id, 1)
	if _furnace_ref != null and is_instance_valid(_furnace_ref):
		_furnace_ref.ignite_ember_burst()
	AudioManager.play_sfx(&"craft", -4.0, 0.03)
	var bitem: ItemData = InventoryManager.get_item(bar_id)
	EventBus.toast_requested.emit("Smelted +1 %s!" % (bitem.display_name if bitem != null else "Bar"))
	refresh_all()
	return true


func _on_inventory_changed() -> void:
	if _is_open:
		refresh_all()


func refresh_all() -> void:
	if not _built:
		return
	var rock: int = InventoryManager.count_item(&"stone")
	var wood: int = InventoryManager.count_item(&"wood")
	var cu_ore: int = InventoryManager.count_item(&"copper_ore")
	var fe_ore: int = InventoryManager.count_item(&"iron_ore")
	_stock_label.text = "Cu:%d Fe:%d · Rock:%d Wood:%d" % [cu_ore, fe_ore, rock, wood]
	var can_cu: bool = (cu_ore >= 3 and wood >= 1) or (rock >= 5 and wood >= 2)
	var can_fe: bool = (fe_ore >= 3 and wood >= 1) or (rock >= 8 and wood >= 3)
	_copper_status.text = "3 Cu Ore+1 Wood (or 5 Rock+2 Wood)" if cu_ore >= 3 else "5 Rock+2 Wood (or 3 Cu Ore+1 Wood)"
	_copper_status.add_theme_color_override(&"font_color", TEXT_OK if can_cu else TEXT_NO)
	_iron_status.text = "3 Fe Ore+1 Wood (or 8 Rock+3 Wood)" if fe_ore >= 3 else "8 Rock+3 Wood (or 3 Fe Ore+1 Wood)"
	_iron_status.add_theme_color_override(&"font_color", TEXT_OK if can_fe else TEXT_NO)


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var w_center: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = w_center
	backdrop.modulate = Color(0.05, 0.04, 0.08, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel: SunnysideBox = SunnysideBox.new()
	panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -94.0
	panel.offset_top = -50.0
	panel.offset_right = 94.0
	panel.offset_bottom = 50.0
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(panel)

	var title: Label = Label.new()
	title.text = "Stone Furnace — Smelt Bars"
	title.position = Vector2(8.0, 6.0)
	title.add_theme_font_size_override(&"font_size", 7)
	title.add_theme_color_override(&"font_color", TEXT_DARK)
	panel.add_child(title)

	var close_btn: Control = Control.new()
	close_btn.position = Vector2(166.0, 5.0)
	close_btn.size = Vector2(16.0, 14.0)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close_furnace()
	)
	panel.add_child(close_btn)
	UiFocus.make_focusable(close_btn, func() -> void: close_furnace(), 4.0, 1.5)
	_close_btn = close_btn
	var cbox: SunnysideBox = SunnysideBox.new()
	cbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	cbox.set_box_style(SunnysideBox.Style.DARK_TAN)
	close_btn.add_child(cbox)
	var cx: TextureRect = TextureRect.new()
	cx.texture = load(AP.UI_CANCEL) as Texture2D
	cx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cx.position = Vector2(3.0, 2.0)
	cx.size = Vector2(10.0, 10.0)
	close_btn.add_child(cx)

	_copper_status = _make_smelt_row(panel, &"copper_bar", "Copper Bar", Vector2(8.0, 22.0))
	_copper_row = _copper_status.get_parent() as Control
	_iron_status = _make_smelt_row(panel, &"iron_bar", "Iron Bar", Vector2(8.0, 52.0))
	_iron_row = _iron_status.get_parent() as Control
	UiFocus.wire_vertical_list([_copper_row, _iron_row, _close_btn], true)

	_stock_label = Label.new()
	_stock_label.position = Vector2(8.0, 84.0)
	_stock_label.size = Vector2(172.0, 10.0)
	_stock_label.add_theme_font_size_override(&"font_size", 5)
	_stock_label.add_theme_color_override(&"font_color", TEXT_DARK)
	panel.add_child(_stock_label)


func _make_smelt_row(parent: Control, bar_id: StringName, title_str: String, pos: Vector2) -> Label:
	var row: Control = Control.new()
	row.position = pos
	row.size = Vector2(172.0, 26.0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			smelt_bar(bar_id)
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			smelt_bar(bar_id)
	)
	parent.add_child(row)
	UiFocus.make_focusable(row, func() -> void: smelt_bar(bar_id), 4.0, 1.5)

	var box: SunnysideBox = SunnysideBox.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.set_box_style(SunnysideBox.Style.DARK_TAN)
	row.add_child(box)

	var item: ItemData = InventoryManager.get_item(bar_id)
	var ic: TextureRect = TextureRect.new()
	ic.texture = item.icon if item != null else null
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.position = Vector2(6.0, 5.0)
	ic.size = Vector2(15.0, 15.0)
	row.add_child(ic)

	var nl: Label = Label.new()
	nl.text = title_str
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nl.position = Vector2(26.0, 3.0)
	nl.add_theme_font_size_override(&"font_size", 7)
	nl.add_theme_color_override(&"font_color", TEXT_GOLD)
	row.add_child(nl)

	var st: Label = Label.new()
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.position = Vector2(26.0, 14.0)
	st.add_theme_font_size_override(&"font_size", 5)
	row.add_child(st)

	var go_l: Label = Label.new()
	go_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go_l.add_theme_font_size_override(&"font_size", 6)
	go_l.add_theme_color_override(&"font_color", TEXT_CREAM)
	go_l.clip_text = true
	go_l.position = Vector2(124.0, 7.0)
	go_l.size = Vector2(42.0, 12.0)
	go_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	go_l.text = "SMELT"
	row.add_child(go_l)
	return st
