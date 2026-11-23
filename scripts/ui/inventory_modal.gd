class_name InventoryModal
extends CanvasLayer

## 24-slot Sunnyside World Inventory & Crop Info Modal matching official Sunnyside UI layout:
## - Warm tan/brown 9-slice frames + crisp white Crop/Item Info card
## - Top tabs: Items (24-slot click-to-swap backpack), Tools (upgrade tiers), People (Bramblebrook cast)
## - Left-side Crop Info card with 3-stage Growth Strip (Seed -> Sprout -> Mature), description & sell value

const AP := preload("res://scripts/core/asset_paths.gd")
const InputPromptBadgeScript := preload("res://scripts/ui/input_prompt_badge.gd")
const UiFocusHelperScript := preload("res://scripts/ui/ui_focus_helper.gd")

signal modal_visibility_changed(is_open: bool)

enum Tab {
	ITEMS = 0,
	CRAFT = 1,
	TOOLS = 2,
	PEOPLE = 3,
}

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.45, 0.35, 0.30, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_OK: Color = Color(0.55, 0.98, 0.58, 1.0)
const TEXT_NO: Color = Color(1.0, 0.56, 0.52, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

var _is_open: bool = false
var _active_tab: int = Tab.ITEMS
var _inspected_slot: int = 0
var _selected_recipe_idx: int = 0
var _selected_npc_idx: int = 0
var _pickup_slot: int = -1 # >= 0 when awaiting second click to swap

var _backdrop: TextureRect = null
var _modal_root: Control = null
var _tab_boxes: Array[SunnysideBox] = []
var _tab_labels: Array[Label] = []
var _items_view: Control = null
var _craft_view: Control = null
var _tools_view: Control = null
var _people_view: Control = null
var _slots: Array[SunnysideSlot] = []
var _recipes: Array[RecipeData] = []
var _craft_cards: Array[SunnysideBox] = []
var _craft_btns: Array[Control] = []
var _craft_action_btn: Control = null
var _people_row_btns: Array[Control] = []
var _items_close_btn: Control = null
var _craft_status_label: Label = null
var _swap_hint_label: Label = null
var _people_profiles: Array[NpcData] = []
var _people_row_boxes: Array[SunnysideBox] = []
var _people_heart_rows: Array[Array] = []
var _people_talk_icons: Array[TextureRect] = []
var _people_gift_icons: Array[TextureRect] = []
var _people_status_labels: Array[Label] = []
var _people_name_labels: Array[Label] = []
var _people_role_labels: Array[Label] = []

# Left-side Crop / Item Info Card widgets
var _info_title: Label = null
var _info_subtitle: Label = null
var _stages_row: Control = null
var _stage_icons: Array[TextureRect] = []
var _single_preview: Control = null
var _single_icon: TextureRect = null
var _npc_preview_box: Control = null
var _npc_preview_body_atlas: AtlasTexture = null
var _npc_preview_hair_atlas: AtlasTexture = null
var _npc_preview_tool_atlas: AtlasTexture = null
var _npc_preview_hair_rect: TextureRect = null
var _single_meta: Label = null
var _meta_badge_label: Label = null
var _desc_label: Label = null
var _price_title_label: Label = null
var _price_label: Label = null
var _built: bool = false


func _ready() -> void:
	layer = 20
	_build_ui()
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.friendship_changed.connect(_on_social_changed)
	set_open(false)


func _exit_tree() -> void:
	if EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.disconnect(_on_inventory_changed)
	if EventBus.friendship_changed.is_connected(_on_social_changed):
		EventBus.friendship_changed.disconnect(_on_social_changed)


func is_open() -> bool:
	return _is_open


func set_open(open: bool) -> void:
	_build_ui()
	_is_open = open
	visible = open
	if open:
		_pickup_slot = -1
		# Default inspect to the currently active hotbar slot (or first non-empty seed/crop slot)
		_inspected_slot = InventoryManager.selected_hotbar_index
		if InventoryManager.get_slot_item_id(_inspected_slot) == &"":
			_inspected_slot = _find_first_non_empty_slot()
		set_active_tab(Tab.ITEMS)
		refresh_all()
	modal_visibility_changed.emit(_is_open)


func toggle() -> void:
	set_open(not _is_open)


func set_active_tab(tab: int) -> void:
	_active_tab = clampi(tab, Tab.ITEMS, Tab.PEOPLE)
	_pickup_slot = -1
	for i: int in range(_tab_boxes.size()):
		var is_cur: bool = (i == _active_tab)
		_tab_boxes[i].set_box_style(SunnysideBox.Style.LIGHT_TAN if is_cur else SunnysideBox.Style.DARK_TAN)
		_tab_labels[i].add_theme_color_override(&"font_color", TEXT_DARK if is_cur else TEXT_CREAM)
	_items_view.visible = (_active_tab == Tab.ITEMS)
	_craft_view.visible = (_active_tab == Tab.CRAFT)
	_tools_view.visible = (_active_tab == Tab.TOOLS)
	_people_view.visible = (_active_tab == Tab.PEOPLE)
	if _active_tab == Tab.TOOLS:
		_refresh_tools_view()
	elif _active_tab == Tab.CRAFT:
		_refresh_craft_view()
	elif _active_tab == Tab.PEOPLE:
		_refresh_people_view()
	_refresh_slots()
	_refresh_info_card()
	if _is_open:
		_focus_active_tab()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"hotbar_prev"):
		set_active_tab(posmod(_active_tab - 1, 4))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"hotbar_next"):
		set_active_tab(posmod(_active_tab + 1, 4))
		get_viewport().set_input_as_handled()
	elif _active_tab == Tab.CRAFT and event.is_action_pressed(&"use_tool"):
		craft_selected_recipe()
		get_viewport().set_input_as_handled()


func _focus_active_tab() -> void:
	match _active_tab:
		Tab.ITEMS:
			if not _slots.is_empty():
				var idx: int = clampi(_inspected_slot, 0, _slots.size() - 1)
				_slots[idx].grab_focus()
		Tab.CRAFT:
			if not _craft_btns.is_empty():
				var cidx: int = clampi(_selected_recipe_idx, 0, _craft_btns.size() - 1)
				_craft_btns[cidx].grab_focus()
			elif _craft_action_btn != null:
				_craft_action_btn.grab_focus()
		Tab.PEOPLE:
			if not _people_row_btns.is_empty():
				var pidx: int = clampi(_selected_npc_idx, 0, _people_row_btns.size() - 1)
				_people_row_btns[pidx].grab_focus()
		Tab.TOOLS:
			if _items_close_btn != null:
				_items_close_btn.grab_focus()


func select_npc_index(idx: int) -> void:
	if _people_profiles.is_empty():
		return
	_selected_npc_idx = clampi(idx, 0, _people_profiles.size() - 1)
	_refresh_people_view()
	_refresh_info_card()


func select_recipe(idx: int) -> void:
	if _recipes.is_empty():
		return
	_selected_recipe_idx = clampi(idx, 0, _recipes.size() - 1)
	_refresh_craft_view()
	_refresh_info_card()


func craft_selected_recipe() -> bool:
	if _recipes.is_empty():
		return false
	var r: RecipeData = _recipes[_selected_recipe_idx]
	if InventoryManager.craft_recipe(r.id):
		AudioManager.play_sfx(&"craft", -5.0, 0.03)
		EventBus.toast_requested.emit("Crafted %dx %s!" % [r.output_count, r.display_name])
		refresh_all()
		return true
	AudioManager.play_sfx(&"error", -8.0, 0.03)
	EventBus.toast_requested.emit("Missing ingredients or backpack full")
	return false


func inspect_slot(slot_idx: int) -> void:
	assert(slot_idx >= 0 and slot_idx < InventoryManager.SLOT_COUNT, "Inspect slot out of range.")
	_inspected_slot = slot_idx
	_refresh_slots()
	_refresh_info_card()


## Handles single-click select + second-click swap (also callable directly by automated verification).
func click_slot(slot_idx: int) -> void:
	assert(slot_idx >= 0 and slot_idx < InventoryManager.SLOT_COUNT, "Click slot out of range.")
	if _pickup_slot == -1:
		_inspected_slot = slot_idx
		if InventoryManager.get_slot_item_id(slot_idx) != &"":
			_pickup_slot = slot_idx
	elif _pickup_slot == slot_idx:
		_pickup_slot = -1
	else:
		InventoryManager.swap_slots(_pickup_slot, slot_idx)
		_inspected_slot = slot_idx
		_pickup_slot = -1
	_refresh_slots()
	_refresh_info_card()


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var w_center_tex: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(w_center_tex != null, "Missing w_box_9slice_c.png")

	# Subtle dark backdrop using real Sunnyside 9-slice center texture
	_backdrop = TextureRect.new()
	_backdrop.name = "DimBackdrop"
	_backdrop.texture = w_center_tex
	_backdrop.modulate = Color(0.05, 0.04, 0.08, 0.50)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# Centered 300x154 pixel modal container inside 320x180 viewport
	_modal_root = Control.new()
	_modal_root.name = "ModalRoot"
	_modal_root.anchor_left = 0.5
	_modal_root.anchor_top = 0.5
	_modal_root.anchor_right = 0.5
	_modal_root.anchor_bottom = 0.5
	_modal_root.offset_left = -150.0
	_modal_root.offset_top = -77.0
	_modal_root.offset_right = 150.0
	_modal_root.offset_bottom = 77.0
	_modal_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_modal_root)

	_build_left_column()
	_build_right_column()


func _build_left_column() -> void:
	# 1. Top-left "Inventory" title pill (104x22 px, centered icon+title via MarginContainer -> HBoxContainer!)
	var header: SunnysideBox = SunnysideBox.new()
	header.name = "InventoryHeaderPill"
	header.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	header.position = Vector2(0.0, 0.0)
	header.size = Vector2(104.0, 22.0)
	_modal_root.add_child(header)

	var plant_icon: TextureRect = UiFocusHelperScript.make_icon_rect(load(AP.ICON_PLANT) as Texture2D, Vector2(10.0, 11.0), "HeaderIcon")
	UiFocusHelperScript.make_centered_button_content(header, "Inventory", 8, TEXT_DARK, 4, 2, 3, plant_icon)

	# 2. White Crop / Item Info Card (104x102 px)
	var card: SunnysideBox = SunnysideBox.new()
	card.name = "CropInfoCard"
	card.set_box_style(SunnysideBox.Style.WHITE)
	card.position = Vector2(0.0, 25.0)
	card.size = Vector2(104.0, 103.0)
	_modal_root.add_child(card)

	_info_title = Label.new()
	_info_title.name = "ItemTitle"
	_info_title.position = Vector2(6.0, 4.0)
	_info_title.size = Vector2(92.0, 11.0)
	_info_title.clip_text = true
	_info_title.add_theme_font_size_override(&"font_size", 8)
	_info_title.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(_info_title)

	_info_subtitle = Label.new()
	_info_subtitle.name = "ItemSubtitle"
	_info_subtitle.position = Vector2(6.0, 14.0)
	_info_subtitle.size = Vector2(92.0, 10.0)
	_info_subtitle.clip_text = true
	_info_subtitle.add_theme_font_size_override(&"font_size", 6)
	_info_subtitle.add_theme_color_override(&"font_color", TEXT_MUTED)
	card.add_child(_info_subtitle)

	# Crop Growth Stages Strip: [Seed] -> [Sprout] -> [Mature] (matching image_89fbf9.png!)
	_stages_row = Control.new()
	_stages_row.name = "StagesRow"
	_stages_row.position = Vector2(5.0, 26.0)
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

	# Single Item / Tool Preview (shown when item has no CropData growth stages)
	_single_preview = Control.new()
	_single_preview.name = "SinglePreviewRow"
	_single_preview.position = Vector2(6.0, 26.0)
	_single_preview.size = Vector2(92.0, 26.0)
	_single_preview.visible = false
	card.add_child(_single_preview)

	var pbox: SunnysideBox = SunnysideBox.new()
	pbox.set_box_style(SunnysideBox.Style.DARK_TAN)
	pbox.position = Vector2(0.0, 0.0)
	pbox.size = Vector2(26.0, 26.0)
	_single_preview.add_child(pbox)

	_single_icon = TextureRect.new()
	_single_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_single_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_single_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_single_icon.position = Vector2(4.0, 4.0)
	_single_icon.size = Vector2(18.0, 18.0)
	pbox.add_child(_single_icon)

	# Dead-centered tight-cropped 18x19 villager preview inside 26x26 pbox (4px L/R, 3.5px T/B -> exact 4x physical px!)
	_npc_preview_box = Control.new()
	_npc_preview_box.name = "NpcPreviewBox"
	_npc_preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_npc_preview_box.position = Vector2(4.0, 3.5)
	_npc_preview_box.size = Vector2(18.0, 19.0)
	_npc_preview_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_npc_preview_box.visible = false
	pbox.add_child(_npc_preview_box)

	var crop_rect: Rect2 = DialogueModal.get_portrait_crop_rect(0)
	_npc_preview_body_atlas = AtlasTexture.new()
	_npc_preview_body_atlas.region = crop_rect
	_npc_preview_hair_atlas = AtlasTexture.new()
	_npc_preview_hair_atlas.region = crop_rect
	_npc_preview_tool_atlas = AtlasTexture.new()
	_npc_preview_tool_atlas.region = crop_rect

	_npc_preview_box.add_child(_make_portrait_rect("Body", _npc_preview_body_atlas))
	_npc_preview_hair_rect = _make_portrait_rect("Hair", _npc_preview_hair_atlas)
	_npc_preview_box.add_child(_npc_preview_hair_rect)
	_npc_preview_box.add_child(_make_portrait_rect("Tools", _npc_preview_tool_atlas))

	_single_meta = Label.new()
	_single_meta.position = Vector2(30.0, 3.0)
	_single_meta.size = Vector2(62.0, 22.0)
	_single_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_single_meta.add_theme_font_size_override(&"font_size", 6)
	_single_meta.add_theme_color_override(&"font_color", TEXT_DARK)
	_single_preview.add_child(_single_meta)

	# Season / Days / Tier Pill inside Info Card (high contrast warm-cream/gold text with crisp espresso outline)
	var meta_pill: SunnysideBox = SunnysideBox.new()
	meta_pill.name = "MetaBadge"
	meta_pill.set_box_style(SunnysideBox.Style.DARK_TAN)
	meta_pill.position = Vector2(6.0, 55.0)
	meta_pill.size = Vector2(92.0, 14.0)
	card.add_child(meta_pill)

	_meta_badge_label = Label.new()
	_meta_badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meta_badge_label.offset_left = 3.0
	_meta_badge_label.offset_top = 2.0
	_meta_badge_label.offset_right = -3.0
	_meta_badge_label.offset_bottom = -2.0
	_meta_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meta_badge_label.add_theme_font_size_override(&"font_size", 6)
	_meta_badge_label.add_theme_color_override(&"font_color", Color(1.0, 0.96, 0.78, 1.0))
	_meta_badge_label.add_theme_color_override(&"font_outline_color", Color(0.12, 0.06, 0.04, 1.0))
	_meta_badge_label.add_theme_constant_override(&"outline_size", 2)
	meta_pill.add_child(_meta_badge_label)

	# Description block
	_desc_label = Label.new()
	_desc_label.name = "DescriptionLabel"
	_desc_label.position = Vector2(6.0, 72.0)
	_desc_label.size = Vector2(92.0, 27.0)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.clip_text = true
	_desc_label.add_theme_font_size_override(&"font_size", 6)
	_desc_label.add_theme_constant_override(&"line_spacing", -2)
	_desc_label.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(_desc_label)

	# 3. Bottom-left Sell Value Pill (104x22 px, matching bottom-left bar of image_89fbf9.png)
	var price_bar: SunnysideBox = SunnysideBox.new()
	price_bar.name = "PricePill"
	price_bar.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	price_bar.position = Vector2(0.0, 132.0)
	price_bar.size = Vector2(104.0, 22.0)
	_modal_root.add_child(price_bar)

	_price_title_label = Label.new()
	_price_title_label.text = "VALUE"
	_price_title_label.position = Vector2(7.0, 5.0)
	_price_title_label.size = Vector2(36.0, 12.0)
	_price_title_label.add_theme_font_size_override(&"font_size", 7)
	_price_title_label.add_theme_color_override(&"font_color", TEXT_DARK)
	price_bar.add_child(_price_title_label)

	var val_box: SunnysideBox = SunnysideBox.new()
	val_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	val_box.position = Vector2(45.0, 4.0)
	val_box.size = Vector2(54.0, 14.0)
	price_bar.add_child(val_box)

	_price_label = Label.new()
	_price_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price_label.add_theme_font_size_override(&"font_size", 7)
	_price_label.add_theme_color_override(&"font_color", TEXT_GOLD)
	_price_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_price_label.add_theme_constant_override(&"outline_size", 2)
	val_box.add_child(_price_label)


func _build_right_column() -> void:
	# Top Tabs Bar: Items, Craft, Tools, People (fits neatly inside 190px!)
	var tab_specs: Array[Array] = [
		["Items", AP.UI_BASKET, 0.0, 46.0],
		["Craft", AP.UI_HAMMER, 48.0, 46.0],
		["Tools", AP.UI_HAND_OPEN, 96.0, 46.0],
		["People", AP.UI_PLAYERCOUNT, 144.0, 46.0],
	]
	_tab_boxes.clear()
	_tab_labels.clear()
	for i: int in range(tab_specs.size()):
		var sp: Array = tab_specs[i]
		var tab_btn: Control = Control.new()
		tab_btn.name = "TabBtn_%s" % (sp[0] as String)
		tab_btn.position = Vector2(110.0 + float(sp[2]), 0.0)
		tab_btn.size = Vector2(float(sp[3]), 22.0)
		tab_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var tab_idx: int = i
		tab_btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				set_active_tab(tab_idx)
		)
		_modal_root.add_child(tab_btn)

		var tbox: SunnysideBox = SunnysideBox.new()
		tbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		tbox.set_box_style(SunnysideBox.Style.LIGHT_TAN if i == 0 else SunnysideBox.Style.DARK_TAN)
		tab_btn.add_child(tbox)
		_tab_boxes.append(tbox)

		# Centered icon + tab label via MarginContainer (12px L/R, 6-8px T/B physical = 3 L/R, 2 T/B in 1x canvas) -> HBoxContainer!
		var ticon: TextureRect = UiFocusHelperScript.make_icon_rect(load(sp[1] as String) as Texture2D, Vector2(8.0, 8.0), "TabIcon")
		var tab_parts: Dictionary = UiFocusHelperScript.make_centered_button_content(
			tab_btn,
			sp[0] as String,
			5,
			TEXT_DARK if i == 0 else TEXT_CREAM,
			3,
			2,
			2,
			ticon
		)
		_tab_labels.append(tab_parts["label"] as Label)

	# Flanking Vryell LB/RB (L1/R1) tab-cycle prompt badges when using a controller!
	var tab_lb: InputPromptBadgeScript = InputPromptBadgeScript.new()
	tab_lb.name = "InvTabPrevBadge"
	tab_lb.configure(&"hotbar_prev", Vector2(7.0, 7.0), true, true, false)
	tab_lb.position = Vector2(97.0, 7.5)
	_modal_root.add_child(tab_lb)

	var tab_rb: InputPromptBadgeScript = InputPromptBadgeScript.new()
	tab_rb.name = "InvTabNextBadge"
	tab_rb.configure(&"hotbar_next", Vector2(7.0, 7.0), true, true, false)
	tab_rb.position = Vector2(302.0, 7.5)
	_modal_root.add_child(tab_rb)

	# Main Right Panel (190x134 px)
	var right_panel: SunnysideBox = SunnysideBox.new()
	right_panel.name = "RightContentPanel"
	right_panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	right_panel.position = Vector2(110.0, 20.0)
	right_panel.size = Vector2(190.0, 134.0)
	_modal_root.add_child(right_panel)

	_build_items_tab(right_panel)
	_build_craft_tab(right_panel)
	_build_tools_tab(right_panel)
	_build_people_tab(right_panel)


func _build_craft_tab(parent: Control) -> void:
	_craft_view = Control.new()
	_craft_view.name = "CraftTabView"
	_craft_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_craft_view.visible = false
	parent.add_child(_craft_view)

	_recipes = InventoryManager.get_all_recipes()
	_craft_cards.clear()
	_craft_btns.clear()
	for i: int in range(_recipes.size()):
		var r: RecipeData = _recipes[i]
		var out_item: ItemData = InventoryManager.get_item(r.output_item_id)
		var col: int = i % 2
		var row: int = floori(float(i) / 2.0)

		var btn: Control = Control.new()
		btn.name = "RecipeBtn_%d" % i
		btn.position = Vector2(8.0 + float(col) * 89.0, 7.0 + float(row) * 31.0)
		btn.size = Vector2(85.0, 28.0)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var ridx: int = i
		btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				select_recipe(ridx)
			elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
				select_recipe(ridx)
		)
		btn.focus_entered.connect(func() -> void: select_recipe(ridx))
		UiFocusHelperScript.make_focusable(btn, func() -> void: craft_selected_recipe(), 4.0, 1.0)
		_craft_view.add_child(btn)
		_craft_btns.append(btn)

		var card: SunnysideBox = SunnysideBox.new()
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.set_box_style(SunnysideBox.Style.DARK_TAN)
		btn.add_child(card)
		_craft_cards.append(card)

		var ic: TextureRect = TextureRect.new()
		ic.texture = out_item.icon if out_item != null else null
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(5.0, 6.0)
		ic.size = Vector2(15.0, 15.0)
		card.add_child(ic)

		var nl: Label = Label.new()
		nl.name = "RecName"
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.add_theme_font_size_override(&"font_size", 5)
		nl.add_theme_color_override(&"font_color", TEXT_CREAM)
		nl.clip_text = true
		nl.position = Vector2(23.0, 3.0)
		nl.size = Vector2(58.0, 10.0)
		nl.text = r.display_name
		card.add_child(nl)

		var il: Label = Label.new()
		il.name = "RecIng"
		il.mouse_filter = Control.MOUSE_FILTER_IGNORE
		il.add_theme_font_size_override(&"font_size", 4)
		il.clip_text = true
		il.position = Vector2(23.0, 14.0)
		il.size = Vector2(58.0, 10.0)
		card.add_child(il)

	# Bottom Craft Status + CRAFT Action Button
	var status_box: SunnysideBox = SunnysideBox.new()
	status_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	status_box.position = Vector2(8.0, 103.0)
	status_box.size = Vector2(110.0, 22.0)
	_craft_view.add_child(status_box)

	_craft_status_label = Label.new()
	_craft_status_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_craft_status_label.offset_left = 5.0
	_craft_status_label.offset_right = -5.0
	_craft_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_craft_status_label.clip_text = true
	_craft_status_label.add_theme_font_size_override(&"font_size", 5)
	_craft_status_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	status_box.add_child(_craft_status_label)

	var craft_btn: Control = Control.new()
	craft_btn.name = "CraftActionBtn"
	craft_btn.position = Vector2(121.0, 103.0)
	craft_btn.size = Vector2(61.0, 22.0)
	craft_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	craft_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			craft_selected_recipe()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			craft_selected_recipe()
	)
	UiFocusHelperScript.make_focusable(craft_btn, func() -> void: craft_selected_recipe(), 4.0, 1.0)
	_craft_view.add_child(craft_btn)
	_craft_action_btn = craft_btn
	UiFocusHelperScript.wire_grid(_craft_btns, 2)
	if not _craft_btns.is_empty():
		var last_r: Control = _craft_btns[_craft_btns.size() - 1]
		last_r.focus_neighbor_bottom = last_r.get_path_to(craft_btn)
		craft_btn.focus_neighbor_top = craft_btn.get_path_to(last_r)

	var cb_box: SunnysideBox = SunnysideBox.new()
	cb_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	cb_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	craft_btn.add_child(cb_box)

	var h_ic: TextureRect = UiFocusHelperScript.make_icon_rect(load(AP.UI_HAMMER) as Texture2D, Vector2(9.0, 9.0), "CraftIcon")
	UiFocusHelperScript.make_centered_button_content(craft_btn, "CRAFT", 6, TEXT_GOLD, 3, 2, 2, h_ic, OUTLINE_DARK, 1)


func _refresh_craft_view() -> void:
	if _recipes.is_empty():
		_recipes = InventoryManager.get_all_recipes()
	for i: int in range(_craft_cards.size()):
		if i >= _recipes.size():
			break
		var r: RecipeData = _recipes[i]
		var can_c: bool = InventoryManager.can_craft_recipe(r.id)
		var is_sel: bool = (i == _selected_recipe_idx)
		var card: SunnysideBox = _craft_cards[i]
		card.set_box_style(SunnysideBox.Style.WHITE if is_sel else SunnysideBox.Style.DARK_TAN)
		var nl: Label = card.get_node("RecName") as Label
		var il: Label = card.get_node("RecIng") as Label
		nl.add_theme_color_override(&"font_color", TEXT_DARK if is_sel else TEXT_CREAM)
		var parts: PackedStringArray = PackedStringArray()
		for k: int in range(r.get_ingredient_count()):
			var iid: StringName = r.ingredient_ids[k]
			var need: int = r.ingredient_counts[k]
			var item_d: ItemData = InventoryManager.get_item(iid)
			var nm: String = item_d.display_name if item_d != null else String(iid)
			parts.append("%d %s" % [need, nm])
		il.text = ", ".join(parts)
		if is_sel:
			il.add_theme_color_override(&"font_color", Color(0.16, 0.48, 0.20, 1.0) if can_c else Color(0.72, 0.20, 0.16, 1.0))
		else:
			il.add_theme_color_override(&"font_color", TEXT_OK if can_c else TEXT_NO)

	if _craft_status_label != null and not _recipes.is_empty():
		var sel_r: RecipeData = _recipes[_selected_recipe_idx]
		var ok: bool = InventoryManager.can_craft_recipe(sel_r.id)
		_craft_status_label.text = "Ready to craft %dx %s!" % [sel_r.output_count, sel_r.display_name] if ok else "Gather ingredients to craft"
		_craft_status_label.add_theme_color_override(&"font_color", TEXT_OK if ok else TEXT_NO)


func _build_items_tab(parent: Control) -> void:
	_items_view = Control.new()
	_items_view.name = "ItemsTabView"
	_items_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_items_view)

	var hb_lbl: Label = Label.new()
	hb_lbl.text = "Hotbar (1-8)"
	hb_lbl.position = Vector2(8.0, 5.0)
	hb_lbl.add_theme_font_size_override(&"font_size", 6)
	hb_lbl.add_theme_color_override(&"font_color", TEXT_DARK)
	_items_view.add_child(hb_lbl)

	var bp_lbl: Label = Label.new()
	bp_lbl.text = "Backpack"
	bp_lbl.position = Vector2(8.0, 41.0)
	bp_lbl.add_theme_font_size_override(&"font_size", 6)
	bp_lbl.add_theme_color_override(&"font_color", TEXT_DARK)
	_items_view.add_child(bp_lbl)

	_slots.clear()
	var slot_ctrls: Array[Control] = []
	for i: int in range(InventoryManager.SLOT_COUNT):
		var col: int = i % 8
		var row: int = floori(float(i) / 8.0)
		var slot: SunnysideSlot = SunnysideSlot.new()
		slot.name = "InvSlot_%d" % i
		slot.configure(i, Vector2(20.0, 20.0), row == 0)
		slot.focus_mode = Control.FOCUS_ALL
		var sy: float = 15.0 if row == 0 else (51.0 + float(row - 1) * 24.0)
		slot.position = Vector2(8.0 + float(col) * 22.0, sy)
		slot.slot_clicked.connect(click_slot)
		slot.slot_hovered.connect(_on_slot_hovered)
		_items_view.add_child(slot)
		_slots.append(slot)
		slot_ctrls.append(slot)
	UiFocusHelperScript.wire_grid(slot_ctrls, 8)

	# Bottom Swap Status & Close Strip
	var footer: SunnysideBox = SunnysideBox.new()
	footer.name = "SwapFooter"
	footer.set_box_style(SunnysideBox.Style.DARK_TAN)
	footer.position = Vector2(8.0, 103.0)
	footer.size = Vector2(150.0, 22.0)
	_items_view.add_child(footer)

	_swap_hint_label = Label.new()
	_swap_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swap_hint_label.offset_left = 6.0
	_swap_hint_label.offset_top = 3.0
	_swap_hint_label.offset_right = -6.0
	_swap_hint_label.offset_bottom = -3.0
	_swap_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_swap_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_swap_hint_label.clip_text = true
	_swap_hint_label.add_theme_font_size_override(&"font_size", 6)
	_swap_hint_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	_swap_hint_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_swap_hint_label.add_theme_constant_override(&"outline_size", 1)
	footer.add_child(_swap_hint_label)

	var close_btn: Control = Control.new()
	close_btn.name = "CloseBtn"
	close_btn.position = Vector2(161.0, 103.0)
	close_btn.size = Vector2(21.0, 22.0)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			set_open(false)
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			set_open(false)
	)
	UiFocusHelperScript.make_focusable(close_btn, func() -> void: set_open(false), 4.0, 1.0)
	_items_view.add_child(close_btn)
	_items_close_btn = close_btn

	var close_box: SunnysideBox = SunnysideBox.new()
	close_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	close_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	close_btn.add_child(close_box)

	var close_x: TextureRect = TextureRect.new()
	close_x.texture = load(AP.UI_CANCEL) as Texture2D
	close_x.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	close_x.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close_x.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	close_x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_x.position = Vector2(5.0, 5.0)
	close_x.size = Vector2(11.0, 11.0)
	close_btn.add_child(close_x)


func _build_tools_tab(parent: Control) -> void:
	_tools_view = Control.new()
	_tools_view.name = "ToolsTabView"
	_tools_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tools_view.visible = false
	parent.add_child(_tools_view)


func _refresh_tools_view() -> void:
	for child: Node in _tools_view.get_children():
		child.queue_free()

	var tool_ids: Array[StringName] = [
		&"tool_hoe",
		&"tool_watering_can",
		&"tool_axe",
		&"tool_pickaxe",
		&"tool_scythe",
		&"tool_fishing_rod",
	]
	var tier_names: PackedStringArray = ["", "Basic", "Copper", "Iron"]
	for i: int in range(tool_ids.size()):
		var t: ToolData = InventoryManager.get_tool(tool_ids[i])
		if t == null:
			continue
		var col: int = i % 2
		var row: int = floori(float(i) / 2.0)
		var card: SunnysideBox = SunnysideBox.new()
		card.set_box_style(SunnysideBox.Style.DARK_TAN)
		card.position = Vector2(8.0 + float(col) * 89.0, 8.0 + float(row) * 39.0)
		card.size = Vector2(85.0, 35.0)
		_tools_view.add_child(card)

		var icon_tr: TextureRect = TextureRect.new()
		icon_tr.texture = t.icon
		icon_tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tr.position = Vector2(5.0, 8.0)
		icon_tr.size = Vector2(18.0, 18.0)
		card.add_child(icon_tr)

		var name_l: Label = Label.new()
		name_l.text = t.display_name
		name_l.position = Vector2(26.0, 4.0)
		name_l.size = Vector2(56.0, 10.0)
		name_l.clip_text = true
		name_l.add_theme_font_size_override(&"font_size", 6)
		name_l.add_theme_color_override(&"font_color", TEXT_CREAM)
		card.add_child(name_l)

		var tier_l: Label = Label.new()
		var t_idx: int = clampi(int(t.tier), 1, 3)
		tier_l.text = "%s • Pwr %d" % [tier_names[t_idx], t.power]
		tier_l.position = Vector2(26.0, 14.0)
		tier_l.size = Vector2(56.0, 10.0)
		tier_l.add_theme_font_size_override(&"font_size", 6)
		tier_l.add_theme_color_override(&"font_color", TEXT_GOLD)
		card.add_child(tier_l)

		var cost_l: Label = Label.new()
		cost_l.text = "Water: %d" % t.max_charges if t.has_charges() else "Vit: -%d" % int(t.vitality_cost)
		cost_l.position = Vector2(26.0, 23.0)
		cost_l.size = Vector2(56.0, 10.0)
		cost_l.add_theme_font_size_override(&"font_size", 5)
		cost_l.add_theme_color_override(&"font_color", TEXT_CREAM)
		card.add_child(cost_l)


func _build_people_tab(parent: Control) -> void:
	_people_view = Control.new()
	_people_view.name = "PeopleTabView"
	_people_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_people_view.visible = false
	parent.add_child(_people_view)

	_people_profiles = SocialManager.get_all_npcs()
	_people_row_boxes.clear()
	_people_row_btns.clear()
	_people_heart_rows.clear()
	_people_talk_icons.clear()
	_people_gift_icons.clear()
	_people_status_labels.clear()
	_people_name_labels.clear()
	_people_role_labels.clear()

	var heart_tex: Texture2D = load(AP.UI_EXPRESSION_LOVE) as Texture2D
	var chat_tex: Texture2D = load(AP.UI_EXPRESSION_CHAT) as Texture2D
	var body_tex: Texture2D = load(AP.NPC_IDLE_BODY) as Texture2D
	var tool_tex: Texture2D = load(AP.NPC_IDLE_TOOLS) as Texture2D

	for i: int in range(_people_profiles.size()):
		var prof: NpcData = _people_profiles[i]
		var row_btn: Control = Control.new()
		row_btn.name = "VillagerRow_%s" % String(prof.npc_id)
		row_btn.position = Vector2(6.0, 4.0 + float(i) * 25.0)
		row_btn.size = Vector2(178.0, 23.0)
		row_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var npc_idx: int = i
		row_btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				select_npc_index(npc_idx)
				row_btn.accept_event()
			elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
				select_npc_index(npc_idx)
				row_btn.accept_event()
		)
		row_btn.focus_entered.connect(func() -> void: select_npc_index(npc_idx))
		UiFocusHelperScript.make_focusable(row_btn, func() -> void: select_npc_index(npc_idx), 4.0, 1.0)
		_people_view.add_child(row_btn)
		_people_row_btns.append(row_btn)

		var row_box: SunnysideBox = SunnysideBox.new()
		row_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		row_box.set_box_style(SunnysideBox.Style.DARK_TAN)
		row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_btn.add_child(row_box)
		_people_row_boxes.append(row_box)

		# Dead-centered tight-cropped 18x19 villager icon (13.5x14.25 = exact 3x physical px, symmetric 4.375px T/B inside 23px row!)
		var p_box: Control = Control.new()
		p_box.name = "PortraitBox"
		p_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_box.position = Vector2(6.5, 4.375)
		p_box.size = Vector2(13.5, 14.25)
		p_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row_box.add_child(p_box)

		var hair_path: String = "%s/IDLE/%s_idle_strip9.png" % [AP.HUMAN_ROOT, String(prof.hair_style)]
		var hair_tex: Texture2D = load(hair_path) as Texture2D

		p_box.add_child(_make_portrait_rect("Body", DialogueModal.make_portrait_atlas(body_tex, 0)))
		var sh: TextureRect = _make_portrait_rect("Hair", DialogueModal.make_portrait_atlas(hair_tex, 0))
		sh.modulate = prof.hair_tint
		p_box.add_child(sh)
		p_box.add_child(_make_portrait_rect("Tools", DialogueModal.make_portrait_atlas(tool_tex, 0)))

		var n_lbl: Label = Label.new()
		n_lbl.text = prof.display_name
		n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n_lbl.position = Vector2(25.0, 2.0)
		n_lbl.size = Vector2(76.0, 10.0)
		n_lbl.clip_text = true
		n_lbl.add_theme_font_size_override(&"font_size", 6)
		n_lbl.add_theme_color_override(&"font_color", TEXT_GOLD)
		row_box.add_child(n_lbl)
		_people_name_labels.append(n_lbl)

		var r_lbl: Label = Label.new()
		r_lbl.text = prof.role_title
		r_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r_lbl.position = Vector2(25.0, 11.0)
		r_lbl.size = Vector2(76.0, 9.0)
		r_lbl.clip_text = true
		r_lbl.add_theme_font_size_override(&"font_size", 4)
		r_lbl.add_theme_color_override(&"font_color", TEXT_CREAM)
		row_box.add_child(r_lbl)
		_people_role_labels.append(r_lbl)

		# Live 10-heart meter on right (integer 7px pitch for crisp uniform pixel hearts!)
		var hearts_row: Array = []
		for h: int in range(SocialManager.MAX_HEARTS):
			var htr: TextureRect = TextureRect.new()
			htr.texture = heart_tex
			htr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			htr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			htr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			htr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			htr.position = Vector2(103.0 + float(h) * 7.0, 3.0)
			htr.size = Vector2(6.0, 6.0)
			row_box.add_child(htr)
			hearts_row.append(htr)
		_people_heart_rows.append(hearts_row)

		# Daily talked & gifted icons + compact status text
		var talk_ic: TextureRect = TextureRect.new()
		talk_ic.texture = chat_tex
		talk_ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		talk_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		talk_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		talk_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		talk_ic.position = Vector2(104.0, 12.0)
		talk_ic.size = Vector2(7.0, 7.0)
		row_box.add_child(talk_ic)
		_people_talk_icons.append(talk_ic)

		var gift_ic: TextureRect = TextureRect.new()
		gift_ic.texture = heart_tex
		gift_ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gift_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gift_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gift_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gift_ic.position = Vector2(114.0, 12.0)
		gift_ic.size = Vector2(7.0, 7.0)
		row_box.add_child(gift_ic)
		_people_gift_icons.append(gift_ic)

		var st_lbl: Label = Label.new()
		st_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st_lbl.position = Vector2(124.0, 11.5)
		st_lbl.size = Vector2(50.0, 9.0)
		st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		st_lbl.clip_text = true
		st_lbl.add_theme_font_size_override(&"font_size", 4)
		st_lbl.add_theme_color_override(&"font_color", TEXT_CREAM)
		row_box.add_child(st_lbl)
		_people_status_labels.append(st_lbl)
	UiFocusHelperScript.wire_vertical_list(_people_row_btns, true)


func _refresh_people_view() -> void:
	for i: int in range(_people_profiles.size()):
		var prof: NpcData = _people_profiles[i]
		var is_sel: bool = (i == _selected_npc_idx)
		_people_row_boxes[i].set_box_style(SunnysideBox.Style.WHITE if is_sel else SunnysideBox.Style.DARK_TAN)
		_people_name_labels[i].add_theme_color_override(&"font_color", TEXT_DARK if is_sel else TEXT_GOLD)
		_people_role_labels[i].add_theme_color_override(&"font_color", TEXT_MUTED if is_sel else TEXT_CREAM)
		_people_status_labels[i].add_theme_color_override(&"font_color", TEXT_DARK if is_sel else TEXT_CREAM)

		var hearts: int = SocialManager.get_hearts(prof.npc_id)
		var talked: bool = SocialManager.has_talked_today(prof.npc_id)
		var gifted: bool = SocialManager.has_gifted_today(prof.npc_id)
		var gifts_wk: int = SocialManager.get_gifts_this_week(prof.npc_id)

		var h_row: Array = _people_heart_rows[i]
		for h: int in range(h_row.size()):
			var htr: TextureRect = h_row[h] as TextureRect
			if h < hearts:
				htr.modulate = Color.WHITE
			else:
				htr.modulate = Color(0.45, 0.35, 0.35, 0.35) if is_sel else Color(0.45, 0.35, 0.35, 0.45)

		_people_talk_icons[i].modulate = Color.WHITE if talked else Color(0.45, 0.40, 0.38, 0.35)
		_people_gift_icons[i].modulate = Color.WHITE if gifted else Color(0.45, 0.40, 0.38, 0.35)
		_people_status_labels[i].text = "%d/10 · G:%d/2" % [hearts, gifts_wk]


func refresh_all() -> void:
	_refresh_slots()
	if _active_tab == Tab.CRAFT:
		_refresh_craft_view()
	elif _active_tab == Tab.TOOLS:
		_refresh_tools_view()
	elif _active_tab == Tab.PEOPLE:
		_refresh_people_view()
	_refresh_info_card()


func _refresh_slots() -> void:
	for i: int in range(_slots.size()):
		var item_id: StringName = InventoryManager.get_slot_item_id(i)
		var item_data: ItemData = InventoryManager.get_item(item_id) if item_id != &"" else null
		var cnt: int = InventoryManager.get_slot_count(i)
		var chg: int = InventoryManager.get_slot_charges(i)
		_slots[i].set_item_display(item_data, cnt, chg)
		_slots[i].set_selected(i == _inspected_slot, true, i == _pickup_slot)

	if _swap_hint_label != null:
		if _pickup_slot >= 0:
			var picked: ItemData = InventoryManager.get_item(InventoryManager.get_slot_item_id(_pickup_slot))
			var pname: String = picked.display_name if picked != null else "Item"
			_swap_hint_label.text = "Moving %s -> click target slot" % pname
		else:
			_swap_hint_label.text = "Select slot to move or swap items"


func _refresh_info_card() -> void:
	if _active_tab == Tab.PEOPLE and not _people_profiles.is_empty():
		var prof: NpcData = _people_profiles[clampi(_selected_npc_idx, 0, _people_profiles.size() - 1)]
		var hearts: int = SocialManager.get_hearts(prof.npc_id)
		var pts: int = SocialManager.get_points(prof.npc_id)
		var talked: bool = SocialManager.has_talked_today(prof.npc_id)
		var gifted: bool = SocialManager.has_gifted_today(prof.npc_id)
		var gifts_wk: int = SocialManager.get_gifts_this_week(prof.npc_id)

		_info_title.text = prof.display_name
		_info_subtitle.text = prof.role_title
		_stages_row.visible = false
		_single_preview.visible = true
		_single_icon.visible = false
		_npc_preview_box.visible = true
		_npc_preview_body_atlas.atlas = load(AP.NPC_IDLE_BODY) as Texture2D
		_npc_preview_hair_atlas.atlas = load("%s/IDLE/%s_idle_strip9.png" % [AP.HUMAN_ROOT, String(prof.hair_style)]) as Texture2D
		_npc_preview_hair_rect.modulate = prof.hair_tint
		_npc_preview_tool_atlas.atlas = load(AP.NPC_IDLE_TOOLS) as Texture2D

		_single_meta.text = "Hearts: %d/10\nPts: %d" % [hearts, pts]
		_meta_badge_label.text = "Talk:%s · Gift:%s (%d/2)" % ["Yes" if talked else "No", "Yes" if gifted else "No", gifts_wk]

		var loved_ids: Array[StringName] = SocialManager.get_discovered_loved(prof.npc_id)
		if loved_ids.is_empty():
			_desc_label.text = "Loves: ??? (Gift to discover!)\n%s" % prof.bio
		else:
			var l_names: PackedStringArray = PackedStringArray()
			for lid: StringName in loved_ids:
				var l_item: ItemData = InventoryManager.get_item(lid)
				l_names.append(l_item.display_name if l_item != null else String(lid))
			_desc_label.text = "Loves: %s\n%s" % [", ".join(l_names), prof.bio]
		if _price_title_label != null:
			_price_title_label.text = "HEARTS"
		_price_label.text = "%d / 10 ♥" % hearts
		return

	if _price_title_label != null:
		_price_title_label.text = "VALUE"
	_single_icon.visible = true
	_npc_preview_box.visible = false

	if _active_tab == Tab.CRAFT and not _recipes.is_empty():
		var r: RecipeData = _recipes[_selected_recipe_idx]
		var out_item: ItemData = InventoryManager.get_item(r.output_item_id)
		_info_title.text = r.display_name
		_info_subtitle.text = "Yields x%d · Placeable" % r.output_count
		_stages_row.visible = false
		_single_preview.visible = true
		_single_icon.texture = out_item.icon if out_item != null else null
		_single_icon.modulate = out_item.icon_tint if out_item != null else Color.WHITE
		var lines: PackedStringArray = PackedStringArray()
		for k: int in range(r.get_ingredient_count()):
			var iid: StringName = r.ingredient_ids[k]
			var need: int = r.ingredient_counts[k]
			var have: int = InventoryManager.count_item(iid)
			var mdata: ItemData = InventoryManager.get_item(iid)
			var nm: String = mdata.display_name if mdata != null else String(iid)
			lines.append("%d/%d %s" % [have, need, nm])
		_single_meta.text = "\n".join(lines)
		_meta_badge_label.text = "Ready to Craft!" if InventoryManager.can_craft_recipe(r.id) else "Need Ingredients"
		_desc_label.text = r.description
		_price_label.text = "%d G" % (out_item.sell_price if out_item != null else 0)
		return

	var item_id: StringName = InventoryManager.get_slot_item_id(_inspected_slot)
	var item: ItemData = InventoryManager.get_item(item_id) if item_id != &"" else null
	var count: int = InventoryManager.get_slot_count(_inspected_slot)
	var charges: int = InventoryManager.get_slot_charges(_inspected_slot)

	if item == null:
		_info_title.text = "Empty Slot"
		_info_subtitle.text = "Slot %d" % (_inspected_slot + 1)
		_stages_row.visible = false
		_single_preview.visible = false
		_meta_badge_label.text = "Available"
		_desc_label.text = "Click any item slot to inspect or rearrange your pack."
		_price_label.text = "---"
		return

	_info_title.text = item.display_name
	_desc_label.text = item.description

	# Resolve CropData for Seeds and Harvested Crops so the 3-stage Growth Strip renders!
	var crop: CropData = InventoryManager.get_crop(item.crop_id) if item.crop_id != &"" else null
	if crop != null:
		_info_subtitle.text = crop.botanical_name if not crop.botanical_name.is_empty() else "Sanctuary Crop"
		_stages_row.visible = true
		_single_preview.visible = false
		_stage_icons[0].texture = crop.get_texture_for_stage(0)
		_stage_icons[1].texture = crop.get_texture_for_stage(2)
		_stage_icons[2].texture = crop.get_texture_for_stage(4)
		var season_list: PackedStringArray = PackedStringArray()
		for s_idx: int in crop.seasons:
			season_list.append(TimeManager.get_season_name(s_idx))
		_meta_badge_label.text = "%dd · %s" % [crop.days_to_mature, "/".join(season_list)]
		_price_label.text = "%d G" % item.sell_price if item.sell_price > 0 else "%d G" % item.buy_price
	else:
		_stages_row.visible = false
		_single_preview.visible = true
		_single_icon.texture = item.icon
		_single_icon.modulate = Color.WHITE if item is ToolData else item.icon_tint
		if item is ToolData:
			var t: ToolData = item as ToolData
			var tier_labels: PackedStringArray = ["", "Basic", "Copper", "Iron"]
			var tier_str: String = tier_labels[clampi(int(t.tier), 1, 3)]
			_info_subtitle.text = "%s Tool" % tier_str
			if t.has_charges():
				_single_meta.text = "Water:\n%d / %d" % [charges, t.max_charges]
				_meta_badge_label.text = "Refill at River"
			else:
				_single_meta.text = "Power: %d\nVit: -%d" % [t.power, int(t.vitality_cost)]
				_meta_badge_label.text = "%s Tier" % tier_str
			_price_label.text = "TOOL"
		else:
			_info_subtitle.text = "Resource" if item.category == ItemData.Category.RESOURCE else "Forage"
			_single_meta.text = "Held: %d\nMax: %d" % [count, item.max_stack]
			_meta_badge_label.text = "+%d Vit" % int(item.vitality_restore) if item.is_edible() else "Material"
			_price_label.text = "%d G" % item.sell_price


func _find_first_non_empty_slot() -> int:
	for i: int in range(InventoryManager.SLOT_COUNT):
		if InventoryManager.get_slot_item_id(i) != &"":
			return i
	return 0


func _make_portrait_rect(layer_name: String, atlas_tex: AtlasTexture) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.name = layer_name
	tr.texture = atlas_tex
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	return tr


func _on_slot_hovered(slot_idx: int) -> void:
	if _pickup_slot == -1:
		_inspected_slot = slot_idx
		_refresh_slots()
		_refresh_info_card()


func _on_inventory_changed() -> void:
	if _is_open:
		refresh_all()


func _on_social_changed(_npc_id: StringName, _pts: int, _hearts: int) -> void:
	if _is_open and _active_tab == Tab.PEOPLE:
		_refresh_people_view()
		_refresh_info_card()
