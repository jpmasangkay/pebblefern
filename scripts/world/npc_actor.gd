class_name NpcActor
extends CharacterBody2D

## Living 3-layer Sunnyside World NPC actor (base + hair + tools foreground arm).
## Supports 9-frame IDLE and 8-frame WALKING strips (BOTH arms always visible & frame-locked!),
## TimeManager-driven daily schedules along road/bridge/ladder waypoints, floating Sunnyside emotes,
## quest-ready overhead badges, and smooth pause-to-face-player dialogue interaction.

const AP := preload("res://scripts/core/asset_paths.gd")

enum ScheduleSlot {
	HOME_MORNING = 0,
	WORK_POST = 1,
	PLAZA_EVENING = 2,
	HOME_NIGHT = 3,
}

const IDLE_FPS: float = 7.5
const IDLE_FRAMES: int = 9
const WALK_FPS: float = 9.0
const WALK_FRAMES: int = 8
const WALK_SPEED: float = 44.0
const ARRIVAL_DIST_PX: float = 3.0
const MAX_PATH_POINTS: int = 16
const TILE_SIZE: float = 16.0

@export var npc_id: StringName = &"villager"
@export var display_name: String = "Villager"
@export var hair_style: StringName = &"shorthair"
@export var hair_tint: Color = Color.WHITE
@export var default_facing_left: bool = false
@export var interact_enabled: bool = true
@export var add_feet_collider: bool = true
@export var greeting_lines: PackedStringArray = PackedStringArray([
	"Lovely morning across Pebblefern Island!",
])

var _body_spr: Sprite2D = null
var _hair_spr: Sprite2D = null
var _tool_spr: Sprite2D = null
var _interact_area: Area2D = null
var _emote_spr: Sprite2D = null
var _quest_badge: Sprite2D = null
var _emote_tween: Tween = null

var _idle_body_tex: Texture2D = null
var _idle_hair_tex: Texture2D = null
var _idle_tool_tex: Texture2D = null
var _walk_body_tex: Texture2D = null
var _walk_hair_tex: Texture2D = null
var _walk_tool_tex: Texture2D = null

var _player_nearby: bool = false
var _player_ref: Node2D = null
var _in_dialogue: bool = false
var _is_walking: bool = false
var _facing_left: bool = false
var _anim_time: float = 0.0
var _badge_bob_time: float = 0.0

# Daily schedule waypoints & active path queue
var _has_schedule: bool = false
var _wp_home: Vector2 = Vector2.ZERO
var _wp_work: Vector2 = Vector2.ZERO
var _wp_plaza: Vector2 = Vector2.ZERO
var _home_z_index: int = 0
var _current_slot: int = ScheduleSlot.WORK_POST
var _path_queue: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _festival_mode: bool = false


func _ready() -> void:
	add_to_group(&"npcs")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0
	_facing_left = default_facing_left

	# Pull authoritative hair style & silver/character tint from SocialManager profile
	# so updates to NpcData resources apply consistently in world, interiors, and UI.
	var social_prof: NpcData = SocialManager.get_npc(npc_id)
	if social_prof != null:
		hair_style = social_prof.hair_style
		hair_tint = social_prof.hair_tint
		display_name = social_prof.display_name

	# Maren starts nested inside MarketStall; detach transform cleanly into world space
	# so she walks freely on her daily schedule while preserving behind-counter z-layering at work!
	if npc_id == &"maren":
		var init_world: Vector2 = global_position
		_home_z_index = z_index
		top_level = true
		global_position = init_world
		interact_enabled = true

	_ensure_visuals_and_nodes()
	_preload_strips()
	_apply_strip_visuals(false)
	_resolve_schedule_waypoints()
	if _has_schedule:
		snap_to_schedule(TimeManager.get_hour_float())
	_refresh_quest_badge()

	if not EventBus.quests_changed.is_connected(_refresh_quest_badge):
		EventBus.quests_changed.connect(_refresh_quest_badge)
	if not EventBus.inventory_changed.is_connected(_refresh_quest_badge):
		EventBus.inventory_changed.connect(_refresh_quest_badge)


func _exit_tree() -> void:
	if _emote_tween != null and _emote_tween.is_valid():
		_emote_tween.kill()
	if EventBus.quests_changed.is_connected(_refresh_quest_badge):
		EventBus.quests_changed.disconnect(_refresh_quest_badge)
	if EventBus.inventory_changed.is_connected(_refresh_quest_badge):
		EventBus.inventory_changed.disconnect(_refresh_quest_badge)


func _ensure_visuals_and_nodes() -> void:
	_body_spr = get_node_or_null("Visuals/BodySprite") as Sprite2D
	_hair_spr = get_node_or_null("Visuals/HairSprite") as Sprite2D
	_tool_spr = get_node_or_null("Visuals/ToolSprite") as Sprite2D
	if _body_spr == null:
		_body_spr = get_node_or_null("BodySprite") as Sprite2D
		_hair_spr = get_node_or_null("HairSprite") as Sprite2D
		_tool_spr = get_node_or_null("ToolSprite") as Sprite2D
	if _body_spr == null:
		var visuals: Node2D = Node2D.new()
		visuals.name = "Visuals"
		add_child(visuals)

		_body_spr = Sprite2D.new()
		_body_spr.name = "BodySprite"
		_body_spr.hframes = IDLE_FRAMES
		_body_spr.vframes = 1
		_body_spr.offset = Vector2(0.0, -6.0)
		visuals.add_child(_body_spr)

		_hair_spr = Sprite2D.new()
		_hair_spr.name = "HairSprite"
		_hair_spr.hframes = IDLE_FRAMES
		_hair_spr.vframes = 1
		_hair_spr.offset = Vector2(0.0, -6.0)
		visuals.add_child(_hair_spr)

		_tool_spr = Sprite2D.new()
		_tool_spr.name = "ToolSprite"
		_tool_spr.hframes = IDLE_FRAMES
		_tool_spr.vframes = 1
		_tool_spr.offset = Vector2(0.0, -6.0)
		visuals.add_child(_tool_spr)

	# Floating Sunnyside emote bubble (expression_love / happiness_04 / expression_confused / expression_chat)
	_emote_spr = get_node_or_null("EmoteSprite") as Sprite2D
	if _emote_spr == null:
		_emote_spr = Sprite2D.new()
		_emote_spr.name = "EmoteSprite"
		_emote_spr.position = Vector2(0.0, -25.0)
		_emote_spr.z_index = 10
		_emote_spr.visible = false
		add_child(_emote_spr)

	# Quest turn-in ready badge (Sunnyside expression_alerted.png)
	_quest_badge = get_node_or_null("QuestReadyBadge") as Sprite2D
	if _quest_badge == null:
		_quest_badge = Sprite2D.new()
		_quest_badge.name = "QuestReadyBadge"
		_quest_badge.texture = load(AP.UI_EXPRESSION_ALERTED) as Texture2D
		_quest_badge.position = Vector2(0.0, -24.0)
		_quest_badge.z_index = 9
		_quest_badge.visible = false
		add_child(_quest_badge)

	if add_feet_collider and get_node_or_null("FeetCollider") == null:
		var cs: CollisionShape2D = CollisionShape2D.new()
		cs.name = "FeetCollider"
		var circ: CircleShape2D = CircleShape2D.new()
		circ.radius = 5.0
		cs.shape = circ
		add_child(cs)

	_interact_area = get_node_or_null("InteractArea") as Area2D
	if _interact_area == null and interact_enabled:
		_interact_area = Area2D.new()
		_interact_area.name = "InteractArea"
		_interact_area.collision_layer = 8
		_interact_area.collision_mask = 4
		_interact_area.monitoring = true
		_interact_area.monitorable = true
		add_child(_interact_area)
		var ics: CollisionShape2D = CollisionShape2D.new()
		ics.name = "InteractShape"
		var irect: CircleShape2D = CircleShape2D.new()
		irect.radius = 22.0
		ics.shape = irect
		_interact_area.add_child(ics)

	if _interact_area != null:
		if not _interact_area.body_entered.is_connected(_on_body_entered):
			_interact_area.body_entered.connect(_on_body_entered)
		if not _interact_area.body_exited.is_connected(_on_body_exited):
			_interact_area.body_exited.connect(_on_body_exited)


func _preload_strips() -> void:
	_idle_body_tex = load(AP.NPC_IDLE_BODY) as Texture2D
	_idle_tool_tex = load(AP.NPC_IDLE_TOOLS) as Texture2D
	var idle_hair_path: String = "%s/IDLE/%s_idle_strip9.png" % [AP.HUMAN_ROOT, String(hair_style)]
	_idle_hair_tex = load(idle_hair_path) as Texture2D

	_walk_body_tex = load(AP.NPC_WALK_BODY) as Texture2D
	_walk_tool_tex = load(AP.NPC_WALK_TOOLS) as Texture2D
	var walk_hair_path: String = "%s/WALKING/%s_walk_strip8.png" % [AP.HUMAN_ROOT, String(hair_style)]
	_walk_hair_tex = load(walk_hair_path) as Texture2D

	assert(_idle_body_tex != null and _idle_tool_tex != null and _idle_hair_tex != null, "NpcActor '%s' missing IDLE strips." % String(npc_id))
	assert(_walk_body_tex != null and _walk_tool_tex != null and _walk_hair_tex != null, "NpcActor '%s' missing WALKING strips." % String(npc_id))


func _apply_strip_visuals(walking: bool) -> void:
	_is_walking = walking
	var frames: int = WALK_FRAMES if walking else IDLE_FRAMES
	_body_spr.texture = _walk_body_tex if walking else _idle_body_tex
	_body_spr.modulate = Color.WHITE
	_body_spr.hframes = frames
	_body_spr.vframes = 1

	_hair_spr.texture = _walk_hair_tex if walking else _idle_hair_tex
	_hair_spr.modulate = hair_tint
	_hair_spr.hframes = frames
	_hair_spr.vframes = 1

	# Foreground arm/hand MUST stay visible & frame-locked in BOTH IDLE and WALKING!
	_tool_spr.visible = true
	_tool_spr.texture = _walk_tool_tex if walking else _idle_tool_tex
	_tool_spr.modulate = Color.WHITE
	_tool_spr.hframes = frames
	_tool_spr.vframes = 1

	var f_idx: int = int(_anim_time * (WALK_FPS if walking else IDLE_FPS)) % frames
	_body_spr.frame = f_idx
	_hair_spr.frame = f_idx
	_tool_spr.frame = f_idx


func _resolve_schedule_waypoints() -> void:
	var wp_root: Node = _find_waypoints_root()
	if wp_root == null:
		return
	var folder_name: String = _get_waypoint_folder_name()
	if folder_name.is_empty():
		return
	var home_m: Marker2D = wp_root.get_node_or_null("%s/HomeDoor" % folder_name) as Marker2D
	var work_m: Marker2D = wp_root.get_node_or_null("%s/WorkPost" % folder_name) as Marker2D
	var plaza_m: Marker2D = wp_root.get_node_or_null("%s/PlazaSpot" % folder_name) as Marker2D
	if home_m == null or work_m == null or plaza_m == null:
		return
	_wp_home = home_m.global_position
	_wp_work = work_m.global_position
	_wp_plaza = plaza_m.global_position
	_has_schedule = true


func _find_waypoints_root() -> Node:
	var cur: Node = get_parent()
	for _depth: int in range(8):
		if cur == null:
			break
		var found: Node = cur.get_node_or_null("NpcScheduleWaypoints")
		if found != null:
			return found
		cur = cur.get_parent()
	return null


func _get_waypoint_folder_name() -> String:
	match npc_id:
		&"maren":
			return "Maren"
		&"kaelen":
			return "Kaelen"
		&"aldric":
			return "Aldric"
		&"lyra":
			return "Lyra"
		&"bram":
			return "Bram"
		_:
			return ""


func get_schedule_slot_for_hour(hour_f: float) -> int:
	var prof: NpcData = SocialManager.get_npc(npc_id)
	var work_start: float = prof.work_start_hour if prof != null else 8.0
	var work_end: float = prof.work_end_hour if prof != null else 17.0
	var plaza_end: float = prof.plaza_end_hour if prof != null else 21.0
	if hour_f >= 6.0 and hour_f < work_start:
		return ScheduleSlot.HOME_MORNING
	if hour_f >= work_start and hour_f < work_end:
		return ScheduleSlot.WORK_POST
	if hour_f >= work_end and hour_f < plaza_end:
		return ScheduleSlot.PLAZA_EVENING
	return ScheduleSlot.HOME_NIGHT


func get_slot_world_position(slot: int) -> Vector2:
	match slot:
		ScheduleSlot.WORK_POST:
			return _wp_work
		ScheduleSlot.PLAZA_EVENING:
			return _wp_plaza
		_:
			return _wp_home


func snap_to_schedule(hour_f: float) -> void:
	if not _has_schedule:
		return
	if _festival_mode:
		_snap_to_festival_plaza()
		return
	var target_slot: int = get_schedule_slot_for_hour(hour_f)
	_current_slot = target_slot
	_path_queue = PackedVector2Array()
	_path_index = 0
	global_position = get_slot_world_position(target_slot)
	_apply_strip_visuals(false)
	_update_maren_counter_z()
	# Face gently toward center of Bramblebrook Plaza during evening gatherings!
	if target_slot == ScheduleSlot.PLAZA_EVENING:
		var plaza_center_x: float = 55.5 * TILE_SIZE
		_facing_left = global_position.x > plaza_center_x
	else:
		_facing_left = default_facing_left


func _build_road_route(from_slot: int, to_slot: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var from_is_home: bool = (from_slot == ScheduleSlot.HOME_MORNING or from_slot == ScheduleSlot.HOME_NIGHT)
	var to_is_home: bool = (to_slot == ScheduleSlot.HOME_MORNING or to_slot == ScheduleSlot.HOME_NIGHT)
	var dest: Vector2 = get_slot_world_position(to_slot)

	match npc_id:
		&"maren":
			if from_is_home and to_slot == ScheduleSlot.WORK_POST:
				pts.append(_tc(44, 27))
				pts.append(_tc(49, 27))
			elif from_slot == ScheduleSlot.WORK_POST and to_slot == ScheduleSlot.PLAZA_EVENING:
				pts.append(_tc(49, 27))
				pts.append(_tc(52, 28))
			elif from_slot == ScheduleSlot.PLAZA_EVENING and to_is_home:
				pts.append(_tc(51, 28))
				pts.append(_tc(44, 27))
			elif from_is_home and to_slot == ScheduleSlot.PLAZA_EVENING:
				pts.append(_tc(44, 27))
				pts.append(_tc(52, 28))
		&"kaelen":
			if from_is_home and to_slot == ScheduleSlot.WORK_POST:
				pts.append(_tc(46, 41))
				pts.append(_tc(52, 41))
			elif from_slot == ScheduleSlot.WORK_POST and to_slot == ScheduleSlot.PLAZA_EVENING:
				pts.append(_tc(53, 41))
				pts.append(_tc(56, 41))
				pts.append(_tc(56, 35))
			elif from_slot == ScheduleSlot.PLAZA_EVENING and to_is_home:
				pts.append(_tc(56, 35))
				pts.append(_tc(56, 41))
				pts.append(_tc(46, 41))
			elif from_is_home and to_slot == ScheduleSlot.PLAZA_EVENING:
				pts.append(_tc(56, 41))
				pts.append(_tc(56, 35))
		&"aldric":
			if from_is_home:
				pts.append(_tc(60, 27))
				pts.append(_tc(56, 28))
			elif to_is_home:
				pts.append(_tc(56, 28))
				pts.append(_tc(60, 27))
		&"lyra":
			# Climbs smoothly down/up the Waterfall Overlook wooden cliff ladder (col 53, rows 12..17)!
			if to_slot == ScheduleSlot.PLAZA_EVENING and from_slot != ScheduleSlot.PLAZA_EVENING:
				pts.append(_tc(54, 12))
				pts.append(_tc(53, 17))
				pts.append(_tc(53, 27))
				pts.append(_tc(55, 29))
			elif from_slot == ScheduleSlot.PLAZA_EVENING and to_slot != ScheduleSlot.PLAZA_EVENING:
				pts.append(_tc(54, 28))
				pts.append(_tc(53, 17))
				pts.append(_tc(53, 12))
			else:
				pts.append(_tc(57, 11))
		&"bram":
			# Crosses cleanly across the Ocean Channel Bridge (row 31, cols 70..78) — NEVER walks on water!
			if to_slot == ScheduleSlot.PLAZA_EVENING and from_slot != ScheduleSlot.PLAZA_EVENING:
				pts.append(_tc(81, 31))
				pts.append(_tc(74, 31))
				pts.append(_tc(66, 31))
				pts.append(_tc(60, 31))
			elif from_slot == ScheduleSlot.PLAZA_EVENING and to_slot != ScheduleSlot.PLAZA_EVENING:
				pts.append(_tc(60, 31))
				pts.append(_tc(66, 31))
				pts.append(_tc(74, 31))
				pts.append(_tc(81, 31))
			else:
				pts.append(_tc(80, 27))

	pts.append(dest)
	assert(pts.size() <= MAX_PATH_POINTS, "NpcActor route exceeds MAX_PATH_POINTS")
	return pts


func _tc(x: int, y: int) -> Vector2:
	return Vector2(float(x) * TILE_SIZE + 8.0, float(y) * TILE_SIZE + 8.0)


func _update_maren_counter_z() -> void:
	if npc_id != &"maren":
		return
	var at_counter: bool = (not _is_walking) and global_position.distance_squared_to(_wp_work) <= 36.0
	z_index = _home_z_index if at_counter else 0


func set_dialogue_paused(paused: bool, face_target: Node2D = null) -> void:
	_in_dialogue = paused
	if face_target != null and is_instance_valid(face_target):
		if face_target.global_position.x < global_position.x - 2.0:
			_facing_left = true
		elif face_target.global_position.x > global_position.x + 2.0:
			_facing_left = false
	if paused and _is_walking:
		_apply_strip_visuals(false)


func is_walking() -> bool:
	return _is_walking


func get_current_slot() -> int:
	return _current_slot


func get_current_anim_name() -> StringName:
	return &"walk" if _is_walking else &"idle"


func show_emote(emote_kind: StringName) -> void:
	if _emote_spr == null:
		return
	var path: String = AP.UI_EXPRESSION_CHAT
	match emote_kind:
		&"love", &"loved":
			path = AP.UI_EXPRESSION_LOVE
		&"happy", &"liked":
			path = AP.UI_EXPRESSION_HAPPY
		&"confused", &"disliked":
			path = AP.UI_EXPRESSION_CONFUSED
		_:
			path = AP.UI_EXPRESSION_CHAT
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	_emote_spr.texture = tex
	_emote_spr.visible = true
	_emote_spr.position = Vector2(0.0, -23.0)
	_emote_spr.scale = Vector2(0.45, 0.45)
	_emote_spr.modulate = Color.WHITE
	if _quest_badge != null:
		_quest_badge.visible = false
	if _emote_tween != null and _emote_tween.is_valid():
		_emote_tween.kill()
	_emote_tween = create_tween()
	_emote_tween.set_parallel(true)
	_emote_tween.tween_property(_emote_spr, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_emote_tween.tween_property(_emote_spr, "position:y", -31.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_emote_tween.chain().tween_interval(0.55)
	_emote_tween.tween_property(_emote_spr, "modulate:a", 0.0, 0.25)
	_emote_tween.tween_callback(func() -> void:
		if _emote_spr != null:
			_emote_spr.visible = false
		_refresh_quest_badge()
	)


func _refresh_quest_badge() -> void:
	if _quest_badge == null:
		return
	var ready_q: QuestData = QuestManager.find_ready_quest_for_npc(npc_id)
	var showing_emote: bool = (_emote_spr != null and _emote_spr.visible)
	_quest_badge.visible = (ready_q != null) and (not showing_emote)


func set_festival_mode(active: bool) -> void:
	_festival_mode = active
	if active:
		_snap_to_festival_plaza()
	elif _has_schedule:
		snap_to_schedule(TimeManager.get_hour_float())


func _snap_to_festival_plaza() -> void:
	_path_queue = PackedVector2Array()
	_path_index = 0
	if _has_schedule:
		global_position = _wp_plaza
	_current_slot = ScheduleSlot.PLAZA_EVENING
	_apply_strip_visuals(false)
	if npc_id == &"maren":
		z_index = 0
	var plaza_center_x: float = 55.5 * TILE_SIZE
	_facing_left = global_position.x > plaza_center_x


func step_schedule(dt: float, ignore_time_pause: bool = false) -> void:
	if not _has_schedule or _festival_mode:
		return
	if _in_dialogue:
		if _is_walking:
			_apply_strip_visuals(false)
		return
	if (not ignore_time_pause) and TimeManager.is_paused():
		if _is_walking:
			_apply_strip_visuals(false)
		return

	var desired_slot: int = get_schedule_slot_for_hour(TimeManager.get_hour_float())
	if desired_slot != _current_slot:
		_path_queue = _build_road_route(_current_slot, desired_slot)
		_path_index = 0
		_current_slot = desired_slot

	if _path_index < _path_queue.size():
		# Pause politely if the player is standing right beside the villager
		if _player_nearby and _player_ref != null and is_instance_valid(_player_ref):
			if _is_walking:
				_apply_strip_visuals(false)
			return

		var target_pt: Vector2 = _path_queue[_path_index]
		var to_target: Vector2 = target_pt - global_position
		var dist: float = to_target.length()
		if dist <= ARRIVAL_DIST_PX:
			global_position = target_pt
			_path_index += 1
			if _path_index >= _path_queue.size():
				_apply_strip_visuals(false)
				_update_maren_counter_z()
				if _current_slot == ScheduleSlot.PLAZA_EVENING:
					_facing_left = global_position.x > (55.5 * TILE_SIZE)
				else:
					_facing_left = default_facing_left
			return

		if not _is_walking:
			_apply_strip_visuals(true)
			if npc_id == &"maren":
				z_index = 0
		var step_dist: float = minf(dist, WALK_SPEED * dt)
		var dir: Vector2 = to_target / dist
		global_position += dir * step_dist
		if dir.x < -0.05:
			_facing_left = true
		elif dir.x > 0.05:
			_facing_left = false
	else:
		if _is_walking:
			_apply_strip_visuals(false)
			_update_maren_counter_z()


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	step_schedule(dt, false)

	_anim_time += dt
	var fps: float = WALK_FPS if _is_walking else IDLE_FPS
	var frames: int = WALK_FRAMES if _is_walking else IDLE_FRAMES
	var frame_idx: int = int(_anim_time * fps) % frames

	var flip_left: bool = _facing_left
	if (not _is_walking) and _player_nearby and _player_ref != null and is_instance_valid(_player_ref):
		if _player_ref.global_position.x < global_position.x - 4.0:
			flip_left = true
		elif _player_ref.global_position.x > global_position.x + 4.0:
			flip_left = false

	_body_spr.frame = frame_idx
	_body_spr.flip_h = flip_left
	_hair_spr.frame = frame_idx
	_hair_spr.flip_h = flip_left
	_tool_spr.frame = frame_idx
	_tool_spr.flip_h = flip_left

	if _quest_badge != null and _quest_badge.visible:
		_badge_bob_time += dt * 4.0
		_quest_badge.position.y = -24.0 + sin(_badge_bob_time) * 1.5


func is_player_nearby() -> bool:
	return interact_enabled and _player_nearby


func trigger_interact() -> void:
	if not interact_enabled:
		return
	AudioManager.play_sfx(&"pickup", -9.0, 0.05)
	EventBus.dialogue_requested.emit(npc_id)


func _on_body_entered(body: Node2D) -> void:
	if not interact_enabled or not body.is_in_group(&"player"):
		return
	_player_nearby = true
	_player_ref = body
	EventBus.interact_prompt_changed.emit(_build_context_prompt())


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_nearby = false
	_player_ref = null
	if interact_enabled:
		EventBus.interact_prompt_changed.emit("")


func _build_context_prompt() -> String:
	var ready_q: QuestData = QuestManager.find_ready_quest_for_npc(npc_id)
	if ready_q != null:
		return "[E] Turn In Quest (%s)" % display_name
	var held_id: StringName = InventoryManager.get_selected_item_id()
	if held_id != &"" and SocialManager.is_giftable_item(held_id) and SocialManager.can_gift_today(npc_id):
		var item_data: ItemData = InventoryManager.get_item(held_id)
		var item_nm: String = item_data.display_name if item_data != null else String(held_id)
		return "[E] Gift %s to %s" % [item_nm, display_name]
	return "[E] Talk to %s" % display_name
