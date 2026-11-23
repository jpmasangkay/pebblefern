class_name SunnysideSlot
extends Control

## Reusable Sunnyside World pixel-art inventory/hotbar slot.
## Adapts cleanly between sleek 28x28 HUD hotbar slots (rendered at 0.5x = exact 2x physical px)
## and compact 20x20 modal backpack slots:
## - Top-left: crisp 1..8 key hint
## - Top-right: Cu/Fe tool tier pip OR seed/placeable overlay miniature (never touches bottom bar!)
## - Bottom-right (strictly INSIDE slot): crisp outlined stack count (12, 6, 4 — zero protruding boxes!)
## - Bottom inner edge: Watering Can bluebar fill gauge

const AP := preload("res://scripts/core/asset_paths.gd")
const InputPromptBadgeScript := preload("res://scripts/ui/input_prompt_badge.gd")

signal slot_clicked(slot_index: int)
signal slot_hovered(slot_index: int)

var slot_index: int = 0
var show_key_hint: bool = false

var _slot_size: Vector2 = Vector2(20.0, 20.0)
var _bg_box: SunnysideBox = null
var _icon_rect: TextureRect = null
var _overlay_rect: TextureRect = null
var _key_badge: InputPromptBadgeScript = null
var _count_label: Label = null
var _tier_label: Label = null
var _charge_bar: TextureRect = null
var _brackets: Control = null
var _bluebar_textures: Array[Texture2D] = []
var _is_selected: bool = false
var _is_pickup_source: bool = false
var _is_focused: bool = false
var _built: bool = false


func _ready() -> void:
	_build_if_needed()


func configure(idx: int, slot_size: Vector2 = Vector2(20.0, 20.0), display_key_hint: bool = false) -> void:
	slot_index = idx
	show_key_hint = display_key_hint
	_slot_size = slot_size
	custom_minimum_size = slot_size
	size = slot_size
	_build_if_needed()
	_apply_layout_metrics()
	if _key_badge != null:
		if show_key_hint and slot_index >= 0 and slot_index < 8:
			var badge_sz: Vector2 = Vector2(6.0, 6.0) if _slot_size.x >= 26.0 else Vector2(4.5, 4.5)
			_key_badge.configure(StringName("slot_%d" % (slot_index + 1)), badge_sz, true, false, true, false)
		else:
			_key_badge.keyboard_only = false
			_key_badge.visible = false


func _build_if_needed() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for p: String in AP.BLUEBAR_PATHS:
		var bt: Texture2D = load(p) as Texture2D
		assert(bt != null, "Missing Sunnyside bluebar PNG: %s" % p)
		_bluebar_textures.append(bt)

	_bg_box = SunnysideBox.new()
	_bg_box.name = "BgBox"
	_bg_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	add_child(_bg_box)

	_icon_rect = TextureRect.new()
	_icon_rect.name = "ItemIcon"
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_icon_rect)

	# Composite crop/flame miniature tucked neatly top-right (well clear of bottom-right stack count & top-left key!)
	_overlay_rect = TextureRect.new()
	_overlay_rect.name = "SeedCropOverlay"
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_overlay_rect.anchor_left = 1.0
	_overlay_rect.anchor_top = 0.0
	_overlay_rect.anchor_right = 1.0
	_overlay_rect.anchor_bottom = 0.0
	_overlay_rect.visible = false
	add_child(_overlay_rect)

	# Micro water charge bar seated cleanly along bottom inner rim of Watering Can slot
	_charge_bar = TextureRect.new()
	_charge_bar.name = "WaterChargeBar"
	_charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_charge_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_charge_bar.stretch_mode = TextureRect.STRETCH_SCALE
	_charge_bar.anchor_left = 0.0
	_charge_bar.anchor_top = 1.0
	_charge_bar.anchor_right = 1.0
	_charge_bar.anchor_bottom = 1.0
	_charge_bar.visible = false
	add_child(_charge_bar)

	# Top-left real Vryell hotbar keycap glyph (1..8 in Keyboard mode; auto-hides in Gamepad/Touch!)
	_key_badge = InputPromptBadgeScript.new()
	_key_badge.name = "KeyHintBadge"
	_key_badge.visible = false
	add_child(_key_badge)

	# Top-right crisp tier pip for Copper ("Cu") / Iron ("Fe") tools (100% clear of bottom water bar!)
	_tier_label = Label.new()
	_tier_label.name = "TierBadge"
	_tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_label.anchor_left = 1.0
	_tier_label.anchor_top = 0.0
	_tier_label.anchor_right = 1.0
	_tier_label.anchor_bottom = 0.0
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tier_label.add_theme_color_override(&"font_outline_color", Color(0.12, 0.07, 0.05, 1.0))
	_tier_label.clip_text = true
	_tier_label.visible = false
	add_child(_tier_label)

	# Bottom-right stack count tucked strictly INSIDE the slot (zero bursting over top border!)
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.anchor_left = 0.0
	_count_label.anchor_top = 1.0
	_count_label.anchor_right = 1.0
	_count_label.anchor_bottom = 1.0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.add_theme_color_override(&"font_color", Color(1.0, 0.98, 0.92, 1.0))
	_count_label.add_theme_color_override(&"font_outline_color", Color(0.12, 0.06, 0.04, 1.0))
	_count_label.clip_text = true
	_count_label.visible = false
	add_child(_count_label)

	# 4-corner Sunnyside selectbox_* selection brackets
	_brackets = Control.new()
	_brackets.name = "SelectBrackets"
	_brackets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brackets.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brackets.visible = false
	add_child(_brackets)

	var corner_specs: Array[Array] = [
		[AP.SELECTBOX_TL, 0.0, 0.0, -2.0, -2.0, 5.0, 6.0],
		[AP.SELECTBOX_TR, 1.0, 0.0, -5.0, -2.0, 2.0, 6.0],
		[AP.SELECTBOX_BL, 0.0, 1.0, -2.0, -6.0, 5.0, 2.0],
		[AP.SELECTBOX_BR, 1.0, 1.0, -5.0, -6.0, 2.0, 2.0],
	]
	for i: int in range(4):
		var sp: Array = corner_specs[i]
		var c_rect: TextureRect = TextureRect.new()
		c_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c_rect.stretch_mode = TextureRect.STRETCH_SCALE
		c_rect.texture = load(sp[0] as String) as Texture2D
		c_rect.anchor_left = sp[1]
		c_rect.anchor_top = sp[2]
		c_rect.anchor_right = sp[1]
		c_rect.anchor_bottom = sp[2]
		c_rect.offset_left = sp[3]
		c_rect.offset_top = sp[4]
		c_rect.offset_right = sp[5]
		c_rect.offset_bottom = sp[6]
		_brackets.add_child(c_rect)

	_apply_layout_metrics()
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)


func _apply_layout_metrics() -> void:
	if not _built:
		return
	var is_hud: bool = _slot_size.x >= 26.0
	if is_hud:
		# Sleek 28x28 HUD slot metrics (rendered at 0.5x scale -> exact 2x crisp physical pixels)
		_icon_rect.offset_left = 5.0
		_icon_rect.offset_top = 5.0
		_icon_rect.offset_right = -5.0
		_icon_rect.offset_bottom = -5.0

		_overlay_rect.offset_left = -12.0
		_overlay_rect.offset_top = 3.0
		_overlay_rect.offset_right = -3.0
		_overlay_rect.offset_bottom = 12.0

		_charge_bar.offset_left = 3.0
		_charge_bar.offset_top = -7.0
		_charge_bar.offset_right = -3.0
		_charge_bar.offset_bottom = -2.5

		_key_badge.position = Vector2(3.0, 3.0)
		_key_badge.size = Vector2(6.0, 6.0)

		_tier_label.add_theme_font_size_override(&"font_size", 7)
		_tier_label.add_theme_constant_override(&"outline_size", 2)
		_tier_label.offset_left = -14.0
		_tier_label.offset_top = 1.5
		_tier_label.offset_right = -2.5
		_tier_label.offset_bottom = 11.5

		_count_label.add_theme_font_size_override(&"font_size", 8)
		_count_label.add_theme_constant_override(&"outline_size", 2)
		_count_label.offset_left = 2.0
		_count_label.offset_top = -12.0
		_count_label.offset_right = -3.0
		_count_label.offset_bottom = -1.5
	else:
		# Compact 20x20 modal backpack/shop/chest slot metrics
		_icon_rect.offset_left = 4.0
		_icon_rect.offset_top = 4.0
		_icon_rect.offset_right = -3.0
		_icon_rect.offset_bottom = -3.0

		_overlay_rect.offset_left = -9.0
		_overlay_rect.offset_top = 2.0
		_overlay_rect.offset_right = -2.0
		_overlay_rect.offset_bottom = 9.0

		_charge_bar.offset_left = 2.0
		_charge_bar.offset_top = -5.5
		_charge_bar.offset_right = -2.0
		_charge_bar.offset_bottom = -1.5

		_key_badge.position = Vector2(2.5, 2.5)
		_key_badge.size = Vector2(4.5, 4.5)

		_tier_label.add_theme_font_size_override(&"font_size", 4)
		_tier_label.add_theme_constant_override(&"outline_size", 1)
		_tier_label.offset_left = -10.0
		_tier_label.offset_top = 1.0
		_tier_label.offset_right = -1.5
		_tier_label.offset_bottom = 7.5

		_count_label.add_theme_font_size_override(&"font_size", 5)
		_count_label.add_theme_constant_override(&"outline_size", 1)
		_count_label.offset_left = 1.0
		_count_label.offset_top = -8.5
		_count_label.offset_right = -2.0
		_count_label.offset_bottom = -1.0


func set_item_display(item: ItemData, count: int, charges: int) -> void:
	_build_if_needed()
	var is_hud: bool = _slot_size.x >= 26.0
	if item == null or count <= 0:
		_icon_rect.texture = null
		_icon_rect.modulate = Color.WHITE
		_overlay_rect.visible = false
		_count_label.visible = false
		_charge_bar.visible = false
		_tier_label.visible = false
		return

	_icon_rect.texture = item.icon
	if item is ToolData:
		var td: ToolData = item as ToolData
		if td.tier == ToolData.ToolTier.COPPER:
			_icon_rect.modulate = Color(1.0, 0.80, 0.56, 1.0)
			_tier_label.text = "Cu"
			_tier_label.add_theme_color_override(&"font_color", Color(1.0, 0.72, 0.36, 1.0))
			_tier_label.visible = true
		elif td.tier == ToolData.ToolTier.IRON:
			_icon_rect.modulate = Color(0.84, 0.94, 1.0, 1.0)
			_tier_label.text = "Fe"
			_tier_label.add_theme_color_override(&"font_color", Color(0.78, 0.92, 1.0, 1.0))
			_tier_label.visible = true
		else:
			_icon_rect.modulate = Color.WHITE
			_tier_label.visible = false
	else:
		_icon_rect.modulate = item.icon_tint
		_tier_label.visible = false

	if item.overlay_icon != null:
		_overlay_rect.texture = item.overlay_icon
		_overlay_rect.visible = true
	else:
		_overlay_rect.visible = false

	if count > 1:
		_count_label.visible = true
		_count_label.text = str(count)
	else:
		_count_label.visible = false

	if item is ToolData and (item as ToolData).has_charges():
		var tool: ToolData = item as ToolData
		var ratio: float = clampf(float(charges) / float(maxi(1, tool.max_charges)), 0.0, 1.0)
		var bar_idx: int = clampi(int(roundf(ratio * float(_bluebar_textures.size() - 1))), 0, _bluebar_textures.size() - 1)
		_charge_bar.texture = _bluebar_textures[bar_idx]
		_charge_bar.visible = true
		# Lift Watering Can icon slightly so the bottom blue fill bar sits cleanly underneath it
		_icon_rect.offset_top = 3.5 if is_hud else 2.5
		_icon_rect.offset_bottom = -7.0 if is_hud else -5.5
	else:
		_charge_bar.visible = false
		_icon_rect.offset_top = 5.0 if is_hud else 4.0
		_icon_rect.offset_bottom = -5.0 if is_hud else -3.0


func set_selected(selected: bool, use_white_bg: bool = false, pickup_highlight: bool = false) -> void:
	_build_if_needed()
	_is_selected = selected
	_is_pickup_source = pickup_highlight
	_brackets.visible = _is_selected or _is_pickup_source or _is_focused
	if _is_pickup_source:
		_bg_box.set_box_style(SunnysideBox.Style.WHITE)
		_brackets.modulate = Color(1.0, 0.92, 0.45, 1.0)
	elif _is_selected and use_white_bg:
		_bg_box.set_box_style(SunnysideBox.Style.WHITE)
		_brackets.modulate = Color.WHITE
	else:
		_bg_box.set_box_style(SunnysideBox.Style.DARK_TAN)
		_brackets.modulate = Color(1.0, 0.94, 0.65, 1.0) if _is_focused else Color.WHITE


func _on_mouse_entered() -> void:
	slot_hovered.emit(slot_index)


func _on_focus_entered() -> void:
	_is_focused = true
	if _brackets != null:
		_brackets.visible = true
		_brackets.modulate = Color(1.0, 0.94, 0.65, 1.0)
	slot_hovered.emit(slot_index)


func _on_focus_exited() -> void:
	_is_focused = false
	if _brackets != null:
		_brackets.visible = _is_selected or _is_pickup_source
		_brackets.modulate = Color(1.0, 0.92, 0.45, 1.0) if _is_pickup_source else Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(slot_index)
			accept_event()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			slot_clicked.emit(slot_index)
			accept_event()
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact"):
		slot_clicked.emit(slot_index)
		accept_event()
