class_name UiFocusHelper
extends RefCounted

## Pure UI helper that attaches crisp Sunnyside 4-corner selection brackets (selectbox_tl/tr/bl/br)
## to any interactive Control so Gamepad/Keyboard focus navigation is unmistakable across every modal,
## and maps ui_accept (A / Cross / Enter / Space) cleanly onto each button's click callback.

const AP := preload("res://scripts/core/asset_paths.gd")

static var _corner_textures: Array[Texture2D] = []


static func clear_cache() -> void:
	_corner_textures.clear()


static func _ensure_corners() -> void:
	if not _corner_textures.is_empty():
		return
	var paths: PackedStringArray = [AP.SELECTBOX_TL, AP.SELECTBOX_TR, AP.SELECTBOX_BL, AP.SELECTBOX_BR]
	for p: String in paths:
		var t: Texture2D = load(p) as Texture2D
		assert(t != null, "UiFocusHelper missing Sunnyside selectbox PNG: %s" % p)
		_corner_textures.append(t)


static func make_focusable(ctrl: Control, on_activate: Callable, corner_size: float = 5.0, outset: float = 1.5) -> void:
	assert(ctrl != null, "UiFocusHelper.make_focusable requires non-null Control.")
	_ensure_corners()
	ctrl.focus_mode = Control.FOCUS_ALL

	var frame: Control = ctrl.get_node_or_null("SunnysideFocusFrame") as Control
	if frame == null:
		frame = Control.new()
		frame.name = "SunnysideFocusFrame"
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.offset_left = -outset
		frame.offset_top = -outset
		frame.offset_right = outset
		frame.offset_bottom = outset
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.z_index = 6
		frame.visible = false
		ctrl.add_child(frame)

		# 4 crisp Sunnyside selection brackets pinned to corners
		var tl: TextureRect = _make_corner("TL", _corner_textures[0], corner_size)
		tl.anchor_left = 0.0; tl.anchor_top = 0.0; tl.anchor_right = 0.0; tl.anchor_bottom = 0.0
		tl.offset_right = corner_size; tl.offset_bottom = corner_size
		frame.add_child(tl)

		var tr: TextureRect = _make_corner("TR", _corner_textures[1], corner_size)
		tr.anchor_left = 1.0; tr.anchor_top = 0.0; tr.anchor_right = 1.0; tr.anchor_bottom = 0.0
		tr.offset_left = -corner_size; tr.offset_bottom = corner_size
		frame.add_child(tr)

		var bl: TextureRect = _make_corner("BL", _corner_textures[2], corner_size)
		bl.anchor_left = 0.0; bl.anchor_top = 1.0; bl.anchor_right = 0.0; bl.anchor_bottom = 1.0
		bl.offset_top = -corner_size; bl.offset_right = corner_size
		frame.add_child(bl)

		var br: TextureRect = _make_corner("BR", _corner_textures[3], corner_size)
		br.anchor_left = 1.0; br.anchor_top = 1.0; br.anchor_right = 1.0; br.anchor_bottom = 1.0
		br.offset_left = -corner_size; br.offset_top = -corner_size
		frame.add_child(br)

		ctrl.focus_entered.connect(func() -> void:
			if is_instance_valid(frame):
				frame.visible = true
		)
		ctrl.focus_exited.connect(func() -> void:
			if is_instance_valid(frame):
				frame.visible = false
		)

	if on_activate.is_valid():
		ctrl.gui_input.connect(func(ev: InputEvent) -> void:
			if ev.is_action_pressed(&"ui_accept") or ev.is_action_pressed(&"interact"):
				on_activate.call()
				ctrl.accept_event()
		)


static func _make_corner(cname: String, tex: Texture2D, sz: float) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.name = cname
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.custom_minimum_size = Vector2(sz, sz)
	return tr


static func make_centered_button_content(
	parent: Control,
	text_str: String,
	font_size: int,
	font_color: Color,
	pad_x: int,
	pad_y: int,
	separation: int,
	leading_node: Control = null,
	outline_color: Color = Color(0.18, 0.10, 0.08, 1.0),
	outline_size: int = 0
) -> Dictionary:
	assert(parent != null, "make_centered_button_content requires non-null parent Control.")
	var mc: MarginContainer = MarginContainer.new()
	mc.name = "ContentMargin"
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_theme_constant_override(&"margin_left", pad_x)
	mc.add_theme_constant_override(&"margin_right", pad_x)
	mc.add_theme_constant_override(&"margin_top", pad_y)
	mc.add_theme_constant_override(&"margin_bottom", pad_y)
	parent.add_child(mc)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "ContentHBox"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override(&"separation", separation)
	mc.add_child(hbox)

	if leading_node != null:
		leading_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		leading_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		leading_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(leading_node)

	var lbl: Label = Label.new()
	lbl.name = "BtnLabel"
	lbl.text = text_str
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.add_theme_font_size_override(&"font_size", font_size)
	lbl.add_theme_color_override(&"font_color", font_color)
	if outline_size > 0:
		lbl.add_theme_color_override(&"font_outline_color", outline_color)
		lbl.add_theme_constant_override(&"outline_size", outline_size)
	hbox.add_child(lbl)

	return {
		"margin": mc,
		"hbox": hbox,
		"label": lbl,
		"icon": leading_node,
	}


static func make_icon_rect(tex: Texture2D, icon_size: Vector2, node_name: String = "BtnIcon") -> TextureRect:
	assert(icon_size.x > 0.0 and icon_size.y > 0.0, "make_icon_rect requires positive icon_size.")
	var tr: TextureRect = TextureRect.new()
	tr.name = node_name
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.custom_minimum_size = icon_size
	tr.size = icon_size
	tr.texture = tex
	return tr


static func wire_vertical_list(controls: Array[Control], wrap: bool = true) -> void:
	var n: int = controls.size()
	if n == 0:
		return
	for i: int in range(n):
		var cur: Control = controls[i]
		if cur == null:
			continue
		var prev_idx: int = (i - 1 + n) % n if wrap else maxi(0, i - 1)
		var next_idx: int = (i + 1) % n if wrap else mini(n - 1, i + 1)
		cur.focus_neighbor_top = cur.get_path_to(controls[prev_idx])
		cur.focus_neighbor_bottom = cur.get_path_to(controls[next_idx])


static func wire_horizontal_list(controls: Array[Control], wrap: bool = true) -> void:
	var n: int = controls.size()
	if n == 0:
		return
	for i: int in range(n):
		var cur: Control = controls[i]
		if cur == null:
			continue
		var prev_idx: int = (i - 1 + n) % n if wrap else maxi(0, i - 1)
		var next_idx: int = (i + 1) % n if wrap else mini(n - 1, i + 1)
		cur.focus_neighbor_left = cur.get_path_to(controls[prev_idx])
		cur.focus_neighbor_right = cur.get_path_to(controls[next_idx])


static func wire_grid(controls: Array[Control], cols: int) -> void:
	var n: int = controls.size()
	if n == 0 or cols <= 0:
		return
	for i: int in range(n):
		var cur: Control = controls[i]
		if cur == null:
			continue
		var col: int = i % cols
		var row: int = floori(float(i) / float(cols))
		var left_i: int = row * cols + (col - 1) if col > 0 else i
		var right_i: int = row * cols + (col + 1) if (col + 1 < cols and row * cols + col + 1 < n) else i
		var up_i: int = i - cols if i >= cols else i
		var down_i: int = i + cols if i + cols < n else i
		cur.focus_neighbor_left = cur.get_path_to(controls[left_i])
		cur.focus_neighbor_right = cur.get_path_to(controls[right_i])
		cur.focus_neighbor_top = cur.get_path_to(controls[up_i])
		cur.focus_neighbor_bottom = cur.get_path_to(controls[down_i])
