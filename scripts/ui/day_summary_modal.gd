class_name DaySummaryModal
extends CanvasLayer

## Sunnyside World overnight End-of-Day Revenue Summary ledger (res://scenes/ui/day_summary_modal.tscn).
## Displayed when sleeping or passing out if any crops, fish, or resources were shipped in the
## Sanctuary Shipping Chest; clicking Continue credits total Sunbursts and starts the next morning.

const AP := preload("res://scripts/core/asset_paths.gd")
const UiFocus := preload("res://scripts/ui/ui_focus_helper.gd")

signal summary_continued()
signal modal_visibility_changed(is_open: bool)

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.45, 0.35, 0.30, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_GREEN: Color = Color(0.18, 0.48, 0.22, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)
const MAX_VISIBLE_ROWS: int = 5

var _is_open: bool = false
var _built: bool = false
var _pending_ledger: Dictionary = {}
var _commit_on_continue: bool = false

var _backdrop: TextureRect = null
var _root_panel: SunnysideBox = null
var _header_title: Label = null
var _header_sub: Label = null
var _rows_container: Control = null
var _total_label: Label = null
var _balance_label: Label = null
var _continue_btn: Control = null


func _ready() -> void:
	layer = 35
	_build_ui()
	visible = false


func is_open() -> bool:
	return _is_open


## Displays an itemized revenue ledger. When commit_on_continue is true, pressing Continue
## commits pending shipments into EconomyManager before emitting summary_continued.
func open_summary(ledger: Dictionary, commit_on_continue: bool = true) -> void:
	_build_ui()
	_pending_ledger = ledger
	_commit_on_continue = commit_on_continue
	_populate_ledger(ledger)
	_is_open = true
	visible = true
	if _continue_btn != null:
		_continue_btn.grab_focus()
	modal_visibility_changed.emit(true)


func confirm_continue() -> void:
	if not _is_open:
		return
	if _commit_on_continue and EconomyManager.has_pending_shipments():
		EconomyManager.commit_overnight_shipping(
			int(_pending_ledger.get("day", TimeManager.current_day)),
			int(_pending_ledger.get("season_index", TimeManager.current_season)),
			int(_pending_ledger.get("year", TimeManager.current_year))
		)
	_is_open = false
	visible = false
	modal_visibility_changed.emit(false)
	summary_continued.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact"):
		confirm_continue()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var w_center: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	var ts_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	assert(w_center != null and ts_tex != null, "Missing Sunnyside UI textures for DaySummaryModal.")

	_backdrop = TextureRect.new()
	_backdrop.name = "DimBackdrop"
	_backdrop.texture = w_center
	_backdrop.modulate = Color(0.03, 0.03, 0.07, 0.78)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# Centered 252x156 Sunnyside Parchment Ledger
	_root_panel = SunnysideBox.new()
	_root_panel.name = "LedgerFrame"
	_root_panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	_root_panel.anchor_left = 0.5
	_root_panel.anchor_top = 0.5
	_root_panel.anchor_right = 0.5
	_root_panel.anchor_bottom = 0.5
	_root_panel.offset_left = -126.0
	_root_panel.offset_top = -78.0
	_root_panel.offset_right = 126.0
	_root_panel.offset_bottom = 78.0
	_root_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root_panel)

	# Header Pill with real Sunnyside coin pile icon (40, 30)
	var header_box: SunnysideBox = SunnysideBox.new()
	header_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	header_box.position = Vector2(6.0, 6.0)
	header_box.size = Vector2(240.0, 22.0)
	_root_panel.add_child(header_box)

	var coin_atlas: AtlasTexture = AtlasTexture.new()
	coin_atlas.atlas = ts_tex
	coin_atlas.region = Rect2(AP.TILE_COIN_PILE.x * 16, AP.TILE_COIN_PILE.y * 16, 16, 16)
	var coin_icon: TextureRect = TextureRect.new()
	coin_icon.texture = coin_atlas
	coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.position = Vector2(7.0, 3.0)
	coin_icon.size = Vector2(15.0, 15.0)
	header_box.add_child(coin_icon)

	_header_title = Label.new()
	_header_title.position = Vector2(26.0, 2.0)
	_header_title.size = Vector2(146.0, 10.0)
	_header_title.add_theme_font_size_override(&"font_size", 8)
	_header_title.add_theme_color_override(&"font_color", TEXT_GOLD)
	_header_title.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_header_title.add_theme_constant_override(&"outline_size", 2)
	header_box.add_child(_header_title)

	_header_sub = Label.new()
	_header_sub.position = Vector2(26.0, 12.0)
	_header_sub.size = Vector2(208.0, 9.0)
	_header_sub.add_theme_font_size_override(&"font_size", 5)
	_header_sub.add_theme_color_override(&"font_color", TEXT_CREAM)
	header_box.add_child(_header_sub)

	# White Itemized Ledger Sheet
	var sheet: SunnysideBox = SunnysideBox.new()
	sheet.name = "LedgerSheet"
	sheet.set_box_style(SunnysideBox.Style.WHITE)
	sheet.position = Vector2(6.0, 31.0)
	sheet.size = Vector2(240.0, 92.0)
	_root_panel.add_child(sheet)

	var col_item: Label = Label.new()
	col_item.add_theme_font_size_override(&"font_size", 5)
	col_item.add_theme_color_override(&"font_color", TEXT_MUTED)
	col_item.clip_text = true
	col_item.position = Vector2(10.0, 4.0)
	col_item.size = Vector2(104.0, 8.0)
	col_item.text = "SHIPPED ITEM"
	sheet.add_child(col_item)

	var col_qty: Label = Label.new()
	col_qty.add_theme_font_size_override(&"font_size", 5)
	col_qty.add_theme_color_override(&"font_color", TEXT_MUTED)
	col_qty.clip_text = true
	col_qty.position = Vector2(122.0, 4.0)
	col_qty.size = Vector2(54.0, 8.0)
	col_qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col_qty.text = "QTY x UNIT"
	sheet.add_child(col_qty)

	var col_sub: Label = Label.new()
	col_sub.add_theme_font_size_override(&"font_size", 5)
	col_sub.add_theme_color_override(&"font_color", TEXT_MUTED)
	col_sub.clip_text = true
	col_sub.position = Vector2(180.0, 4.0)
	col_sub.size = Vector2(50.0, 8.0)
	col_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col_sub.text = "SUBTOTAL"
	sheet.add_child(col_sub)

	_rows_container = Control.new()
	_rows_container.name = "RowsContainer"
	_rows_container.position = Vector2(6.0, 14.0)
	_rows_container.size = Vector2(228.0, 74.0)
	sheet.add_child(_rows_container)

	# Footer Totals + Continue Button
	var total_box: SunnysideBox = SunnysideBox.new()
	total_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	total_box.position = Vector2(6.0, 127.0)
	total_box.size = Vector2(160.0, 23.0)
	_root_panel.add_child(total_box)

	_total_label = Label.new()
	_total_label.position = Vector2(7.0, 2.0)
	_total_label.size = Vector2(146.0, 10.0)
	_total_label.add_theme_font_size_override(&"font_size", 7)
	_total_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	_total_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_total_label.add_theme_constant_override(&"outline_size", 2)
	total_box.add_child(_total_label)

	_balance_label = Label.new()
	_balance_label.position = Vector2(7.0, 12.0)
	_balance_label.size = Vector2(146.0, 9.0)
	_balance_label.add_theme_font_size_override(&"font_size", 5)
	_balance_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	total_box.add_child(_balance_label)

	var cont_btn: Control = Control.new()
	cont_btn.name = "ContinueBtn"
	cont_btn.position = Vector2(170.0, 127.0)
	cont_btn.size = Vector2(76.0, 23.0)
	cont_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	cont_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			confirm_continue()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			confirm_continue()
	)
	_root_panel.add_child(cont_btn)
	UiFocus.make_focusable(cont_btn, func() -> void: confirm_continue(), 5.0, 1.5)
	_continue_btn = cont_btn

	var btn_box: SunnysideBox = SunnysideBox.new()
	btn_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	cont_btn.add_child(btn_box)

	var ok_icon: TextureRect = UiFocus.make_icon_rect(load(AP.UI_CONFIRM) as Texture2D, Vector2(9.0, 9.0), "BtnIcon")
	UiFocus.make_centered_button_content(cont_btn, "Continue", 7, TEXT_CREAM, 3, 2, 2, ok_icon)


func _populate_ledger(ledger: Dictionary) -> void:
	for child: Node in _rows_container.get_children():
		child.queue_free()

	var day_num: int = int(ledger.get("day", TimeManager.current_day))
	var s_idx: int = int(ledger.get("season_index", TimeManager.current_season))
	var year_num: int = int(ledger.get("year", TimeManager.current_year))
	var season_name: String = TimeManager.get_season_name(s_idx)

	_header_title.text = "Sanctuary Earnings"
	_header_sub.text = "%s Day %d, Year %d · Shipping Chest Ledger" % [season_name, day_num, year_num]

	var rows: Array = ledger.get("rows", []) as Array
	var shown: int = mini(rows.size(), MAX_VISIBLE_ROWS)
	for i: int in range(shown):
		var row: Dictionary = rows[i] as Dictionary
		var item_id: StringName = row["item_id"] as StringName
		var item_data: ItemData = InventoryManager.get_item(item_id)
		var ry: float = float(i) * 14.0

		var row_bg: SunnysideBox = SunnysideBox.new()
		row_bg.set_box_style(SunnysideBox.Style.LIGHT_TAN)
		row_bg.position = Vector2(0.0, ry)
		row_bg.size = Vector2(228.0, 13.0)
		_rows_container.add_child(row_bg)

		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = item_data.icon if item_data != null else null
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2(4.0, 1.5)
		icon_rect.size = Vector2(10.0, 10.0)
		row_bg.add_child(icon_rect)

		var name_l: Label = Label.new()
		name_l.add_theme_font_size_override(&"font_size", 6)
		name_l.add_theme_color_override(&"font_color", TEXT_DARK)
		name_l.clip_text = true
		name_l.position = Vector2(17.0, 2.0)
		name_l.size = Vector2(98.0, 10.0)
		name_l.text = String(row["display_name"])
		row_bg.add_child(name_l)

		var qty_l: Label = Label.new()
		qty_l.add_theme_font_size_override(&"font_size", 6)
		qty_l.add_theme_color_override(&"font_color", TEXT_MUTED)
		qty_l.clip_text = true
		qty_l.position = Vector2(116.0, 2.0)
		qty_l.size = Vector2(54.0, 10.0)
		qty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_l.text = "%d x %d G" % [int(row["count"]), int(row["unit_price"])]
		row_bg.add_child(qty_l)

		var sub_l: Label = Label.new()
		sub_l.add_theme_font_size_override(&"font_size", 6)
		sub_l.add_theme_color_override(&"font_color", TEXT_GREEN)
		sub_l.clip_text = true
		sub_l.position = Vector2(174.0, 2.0)
		sub_l.size = Vector2(49.0, 10.0)
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sub_l.text = "+%d G" % int(row["subtotal"])
		row_bg.add_child(sub_l)

	if rows.size() > MAX_VISIBLE_ROWS:
		var extra_n: int = rows.size() - MAX_VISIBLE_ROWS
		var extra_l: Label = Label.new()
		extra_l.text = "... and %d more shipped item(s)" % extra_n
		extra_l.position = Vector2(4.0, 66.0)
		extra_l.add_theme_font_size_override(&"font_size", 5)
		extra_l.add_theme_color_override(&"font_color", TEXT_MUTED)
		_rows_container.add_child(extra_l)

	var total_earned: int = int(ledger.get("total_earned", 0))
	var bal_after: int = int(ledger.get("balance_after", EconomyManager.get_sunbursts() + total_earned))
	_total_label.text = "Total Earned: +%d G" % total_earned
	_balance_label.text = "New Balance: %d Sunbursts" % bal_after
