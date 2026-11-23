class_name QuestBoardModal
extends CanvasLayer

## Sunnyside World Bramblebrook Community Board Modal (0.5x virtual canvas = exact 2x px on 1280x720).
## Left column shows today's rotating villager requests (Accept button);
## Right column shows active accepted quests with live inventory progress and turn-in readiness.

const AP := preload("res://scripts/core/asset_paths.gd")
const UiFocus := preload("res://scripts/ui/ui_focus_helper.gd")

signal modal_visibility_changed(is_open: bool)

const UI_SCALE: float = 0.5
const MAX_VISIBLE_CARDS: int = 3

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_MUTED: Color = Color(0.46, 0.34, 0.27, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)
const TEXT_GOLD: Color = Color(1.0, 0.88, 0.42, 1.0)
const TEXT_OK: Color = Color(0.16, 0.52, 0.24, 1.0)
const OUTLINE_DARK: Color = Color(0.18, 0.10, 0.08, 1.0)

var _is_open: bool = false
var _built: bool = false

var _root_ctrl: Control = null
var _subtitle_label: Label = null
var _active_badge_label: Label = null
var _board_list_holder: Control = null
var _active_list_holder: Control = null
var _close_btn: Control = null
var _accept_btns: Array[Control] = []

var _tex_coin: Texture2D = null
var _tex_heart: Texture2D = null
var _tex_alert: Texture2D = null
var _tex_chat: Texture2D = null


func _ready() -> void:
	layer = 23
	_build_ui()
	EventBus.quests_changed.connect(_on_data_changed)
	EventBus.inventory_changed.connect(_on_data_changed)
	set_open(false)


func _exit_tree() -> void:
	if EventBus.quests_changed.is_connected(_on_data_changed):
		EventBus.quests_changed.disconnect(_on_data_changed)
	if EventBus.inventory_changed.is_connected(_on_data_changed):
		EventBus.inventory_changed.disconnect(_on_data_changed)


func is_open() -> bool:
	return _is_open


func set_open(open: bool) -> void:
	_build_ui()
	_is_open = open
	visible = open
	if open:
		refresh_all()
	modal_visibility_changed.emit(_is_open)


func accept_board_quest_by_index(idx: int) -> bool:
	var board: Array[QuestData] = QuestManager.get_board_quests()
	if idx < 0 or idx >= board.size():
		return false
	var q: QuestData = board[idx]
	if QuestManager.accept_quest(q.quest_id):
		AudioManager.play_sfx(&"confirm" if AudioManager.has_sfx(&"confirm") else &"pickup", -6.0, 0.04)
		EventBus.toast_requested.emit("Accepted: %s!" % q.title)
		refresh_all()
		return true
	AudioManager.play_sfx(&"error", -8.0, 0.03)
	EventBus.toast_requested.emit("Active quest log is full!")
	return false


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"toggle_inventory") or event.is_action_pressed(&"ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _on_data_changed() -> void:
	if _is_open:
		refresh_all()


func refresh_all() -> void:
	if not _built:
		return
	var board: Array[QuestData] = QuestManager.get_board_quests()
	var active: Array[QuestData] = QuestManager.get_active_quests()
	_subtitle_label.text = "%s · Daily Villager Requests" % TimeManager.get_formatted_date()
	_active_badge_label.text = "Active: %d / %d" % [active.size(), QuestManager.MAX_ACTIVE_QUESTS]

	# Rebuild Left Column: Today's Posted Requests
	_accept_btns.clear()
	for c: Node in _board_list_holder.get_children():
		c.queue_free()
	if board.is_empty():
		_add_empty_card(_board_list_holder, "All Posted Requests Accepted!", "Check back tomorrow morning for fresh villager requests on the board.")
	else:
		var count: int = mini(board.size(), MAX_VISIBLE_CARDS)
		for i: int in range(count):
			_add_quest_card(_board_list_holder, board[i], i, false)

	# Rebuild Right Column: Active & Ready Quests
	for c: Node in _active_list_holder.get_children():
		c.queue_free()
	if active.is_empty():
		_add_empty_card(_active_list_holder, "No Active Requests Yet", "Select Accept on a posted request, gather the items, then talk to the villager to claim your reward!")
	else:
		var count: int = mini(active.size(), MAX_VISIBLE_CARDS)
		for i: int in range(count):
			_add_quest_card(_active_list_holder, active[i], i, true)

	var focus_ring: Array[Control] = []
	for ab: Control in _accept_btns:
		focus_ring.append(ab)
	if _close_btn != null:
		focus_ring.append(_close_btn)
	UiFocus.wire_vertical_list(focus_ring, true)
	if _is_open and not focus_ring.is_empty():
		focus_ring[0].grab_focus()


func _add_empty_card(holder: Control, heading: String, body: String) -> void:
	var card: SunnysideBox = SunnysideBox.new()
	card.set_box_style(SunnysideBox.Style.WHITE)
	card.position = Vector2(0.0, 0.0)
	card.size = Vector2(204.0, 74.0)
	holder.add_child(card)

	var hl: Label = Label.new()
	hl.text = heading
	hl.position = Vector2(10.0, 10.0)
	hl.size = Vector2(184.0, 14.0)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.add_theme_font_size_override(&"font_size", 9)
	hl.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(hl)

	var bl: Label = Label.new()
	bl.text = body
	bl.position = Vector2(10.0, 28.0)
	bl.size = Vector2(184.0, 38.0)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.add_theme_font_size_override(&"font_size", 8)
	bl.add_theme_color_override(&"font_color", TEXT_MUTED)
	card.add_child(bl)


func _add_quest_card(holder: Control, q: QuestData, idx: int, is_active_card: bool) -> void:
	var prof: NpcData = SocialManager.get_npc(q.npc_id)
	var npc_name: String = prof.display_name if prof != null else String(q.npc_id)
	var preview_item: ItemData = InventoryManager.get_item(q.preview_item_id)
	var have: int = QuestManager.get_quest_progress(q)
	var ready: bool = have >= q.required_count

	var card: SunnysideBox = SunnysideBox.new()
	card.name = "QuestCard_%d" % idx
	card.set_box_style(SunnysideBox.Style.WHITE)
	card.position = Vector2(0.0, float(idx) * 62.0)
	card.size = Vector2(204.0, 58.0)
	holder.add_child(card)

	# Item icon badge on left
	var icon_box: SunnysideBox = SunnysideBox.new()
	icon_box.set_box_style(SunnysideBox.Style.DARK_TAN)
	icon_box.position = Vector2(6.0, 7.0)
	icon_box.size = Vector2(26.0, 26.0)
	card.add_child(icon_box)

	var item_tr: TextureRect = TextureRect.new()
	item_tr.texture = preview_item.icon if preview_item != null else _tex_chat
	item_tr.modulate = preview_item.icon_tint if preview_item != null else Color.WHITE
	item_tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_tr.position = Vector2(4.0, 4.0)
	item_tr.size = Vector2(18.0, 18.0)
	icon_box.add_child(item_tr)

	# Title + Requesting Villager
	var title_l: Label = Label.new()
	title_l.text = q.title
	title_l.position = Vector2(36.0, 5.0)
	title_l.size = Vector2(162.0, 12.0)
	title_l.clip_text = true
	title_l.add_theme_font_size_override(&"font_size", 9)
	title_l.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(title_l)

	var req_l: Label = Label.new()
	req_l.text = "%s wants %d %s (%d/%d)" % [npc_name, q.required_count, q.required_label, mini(have, q.required_count), q.required_count]
	req_l.position = Vector2(36.0, 18.0)
	req_l.size = Vector2(162.0, 12.0)
	req_l.clip_text = true
	req_l.add_theme_font_size_override(&"font_size", 7)
	req_l.add_theme_color_override(&"font_color", TEXT_OK if ready else TEXT_MUTED)
	card.add_child(req_l)

	# Bottom Row: Gold + Friendship Rewards (Left) + Accept / Ready Action Pill (Right)
	var coin_tr: TextureRect = TextureRect.new()
	coin_tr.texture = _tex_coin
	coin_tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_tr.position = Vector2(7.0, 39.0)
	coin_tr.size = Vector2(11.0, 11.0)
	card.add_child(coin_tr)

	var gold_l: Label = Label.new()
	gold_l.text = "%d G" % q.reward_gold
	gold_l.position = Vector2(19.0, 38.0)
	gold_l.size = Vector2(36.0, 13.0)
	gold_l.add_theme_font_size_override(&"font_size", 8)
	gold_l.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(gold_l)

	var heart_tr: TextureRect = TextureRect.new()
	heart_tr.texture = _tex_heart
	heart_tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heart_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart_tr.position = Vector2(56.0, 40.0)
	heart_tr.size = Vector2(9.0, 9.0)
	card.add_child(heart_tr)

	var f_l: Label = Label.new()
	f_l.text = "+%d" % q.reward_friendship
	f_l.position = Vector2(67.0, 38.0)
	f_l.size = Vector2(34.0, 13.0)
	f_l.add_theme_font_size_override(&"font_size", 8)
	f_l.add_theme_color_override(&"font_color", TEXT_DARK)
	card.add_child(f_l)

	if not is_active_card:
		var q_id: StringName = q.quest_id
		var q_title: String = q.title
		var on_accept: Callable = func() -> void:
			if QuestManager.accept_quest(q_id):
				AudioManager.play_sfx(&"pickup", -6.0, 0.04)
				EventBus.toast_requested.emit("Accepted: %s!" % q_title)
				refresh_all()
			else:
				AudioManager.play_sfx(&"error", -8.0, 0.03)
				EventBus.toast_requested.emit("Quest log full!")
		var btn: Control = Control.new()
		btn.name = "AcceptBtn_%d" % idx
		btn.position = Vector2(130.0, 35.0)
		btn.size = Vector2(67.0, 19.0)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				on_accept.call()
				btn.accept_event()
			elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
				on_accept.call()
				btn.accept_event()
		)
		card.add_child(btn)
		UiFocus.make_focusable(btn, on_accept, 5.0, 1.5)
		_accept_btns.append(btn)

		var bg: SunnysideBox = SunnysideBox.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.set_box_style(SunnysideBox.Style.DARK_TAN)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg)

		UiFocus.make_centered_button_content(btn, "Accept", 8, TEXT_GOLD, 6, 3, 4, null, OUTLINE_DARK, 2)
	else:
		var badge: SunnysideBox = SunnysideBox.new()
		badge.set_box_style(SunnysideBox.Style.DARK_TAN)
		badge.position = Vector2(104.0, 36.0)
		badge.size = Vector2(93.0, 17.0)
		card.add_child(badge)

		var st_lbl: Label = Label.new()
		st_lbl.text = "Talk to %s!" % npc_name if ready else "Gathering..."
		st_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		st_lbl.offset_left = 4.0
		st_lbl.offset_right = -4.0
		st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		st_lbl.clip_text = true
		st_lbl.add_theme_font_size_override(&"font_size", 7)
		st_lbl.add_theme_color_override(&"font_color", TEXT_GOLD if ready else TEXT_CREAM)
		st_lbl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
		st_lbl.add_theme_constant_override(&"outline_size", 2)
		badge.add_child(st_lbl)


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var ts_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	var coin_atlas: AtlasTexture = AtlasTexture.new()
	coin_atlas.atlas = ts_tex
	coin_atlas.region = Rect2(AP.TILE_COIN_PILE.x * 16, AP.TILE_COIN_PILE.y * 16, 16, 16)
	_tex_coin = coin_atlas
	_tex_heart = load(AP.UI_EXPRESSION_LOVE) as Texture2D
	_tex_alert = load(AP.UI_EXPRESSION_ALERTED) as Texture2D
	_tex_chat = load(AP.UI_EXPRESSION_CHAT) as Texture2D

	var w_center_tex: Texture2D = load(AP.UI_9SLICE_DIR + "/w_box_9slice_c.png") as Texture2D
	assert(w_center_tex != null, "Missing w_box_9slice_c.png")

	var backdrop: TextureRect = TextureRect.new()
	backdrop.name = "DimBackdrop"
	backdrop.texture = w_center_tex
	backdrop.modulate = Color(0.05, 0.04, 0.08, 0.50)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_root_ctrl = Control.new()
	_root_ctrl.name = "QuestBoardRoot"
	_root_ctrl.anchor_left = 0.0
	_root_ctrl.anchor_top = 0.0
	_root_ctrl.anchor_right = 1.0 / UI_SCALE
	_root_ctrl.anchor_bottom = 1.0 / UI_SCALE
	_root_ctrl.scale = Vector2(UI_SCALE, UI_SCALE)
	_root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root_ctrl)

	# Centered 448x254 Community Board panel in 640x360 virtual space (= 896x508 physical px at 1280x720!)
	var board_box: SunnysideBox = SunnysideBox.new()
	board_box.name = "BoardFrame"
	board_box.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	board_box.anchor_left = 0.5
	board_box.anchor_top = 0.5
	board_box.anchor_right = 0.5
	board_box.anchor_bottom = 0.5
	board_box.offset_left = -224.0
	board_box.offset_top = -127.0
	board_box.offset_right = 224.0
	board_box.offset_bottom = 127.0
	_root_ctrl.add_child(board_box)

	# Header bar
	var header: SunnysideBox = SunnysideBox.new()
	header.set_box_style(SunnysideBox.Style.DARK_TAN)
	header.position = Vector2(8.0, 8.0)
	header.size = Vector2(432.0, 30.0)
	board_box.add_child(header)

	var h_icon: TextureRect = TextureRect.new()
	h_icon.texture = _tex_chat
	h_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h_icon.position = Vector2(8.0, 7.0)
	h_icon.size = Vector2(15.0, 15.0)
	header.add_child(h_icon)

	var title_lbl: Label = Label.new()
	title_lbl.text = "Bramblebrook Community Board"
	title_lbl.position = Vector2(28.0, 3.0)
	title_lbl.size = Vector2(240.0, 14.0)
	title_lbl.add_theme_font_size_override(&"font_size", 11)
	title_lbl.add_theme_color_override(&"font_color", TEXT_GOLD)
	title_lbl.add_theme_color_override(&"font_outline_color", OUTLINE_DARK)
	title_lbl.add_theme_constant_override(&"outline_size", 2)
	header.add_child(title_lbl)

	_subtitle_label = Label.new()
	_subtitle_label.position = Vector2(28.0, 16.0)
	_subtitle_label.size = Vector2(240.0, 11.0)
	_subtitle_label.add_theme_font_size_override(&"font_size", 7)
	_subtitle_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	header.add_child(_subtitle_label)

	_active_badge_label = Label.new()
	_active_badge_label.position = Vector2(304.0, 8.0)
	_active_badge_label.size = Vector2(92.0, 14.0)
	_active_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_active_badge_label.add_theme_font_size_override(&"font_size", 9)
	_active_badge_label.add_theme_color_override(&"font_color", TEXT_CREAM)
	header.add_child(_active_badge_label)

	# Close button
	var close_btn: Control = Control.new()
	close_btn.name = "CloseBoardBtn"
	close_btn.position = Vector2(404.0, 5.0)
	close_btn.size = Vector2(20.0, 20.0)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			set_open(false)
			close_btn.accept_event()
	)
	header.add_child(close_btn)
	UiFocus.make_focusable(close_btn, func() -> void: set_open(false), 5.0, 1.5)
	_close_btn = close_btn

	var c_icon: TextureRect = TextureRect.new()
	c_icon.texture = load(AP.UI_CANCEL) as Texture2D
	c_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	c_icon.offset_left = 3.0
	c_icon.offset_top = 3.0
	c_icon.offset_right = -3.0
	c_icon.offset_bottom = -3.0
	c_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_btn.add_child(c_icon)

	# Left Column Header & Container (Posted Requests)
	var left_hdr: Label = Label.new()
	left_hdr.text = "Posted Today"
	left_hdr.position = Vector2(14.0, 42.0)
	left_hdr.size = Vector2(204.0, 13.0)
	left_hdr.add_theme_font_size_override(&"font_size", 9)
	left_hdr.add_theme_color_override(&"font_color", TEXT_DARK)
	board_box.add_child(left_hdr)

	var left_well: SunnysideBox = SunnysideBox.new()
	left_well.set_box_style(SunnysideBox.Style.DARK_TAN)
	left_well.position = Vector2(10.0, 56.0)
	left_well.size = Vector2(212.0, 190.0)
	board_box.add_child(left_well)

	_board_list_holder = Control.new()
	_board_list_holder.position = Vector2(4.0, 4.0)
	_board_list_holder.size = Vector2(204.0, 182.0)
	left_well.add_child(_board_list_holder)

	# Right Column Header & Container (Active Quests)
	var right_hdr: Label = Label.new()
	right_hdr.text = "Active Quests"
	right_hdr.position = Vector2(230.0, 42.0)
	right_hdr.size = Vector2(204.0, 13.0)
	right_hdr.add_theme_font_size_override(&"font_size", 9)
	right_hdr.add_theme_color_override(&"font_color", TEXT_DARK)
	board_box.add_child(right_hdr)

	var right_well: SunnysideBox = SunnysideBox.new()
	right_well.set_box_style(SunnysideBox.Style.DARK_TAN)
	right_well.position = Vector2(226.0, 56.0)
	right_well.size = Vector2(212.0, 190.0)
	board_box.add_child(right_well)

	_active_list_holder = Control.new()
	_active_list_holder.position = Vector2(4.0, 4.0)
	_active_list_holder.size = Vector2(204.0, 182.0)
	right_well.add_child(_active_list_holder)
