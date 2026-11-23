class_name ShippingModal
extends CanvasLayer

## Sanctuary Shipping Chest Deposit Modal (res://scenes/ui/shipping_modal.tscn).
## Allows depositing sellable crops, fish, forage, and crafted items with -/+ quantity controls,
## shows tonight's pending Sunbursts earnings, and provides Undo Last Shipped support.

const AP := preload("res://scripts/core/asset_paths.gd")
const UiFocus := preload("res://scripts/ui/ui_focus_helper.gd")

signal modal_visibility_changed(is_open: bool)

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.45, 0.35, 0.30, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

var _is_open: bool = false
var _built: bool = false
var _selected_slot: int = 0
var _qty: int = 1

var _slots: Array[SunnysideSlot] = []
var _item_icon: TextureRect = null
var _item_title: Label = null
var _item_unit_label: Label = null
var _qty_label: Label = null
var _ship_total_label: Label = null
var _pending_label: Label = null
var _undo_label: Label = null
var _qty_minus_btn: Control = null
var _qty_plus_btn: Control = null
var _ship_btn: Control = null
var _undo_btn: Control = null
var _close_btn: Control = null


func _ready() -> void:
	layer = 22
	_build_ui()
	EventBus.inventory_changed.connect(_on_state_changed)
	EventBus.shipping_ledger_changed.connect(_on_state_changed)
	set_open(false)


func _exit_tree() -> void:
	if EventBus.inventory_changed.is_connected(_on_state_changed):
		EventBus.inventory_changed.disconnect(_on_state_changed)
	if EventBus.shipping_ledger_changed.is_connected(_on_state_changed):
		EventBus.shipping_ledger_changed.disconnect(_on_state_changed)


func is_open() -> bool:
	return _is_open


func set_open(open: bool) -> void:
	_build_ui()
	_is_open = open
	visible = open
	if open:
		_selected_slot = _find_best_initial_slot()
		_qty = 1
		refresh_all()
		if _selected_slot >= 0 and _selected_slot < _slots.size():
			_slots[_selected_slot].grab_focus()
	modal_visibility_changed.emit(_is_open)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_inventory"):
		set_open(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"use_tool"):
		ship_selected()
		get_viewport().set_input_as_handled()


func select_slot(slot_idx: int) -> void:
	_selected_slot = clampi(slot_idx, 0, InventoryManager.SLOT_COUNT - 1)
	_qty = 1
	refresh_all()


func adjust_qty(delta: int) -> void:
	var max_q: int = maxi(1, InventoryManager.get_slot_count(_selected_slot))
	_qty = clampi(_qty + delta, 1, max_q)
	refresh_all()


func ship_selected() -> bool:
	var item_id: StringName = InventoryManager.get_slot_item_id(_selected_slot)
	var item: ItemData = InventoryManager.get_item(item_id) if item_id != &"" else null
	if item == null or not item.is_sellable():
		AudioManager.play_sfx(&"error", -8.0, 0.03)
		EventBus.toast_requested.emit("Select a sellable crop, fish, or item")
		return false
	var avail: int = InventoryManager.get_slot_count(_selected_slot)
	var ship_n: int = clampi(_qty, 1, avail)
	if EconomyManager.ship_from_inventory_slot(_selected_slot, ship_n):
		AudioManager.play_sfx(&"place", -5.0, 0.04)
		EventBus.toast_requested.emit("Shipped %d %s (+%d G tonight)" % [ship_n, item.display_name, ship_n * item.sell_price])
		_qty = 1
		refresh_all()
		return true
	return false


func undo_last() -> bool:
	var undone: Dictionary = EconomyManager.undo_last_shipped()
	if undone.is_empty():
		AudioManager.play_sfx(&"error", -8.0, 0.03)
		return false
	var item: ItemData = InventoryManager.get_item(undone["item_id"] as StringName)
	var nm: String = item.display_name if item != null else "item"
	AudioManager.play_sfx(&"pickup", -6.0, 0.03)
	EventBus.toast_requested.emit("Returned %d %s to pack" % [int(undone["count"]), nm])
	refresh_all()
	return true


func refresh_all() -> void:
	if not _built:
		return
	for i: int in range(_slots.size()):
		var iid: StringName = InventoryManager.get_slot_item_id(i)
		var itm: ItemData = InventoryManager.get_item(iid) if iid != &"" else null
		var cnt: int = InventoryManager.get_slot_count(i)
		var chg: int = InventoryManager.get_slot_charges(i)
		_slots[i].set_item_display(itm, cnt, chg)
		_slots[i].set_selected(i == _selected_slot, true, false)
		_slots[i].modulate = Color.WHITE if (itm == null or itm.is_sellable()) else Color(0.70, 0.68, 0.68, 0.85)

	var sel_id: StringName = InventoryManager.get_slot_item_id(_selected_slot)
	var sel_item: ItemData = InventoryManager.get_item(sel_id) if sel_id != &"" else null
	var avail: int = InventoryManager.get_slot_count(_selected_slot)

	if sel_item != null and sel_item.is_sellable() and avail > 0:
		_qty = clampi(_qty, 1, avail)
		_item_icon.texture = sel_item.icon
		_item_title.text = sel_item.display_name
		_item_unit_label.text = "%d G each · Pack: %d" % [sel_item.sell_price, avail]
		_qty_label.text = str(_qty)
		_ship_total_label.text = "+%d G" % (_qty * sel_item.sell_price)
	else:
		_item_icon.texture = sel_item.icon if sel_item != null else null
		_item_title.text = sel_item.display_name if sel_item != null else "Choose Item"
		_item_unit_label.text = "Not sellable" if sel_item != null else "Click a pack slot"
		_qty_label.text = "0"
		_ship_total_label.text = "---"

	var pend_cnt: int = EconomyManager.get_pending_shipped_count()
	var pend_g: int = EconomyManager.get_pending_shipped_total()
	_pending_label.text = "Tonight: %d items (+%d G)" % [pend_cnt, pend_g]

	var last_e: Dictionary = EconomyManager.get_last_shipped_entry()
	if last_e.is_empty():
		_undo_label.text = "Undo Last"
	else:
		var li: ItemData = InventoryManager.get_item(last_e["item_id"] as StringName)
		var ln: String = li.display_name if li != null else "Item"
		_undo_label.text = "Undo %dx %s" % [int(last_e["count"]), ln]


func _find_best_initial_slot() -> int:
	var held_idx: int = InventoryManager.selected_hotbar_index
	var held_item: ItemData = InventoryManager.get_selected_item_data()
	if held_item != null and held_item.is_sellable():
		return held_idx
	for i: int in range(InventoryManager.SLOT_COUNT):
		var iid: StringName = InventoryManager.get_slot_item_id(i)
		var itm: ItemData = InventoryManager.get_item(iid) if iid != &"" else null
		if itm != null and itm.is_sellable():
			return i
	return held_idx


func _on_state_changed() -> void:
	if _is_open:
		refresh_all()


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var w_center: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(w_center != null, "Missing w_box_9slice_c.png")

	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = w_center
	backdrop.modulate = Color(0.05, 0.04, 0.08, 0.50)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var modal: Control = Control.new()
	modal.anchor_left = 0.5
	modal.anchor_top = 0.5
	modal.anchor_right = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -150.0
	modal.offset_top = -74.0
	modal.offset_right = 150.0
	modal.offset_bottom = 74.0
	modal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(modal)

	# Left Column: Header + Deposit Card + Ship / Undo Controls
	var hdr: SunnysideBox = SunnysideBox.new()
	hdr.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(104.0, 22.0)
	modal.add_child(hdr)

	var hdr_ic: TextureRect = TextureRect.new()
	hdr_ic.texture = load(AP.UI_BASKET) as Texture2D
	hdr_ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hdr_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hdr_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr_ic.position = Vector2(6.0, 5.0)
	hdr_ic.size = Vector2(11.0, 11.0)
	hdr.add_child(hdr_ic)

	var hdr_l: Label = Label.new()
	hdr_l.text = "Shipping Chest"
	hdr_l.position = Vector2(20.0, 5.0)
	hdr_l.add_theme_font_size_override(&"font_size", 7)
	hdr_l.add_theme_color_override(&"font_color", TEXT_DARK)
	hdr.add_child(hdr_l)

	var card: SunnysideBox = SunnysideBox.new()
	card.set_box_style(SunnysideBox.Style.WHITE)
	card.position = Vector2(0.0, 25.0)
	card.size = Vector2(104.0, 96.0)
	modal.add_child(card)

	var ibox: SunnysideBox = SunnysideBox.new()
	ibox.set_box_style(SunnysideBox.Style.DARK_TAN)
	ibox.position = Vector2(6.0, 6.0)
	ibox.size = Vector2(24.0, 24.0)
	card.add_child(ibox)

	_item_icon = TextureRect.new()
	_item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.position = Vector2(3.0, 3.0)
	_item_icon.size = Vector2(18.0, 18.0)
	ibox.add_child(_item_icon)

	_item_title = Label.new()
	_item_title.position = Vector2(33.0, 6.0)
	_item_title.size = Vector2(66.0, 10.0)
	_item_title.clip_text = true
	_item_title.add_theme_font_size_override(&"font_size", 7)
	_item_title.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(_item_title)

	_item_unit_label = Label.new()
	_item_unit_label.position = Vector2(33.0, 17.0)
	_item_unit_label.size = Vector2(66.0, 12.0)
	_item_unit_label.clip_text = true
	_item_unit_label.add_theme_font_size_override(&"font_size", 5)
	_item_unit_label.add_theme_color_override(&"font_color", TEXT_MUTED)
	card.add_child(_item_unit_label)

	# Quantity Spinner (- / qty / +)
	_qty_minus_btn = _make_icon_btn(card, AP.UI_ARROW_LEFT, Vector2(6.0, 36.0), Vector2(16.0, 16.0), func() -> void: adjust_qty(-1))
	var qbox: SunnysideBox = SunnysideBox.new()
	qbox.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	qbox.position = Vector2(24.0, 36.0)
	qbox.size = Vector2(26.0, 16.0)
	card.add_child(qbox)

	_qty_label = Label.new()
	_qty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_qty_label.add_theme_font_size_override(&"font_size", 7)
	_qty_label.add_theme_color_override(&"font_color", TEXT_DARK)
	qbox.add_child(_qty_label)

	_qty_plus_btn = _make_icon_btn(card, AP.UI_ARROW_RIGHT, Vector2(52.0, 36.0), Vector2(16.0, 16.0), func() -> void: adjust_qty(1))

	# Subtotal preview pill
	var sub_box: SunnysideBox = SunnysideBox.new()
	sub_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	sub_box.position = Vector2(70.0, 36.0)
	sub_box.size = Vector2(28.0, 16.0)
	card.add_child(sub_box)

	_ship_total_label = Label.new()
	_ship_total_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ship_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ship_total_label.add_theme_font_size_override(&"font_size", 5)
	_ship_total_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	sub_box.add_child(_ship_total_label)

	# Ship Button
	_ship_btn = _make_text_btn(card, "Ship Item", AP.UI_CONFIRM, Vector2(6.0, 56.0), Vector2(92.0, 17.0), func() -> void: ship_selected())

	# Undo Last Button
	_undo_btn = _make_text_btn(card, "Undo Last", AP.UI_ARROW_LEFT, Vector2(6.0, 75.0), Vector2(92.0, 16.0), func() -> void: undo_last())
	_undo_label = _undo_btn.find_child("BtnLabel", true, false) as Label

	# Tonight Pending Banner
	var pend_box: SunnysideBox = SunnysideBox.new()
	pend_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	pend_box.position = Vector2(0.0, 124.0)
	pend_box.size = Vector2(104.0, 22.0)
	modal.add_child(pend_box)

	_pending_label = Label.new()
	_pending_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pending_label.offset_left = 4.0
	_pending_label.offset_right = -4.0
	_pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pending_label.clip_text = true
	_pending_label.add_theme_font_size_override(&"font_size", 5)
	_pending_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	_pending_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_pending_label.add_theme_constant_override(&"outline_size", 1)
	pend_box.add_child(_pending_label)

	# Right Panel: 24-Slot Backpack Picker
	var right_panel: SunnysideBox = SunnysideBox.new()
	right_panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	right_panel.position = Vector2(110.0, 0.0)
	right_panel.size = Vector2(190.0, 146.0)
	modal.add_child(right_panel)

	var bp_title: Label = Label.new()
	bp_title.text = "Select crops, fish, or goods to ship overnight"
	bp_title.position = Vector2(8.0, 6.0)
	bp_title.add_theme_font_size_override(&"font_size", 6)
	bp_title.add_theme_color_override(&"font_color", TEXT_DARK)
	right_panel.add_child(bp_title)

	_slots.clear()
	var slot_ctrls: Array[Control] = []
	for i: int in range(InventoryManager.SLOT_COUNT):
		var col: int = i % 8
		var row: int = floori(float(i) / 8.0)
		var slot: SunnysideSlot = SunnysideSlot.new()
		slot.configure(i, Vector2(20.0, 20.0), row == 0)
		slot.focus_mode = Control.FOCUS_ALL
		slot.position = Vector2(8.0 + float(col) * 22.0, 20.0 + float(row) * 25.0)
		slot.slot_clicked.connect(select_slot)
		var s_idx: int = i
		slot.focus_entered.connect(func() -> void:
			if _is_open and _selected_slot != s_idx:
				select_slot(s_idx)
		)
		right_panel.add_child(slot)
		_slots.append(slot)
		slot_ctrls.append(slot)

	var hint_box: SunnysideBox = SunnysideBox.new()
	hint_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	hint_box.position = Vector2(8.0, 118.0)
	hint_box.size = Vector2(150.0, 20.0)
	right_panel.add_child(hint_box)

	var hint_l: Label = Label.new()
	hint_l.text = "Paid overnight when sleeping in bed"
	hint_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint_l.offset_left = 6.0
	hint_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_l.add_theme_font_size_override(&"font_size", 5)
	hint_l.add_theme_color_override(&"font_color", TEXT_CREAM)
	hint_box.add_child(hint_l)

	_close_btn = _make_icon_btn(right_panel, AP.UI_CANCEL, Vector2(161.0, 118.0), Vector2(21.0, 20.0), func() -> void: set_open(false))

	# Wire controller focus navigation across left deposit controls and 24-slot grid
	UiFocus.wire_grid(slot_ctrls, 8)
	for i: int in range(_slots.size()):
		if i % 8 == 0:
			_slots[i].focus_neighbor_left = _slots[i].get_path_to(_ship_btn)
		if i >= 16:
			_slots[i].focus_neighbor_bottom = _slots[i].get_path_to(_close_btn)
	_qty_minus_btn.focus_neighbor_right = _qty_minus_btn.get_path_to(_qty_plus_btn)
	_qty_minus_btn.focus_neighbor_bottom = _qty_minus_btn.get_path_to(_ship_btn)
	_qty_plus_btn.focus_neighbor_left = _qty_plus_btn.get_path_to(_qty_minus_btn)
	_qty_plus_btn.focus_neighbor_right = _qty_plus_btn.get_path_to(_slots[0])
	_qty_plus_btn.focus_neighbor_bottom = _qty_plus_btn.get_path_to(_ship_btn)
	_ship_btn.focus_neighbor_top = _ship_btn.get_path_to(_qty_minus_btn)
	_ship_btn.focus_neighbor_bottom = _ship_btn.get_path_to(_undo_btn)
	_ship_btn.focus_neighbor_right = _ship_btn.get_path_to(_slots[0])
	_undo_btn.focus_neighbor_top = _undo_btn.get_path_to(_ship_btn)
	_undo_btn.focus_neighbor_right = _undo_btn.get_path_to(_slots[16])
	_close_btn.focus_neighbor_top = _close_btn.get_path_to(_slots[23])
	_close_btn.focus_neighbor_left = _close_btn.get_path_to(_undo_btn)


func _make_icon_btn(parent: Control, icon_path: String, pos: Vector2, bsize: Vector2, on_press: Callable) -> Control:
	var btn: Control = Control.new()
	btn.position = pos
	btn.size = bsize
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_press.call()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			on_press.call()
	)
	parent.add_child(btn)
	UiFocus.make_focusable(btn, on_press, 4.0, 1.5)

	var box: SunnysideBox = SunnysideBox.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.set_box_style(SunnysideBox.Style.DARK_TAN)
	btn.add_child(box)

	var ic: TextureRect = TextureRect.new()
	ic.texture = load(icon_path) as Texture2D
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.position = Vector2(3.0, 3.0)
	ic.size = bsize - Vector2(6.0, 6.0)
	btn.add_child(ic)
	return btn


func _make_text_btn(parent: Control, text_str: String, icon_path: String, pos: Vector2, bsize: Vector2, on_press: Callable) -> Control:
	var btn: Control = Control.new()
	btn.position = pos
	btn.size = bsize
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_press.call()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			on_press.call()
	)
	parent.add_child(btn)
	UiFocus.make_focusable(btn, on_press, 4.0, 1.5)

	var box: SunnysideBox = SunnysideBox.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.set_box_style(SunnysideBox.Style.DARK_TAN)
	btn.add_child(box)

	var ic: TextureRect = UiFocus.make_icon_rect(load(icon_path) as Texture2D, Vector2(8.0, 8.0), "BtnIcon")
	UiFocus.make_centered_button_content(btn, text_str, 6, TEXT_CREAM, 3, 2, 2, ic)
	return btn
