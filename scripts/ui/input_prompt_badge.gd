class_name InputPromptBadge
extends TextureRect

## Reusable live-updating Vryell pixel-art control prompt badge (scenes/ui/input_prompt_badge.tscn).
## Listens to EventBus.input_mode_changed and automatically displays the tight-cropped Vryell icon
## for Keyboard/Mouse, Xbox, PlayStation, or Nintendo Switch (or hides cleanly on Touch when configured).
## Always keeps exact aspect ratio, centered vertically & horizontally inside HBox/Button containers.

const ControlIconsScript := preload("res://scripts/core/control_icons.gd")
const DEFAULT_BADGE_SIZE: Vector2 = Vector2(10.0, 10.0) # 20x20 physical px on 0.5x UI canvas

@export var action_name: StringName = &"interact":
	set(value):
		action_name = value
		if _initialized:
			refresh_icon()
@export var hide_on_touch: bool = true:
	set(value):
		hide_on_touch = value
		if _initialized:
			refresh_icon()
@export var gamepad_only: bool = false:
	set(value):
		gamepad_only = value
		if _initialized:
			refresh_icon()
@export var keyboard_only: bool = false:
	set(value):
		keyboard_only = value
		if _initialized:
			refresh_icon()

var _base_size: Vector2 = DEFAULT_BADGE_SIZE
var _allow_wide_aspect: bool = true
var _initialized: bool = false


func _ready() -> void:
	_apply_rect_flags()
	if custom_minimum_size.x > 0.0 and custom_minimum_size.y > 0.0 and not _initialized:
		_base_size = custom_minimum_size
	_initialized = true
	if not EventBus.input_mode_changed.is_connected(_on_input_mode_changed):
		EventBus.input_mode_changed.connect(_on_input_mode_changed)
	refresh_icon()


func _exit_tree() -> void:
	if EventBus.input_mode_changed.is_connected(_on_input_mode_changed):
		EventBus.input_mode_changed.disconnect(_on_input_mode_changed)


func _apply_rect_flags() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(
	p_action: StringName,
	badge_size: Vector2 = DEFAULT_BADGE_SIZE,
	p_hide_on_touch: bool = true,
	p_gamepad_only: bool = false,
	p_keyboard_only: bool = false,
	p_allow_wide_aspect: bool = true
) -> void:
	assert(badge_size.x > 0.0 and badge_size.y > 0.0, "InputPromptBadge requires positive badge_size")
	# Set expand_mode BEFORE assigning texture so TextureRect never clamps size back to raw atlas pixels!
	_initialized = false
	_apply_rect_flags()
	_base_size = badge_size
	_allow_wide_aspect = p_allow_wide_aspect
	action_name = p_action
	hide_on_touch = p_hide_on_touch
	gamepad_only = p_gamepad_only
	keyboard_only = p_keyboard_only
	custom_minimum_size = _base_size
	size = _base_size
	_initialized = true
	refresh_icon()


func _on_input_mode_changed(_mode: int, _family: int) -> void:
	refresh_icon()


func refresh_icon() -> void:
	_apply_rect_flags()
	var mode: int = InputModeManager.current_mode
	var fam: int = InputModeManager.get_effective_gamepad_family()

	if gamepad_only and mode != InputModeManager.InputMode.GAMEPAD:
		visible = false
		return
	if keyboard_only and mode != InputModeManager.InputMode.KEYBOARD_MOUSE:
		visible = false
		return
	if hide_on_touch and mode == InputModeManager.InputMode.TOUCH:
		visible = false
		return

	var tex: AtlasTexture = ControlIconsScript.get_action_texture(action_name, mode, fam, hide_on_touch)
	texture = tex
	visible = (tex != null)
	if tex == null:
		return

	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var target_sz: Vector2 = _base_size
	# Snap standard 10px/11px tall keycaps to exact integer 1:1 virtual scale (2x crisp physical px) when requested at ~10.0!
	if absf(_base_size.y - 10.0) <= 0.5 and th >= 10.0 and th <= 11.0:
		target_sz = Vector2(th, th)
	# Wide keys (Tab, Space, Esc, LB/RB, L1/R1) expand horizontally cleanly to preserve height without vertical stretching
	if _allow_wide_aspect and tw > th + 1.0:
		var wide_w: float = maxf(target_sz.y * (tw / maxf(1.0, th)), _base_size.x * 1.4)
		target_sz = Vector2(minf(ceilf(wide_w), _base_size.x * 1.8), target_sz.y)

	custom_minimum_size = target_sz
	size = target_sz
