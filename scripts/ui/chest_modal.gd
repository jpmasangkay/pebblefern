class_name ChestModal
extends CanvasLayer

## Interactive 16-slot Storage Chest <-> 24-slot Player Backpack transfer UI.
## Click any backpack slot to deposit into the chest; click any chest slot to withdraw to pack.

const AP := preload("res://scripts/core/asset_paths.gd")
const UiFocus := preload("res://scripts/ui/ui_focus_helper.gd")

signal modal_visibility_changed(is_open: bool)

const TEXT_DARK: Color = Color(0.22, 0.13, 0.10, 1.0)
const TEXT_CREAM: Color = Color(0.98, 0.94, 0.85, 1.0)

var _is_open: bool = false
var _built: bool = false
var _scene_id: StringName = &"farm_sanctuary"
var _chest_cell: Vector2i = Vector2i.ZERO
var _chest_node: PlacedChest = null

var _chest_slots: Array[SunnysideSlot] = []
var _inv_slots: Array[SunnysideSlot] = []
var _close_btn: Control = null


func _ready() -> void:
	layer = 24
	_build_ui()
	EventBus.inventory_changed.connect(_on_inventory_changed)
	visible = false


func _exit_tree() -> void:
	if EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.disconnect(_on_inventory_changed)


func is_open() -> bool:
	return _is_open


func open_chest(p_scene_id: StringName, p_cell: Vector2i, p_chest: PlacedChest = null) -> void:
	_build_ui()
	_scene_id = p_scene_id
	_chest_cell = p_cell
	_chest_node = p_chest
	if _chest_node != null and is_instance_valid(_chest_node):
		_chest_node.set_lid_open(true)
	_is_open = true
	visible = true
	refresh_all()
	if not _inv_slots.is_empty():
		_inv_slots[0].grab_focus()
	modal_visibility_changed.emit(true)


func close_chest() -> void:
	if not _is_open:
		return
	if _chest_node != null and is_instance_valid(_chest_node):
		_chest_node.set_lid_open(false)
	_chest_node = null
	_is_open = false
	visible = false
	modal_visibility_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_inventory"):
		close_chest()
		get_viewport().set_input_as_handled()


func _on_chest_slot_clicked(idx: int) -> void:
	if PlacedChest.withdraw_to_inventory(_scene_id, _chest_cell, idx):
		AudioManager.play_sfx(&"pickup", -6.0, 0.04)
		refresh_all()


func _on_inv_slot_clicked(idx: int) -> void:
	if PlacedChest.deposit_from_inventory_slot(_scene_id, _chest_cell, idx):
		AudioManager.play_sfx(&"place", -6.0, 0.04)
		refresh_all()


func _on_inventory_changed() -> void:
	if _is_open:
		refresh_all()


func refresh_all() -> void:
	if not _built:
		return
	var cslots: Array[Dictionary] = PlacedChest.get_chest_slots(_scene_id, _chest_cell)
	for i: int in range(PlacedChest.CHEST_SLOT_COUNT):
		var id_str: String = String(cslots[i]["id"])
		var itm: ItemData = InventoryManager.get_item(StringName(id_str)) if not id_str.is_empty() else null
		_chest_slots[i].set_item_display(itm, int(cslots[i]["count"]), int(cslots[i]["charges"]))
		_chest_slots[i].set_selected(false, false, false)

	for i: int in range(InventoryManager.SLOT_COUNT):
		var iid: StringName = InventoryManager.get_slot_item_id(i)
		var itm2: ItemData = InventoryManager.get_item(iid) if iid != &"" else null
		_inv_slots[i].set_item_display(itm2, InventoryManager.get_slot_count(i), InventoryManager.get_slot_charges(i))
		_inv_slots[i].set_selected(false, false, false)


func _build_ui() -> void:
	if _built:
		return
	_built = true

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

	var panel: SunnysideBox = SunnysideBox.new()
	panel.set_box_style(SunnysideBox.Style.LIGHT_TAN)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -98.0
	panel.offset_top = -80.0
	panel.offset_right = 98.0
	panel.offset_bottom = 80.0
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(panel)

	var chest_lbl: Label = Label.new()
	chest_lbl.text = "Storage Chest (16 Slots · Click to transfer)"
	chest_lbl.position = Vector2(9.0, 5.0)
	chest_lbl.add_theme_font_size_override(&"font_size", 6)
	chest_lbl.add_theme_color_override(&"font_color", TEXT_DARK)
	panel.add_child(chest_lbl)

	var close_btn: Control = Control.new()
	close_btn.position = Vector2(174.0, 4.0)
	close_btn.size = Vector2(16.0, 14.0)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close_chest()
	)
	panel.add_child(close_btn)
	UiFocus.make_focusable(close_btn, func() -> void: close_chest(), 4.0, 1.5)
	_close_btn = close_btn
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
	cx.position = Vector2(3.0, 2.0)
	cx.size = Vector2(10.0, 10.0)
	close_btn.add_child(cx)

	_chest_slots.clear()
	for i: int in range(PlacedChest.CHEST_SLOT_COUNT):
		var col: int = i % 8
		var row: int = floori(float(i) / 8.0)
		var slot: SunnysideSlot = SunnysideSlot.new()
		slot.configure(i, Vector2(20.0, 20.0), false)
		slot.focus_mode = Control.FOCUS_ALL
		slot.position = Vector2(9.0 + float(col) * 22.0, 18.0 + float(row) * 23.0)
		slot.slot_clicked.connect(_on_chest_slot_clicked)
		panel.add_child(slot)
		_chest_slots.append(slot)

	var pack_lbl: Label = Label.new()
	pack_lbl.text = "Backpack"
	pack_lbl.position = Vector2(9.0, 68.0)
	pack_lbl.add_theme_font_size_override(&"font_size", 6)
	pack_lbl.add_theme_color_override(&"font_color", TEXT_DARK)
	panel.add_child(pack_lbl)

	_inv_slots.clear()
	for i: int in range(InventoryManager.SLOT_COUNT):
		var col: int = i % 8
		var row: int = floori(float(i) / 8.0)
		var slot: SunnysideSlot = SunnysideSlot.new()
		slot.configure(i, Vector2(20.0, 20.0), row == 0)
		slot.focus_mode = Control.FOCUS_ALL
		slot.position = Vector2(9.0 + float(col) * 22.0, 80.0 + float(row) * 24.0)
		slot.slot_clicked.connect(_on_inv_slot_clicked)
		panel.add_child(slot)
		_inv_slots.append(slot)

	var chest_ctrls: Array[Control] = []
	for s: SunnysideSlot in _chest_slots:
		chest_ctrls.append(s)
	var inv_ctrls: Array[Control] = []
	for s: SunnysideSlot in _inv_slots:
		inv_ctrls.append(s)
	UiFocus.wire_grid(chest_ctrls, 8)
	UiFocus.wire_grid(inv_ctrls, 8)
	for col: int in range(8):
		_chest_slots[col].focus_neighbor_top = _chest_slots[col].get_path_to(_close_btn)
		_chest_slots[8 + col].focus_neighbor_bottom = _chest_slots[8 + col].get_path_to(_inv_slots[col])
		_inv_slots[col].focus_neighbor_top = _inv_slots[col].get_path_to(_chest_slots[8 + col])
	_close_btn.focus_neighbor_bottom = _close_btn.get_path_to(_chest_slots[7])
