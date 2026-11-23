class_name DialogueModal
extends CanvasLayer

## Crisp bottom-center Sunnyside World villager dialogue card (0.5x virtual canvas = exact 2x px on 1280x720).
## Displays live animated 3-layer NPC portrait (BOTH arms via tools_idle_strip9), Name & Role,
## 10-Heart friendship row, typewriter dialogue text, and contextual actions (Turn In Quest / Open Shop / Open Forge).

const AP := preload("res://scripts/core/asset_paths.gd")
const InputPromptBadgeScript := preload("res://scripts/ui/input_prompt_badge.gd")
const UiFocusHelperScript := preload("res://scripts/ui/ui_focus_helper.gd")

signal modal_visibility_changed(is_open: bool)
signal festival_action_requested(action_id: StringName)

const UI_SCALE: float = 0.5
const PORTRAIT_FPS: float = 7.5
const PORTRAIT_FRAMES: int = 9
const IDLE_FRAME_W: float = 96.0
# Verified tight non-transparent pixel union across base_idle + tools_idle + all 5 hair strips (9 frames):
# x = 39..56 (18px wide), y = 20..38 (19px tall) — removes excess bottom/side padding with zero hair clipping.
const PORTRAIT_CROP_X: float = 39.0
const PORTRAIT_CROP_Y: float = 20.0
const PORTRAIT_CROP_W: float = 18.0
const PORTRAIT_CROP_H: float = 19.0
const TYPEWRITER_CPS: float = 64.0

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.46, 0.34, 0.27, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_ROSE: Color = Color(0.84, 0.22, 0.34, 1.0)
const TEXT_EMERALD: Color = Color(0.16, 0.52, 0.26, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

var _is_open: bool = false
var _built: bool = false
var _current_npc_id: StringName = &""
var _current_actor: NpcActor = null
var _shop_id_to_open: StringName = &""

var _root_ctrl: Control = null
var _portrait_body_rect: TextureRect = null
var _portrait_hair_rect: TextureRect = null
var _portrait_tool_rect: TextureRect = null
var _portrait_body_atlas: AtlasTexture = null
var _portrait_hair_atlas: AtlasTexture = null
var _portrait_tool_atlas: AtlasTexture = null
var _last_anim_frame: int = -1
var _portrait_badge_label: Label = null
var _name_label: Label = null
var _role_label: Label = null
var _heart_icons: Array[TextureRect] = []
var _speech_label: Label = null
var _status_hint_label: Label = null

var _quest_btn: Control = null
var _quest_btn_label: Label = null
var _shop_btn: Control = null
var _shop_btn_label: Label = null
var _festival_btn: Control = null
var _festival_btn_label: Label = null
var _festival_action_id: StringName = &""
var _next_btn: Control = null
var _next_btn_label: Label = null

var _full_text: String = ""
var _visible_chars_f: float = 0.0
var _anim_time: float = 0.0
var _custom_badge_text: String = ""
var _custom_badge_color: Color = TEXT_CREAM


func _ready() -> void:
	layer = 24
	_build_ui()
	set_open(false)


func _exit_tree() -> void:
	_release_actor()
	if get_viewport() != null and get_viewport().size_changed.is_connected(_apply_safe_area_insets):
		get_viewport().size_changed.disconnect(_apply_safe_area_insets)


func _apply_safe_area_insets() -> void:
	if _root_ctrl == null or get_viewport() == null:
		return
	var win_sz: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var inset_l: float = 0.0
	var inset_r: float = 0.0
	var inset_t: float = 0.0
	var inset_b: float = 0.0
	if win_sz.x > 0 and win_sz.y > 0 and safe.size.x > 0 and safe.size.y > 0:
		var vp_sz: Vector2 = get_viewport().get_visible_rect().size
		var sx: float = (vp_sz.x / float(win_sz.x)) / UI_SCALE
		var sy: float = (vp_sz.y / float(win_sz.y)) / UI_SCALE
		inset_l = clampf(float(maxi(0, safe.position.x)) * sx, 0.0, 28.0)
		inset_t = clampf(float(maxi(0, safe.position.y)) * sy, 0.0, 16.0)
		inset_r = clampf(float(maxi(0, win_sz.x - safe.end.x)) * sx, 0.0, 28.0)
		inset_b = clampf(float(maxi(0, win_sz.y - safe.end.y)) * sy, 0.0, 16.0)
	_root_ctrl.offset_left = inset_l
	_root_ctrl.offset_top = inset_t
	_root_ctrl.offset_right = -inset_r
	_root_ctrl.offset_bottom = -inset_b


func is_open() -> bool:
	return _is_open


func get_current_npc_id() -> StringName:
	return _current_npc_id


func get_speech_text() -> String:
	return _full_text


func open_dialogue(
	npc_id: StringName,
	actor: NpcActor = null,
	override_line: String = "",
	badge_text: String = "",
	badge_color: Color = TEXT_GOLD,
	face_target: Node2D = null
) -> void:
	_build_ui()
	_release_actor()

	var prof: NpcData = SocialManager.get_npc(npc_id)
	assert(prof != null, "DialogueModal cannot open unknown npc_id: %s" % String(npc_id))

	_current_npc_id = npc_id
	_current_actor = actor
	if _current_actor != null and is_instance_valid(_current_actor):
		_current_actor.set_dialogue_paused(true, face_target)

	var line: String = override_line
	if line.is_empty():
		var talk_pts: int = SocialManager.record_talk(npc_id)
		line = SocialManager.get_contextual_dialogue(npc_id, true)
		if talk_pts > 0 and badge_text.is_empty():
			badge_text = "+%d Friends" % talk_pts
			badge_color = TEXT_GOLD

	_custom_badge_text = badge_text
	_custom_badge_color = badge_color
	_load_portrait(prof)
	_set_speech(line)
	_refresh_header_and_buttons(prof)

	_is_open = true
	visible = true
	_focus_default_button()
	modal_visibility_changed.emit(true)


func set_open(open: bool) -> void:
	if not open:
		_release_actor()
		_is_open = false
		visible = false
		_current_npc_id = &""
		modal_visibility_changed.emit(false)


func finish_typewriter() -> void:
	_visible_chars_f = float(_full_text.length())
	if _speech_label != null:
		_speech_label.visible_characters = -1
	_update_next_button_label()


func is_typewriter_finished() -> bool:
	return _visible_chars_f >= float(_full_text.length())


func trigger_turn_in_quest() -> bool:
	if not _is_open or _current_npc_id == &"":
		return false
	var ready_q: QuestData = QuestManager.find_ready_quest_for_npc(_current_npc_id)
	if ready_q == null:
		return false
	var res: Dictionary = QuestManager.turn_in_quest(ready_q.quest_id)
	if not bool(res.get("ok", false)):
		return false

	AudioManager.play_sfx(&"coin", -4.0, 0.03)
	AudioManager.play_sfx(&"harvest", -6.0, 0.03)
	if _current_actor != null and is_instance_valid(_current_actor):
		_current_actor.show_emote(&"love")

	var gold: int = int(res.get("reward_gold", 0))
	var fpts: int = int(res.get("reward_friendship", 0))
	var prof: NpcData = SocialManager.get_npc(_current_npc_id)
	_custom_badge_text = "+%dG · +%d♥" % [gold, fpts]
	_custom_badge_color = TEXT_GOLD
	_set_speech("You brought everything I asked for! Thank you so much — here is %d G for your help!" % gold)
	finish_typewriter()
	if prof != null:
		_refresh_header_and_buttons(prof)
	EventBus.toast_requested.emit("Quest Complete! +%d G & +%d Friendship!" % [gold, fpts])
	return true


func _release_actor() -> void:
	if _current_actor != null and is_instance_valid(_current_actor):
		_current_actor.set_dialogue_paused(false)
	_current_actor = null


func _set_speech(text: String) -> void:
	_full_text = text
	_visible_chars_f = 0.0
	if _speech_label != null:
		_speech_label.text = _full_text
		_speech_label.visible_characters = 0
	_update_next_button_label()


func _update_next_button_label() -> void:
	if _next_btn_label == null:
		return
	_next_btn_label.text = "Close" if is_typewriter_finished() else "Skip"


func _focus_default_button() -> void:
	var vis_btns: Array[Control] = []
	if _quest_btn != null and _quest_btn.visible:
		vis_btns.append(_quest_btn)
	if _shop_btn != null and _shop_btn.visible:
		vis_btns.append(_shop_btn)
	if _festival_btn != null and _festival_btn.visible:
		vis_btns.append(_festival_btn)
	if _next_btn != null and _next_btn.visible:
		vis_btns.append(_next_btn)
	UiFocusHelperScript.wire_horizontal_list(vis_btns, true)
	if _next_btn != null and _next_btn.visible:
		_next_btn.grab_focus()
	elif not vis_btns.is_empty():
		vis_btns[0].grab_focus()


## Returns a tight-cropped AtlasTexture wrapping the visible 18x19 villager pixels of frame `frame_idx`.
static func make_portrait_atlas(sheet: Texture2D, frame_idx: int = 0) -> AtlasTexture:
	assert(sheet != null, "make_portrait_atlas requires non-null sheet texture")
	assert(frame_idx >= 0 and frame_idx < PORTRAIT_FRAMES, "Portrait frame out of range: %d" % frame_idx)
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = sheet
	at.region = get_portrait_crop_rect(frame_idx)
	return at


static func get_portrait_crop_rect(frame_idx: int = 0) -> Rect2:
	var clamped: int = clampi(frame_idx, 0, PORTRAIT_FRAMES - 1)
	return Rect2(
		float(clamped) * IDLE_FRAME_W + PORTRAIT_CROP_X,
		PORTRAIT_CROP_Y,
		PORTRAIT_CROP_W,
		PORTRAIT_CROP_H
	)


func _load_portrait(prof: NpcData) -> void:
	var body_tex: Texture2D = load(AP.NPC_IDLE_BODY) as Texture2D
	var tool_tex: Texture2D = load(AP.NPC_IDLE_TOOLS) as Texture2D
	var hair_path: String = "%s/IDLE/%s_idle_strip9.png" % [AP.HUMAN_ROOT, String(prof.hair_style)]
	var hair_tex: Texture2D = load(hair_path) as Texture2D
	assert(body_tex != null and tool_tex != null and hair_tex != null, "DialogueModal missing portrait strips for %s" % String(prof.npc_id))

	_portrait_body_atlas.atlas = body_tex
	_portrait_hair_atlas.atlas = hair_tex
	_portrait_tool_atlas.atlas = tool_tex
	_portrait_hair_rect.modulate = prof.hair_tint
	_last_anim_frame = -1
	_set_portrait_frame(0)


func _set_portrait_frame(frame_idx: int) -> void:
	if frame_idx == _last_anim_frame:
		return
	_last_anim_frame = frame_idx
	var region: Rect2 = get_portrait_crop_rect(frame_idx)
	_portrait_body_atlas.region = region
	_portrait_hair_atlas.region = region
	_portrait_tool_atlas.region = region


func _refresh_header_and_buttons(prof: NpcData) -> void:
	var hearts: int = SocialManager.get_hearts(prof.npc_id)
	var pts: int = SocialManager.get_points(prof.npc_id)
	_name_label.text = prof.display_name
	_role_label.text = prof.role_title

	for i: int in range(_heart_icons.size()):
		if i < hearts:
			_heart_icons[i].modulate = Color.WHITE
		else:
			_heart_icons[i].modulate = Color(0.45, 0.34, 0.32, 0.35)

	if not _custom_badge_text.is_empty():
		_portrait_badge_label.text = _custom_badge_text
		_portrait_badge_label.add_theme_color_override(&"font_color", _custom_badge_color)
	else:
		_portrait_badge_label.text = "%d/10 ♥ (%d)" % [hearts, pts]
		_portrait_badge_label.add_theme_color_override(&"font_color", TEXT_CREAM)

	# Contextual Turn In Quest button
	var ready_q: QuestData = QuestManager.find_ready_quest_for_npc(prof.npc_id)
	if ready_q != null:
		_quest_btn.visible = true
		_quest_btn_label.text = "Turn In: %s" % ready_q.required_label
	else:
		_quest_btn.visible = false

	# Contextual Shop / Forge shortcut button for Maren & Kaelen
	_shop_id_to_open = prof.shop_id
	if _shop_id_to_open == &"maren_seeds":
		_shop_btn.visible = true
		_shop_btn_label.text = "Open Shop"
	elif _shop_id_to_open == &"kaelen_forge":
		_shop_btn.visible = true
		_shop_btn_label.text = "Open Forge"
	else:
		_shop_btn.visible = false

	# Position shop button neatly beside quest button when both are visible
	_shop_btn.position.x = 122.0 if _quest_btn.visible else 0.0

	# Contextual Bloom Blossom Festival action for Mayor Aldric!
	_festival_action_id = &""
	if prof.npc_id == &"aldric":
		if FestivalManager.is_festival_active:
			_festival_action_id = &"open_showcase"
			_festival_btn.visible = true
			_festival_btn_label.text = "Festival Results" if FestivalManager.showcase_submitted_this_festival else "Harvest Showcase"
		elif FestivalManager.can_start_festival_now():
			_festival_action_id = &"start_festival"
			_festival_btn.visible = true
			_festival_btn_label.text = "Start Festival!"
		else:
			_festival_btn.visible = false
	else:
		_festival_btn.visible = false
	_festival_btn.position.x = 122.0 if _quest_btn.visible else 0.0

	# Subtle status hint when no left buttons are shown
	if (not _quest_btn.visible) and (not _shop_btn.visible) and (not _festival_btn.visible):
		var gifts_wk: int = SocialManager.get_gifts_this_week(prof.npc_id)
		_status_hint_label.visible = true
		_status_hint_label.text = "Gifts this week: %d / %d" % [gifts_wk, SocialManager.MAX_GIFTS_PER_WEEK]
	else:
		_status_hint_label.visible = false


func _process(delta: float) -> void:
	if not _is_open:
		return
	var dt: float = minf(delta, 0.1)
	_anim_time += dt
	var f_idx: int = int(_anim_time * PORTRAIT_FPS) % PORTRAIT_FRAMES
	if _portrait_body_atlas != null:
		_set_portrait_frame(f_idx)

	if not is_typewriter_finished():
		_visible_chars_f = minf(_visible_chars_f + dt * TYPEWRITER_CPS, float(_full_text.length()))
		if _speech_label != null:
			_speech_label.visible_characters = int(_visible_chars_f)
		if is_typewriter_finished():
			_update_next_button_label()


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		_on_next_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_inventory") or event.is_action_pressed(&"ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _on_next_pressed() -> void:
	if not is_typewriter_finished():
		finish_typewriter()
		return
	AudioManager.play_sfx(&"pickup", -12.0, 0.04)
	set_open(false)


func _on_shop_pressed() -> void:
	var target_shop: StringName = _shop_id_to_open
	set_open(false)
	if target_shop != &"":
		EventBus.shop_requested.emit(target_shop)


func _on_festival_pressed() -> void:
	var act: StringName = _festival_action_id
	set_open(false)
	if act != &"":
		festival_action_requested.emit(act)


func _build_ui() -> void:
	if _built:
		return
	_built = true

	_root_ctrl = Control.new()
	_root_ctrl.name = "DialogueRoot"
	_root_ctrl.anchor_left = 0.0
	_root_ctrl.anchor_top = 0.0
	_root_ctrl.anchor_right = 1.0 / UI_SCALE
	_root_ctrl.anchor_bottom = 1.0 / UI_SCALE
	_root_ctrl.scale = Vector2(UI_SCALE, UI_SCALE)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	_root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root_ctrl)
	_apply_safe_area_insets()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_safe_area_insets):
		get_viewport().size_changed.connect(_apply_safe_area_insets)

	# Bottom-center cozy Sunnyside dialogue card (452 x 114 in 640x360 = 904x228 physical px at 1280x720, 20px bottom margin!)
	var card: SunnysideBox = SunnysideBox.new()
	card.name = "DialogueCard"
	card.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	card.anchor_left = 0.5
	card.anchor_top = 1.0
	card.anchor_right = 0.5
	card.anchor_bottom = 1.0
	card.offset_left = -226.0
	card.offset_top = -124.0
	card.offset_right = 226.0
	card.offset_bottom = -10.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ctrl.add_child(card)

	# 1. Left Portrait Box (framed 3-layer animated Sunnyside character with BOTH arms!)
	var portrait_outer: SunnysideBox = SunnysideBox.new()
	portrait_outer.name = "PortraitFrame"
	portrait_outer.set_box_style(SunnysideBox.Style.DARK_TAN)
	portrait_outer.position = Vector2(9.0, 9.0)
	portrait_outer.size = Vector2(84.0, 96.0)
	card.add_child(portrait_outer)

	var portrait_matte: SunnysideBox = SunnysideBox.new()
	portrait_matte.name = "PortraitMatte"
	portrait_matte.set_box_style(SunnysideBox.Style.WHITE)
	portrait_matte.position = Vector2(4.0, 4.0)
	portrait_matte.size = Vector2(76.0, 66.0)
	portrait_outer.add_child(portrait_matte)

	# Dead-centered tight-cropped 18x19 portrait at exact 2.5x virtual (= 5x integer physical px at 1280x720):
	# 15.5px L/R and 9.25px T/B inside 76x66 PortraitMatte -> balanced matte padding above head & below feet!
	var portrait_box: Control = Control.new()
	portrait_box.name = "PortraitBox"
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.position = Vector2(15.5, 9.25)
	portrait_box.size = Vector2(45.0, 47.5)
	portrait_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_matte.add_child(portrait_box)

	_portrait_body_atlas = AtlasTexture.new()
	_portrait_hair_atlas = AtlasTexture.new()
	_portrait_tool_atlas = AtlasTexture.new()

	_portrait_body_rect = _make_portrait_layer_rect("Body", _portrait_body_atlas)
	portrait_box.add_child(_portrait_body_rect)

	_portrait_hair_rect = _make_portrait_layer_rect("Hair", _portrait_hair_atlas)
	portrait_box.add_child(_portrait_hair_rect)

	_portrait_tool_rect = _make_portrait_layer_rect("Tools", _portrait_tool_atlas)
	portrait_box.add_child(_portrait_tool_rect)

	# Vertically centered bottom portrait footer (y=70..93 strictly above the 3px bottom bevel!)
	var footer_margin: MarginContainer = MarginContainer.new()
	footer_margin.name = "PortraitFooterMargin"
	footer_margin.position = Vector2(3.0, 70.0)
	footer_margin.size = Vector2(78.0, 23.0)
	footer_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_margin.add_theme_constant_override(&"margin_left", 4)
	footer_margin.add_theme_constant_override(&"margin_right", 4)
	footer_margin.add_theme_constant_override(&"margin_top", 2)
	footer_margin.add_theme_constant_override(&"margin_bottom", 2)
	portrait_outer.add_child(footer_margin)

	_portrait_badge_label = Label.new()
	_portrait_badge_label.name = "PortraitBadge"
	_portrait_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_badge_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_badge_label.clip_text = true
	_portrait_badge_label.add_theme_font_size_override(&"font_size", 7)
	_portrait_badge_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	_portrait_badge_label.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	_portrait_badge_label.add_theme_constant_override(&"outline_size", 2)
	footer_margin.add_child(_portrait_badge_label)

	# 2. Right Header: Villager Name, Role Title, and 10-Heart Row
	_name_label = Label.new()
	_name_label.name = "NpcNameLabel"
	_name_label.position = Vector2(101.0, 8.0)
	_name_label.size = Vector2(120.0, 14.0)
	_name_label.clip_text = true
	_name_label.add_theme_font_size_override(&"font_size", 11)
	_name_label.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(_name_label)

	_role_label = Label.new()
	_role_label.name = "NpcRoleLabel"
	_role_label.position = Vector2(101.0, 21.0)
	_role_label.size = Vector2(210.0, 11.0)
	_role_label.clip_text = true
	_role_label.add_theme_font_size_override(&"font_size", 7)
	_role_label.add_theme_color_override(&"font_color", TEXT_MUTED)
	card.add_child(_role_label)

	var heart_tex: Texture2D = load(AP.UI_EXPRESSION_LOVE) as Texture2D
	assert(heart_tex != null, "Missing expression_love.png")
	_heart_icons.clear()
	for h: int in range(SocialManager.MAX_HEARTS):
		var htr: TextureRect = TextureRect.new()
		htr.name = "Heart_%d" % h
		htr.texture = heart_tex
		htr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		htr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		htr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		htr.position = Vector2(325.0 + float(h) * 12.0, 11.0)
		htr.size = Vector2(10.0, 10.0)
		card.add_child(htr)
		_heart_icons.append(htr)

	# 3. Dialogue Speech Paper (SunnysideBox.Style.WHITE with balanced inner MarginContainer padding)
	var speech_box: SunnysideBox = SunnysideBox.new()
	speech_box.name = "SpeechPaper"
	speech_box.set_box_style(SunnysideBox.Style.WHITE)
	speech_box.position = Vector2(100.0, 34.0)
	speech_box.size = Vector2(343.0, 45.0)
	card.add_child(speech_box)

	var speech_margin: MarginContainer = MarginContainer.new()
	speech_margin.name = "SpeechMargin"
	speech_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	speech_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_margin.add_theme_constant_override(&"margin_left", 9)
	speech_margin.add_theme_constant_override(&"margin_right", 9)
	speech_margin.add_theme_constant_override(&"margin_top", 6)
	speech_margin.add_theme_constant_override(&"margin_bottom", 6)
	speech_box.add_child(speech_margin)

	_speech_label = Label.new()
	_speech_label.name = "SpeechLabel"
	_speech_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speech_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_label.clip_text = true
	_speech_label.add_theme_font_size_override(&"font_size", 9)
	_speech_label.add_theme_color_override(&"font_color", TEXT_DARK)
	speech_margin.add_child(_speech_label)

	# 4. Bottom Action Bar (Turn In Quest, Open Shop/Forge, Close [E] — all with centered MarginContainer -> HBoxContainer!)
	var bar: Control = Control.new()
	bar.name = "ActionBar"
	bar.position = Vector2(100.0, 83.0)
	bar.size = Vector2(343.0, 22.0)
	card.add_child(bar)

	_status_hint_label = Label.new()
	_status_hint_label.name = "StatusHint"
	_status_hint_label.position = Vector2(2.0, 4.0)
	_status_hint_label.size = Vector2(180.0, 14.0)
	_status_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_hint_label.add_theme_font_size_override(&"font_size", 8)
	_status_hint_label.add_theme_color_override(&"font_color", TEXT_MUTED)
	bar.add_child(_status_hint_label)

	_quest_btn = _make_action_button("TurnInBtn", Vector2(0.0, 0.0), Vector2(116.0, 22.0), "Turn In Quest!", TEXT_GOLD, func() -> void: trigger_turn_in_quest())
	_quest_btn_label = _quest_btn.find_child("BtnLabel", true, false) as Label
	_quest_btn.visible = false
	bar.add_child(_quest_btn)

	_shop_btn = _make_action_button("ShopBtn", Vector2(0.0, 0.0), Vector2(92.0, 22.0), "Open Shop", TEXT_CREAM, _on_shop_pressed)
	_shop_btn_label = _shop_btn.find_child("BtnLabel", true, false) as Label
	_shop_btn.visible = false
	bar.add_child(_shop_btn)

	_festival_btn = _make_action_button("FestivalBtn", Vector2(0.0, 0.0), Vector2(118.0, 22.0), "Harvest Showcase", TEXT_GOLD, _on_festival_pressed)
	_festival_btn_label = _festival_btn.find_child("BtnLabel", true, false) as Label
	_festival_btn.visible = false
	bar.add_child(_festival_btn)

	var next_badge: InputPromptBadgeScript = InputPromptBadgeScript.new()
	next_badge.name = "NextPromptBadge"
	next_badge.configure(&"interact", Vector2(10.0, 10.0), true, false, false)
	_next_btn = _make_action_button("NextBtn", Vector2(251.0, 0.0), Vector2(92.0, 22.0), "Close", TEXT_CREAM, _on_next_pressed, next_badge)
	_next_btn_label = _next_btn.find_child("BtnLabel", true, false) as Label
	bar.add_child(_next_btn)


func _make_portrait_layer_rect(layer_name: String, atlas_tex: AtlasTexture) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.name = layer_name
	tr.texture = atlas_tex
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	return tr


func _make_action_button(
	btn_name: String,
	pos: Vector2,
	sz: Vector2,
	text: String,
	color: Color,
	on_click: Callable,
	leading_icon: Control = null
) -> Control:
	var btn: Control = Control.new()
	btn.name = btn_name
	btn.position = pos
	btn.size = sz
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_click.call()
			btn.accept_event()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			on_click.call()
			btn.accept_event()
	)
	UiFocusHelperScript.make_focusable(btn, on_click, 5.0, 1.5)
	var bg: SunnysideBox = SunnysideBox.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_box_style(SunnysideBox.Style.DARK_TAN)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)

	# Uniform 12px L/R, 6px T/B physical padding (= 6 L/R, 3 T/B in 0.5x UI space) + 8px (= 4) icon/text separation!
	UiFocusHelperScript.make_centered_button_content(
		btn,
		text,
		8,
		color,
		6,
		3,
		4,
		leading_icon,
		OUTLINE_DARK,
		2
	)
	return btn
