class_name ShopModal
extends CanvasLayer

## Sunnyside World Maren's Seed Shop & Kaelen's Blacksmith Forge Modal (res://scenes/ui/shop_modal.tscn).
## Matches the official Sunnyside UI layout:
## - Left Card: Selected crop 3-stage Growth Strip (Seed -> Sprout -> Mature) / Sell preview / Tool Upgrade details
## - Bottom-Left Action Bar: [BUY / SELL / UPGRADE] + [- qty +] spinner + [Total G] pill
## - Right Panel: Seeds (all 11 crops with seasonal tags), Sell (24-slot backpack), Forge (Kaelen Basic->Copper->Iron)

const AP := preload("res://scripts/core/asset_paths.gd")
const InputPromptBadgeScript := preload("res://scripts/ui/input_prompt_badge.gd")
const UiFocusHelperScript := preload("res://scripts/ui/ui_focus_helper.gd")

signal modal_visibility_changed(is_open: bool)

enum Tab {
	SEEDS = 0,
	SELL = 1,
	FORGE = 2,
}

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.45, 0.35, 0.30, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_OK: Color = Color(0.18, 0.50, 0.22, 1.0)
const TEXT_WARN: Color = Color(0.72, 0.22, 0.18, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

var _is_open: bool = false
var _built: bool = false
var _active_tab: int = Tab.SEEDS
var _selected_seed_idx: int = 0
var _selected_sell_slot: int = 0
var _selected_tool_idx: int = 0
var _qty: int = 1

var _crops: Array[CropData] = []
var _tab_boxes: Array[SunnysideBox] = []
var _tab_labels: Array[Label] = []
var _seeds_view: Control = null
var _sell_view: Control = null
var _forge_view: Control = null
var _seed_cards: Array[SunnysideBox] = []
var _seed_btns: Array[Control] = []
var _seed_name_labels: Array[Label] = []
var _seed_star_labels: Array[Label] = []
var _sell_slots: Array[SunnysideSlot] = []
var _forge_cards: Array[SunnysideBox] = []
var _forge_btns: Array[Control] = []
var _primary_act_btn: Control = null

# Left Column Widgets
var _header_title: Label = null
var _gold_pill_label: Label = null
var _info_title: Label = null
var _info_subtitle: Label = null
var _stages_row: Control = null
var _stage_icons: Array[TextureRect] = []
var _single_preview: Control = null
var _single_icon: TextureRect = null
var _single_meta: Label = null
var _meta_badge_label: Label = null
var _desc_label: Label = null
var _action_btn_label: Label = null
var _qty_label: Label = null
var _spinner_ctrl: Control = null
var _cost_label: Label = null


func _ready() -> void:
	layer = 22
	_build_ui()
	EventBus.inventory_changed.connect(_on_data_changed)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.tool_upgraded.connect(_on_tool_upgraded)
	set_open(false)


func _exit_tree() -> void:
	if EventBus.inventory_changed.is_connected(_on_data_changed):
		EventBus.inventory_changed.disconnect(_on_data_changed)
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if EventBus.tool_upgraded.is_connected(_on_tool_upgraded):
		EventBus.tool_upgraded.disconnect(_on_tool_upgraded)


func is_open() -> bool:
	return _is_open


func set_open(open: bool, initial_tab: int = Tab.SEEDS) -> void:
	_build_ui()
	_is_open = open
	visible = open
	if open:
		_qty = 1
		set_active_tab(initial_tab)
		refresh_all()
	modal_visibility_changed.emit(_is_open)


func set_active_tab(tab: int) -> void:
	_active_tab = clampi(tab, Tab.SEEDS, Tab.FORGE)
	_qty = 1
	for i: int in range(_tab_boxes.size()):
		var is_cur: bool = (i == _active_tab)
		_tab_boxes[i].set_box_style(SunnysideBox.Style.LIGHT_TAN if is_cur else SunnysideBox.Style.DARK_TAN)
		_tab_labels[i].add_theme_color_override(&"font_color", TEXT_DARK if is_cur else TEXT_CREAM)
	_seeds_view.visible = (_active_tab == Tab.SEEDS)
	_sell_view.visible = (_active_tab == Tab.SELL)
	_forge_view.visible = (_active_tab == Tab.FORGE)
	_header_title.text = "Kaelen's Forge" if _active_tab == Tab.FORGE else "Maren's Shop"
	if _active_tab == Tab.SELL:
		_selected_sell_slot = _find_first_sellable_slot()
	refresh_all()
	if _is_open:
		_focus_active_tab()


func _focus_active_tab() -> void:
	match _active_tab:
		Tab.SEEDS:
			if not _seed_btns.is_empty():
				_seed_btns[clampi(_selected_seed_idx, 0, _seed_btns.size() - 1)].grab_focus()
		Tab.SELL:
			if not _sell_slots.is_empty():
				_sell_slots[clampi(_selected_sell_slot, 0, _sell_slots.size() - 1)].grab_focus()
		Tab.FORGE:
			if not _forge_btns.is_empty():
				_forge_btns[clampi(_selected_tool_idx, 0, _forge_btns.size() - 1)].grab_focus()


func select_seed_index(idx: int) -> void:
	if _crops.is_empty():
		return
	_selected_seed_idx = clampi(idx, 0, _crops.size() - 1)
	_qty = 1
	refresh_all()


func select_sell_slot(slot_idx: int) -> void:
	_selected_sell_slot = clampi(slot_idx, 0, InventoryManager.SLOT_COUNT - 1)
	_qty = 1
	refresh_all()


func select_tool_index(idx: int) -> void:
	_selected_tool_idx = clampi(idx, 0, EconomyManager.UPGRADEABLE_TOOLS.size() - 1)
	refresh_all()


func adjust_qty(delta: int) -> void:
	if _active_tab == Tab.SEEDS:
		_qty = clampi(_qty + delta, 1, 99)
	elif _active_tab == Tab.SELL:
		var max_q: int = maxi(1, InventoryManager.get_slot_count(_selected_sell_slot))
		_qty = clampi(_qty + delta, 1, max_q)
	refresh_all()


func execute_primary_action() -> bool:
	match _active_tab:
		Tab.SEEDS:
			if _crops.is_empty():
				return false
			var crop: CropData = _crops[_selected_seed_idx]
			if EconomyManager.buy_item(crop.seed_item_id, _qty):
				EventBus.toast_requested.emit("Bought %dx %s Seeds!" % [_qty, crop.display_name])
				refresh_all()
				return true
			AudioManager.play_sfx(&"error", -8.0, 0.03)
			EventBus.toast_requested.emit("Not enough Sunbursts or pack full")
			return false

		Tab.SELL:
			var iid: StringName = InventoryManager.get_slot_item_id(_selected_sell_slot)
			var itm: ItemData = InventoryManager.get_item(iid) if iid != &"" else null
			if itm == null or not itm.is_sellable():
				AudioManager.play_sfx(&"error", -8.0, 0.03)
				EventBus.toast_requested.emit("Select a sellable item")
				return false
			var sell_n: int = clampi(_qty, 1, InventoryManager.get_slot_count(_selected_sell_slot))
			var earned: int = EconomyManager.sell_from_inventory_slot(_selected_sell_slot, sell_n)
			if earned > 0:
				EventBus.toast_requested.emit("Sold %dx %s (+%d G)" % [sell_n, itm.display_name, earned])
				_qty = 1
				refresh_all()
				return true
			return false

		Tab.FORGE:
			var tid: StringName = EconomyManager.UPGRADEABLE_TOOLS[_selected_tool_idx]
			if EconomyManager.upgrade_tool(tid):
				var t: ToolData = InventoryManager.get_tool(tid)
				var tname: String = "Copper" if t.tier == ToolData.ToolTier.COPPER else "Iron"
				EventBus.toast_requested.emit("Upgraded %s to %s!" % [t.display_name, tname])
				refresh_all()
				return true
			AudioManager.play_sfx(&"error", -8.0, 0.03)
			EventBus.toast_requested.emit("Need more Sunbursts or materials")
			return false
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_inventory"):
		set_open(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"hotbar_prev"):
		set_active_tab(posmod(_active_tab - 1, 3))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"hotbar_next"):
		set_active_tab(posmod(_active_tab + 1, 3))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"use_tool"):
		execute_primary_action()
		get_viewport().set_input_as_handled()


func _on_data_changed() -> void:
	if _is_open:
		refresh_all()


func _on_currency_changed(_bal: int, _delta: int) -> void:
	if _is_open:
		refresh_all()


func _on_tool_upgraded(_tid: StringName, _tier: int) -> void:
	if _is_open:
		refresh_all()


func refresh_all() -> void:
	if not _built:
		return
	_gold_pill_label.text = "%d G" % EconomyManager.get_sunbursts()
	_refresh_seeds_grid()
	_refresh_sell_grid()
	_refresh_forge_grid()
	_refresh_left_card()


func _refresh_seeds_grid() -> void:
	var cur_s: int = TimeManager.current_season
	for i: int in range(_seed_cards.size()):
		var is_sel: bool = (i == _selected_seed_idx)
		var crop: CropData = _crops[i]
		var in_season: bool = crop.is_valid_season(cur_s)
		_seed_cards[i].set_box_style(SunnysideBox.Style.WHITE if is_sel else SunnysideBox.Style.DARK_TAN)
		_seed_cards[i].modulate = Color.WHITE if (in_season or is_sel) else Color(0.84, 0.82, 0.80, 0.92)
		if i < _seed_name_labels.size():
			var nl: Label = _seed_name_labels[i]
			nl.add_theme_color_override(&"font_color", TEXT_DARK if is_sel else TEXT_CREAM)
			nl.add_theme_constant_override(&"outline_size", 0 if is_sel else 1)
		if i < _seed_star_labels.size():
			_seed_star_labels[i].visible = in_season


func _refresh_sell_grid() -> void:
	for i: int in range(_sell_slots.size()):
		var iid: StringName = InventoryManager.get_slot_item_id(i)
		var itm: ItemData = InventoryManager.get_item(iid) if iid != &"" else null
		_sell_slots[i].set_item_display(itm, InventoryManager.get_slot_count(i), InventoryManager.get_slot_charges(i))
		_sell_slots[i].set_selected(i == _selected_sell_slot, true, false)
		_sell_slots[i].modulate = Color.WHITE if (itm == null or itm.is_sellable()) else Color(0.70, 0.68, 0.68, 0.85)


func _refresh_forge_grid() -> void:
	var tier_names: PackedStringArray = ["", "Basic", "Copper", "Iron"]
	for i: int in range(_forge_cards.size()):
		var tid: StringName = EconomyManager.UPGRADEABLE_TOOLS[i]
		var t: ToolData = InventoryManager.get_tool(tid)
		var spec: Dictionary = EconomyManager.get_tool_upgrade_spec(tid)
		var card: SunnysideBox = _forge_cards[i]
		card.set_box_style(SunnysideBox.Style.WHITE if i == _selected_tool_idx else SunnysideBox.Style.DARK_TAN)
		var is_sel: bool = (i == _selected_tool_idx)
		var t_lbl: Label = card.get_node("TierLbl") as Label
		var c_lbl: Label = card.get_node("CostLbl") as Label
		var n_lbl: Label = card.get_node("NameLbl") as Label
		n_lbl.add_theme_color_override(&"font_color", TEXT_DARK if is_sel else TEXT_CREAM)
		if t != null:
			var cur_name: String = tier_names[clampi(int(t.tier), 1, 3)]
			if bool(spec.get("maxed", false)):
				t_lbl.text = "%s (MAX)" % cur_name
				c_lbl.text = "Maxed"
			else:
				t_lbl.text = "%s -> %s" % [cur_name, String(spec["next_tier_name"])]
				c_lbl.text = "%d G" % int(spec["cost_g"])
			var can_up: bool = EconomyManager.can_upgrade_tool(tid)
			var ok_col: Color = TEXT_OK if is_sel else Color(0.58, 0.96, 0.58, 1.0)
			t_lbl.add_theme_color_override(&"font_color", ok_col if can_up else (TEXT_MUTED if is_sel else TEXT_GOLD))


func _refresh_left_card() -> void:
	match _active_tab:
		Tab.SEEDS:
			_spinner_ctrl.visible = true
			_action_btn_label.text = "BUY"
			if _crops.is_empty():
				return
			var crop: CropData = _crops[_selected_seed_idx]
			var seed_item: ItemData = InventoryManager.get_item(crop.seed_item_id)
			var unit_p: int = seed_item.buy_price if seed_item != null else 20
			_info_title.text = crop.display_name
			_info_subtitle.text = crop.botanical_name if not crop.botanical_name.is_empty() else "Sanctuary Seed"
			_stages_row.visible = true
			_single_preview.visible = false
			_stage_icons[0].texture = seed_item.icon if seed_item != null else crop.get_texture_for_stage(0)
			_stage_icons[1].texture = crop.get_texture_for_stage(2)
			_stage_icons[2].texture = crop.harvest_icon if crop.harvest_icon != null else crop.get_texture_for_stage(4)
			var s_names: PackedStringArray = PackedStringArray()
			for s_idx: int in crop.seasons:
				s_names.append(TimeManager.get_season_name(s_idx))
			var in_s: bool = crop.is_valid_season(TimeManager.current_season)
			_meta_badge_label.text = "%dd · %s%s" % [crop.days_to_mature, "/".join(s_names), " ★" if in_s else ""]
			var harvest_item: ItemData = InventoryManager.get_item(crop.harvest_item_id)
			var sell_val: int = harvest_item.sell_price if harvest_item != null else 0
			_desc_label.text = "Grows in %d days. Sells for %dG." % [crop.days_to_mature, sell_val]
			_qty_label.text = str(_qty)
			var total_g: int = unit_p * _qty
			_cost_label.text = "%d G" % total_g
			_cost_label.add_theme_color_override(&"font_color", TEXT_GOLD if EconomyManager.can_afford(total_g) else TEXT_WARN)

		Tab.SELL:
			_spinner_ctrl.visible = true
			_action_btn_label.text = "SELL"
			_stages_row.visible = false
			_single_preview.visible = true
			var iid: StringName = InventoryManager.get_slot_item_id(_selected_sell_slot)
			var itm: ItemData = InventoryManager.get_item(iid) if iid != &"" else null
			var avail: int = InventoryManager.get_slot_count(_selected_sell_slot)
			if itm != null and itm.is_sellable() and avail > 0:
				_qty = clampi(_qty, 1, avail)
				_info_title.text = itm.display_name
				_info_subtitle.text = "Direct Sale"
				_single_icon.texture = itm.icon
				_single_icon.modulate = itm.icon_tint
				_single_meta.text = "Unit: %d G\nPack: %d" % [itm.sell_price, avail]
				_meta_badge_label.text = "Instant Sunbursts"
				_desc_label.text = itm.description
				_qty_label.text = str(_qty)
				_cost_label.text = "+%d G" % (itm.sell_price * _qty)
				_cost_label.add_theme_color_override(&"font_color", TEXT_GOLD)
			else:
				_info_title.text = "Select Item"
				_info_subtitle.text = "Sell to Maren"
				_single_icon.texture = itm.icon if itm != null else null
				_single_icon.modulate = itm.icon_tint if itm != null else Color.WHITE
				_single_meta.text = "Click a crop,\nfish, or item"
				_meta_badge_label.text = "Not Sellable" if itm != null else "Choose Slot"
				_desc_label.text = "Sell crops, fish, forage, or crafted goods right away."
				_qty_label.text = "0"
				_cost_label.text = "---"

		Tab.FORGE:
			_spinner_ctrl.visible = false
			_action_btn_label.text = "FORGE"
			_stages_row.visible = false
			_single_preview.visible = true
			var tid: StringName = EconomyManager.UPGRADEABLE_TOOLS[_selected_tool_idx]
			var t: ToolData = InventoryManager.get_tool(tid)
			var spec: Dictionary = EconomyManager.get_tool_upgrade_spec(tid)
			if t == null or spec.is_empty():
				return
			_info_title.text = t.display_name
			_single_icon.texture = t.icon
			_single_icon.modulate = Color.WHITE
			if bool(spec.get("maxed", false)):
				_info_subtitle.text = "Iron Grade (Max)"
				_single_meta.text = "Power: %d\nMax Tier" % t.power
				_meta_badge_label.text = "Masterwork"
				_desc_label.text = String(spec["benefit"])
				_cost_label.text = "MAX"
				_cost_label.add_theme_color_override(&"font_color", TEXT_GOLD)
			else:
				_info_subtitle.text = "Upgrade -> %s" % String(spec["next_tier_name"])
				var mat_lines: PackedStringArray = PackedStringArray()
				for m: Variant in (spec["materials"] as Array):
					var md: Dictionary = m as Dictionary
					var mid: StringName = md["id"] as StringName
					var need: int = int(md["count"])
					var have: int = InventoryManager.count_item(mid)
					var mitem: ItemData = InventoryManager.get_item(mid)
					var mname: String = mitem.display_name if mitem != null else String(mid)
					mat_lines.append("%d/%d %s" % [have, need, mname])
				_single_meta.text = "\n".join(mat_lines)
				_meta_badge_label.text = "Ready!" if EconomyManager.can_upgrade_tool(tid) else "Need Materials"
				_desc_label.text = String(spec["benefit"])
				var cost_g: int = int(spec["cost_g"])
				_cost_label.text = "%d G" % cost_g
				_cost_label.add_theme_color_override(&"font_color", TEXT_GOLD if EconomyManager.can_afford(cost_g) else TEXT_WARN)


func _find_first_sellable_slot() -> int:
	for i: int in range(InventoryManager.SLOT_COUNT):
		var iid: StringName = InventoryManager.get_slot_item_id(i)
		var itm: ItemData = InventoryManager.get_item(iid) if iid != &"" else null
		if itm != null and itm.is_sellable():
			return i
	return 0


func _build_ui() -> void:
	if _built:
		return
	_built = true
	_crops = InventoryManager.get_all_crops()

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

	# Centered 302x156 Sunnyside Shop Modal (matching official image_89fbf9.png!)
	var modal: Control = Control.new()
	modal.anchor_left = 0.5
	modal.anchor_top = 0.5
	modal.anchor_right = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left = -151.0
	modal.offset_top = -78.0
	modal.offset_right = 151.0
	modal.offset_bottom = 78.0
	modal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(modal)

	_build_left_column(modal)
	_build_right_column(modal)


func _build_left_column(modal: Control) -> void:
	# 1. Top-left Shop Header + Live Sunbursts Pill
	var header: SunnysideBox = SunnysideBox.new()
	header.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	header.position = Vector2(0.0, 0.0)
	header.size = Vector2(106.0, 22.0)
	modal.add_child(header)

	_header_title = Label.new()
	_header_title.text = "Maren's Shop"
	_header_title.position = Vector2(6.0, 4.0)
	_header_title.size = Vector2(60.0, 14.0)
	_header_title.clip_text = true
	_header_title.add_theme_font_size_override(&"font_size", 7)
	_header_title.add_theme_color_override(&"font_color", TEXT_DARK)
	header.add_child(_header_title)

	var gbox: SunnysideBox = SunnysideBox.new()
	gbox.set_box_style(SunnysideBox.Style.DARK_TAN)
	gbox.position = Vector2(65.0, 4.0)
	gbox.size = Vector2(36.0, 14.0)
	header.add_child(gbox)

	_gold_pill_label = Label.new()
	_gold_pill_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gold_pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_pill_label.add_theme_font_size_override(&"font_size", 6)
	_gold_pill_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	_gold_pill_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_gold_pill_label.add_theme_constant_override(&"outline_size", 1)
	gbox.add_child(_gold_pill_label)

	# 2. Crisp White Crop/Tool Info Card (106x103)
	var card: SunnysideBox = SunnysideBox.new()
	card.set_box_style(SunnysideBox.Style.WHITE)
	card.position = Vector2(0.0, 25.0)
	card.size = Vector2(106.0, 103.0)
	modal.add_child(card)

	_info_title = Label.new()
	_info_title.position = Vector2(6.0, 4.0)
	_info_title.size = Vector2(94.0, 11.0)
	_info_title.clip_text = true
	_info_title.add_theme_font_size_override(&"font_size", 8)
	_info_title.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(_info_title)

	_info_subtitle = Label.new()
	_info_subtitle.position = Vector2(6.0, 14.0)
	_info_subtitle.size = Vector2(94.0, 10.0)
	_info_subtitle.clip_text = true
	_info_subtitle.add_theme_font_size_override(&"font_size", 6)
	_info_subtitle.add_theme_color_override(&"font_color", TEXT_MUTED)
	card.add_child(_info_subtitle)

	# 3-Stage Crop Growth Strip: [Seed] -> [Sprout] -> [Mature]
	_stages_row = Control.new()
	_stages_row.position = Vector2(6.0, 26.0)
	_stages_row.size = Vector2(94.0, 26.0)
	card.add_child(_stages_row)

	var arrow_tex: Texture2D = load(AP.UI_ARROW_RIGHT) as Texture2D
	_stage_icons.clear()
	for s: int in range(3):
		var sx: float = float(s) * 34.0
		var sbox: SunnysideBox = SunnysideBox.new()
		sbox.set_box_style(SunnysideBox.Style.LIGHT_TAN)
		sbox.position = Vector2(sx, 0.0)
		sbox.size = Vector2(26.0, 26.0)
		_stages_row.add_child(sbox)

		var sicon: TextureRect = TextureRect.new()
		sicon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sicon.position = Vector2(4.0, 4.0)
		sicon.size = Vector2(18.0, 18.0)
		sbox.add_child(sicon)
		_stage_icons.append(sicon)

		if s < 2:
			var arr: TextureRect = TextureRect.new()
			arr.texture = arrow_tex
			arr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			arr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			arr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			arr.position = Vector2(sx + 26.0, 9.0)
			arr.size = Vector2(8.0, 8.0)
			_stages_row.add_child(arr)

	# Single Item / Tool Upgrade Preview
	_single_preview = Control.new()
	_single_preview.position = Vector2(6.0, 26.0)
	_single_preview.size = Vector2(94.0, 26.0)
	_single_preview.visible = false
	card.add_child(_single_preview)

	var pbox: SunnysideBox = SunnysideBox.new()
	pbox.set_box_style(SunnysideBox.Style.DARK_TAN)
	pbox.size = Vector2(26.0, 26.0)
	_single_preview.add_child(pbox)

	_single_icon = TextureRect.new()
	_single_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_single_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_single_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_single_icon.position = Vector2(4.0, 4.0)
	_single_icon.size = Vector2(18.0, 18.0)
	pbox.add_child(_single_icon)

	_single_meta = Label.new()
	_single_meta.position = Vector2(30.0, 2.0)
	_single_meta.size = Vector2(64.0, 24.0)
	_single_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_single_meta.add_theme_font_size_override(&"font_size", 5)
	_single_meta.add_theme_color_override(&"font_color", TEXT_DARK)
	_single_preview.add_child(_single_meta)

	var meta_pill: SunnysideBox = SunnysideBox.new()
	meta_pill.set_box_style(SunnysideBox.Style.DARK_TAN)
	meta_pill.position = Vector2(6.0, 55.0)
	meta_pill.size = Vector2(94.0, 14.0)
	card.add_child(meta_pill)

	_meta_badge_label = Label.new()
	_meta_badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meta_badge_label.offset_left = 3.0
	_meta_badge_label.offset_right = -3.0
	_meta_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meta_badge_label.add_theme_font_size_override(&"font_size", 5)
	_meta_badge_label.add_theme_color_override(&"font_color", Color(1.0, 0.96, 0.78, 1.0))
	_meta_badge_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_meta_badge_label.add_theme_constant_override(&"outline_size", 1)
	meta_pill.add_child(_meta_badge_label)

	_desc_label = Label.new()
	_desc_label.position = Vector2(6.0, 72.0)
	_desc_label.size = Vector2(94.0, 27.0)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.clip_text = true
	_desc_label.add_theme_font_size_override(&"font_size", 5)
	_desc_label.add_theme_constant_override(&"line_spacing", -1)
	_desc_label.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(_desc_label)

	# 3. Bottom-Left Action Bar matching image_89fbf9.png: [BUY] [ ^ qty v ] [ 200 G ]
	var bar: SunnysideBox = SunnysideBox.new()
	bar.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	bar.position = Vector2(0.0, 131.0)
	bar.size = Vector2(106.0, 25.0)
	modal.add_child(bar)

	# Primary BUY / SELL / FORGE Button
	var act_btn: Control = Control.new()
	act_btn.name = "PrimaryActionBtn"
	act_btn.position = Vector2(4.0, 4.0)
	act_btn.size = Vector2(34.0, 17.0)
	act_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	act_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			execute_primary_action()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			execute_primary_action()
		elif ev.is_action_pressed(&"ui_left"):
			adjust_qty(-1)
			act_btn.accept_event()
		elif ev.is_action_pressed(&"ui_right"):
			adjust_qty(1)
			act_btn.accept_event()
	)
	UiFocusHelperScript.make_focusable(act_btn, func() -> void: execute_primary_action(), 4.0, 1.0)
	bar.add_child(act_btn)
	_primary_act_btn = act_btn

	var act_box: SunnysideBox = SunnysideBox.new()
	act_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	act_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	act_btn.add_child(act_box)

	var act_parts: Dictionary = UiFocusHelperScript.make_centered_button_content(act_btn, "BUY", 6, TEXT_CREAM, 3, 2, 2)
	_action_btn_label = act_parts["label"] as Label

	# Quantity Spinner [ - | qty | + ] using real arrow_up.png / arrow_up-1.png
	_spinner_ctrl = Control.new()
	_spinner_ctrl.position = Vector2(39.0, 2.0)
	_spinner_ctrl.size = Vector2(27.0, 21.0)
	bar.add_child(_spinner_ctrl)

	var qbox: SunnysideBox = SunnysideBox.new()
	qbox.set_box_style(SunnysideBox.Style.WHITE)
	qbox.position = Vector2(0.0, 2.0)
	qbox.size = Vector2(27.0, 17.0)
	_spinner_ctrl.add_child(qbox)

	_qty_label = Label.new()
	_qty_label.add_theme_font_size_override(&"font_size", 6)
	_qty_label.add_theme_color_override(&"font_color", TEXT_DARK)
	_qty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_qty_label.offset_left = 2.0
	_qty_label.offset_top = 0.0
	_qty_label.offset_right = -11.0
	_qty_label.offset_bottom = -1.0
	_qty_label.clip_text = true
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_qty_label.text = "1"
	qbox.add_child(_qty_label)

	_make_tiny_arrow(_spinner_ctrl, AP.UI_ARROW_UP, Vector2(17.0, 2.0), func() -> void: adjust_qty(1))
	_make_tiny_arrow(_spinner_ctrl, AP.UI_ARROW_DOWN, Vector2(17.0, 11.0), func() -> void: adjust_qty(-1))

	# Total Cost Pill
	var cost_box: SunnysideBox = SunnysideBox.new()
	cost_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	cost_box.position = Vector2(68.0, 4.0)
	cost_box.size = Vector2(34.0, 17.0)
	bar.add_child(cost_box)

	_cost_label = Label.new()
	_cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override(&"font_size", 6)
	_cost_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	_cost_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_cost_label.add_theme_constant_override(&"outline_size", 1)
	cost_box.add_child(_cost_label)


func _build_right_column(modal: Control) -> void:
	# Top Tabs: Seeds (Maren), Sell (Pack), Forge (Kaelen) + Close X
	var tab_specs: Array[Array] = [
		["Seeds", AP.ICON_PLANT, 0.0, 56.0],
		["Sell", AP.UI_BASKET, 58.0, 52.0],
		["Forge", AP.UI_HAMMER, 112.0, 56.0],
	]
	_tab_boxes.clear()
	_tab_labels.clear()
	for i: int in range(tab_specs.size()):
		var sp: Array = tab_specs[i]
		var tbtn: Control = Control.new()
		tbtn.position = Vector2(112.0 + float(sp[2]), 0.0)
		tbtn.size = Vector2(float(sp[3]), 22.0)
		tbtn.mouse_filter = Control.MOUSE_FILTER_STOP
		var t_idx: int = i
		tbtn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				set_active_tab(t_idx)
		)
		modal.add_child(tbtn)

		var tbox: SunnysideBox = SunnysideBox.new()
		tbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		tbox.set_box_style(SunnysideBox.Style.LIGHT_TAN if i == 0 else SunnysideBox.Style.DARK_TAN)
		tbtn.add_child(tbox)
		_tab_boxes.append(tbox)

		var tic: TextureRect = UiFocusHelperScript.make_icon_rect(load(sp[1] as String) as Texture2D, Vector2(8.0, 8.0), "TabIcon")
		var tab_parts: Dictionary = UiFocusHelperScript.make_centered_button_content(
			tbtn,
			sp[0] as String,
			6,
			TEXT_DARK if i == 0 else TEXT_CREAM,
			3,
			2,
			2,
			tic
		)
		_tab_labels.append(tab_parts["label"] as Label)

	# Flanking Vryell LB/RB tab-cycle badges in Gamepad mode
	var sh_lb: InputPromptBadgeScript = InputPromptBadgeScript.new()
	sh_lb.name = "ShopTabPrevBadge"
	sh_lb.configure(&"hotbar_prev", Vector2(7.0, 7.0), true, true, false)
	sh_lb.position = Vector2(99.0, 7.5)
	modal.add_child(sh_lb)

	var sh_rb: InputPromptBadgeScript = InputPromptBadgeScript.new()
	sh_rb.name = "ShopTabNextBadge"
	sh_rb.configure(&"hotbar_next", Vector2(7.0, 7.0), true, true, false)
	sh_rb.position = Vector2(271.0, 7.5)
	modal.add_child(sh_rb)

	# Close Button top-right
	var close_btn: Control = Control.new()
	close_btn.position = Vector2(282.0, 0.0)
	close_btn.size = Vector2(20.0, 20.0)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			set_open(false)
	)
	modal.add_child(close_btn)
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
	cx.position = Vector2(4.0, 4.0)
	cx.size = Vector2(11.0, 11.0)
	close_btn.add_child(cx)

	# Main Right Panel (190x136)
	var rpanel: SunnysideBox = SunnysideBox.new()
	rpanel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	rpanel.position = Vector2(112.0, 20.0)
	rpanel.size = Vector2(190.0, 136.0)
	modal.add_child(rpanel)

	_build_seeds_tab(rpanel)
	_build_sell_tab(rpanel)
	_build_forge_tab(rpanel)


func _build_seeds_tab(parent: Control) -> void:
	_seeds_view = Control.new()
	_seeds_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_seeds_view)

	var hdr_l: Label = Label.new()
	hdr_l.text = "Maren's Seasonal Seed Catalog (★ = In Season)"
	hdr_l.position = Vector2(7.0, 5.0)
	hdr_l.add_theme_font_size_override(&"font_size", 5)
	hdr_l.add_theme_color_override(&"font_color", TEXT_DARK)
	_seeds_view.add_child(hdr_l)

	_seed_cards.clear()
	_seed_btns.clear()
	_seed_name_labels.clear()
	_seed_star_labels.clear()
	for i: int in range(_crops.size()):
		var crop: CropData = _crops[i]
		var seed_item: ItemData = InventoryManager.get_item(crop.seed_item_id)
		var col: int = i % 4
		var row: int = floori(float(i) / 4.0)

		var cbtn: Control = Control.new()
		cbtn.position = Vector2(7.0 + float(col) * 44.5, 16.0 + float(row) * 38.0)
		cbtn.size = Vector2(42.0, 35.0)
		cbtn.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx: int = i
		cbtn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				select_seed_index(idx)
			elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
				select_seed_index(idx)
		)
		cbtn.focus_entered.connect(func() -> void: select_seed_index(idx))
		UiFocusHelperScript.make_focusable(cbtn, func() -> void: execute_primary_action(), 4.0, 1.0)
		_seeds_view.add_child(cbtn)
		_seed_btns.append(cbtn)

		var cbox: SunnysideBox = SunnysideBox.new()
		cbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		cbox.set_box_style(SunnysideBox.Style.DARK_TAN)
		cbtn.add_child(cbox)
		_seed_cards.append(cbox)

		var ic: TextureRect = TextureRect.new()
		ic.texture = seed_item.icon if seed_item != null else null
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(5.0, 4.0)
		ic.size = Vector2(13.0, 13.0)
		cbtn.add_child(ic)

		var ov: TextureRect = TextureRect.new()
		ov.texture = crop.harvest_icon
		ov.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ov.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.position = Vector2(20.0, 4.0)
		ov.size = Vector2(13.0, 13.0)
		cbtn.add_child(ov)

		var star_l: Label = Label.new()
		star_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_l.add_theme_font_size_override(&"font_size", 4)
		star_l.add_theme_color_override(&"font_color", TEXT_GOLD)
		star_l.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
		star_l.add_theme_constant_override(&"outline_size", 1)
		star_l.clip_text = true
		star_l.position = Vector2(32.0, 2.0)
		star_l.size = Vector2(8.0, 8.0)
		star_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_l.text = "★"
		cbtn.add_child(star_l)
		_seed_star_labels.append(star_l)

		var nl: Label = Label.new()
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.add_theme_font_size_override(&"font_size", 4)
		nl.add_theme_color_override(&"font_color", TEXT_CREAM)
		nl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
		nl.add_theme_constant_override(&"outline_size", 1)
		nl.clip_text = true
		nl.position = Vector2(2.0, 17.0)
		nl.size = Vector2(38.0, 8.0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.text = crop.display_name
		cbtn.add_child(nl)
		_seed_name_labels.append(nl)

		var pl: Label = Label.new()
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pl.add_theme_font_size_override(&"font_size", 4)
		pl.add_theme_color_override(&"font_color", TEXT_GOLD)
		pl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
		pl.add_theme_constant_override(&"outline_size", 1)
		pl.clip_text = true
		pl.position = Vector2(2.0, 25.0)
		pl.size = Vector2(38.0, 8.0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.text = "%dG" % (seed_item.buy_price if seed_item != null else 0)
		cbtn.add_child(pl)
	UiFocusHelperScript.wire_grid(_seed_btns, 4)
	if _primary_act_btn != null and not _seed_btns.is_empty():
		_seed_btns[0].focus_neighbor_left = _seed_btns[0].get_path_to(_primary_act_btn)
		_primary_act_btn.focus_neighbor_right = _primary_act_btn.get_path_to(_seed_btns[0])


func _build_sell_tab(parent: Control) -> void:
	_sell_view = Control.new()
	_sell_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sell_view.visible = false
	parent.add_child(_sell_view)

	var title_l: Label = Label.new()
	title_l.text = "Click any pack item, then press SELL"
	title_l.position = Vector2(8.0, 6.0)
	title_l.add_theme_font_size_override(&"font_size", 6)
	title_l.add_theme_color_override(&"font_color", TEXT_DARK)
	_sell_view.add_child(title_l)

	_sell_slots.clear()
	var sell_ctrls: Array[Control] = []
	for i: int in range(InventoryManager.SLOT_COUNT):
		var col: int = i % 8
		var row: int = floori(float(i) / 8.0)
		var slot: SunnysideSlot = SunnysideSlot.new()
		slot.configure(i, Vector2(20.0, 20.0), row == 0)
		slot.focus_mode = Control.FOCUS_ALL
		slot.position = Vector2(8.0 + float(col) * 22.0, 20.0 + float(row) * 26.0)
		slot.slot_clicked.connect(select_sell_slot)
		slot.slot_hovered.connect(select_sell_slot)
		_sell_view.add_child(slot)
		_sell_slots.append(slot)
		sell_ctrls.append(slot)
	UiFocusHelperScript.wire_grid(sell_ctrls, 8)


func _build_forge_tab(parent: Control) -> void:
	_forge_view = Control.new()
	_forge_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_forge_view.visible = false
	parent.add_child(_forge_view)

	var title_l: Label = Label.new()
	title_l.text = "Kaelen's Blacksmith — Basic -> Copper -> Iron"
	title_l.position = Vector2(8.0, 5.0)
	title_l.add_theme_font_size_override(&"font_size", 5)
	title_l.add_theme_color_override(&"font_color", TEXT_DARK)
	_forge_view.add_child(title_l)

	_forge_cards.clear()
	_forge_btns.clear()
	for i: int in range(EconomyManager.UPGRADEABLE_TOOLS.size()):
		var tid: StringName = EconomyManager.UPGRADEABLE_TOOLS[i]
		var t: ToolData = InventoryManager.get_tool(tid)
		var btn: Control = Control.new()
		btn.position = Vector2(8.0, 17.0 + float(i) * 28.0)
		btn.size = Vector2(174.0, 25.0)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx: int = i
		btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				select_tool_index(idx)
			elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
				select_tool_index(idx)
		)
		btn.focus_entered.connect(func() -> void: select_tool_index(idx))
		UiFocusHelperScript.make_focusable(btn, func() -> void: execute_primary_action(), 4.0, 1.0)
		_forge_view.add_child(btn)
		_forge_btns.append(btn)

		var card: SunnysideBox = SunnysideBox.new()
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.set_box_style(SunnysideBox.Style.DARK_TAN)
		btn.add_child(card)
		_forge_cards.append(card)

		var ic: TextureRect = TextureRect.new()
		ic.texture = t.icon if t != null else null
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(6.0, 5.0)
		ic.size = Vector2(15.0, 15.0)
		card.add_child(ic)

		var nl: Label = Label.new()
		nl.name = "NameLbl"
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.add_theme_font_size_override(&"font_size", 6)
		nl.add_theme_color_override(&"font_color", TEXT_CREAM)
		nl.clip_text = true
		nl.position = Vector2(26.0, 3.0)
		nl.size = Vector2(90.0, 10.0)
		nl.text = t.display_name if t != null else String(tid)
		card.add_child(nl)

		var tl: Label = Label.new()
		tl.name = "TierLbl"
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tl.add_theme_font_size_override(&"font_size", 5)
		tl.add_theme_color_override(&"font_color", TEXT_GOLD)
		tl.clip_text = true
		tl.position = Vector2(26.0, 13.0)
		tl.size = Vector2(96.0, 9.0)
		card.add_child(tl)

		var cl: Label = Label.new()
		cl.name = "CostLbl"
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_theme_font_size_override(&"font_size", 6)
		cl.add_theme_color_override(&"font_color", TEXT_GOLD)
		cl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
		cl.add_theme_constant_override(&"outline_size", 1)
		cl.clip_text = true
		cl.position = Vector2(124.0, 6.0)
		cl.size = Vector2(44.0, 12.0)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_child(cl)
	UiFocusHelperScript.wire_vertical_list(_forge_btns, true)


func _make_tiny_arrow(parent: Control, icon_path: String, pos: Vector2, on_press: Callable) -> void:
	var btn: Control = Control.new()
	btn.position = pos
	btn.size = Vector2(9.0, 8.0)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_press.call()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			on_press.call()
	)
	parent.add_child(btn)
	var ic: TextureRect = TextureRect.new()
	ic.texture = load(icon_path) as Texture2D
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(ic)
