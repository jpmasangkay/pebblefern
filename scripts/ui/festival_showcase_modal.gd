class_name FestivalShowcaseModal
extends CanvasLayer

## Interactive Bloom Blossom Festival Harvest Showcase modal (0.5x Sunnyside canvas = 2x px on 1280x720).
## Lets the player select a Crop, Fish, or Cave Gem from their backpack for Mayor Aldric to judge,
## awarding +300 G (1st Place) or +150 G (Participation) + 100 Friendship with all 5 villagers.

const AP := preload("res://scripts/core/asset_paths.gd")
const UiFocus := preload("res://scripts/ui/ui_focus_helper.gd")

signal modal_visibility_changed(is_open: bool)

const UI_SCALE: float = 0.5
const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.46, 0.34, 0.27, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_GREEN: Color = Color(0.16, 0.52, 0.24, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

var _is_open: bool = false
var _built: bool = false
var _eligible_slots: Array[int] = []
var _selected_entry_idx: int = -1
var _last_result: Dictionary = {}

var _root_ctrl: Control = null
var _list_container: Control = null
var _empty_label: Label = null
var _preview_icon: TextureRect = null
var _preview_name: Label = null
var _preview_tier: Label = null
var _result_label: Label = null
var _submit_btn: Control = null
var _submit_btn_label: Label = null
var _end_btn: Control = null
var _close_btn: Control = null
var _entry_btns: Array[Control] = []


func _ready() -> void:
	layer = 26
	_build_ui()
	set_open(false)


func is_open() -> bool:
	return _is_open


func set_open(open: bool) -> void:
	_build_ui()
	_is_open = open
	visible = open
	if open:
		_last_result.clear()
		refresh_entries()
	modal_visibility_changed.emit(open)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_inventory"):
		set_open(false)
		get_viewport().set_input_as_handled()


func refresh_entries() -> void:
	if not _built:
		return
	for c: Node in _list_container.get_children():
		c.queue_free()
	_eligible_slots.clear()
	_entry_btns.clear()

	for slot_idx: int in range(InventoryManager.SLOT_COUNT):
		var iid: StringName = InventoryManager.get_slot_item_id(slot_idx)
		var cnt: int = InventoryManager.get_slot_count(slot_idx)
		if iid != &"" and cnt > 0 and FestivalManager.is_showcase_eligible_item(iid):
			_eligible_slots.append(slot_idx)

	if _eligible_slots.is_empty():
		_selected_entry_idx = -1
		_empty_label.visible = true
	else:
		_empty_label.visible = false
		if _selected_entry_idx < 0 or _selected_entry_idx >= _eligible_slots.size():
			_selected_entry_idx = 0

	var shown: int = mini(_eligible_slots.size(), 6)
	for i: int in range(shown):
		var s_idx: int = _eligible_slots[i]
		var item: ItemData = InventoryManager.get_item(InventoryManager.get_slot_item_id(s_idx))
		var cnt: int = InventoryManager.get_slot_count(s_idx)
		var is_sel: bool = (i == _selected_entry_idx)

		var row: Control = Control.new()
		row.name = "EntryRow_%d" % i
		row.position = Vector2(0.0, float(i) * 23.0)
		row.size = Vector2(182.0, 21.0)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var entry_idx: int = i
		var on_sel: Callable = func() -> void:
			_selected_entry_idx = entry_idx
			refresh_entries()
		row.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				on_sel.call()
				row.accept_event()
		)
		_list_container.add_child(row)
		UiFocus.make_focusable(row, on_sel, 5.0, 1.5)
		_entry_btns.append(row)

		var rbox: SunnysideBox = SunnysideBox.new()
		rbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		rbox.set_box_style(SunnysideBox.Style.WHITE if is_sel else SunnysideBox.Style.DARK_TAN)
		rbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rbox)

		var ic: TextureRect = TextureRect.new()
		ic.texture = item.icon if item != null else null
		ic.modulate = item.icon_tint if item != null else Color.WHITE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(5.0, 3.0)
		ic.size = Vector2(15.0, 15.0)
		row.add_child(ic)

		var nl: Label = Label.new()
		nl.text = "%s (x%d)" % [item.display_name, cnt] if item != null else "Item"
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.position = Vector2(24.0, 4.0)
		nl.size = Vector2(106.0, 13.0)
		nl.clip_text = true
		nl.add_theme_font_size_override(&"font_size", 8)
		nl.add_theme_color_override(&"font_color", TEXT_DARK if is_sel else TEXT_CREAM)
		row.add_child(nl)

		var vl: Label = Label.new()
		vl.text = "%d G" % (item.sell_price if item != null else 0)
		vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vl.position = Vector2(132.0, 4.0)
		vl.size = Vector2(44.0, 13.0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.add_theme_font_size_override(&"font_size", 8)
		vl.add_theme_color_override(&"font_color", TEXT_GREEN if is_sel else TEXT_GOLD)
		row.add_child(vl)

	_refresh_judging_card()
	_wire_focus_navigation()


func _wire_focus_navigation() -> void:
	var right_btns: Array[Control] = []
	if _submit_btn != null and _submit_btn.visible:
		right_btns.append(_submit_btn)
	if _end_btn != null and _end_btn.visible:
		right_btns.append(_end_btn)
	if _close_btn != null:
		right_btns.append(_close_btn)
	UiFocus.wire_vertical_list(right_btns, true)

	if not _entry_btns.is_empty():
		UiFocus.wire_vertical_list(_entry_btns, true)
		var right_target: Control = right_btns[0] if not right_btns.is_empty() else null
		for eb: Control in _entry_btns:
			if right_target != null:
				eb.focus_neighbor_right = eb.get_path_to(right_target)
		for rb: Control in right_btns:
			rb.focus_neighbor_left = rb.get_path_to(_entry_btns[clampi(_selected_entry_idx, 0, _entry_btns.size() - 1)])

	if _is_open:
		if not _entry_btns.is_empty() and not FestivalManager.showcase_submitted_this_festival:
			_entry_btns[clampi(_selected_entry_idx, 0, _entry_btns.size() - 1)].grab_focus()
		elif not right_btns.is_empty():
			right_btns[0].grab_focus()


func _refresh_judging_card() -> void:
	if FestivalManager.showcase_submitted_this_festival:
		_submit_btn.visible = false
		_end_btn.visible = true
		var rank_str: String = String(_last_result.get("rank_title", "Showcase Complete!"))
		var judge_str: String = String(_last_result.get("judge_line", "Mayor Aldric has announced this year's winner!"))
		_preview_name.text = rank_str
		_preview_tier.text = "+%d G · +100♥ All Villagers" % int(_last_result.get("gold_reward", 150))
		_result_label.text = judge_str
		return

	_end_btn.visible = true
	if _selected_entry_idx >= 0 and _selected_entry_idx < _eligible_slots.size():
		var slot_idx: int = _eligible_slots[_selected_entry_idx]
		var item: ItemData = InventoryManager.get_item(InventoryManager.get_slot_item_id(slot_idx))
		_preview_icon.visible = true
		_preview_icon.texture = item.icon
		_preview_icon.modulate = item.icon_tint
		_preview_name.text = item.display_name
		var is_prize: bool = item.sell_price >= FestivalManager.FIRST_PLACE_VALUE_THRESHOLD
		_preview_tier.text = "Prize Quality! (%d G)" % item.sell_price if is_prize else "Cozy Entry (%d G)" % item.sell_price
		_result_label.text = "Submit 1 %s to Mayor Aldric's Bloom Blossom judging table! Prizes: +300 G (1st) / +150 G + 100♥ with everyone!" % item.display_name
		_submit_btn.visible = true
		_submit_btn_label.text = "Submit Entry!"
	else:
		_preview_icon.visible = false
		_preview_name.text = "No Eligible Entry"
		_preview_tier.text = "Bring a Crop, Fish, or Gem"
		_result_label.text = "Harvest a crop, catch a fish, or mine an Azure Crystal to enter the Harvest Showcase!"
		_submit_btn.visible = false


func trigger_submit_selected() -> Dictionary:
	if _selected_entry_idx < 0 or _selected_entry_idx >= _eligible_slots.size():
		return {"ok": false, "reason": "No item selected."}
	var res: Dictionary = FestivalManager.submit_showcase_item(_eligible_slots[_selected_entry_idx])
	if bool(res.get("ok", false)):
		_last_result = res
		refresh_entries()
	else:
		AudioManager.play_sfx(&"error", -8.0, 0.03)
		EventBus.toast_requested.emit(String(res.get("reason", "Cannot submit.")))
	return res


func _build_ui() -> void:
	if _built:
		return
	_built = true

	_root_ctrl = Control.new()
	_root_ctrl.name = "FestivalShowcaseRoot"
	_root_ctrl.anchor_left = 0.0
	_root_ctrl.anchor_top = 0.0
	_root_ctrl.anchor_right = 1.0 / UI_SCALE
	_root_ctrl.anchor_bottom = 1.0 / UI_SCALE
	_root_ctrl.scale = Vector2(UI_SCALE, UI_SCALE)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root_ctrl)

	var w_center: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = w_center
	backdrop.modulate = Color(0.05, 0.04, 0.08, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_root_ctrl.add_child(backdrop)

	# Centered 384x200 Sunnyside Festival Card
	var card: SunnysideBox = SunnysideBox.new()
	card.name = "ShowcaseCard"
	card.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -192.0
	card.offset_top = -100.0
	card.offset_right = 192.0
	card.offset_bottom = 100.0
	_root_ctrl.add_child(card)

	var title_bar: SunnysideBox = SunnysideBox.new()
	title_bar.set_box_style(SunnysideBox.Style.DARK_TAN)
	title_bar.position = Vector2(8.0, 8.0)
	title_bar.size = Vector2(342.0, 22.0)
	card.add_child(title_bar)

	var title_lbl: Label = Label.new()
	title_lbl.text = "Bloom Blossom Festival — Harvest Showcase"
	title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_lbl.offset_left = 10.0
	title_lbl.offset_right = -10.0
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override(&"font_size", 10)
	title_lbl.add_theme_color_override(&"font_color", TEXT_GOLD)
	title_lbl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	title_lbl.add_theme_constant_override(&"outline_size", 2)
	title_bar.add_child(title_lbl)

	_close_btn = _make_btn("CloseBtn", Vector2(354.0, 8.0), Vector2(22.0, 22.0), "X", TEXT_CREAM, func() -> void: set_open(false))
	card.add_child(_close_btn)

	# Left Panel: Eligible Crops / Fish / Cave Gems from Backpack
	var left_box: SunnysideBox = SunnysideBox.new()
	left_box.set_box_style(SunnysideBox.Style.WHITE)
	left_box.position = Vector2(8.0, 36.0)
	left_box.size = Vector2(194.0, 156.0)
	card.add_child(left_box)

	var left_hdr: Label = Label.new()
	left_hdr.text = "Your Crops, Fish & Cave Gems"
	left_hdr.position = Vector2(6.0, 4.0)
	left_hdr.size = Vector2(182.0, 12.0)
	left_hdr.add_theme_font_size_override(&"font_size", 7)
	left_hdr.add_theme_color_override(&"font_color", TEXT_MUTED)
	left_box.add_child(left_hdr)

	_list_container = Control.new()
	_list_container.position = Vector2(6.0, 18.0)
	_list_container.size = Vector2(182.0, 134.0)
	left_box.add_child(_list_container)

	_empty_label = Label.new()
	_empty_label.text = "No crops, fish, or gems in your pack yet!"
	_empty_label.position = Vector2(10.0, 54.0)
	_empty_label.size = Vector2(174.0, 40.0)
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override(&"font_size", 8)
	_empty_label.add_theme_color_override(&"font_color", TEXT_MUTED)
	left_box.add_child(_empty_label)

	# Right Panel: Judging Preview & Rewards
	var right_box: SunnysideBox = SunnysideBox.new()
	right_box.set_box_style(SunnysideBox.Style.WHITE)
	right_box.position = Vector2(208.0, 36.0)
	right_box.size = Vector2(168.0, 112.0)
	card.add_child(right_box)

	var p_frame: SunnysideBox = SunnysideBox.new()
	p_frame.set_box_style(SunnysideBox.Style.DARK_TAN)
	p_frame.position = Vector2(8.0, 8.0)
	p_frame.size = Vector2(30.0, 30.0)
	right_box.add_child(p_frame)

	_preview_icon = TextureRect.new()
	_preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_icon.position = Vector2(5.0, 5.0)
	_preview_icon.size = Vector2(20.0, 20.0)
	p_frame.add_child(_preview_icon)

	_preview_name = Label.new()
	_preview_name.position = Vector2(44.0, 8.0)
	_preview_name.size = Vector2(116.0, 14.0)
	_preview_name.clip_text = true
	_preview_name.add_theme_font_size_override(&"font_size", 9)
	_preview_name.add_theme_color_override(&"font_color", TEXT_DARK)
	right_box.add_child(_preview_name)

	_preview_tier = Label.new()
	_preview_tier.position = Vector2(44.0, 22.0)
	_preview_tier.size = Vector2(116.0, 12.0)
	_preview_tier.clip_text = true
	_preview_tier.add_theme_font_size_override(&"font_size", 7)
	_preview_tier.add_theme_color_override(&"font_color", TEXT_GREEN)
	right_box.add_child(_preview_tier)

	_result_label = Label.new()
	_result_label.position = Vector2(8.0, 44.0)
	_result_label.size = Vector2(152.0, 62.0)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override(&"font_size", 8)
	_result_label.add_theme_color_override(&"font_color", TEXT_DARK)
	right_box.add_child(_result_label)

	_submit_btn = _make_btn("SubmitBtn", Vector2(208.0, 152.0), Vector2(168.0, 20.0), "Submit Entry!", TEXT_GOLD, func() -> void: trigger_submit_selected())
	_submit_btn_label = _submit_btn.find_child("BtnLabel", true, false) as Label
	card.add_child(_submit_btn)

	_end_btn = _make_btn("EndFestivalBtn", Vector2(208.0, 174.0), Vector2(168.0, 18.0), "Conclude Festival", TEXT_CREAM, func() -> void:
		set_open(false)
		FestivalManager.end_festival(true)
	)
	card.add_child(_end_btn)


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
	)
	UiFocus.make_focusable(btn, cb, 5.0, 1.5)
	var bg: SunnysideBox = SunnysideBox.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_box_style(SunnysideBox.Style.DARK_TAN)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)

	var pad_x: int = 2 if sz.x <= 26.0 else 6
	var pad_y: int = 2 if sz.y <= 20.0 else 3
	UiFocus.make_centered_button_content(btn, text_str, 8, col, pad_x, pad_y, 4, null, OUTLINE_DARK, 2)
	return btn
