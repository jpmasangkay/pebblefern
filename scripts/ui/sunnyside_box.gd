@tool
class_name SunnysideBox
extends Control

## Zero-procedural-art 9-slice UI panel built directly from Sunnyside World's real 3x3 PNGs
## under UI/9slice_box_white/ (dt = Dark Tan, lt = Light Tan, w = White).

const AP := preload("res://scripts/core/asset_paths.gd")

enum Style {
	DARK_TAN = 0,
	LIGHT_TAN = 1,
	WHITE = 2,
}

const BORDER: float = 3.0
const PARTS: PackedStringArray = ["tl", "tc", "tr", "lc", "c", "rc", "bl", "bc", "br"]

static var _tex_cache: Dictionary = {} # String -> Texture2D

@export var box_style: Style = Style.LIGHT_TAN:
	set(value):
		box_style = value
		_apply_style_textures()

var _slices: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_slices()
	_apply_style_textures()


func set_box_style(new_style: Style) -> void:
	box_style = new_style
	_ensure_slices()
	_apply_style_textures()


func _ensure_slices() -> void:
	if _slices.size() == 9:
		return
	_slices.clear()
	for child: Node in get_children():
		if child.name.begins_with("_Slice_"):
			child.queue_free()

	# [anchor_l, anchor_t, anchor_r, anchor_b, off_l, off_t, off_r, off_b]
	var rects: Array[Array] = [
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, BORDER, BORDER],            # tl
		[0.0, 0.0, 1.0, 0.0, BORDER, 0.0, -BORDER, BORDER],        # tc
		[1.0, 0.0, 1.0, 0.0, -BORDER, 0.0, 0.0, BORDER],           # tr
		[0.0, 0.0, 0.0, 1.0, 0.0, BORDER, BORDER, -BORDER],        # lc
		[0.0, 0.0, 1.0, 1.0, BORDER, BORDER, -BORDER, -BORDER],    # c
		[1.0, 0.0, 1.0, 1.0, -BORDER, BORDER, 0.0, -BORDER],       # rc
		[0.0, 1.0, 0.0, 1.0, 0.0, -BORDER, BORDER, 0.0],           # bl
		[0.0, 1.0, 1.0, 1.0, BORDER, -BORDER, -BORDER, 0.0],       # bc
		[1.0, 1.0, 1.0, 1.0, -BORDER, -BORDER, 0.0, 0.0],          # br
	]

	for i: int in range(9):
		var slice_rect: TextureRect = TextureRect.new()
		slice_rect.name = "_Slice_%s" % PARTS[i]
		slice_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slice_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slice_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slice_rect.stretch_mode = TextureRect.STRETCH_SCALE
		var r: Array = rects[i]
		slice_rect.anchor_left = r[0]
		slice_rect.anchor_top = r[1]
		slice_rect.anchor_right = r[2]
		slice_rect.anchor_bottom = r[3]
		slice_rect.offset_left = r[4]
		slice_rect.offset_top = r[5]
		slice_rect.offset_right = r[6]
		slice_rect.offset_bottom = r[7]
		add_child(slice_rect)
		_slices.append(slice_rect)


func _apply_style_textures() -> void:
	if _slices.size() != 9:
		return
	var prefix: String = "lt"
	if box_style == Style.DARK_TAN:
		prefix = "dt"
	elif box_style == Style.WHITE:
		prefix = "w"

	for i: int in range(9):
		var path: String = "%s/%s_box_9slice_%s.png" % [AP.UI_9SLICE_DIR, prefix, PARTS[i]]
		var tex: Texture2D = _tex_cache.get(path, null) as Texture2D
		if tex == null:
			tex = load(path) as Texture2D
			assert(tex != null, "Missing Sunnyside 9-slice PNG: %s" % path)
			_tex_cache[path] = tex
		_slices[i].texture = tex
