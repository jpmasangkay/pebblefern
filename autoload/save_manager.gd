extends Node

## Lossless 3-slot JSON Save/Load manager (user://saves/slot_1.json .. slot_3.json).
## Persists Time, Weather, Economy, Inventory + Tool Tiers, Vitality, Persistent World Grids
## (crops, placed objects, 16-slot PlacedChest contents, destroyed resources, harvested bushes),
## Social Friendship/Gifts, Quests, Festival history, Audio SFX volume, and exact Scene + Player Position.

const SAVE_DIR: String = "user://saves"
const MAX_SLOTS: int = 3
const SAVE_SCHEMA_VERSION: int = 1
const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const SENTINEL_POS: Vector2 = Vector2(-99999.0, -99999.0)

var active_slot: int = 1
var auto_save_enabled: bool = true

var _pending_load_state: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func get_slot_path(slot_idx: int) -> String:
	var clamped: int = clampi(slot_idx, 1, MAX_SLOTS)
	return "%s/slot_%d.json" % [SAVE_DIR, clamped]


func slot_exists(slot_idx: int) -> bool:
	if slot_idx < 1 or slot_idx > MAX_SLOTS:
		return false
	return FileAccess.file_exists(get_slot_path(slot_idx))


func has_any_save() -> bool:
	for s: int in range(1, MAX_SLOTS + 1):
		if slot_exists(s):
			return true
	return false


func get_most_recent_slot() -> int:
	var best_slot: int = 0
	var best_unix: int = -1
	for s: int in range(1, MAX_SLOTS + 1):
		var summary: Dictionary = get_slot_summary(s)
		if bool(summary.get("exists", false)):
			var ts: int = int(summary.get("saved_unix", 0))
			if ts >= best_unix:
				best_unix = ts
				best_slot = s
	return best_slot


func get_first_empty_or_default_slot() -> int:
	for s: int in range(1, MAX_SLOTS + 1):
		if not slot_exists(s):
			return s
	return 1


func get_slot_summary(slot_idx: int) -> Dictionary:
	var clamped: int = clampi(slot_idx, 1, MAX_SLOTS)
	var empty_summary: Dictionary = {
		"exists": false,
		"slot": clamped,
		"day": 1,
		"season": 0,
		"season_name": "Bloom",
		"year": 1,
		"sunbursts": 0,
		"scene_path": FARM_SCENE_PATH,
		"saved_unix": 0,
		"formatted_date": "Empty Slot",
	}
	var payload: Dictionary = _read_slot_json(clamped)
	if payload.is_empty():
		return empty_summary

	var t_dict: Dictionary = payload.get("time", {}) as Dictionary
	var e_dict: Dictionary = payload.get("economy", {}) as Dictionary
	var day_v: int = clampi(int(t_dict.get("day", 1)), 1, TimeManager.DAYS_PER_SEASON)
	var season_v: int = clampi(int(t_dict.get("season", 0)), 0, TimeManager.SEASONS_PER_YEAR - 1)
	var year_v: int = maxi(1, int(t_dict.get("year", 1)))
	var season_nm: String = TimeManager.get_season_name(season_v)
	var gold_v: int = maxi(0, int(e_dict.get("sunbursts", 0)))

	return {
		"exists": true,
		"slot": clamped,
		"day": day_v,
		"season": season_v,
		"season_name": season_nm,
		"year": year_v,
		"sunbursts": gold_v,
		"scene_path": String(payload.get("scene_path", FARM_SCENE_PATH)),
		"saved_unix": int(payload.get("saved_unix", 0)),
		"formatted_date": "Year %d · %s %d" % [year_v, season_nm, day_v],
	}


## Captures the complete live game state and writes it atomically to `slot_idx` (defaults to `active_slot`).
func save_slot(
	slot_idx: int = -1,
	override_scene_path: String = "",
	override_player_pos: Vector2 = SENTINEL_POS,
	play_sfx: bool = true
) -> bool:
	var slot: int = clampi(slot_idx if slot_idx >= 1 and slot_idx <= MAX_SLOTS else active_slot, 1, MAX_SLOTS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

	var scene_path: String = override_scene_path
	var player_pos: Vector2 = override_player_pos
	var mine_floor: int = 1
	var interior_id: String = ""

	var cur_scene: Node = get_tree().current_scene
	if cur_scene != null:
		if scene_path.is_empty():
			var p: String = cur_scene.scene_file_path
			if not p.is_empty() and p != "res://scenes/ui/title_screen.tscn":
				scene_path = p
		if player_pos == SENTINEL_POS:
			var p_node: Node2D = cur_scene.get_node_or_null("WorldEntities/Player") as Node2D
			if p_node != null:
				player_pos = p_node.global_position
		if cur_scene.get("current_floor") != null:
			mine_floor = clampi(int(cur_scene.get("current_floor")), 1, 3)
		if cur_scene.get("active_theme_id") != null:
			interior_id = String(cur_scene.get("active_theme_id"))

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		scene_path = FARM_SCENE_PATH
	if player_pos == SENTINEL_POS:
		player_pos = Vector2.ZERO

	var payload: Dictionary = {
		"version": SAVE_SCHEMA_VERSION,
		"slot": slot,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"scene_path": scene_path,
		"has_player_pos": player_pos != Vector2.ZERO,
		"player_pos": {"x": player_pos.x, "y": player_pos.y},
		"mine_floor": mine_floor,
		"interior_id": interior_id,
		"return_scene": SceneTransition.active_return_scene,
		"return_pos": {"x": SceneTransition.active_return_position.x, "y": SceneTransition.active_return_position.y},
		"master_volume": AudioManager.get_master_volume(),
		"time": TimeManager.serialize(),
		"economy": EconomyManager.serialize(),
		"inventory": InventoryManager.serialize(),
		"vitality": VitalitySystem.serialize(),
		"world_grid": GridStateManager.serialize_world_state(),
		"social": SocialManager.serialize(),
		"quests": QuestManager.serialize(),
		"festivals": FestivalManager.serialize(),
	}

	var json_text: String = JSON.stringify(payload, "\t")
	var final_path: String = get_slot_path(slot)
	var tmp_path: String = final_path + ".tmp"
	var fa: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if fa == null:
		return false
	fa.store_string(json_text)
	fa.flush()
	fa.close()

	var abs_tmp: String = ProjectSettings.globalize_path(tmp_path)
	var abs_final: String = ProjectSettings.globalize_path(final_path)
	var ren_err: Error = DirAccess.rename_absolute(abs_tmp, abs_final)
	if ren_err != OK:
		# Windows fallback if target exists before rename
		if FileAccess.file_exists(final_path):
			DirAccess.remove_absolute(abs_final)
			ren_err = DirAccess.rename_absolute(abs_tmp, abs_final)
	if ren_err != OK:
		return false

	active_slot = slot
	if play_sfx:
		AudioManager.play_sfx(&"save", -5.0, 0.02)
	EventBus.game_saved.emit(slot)
	return true


## Auto-saves quietly after overnight shipping settles on morning wake-up.
func auto_save_morning() -> bool:
	if not auto_save_enabled:
		return false
	return save_slot(active_slot, "", SENTINEL_POS, false)


## Loads a saved JSON slot and restores all persistent world & player systems deterministically.
func load_slot(slot_idx: int, transition_scene: bool = true, immediate_transition: bool = false) -> bool:
	var slot: int = clampi(slot_idx, 1, MAX_SLOTS)
	var payload: Dictionary = _read_slot_json(slot)
	if payload.is_empty():
		return false

	# 1. Restore Time FIRST (its deserialize emits day_started; social/quests/festivals override cleanly after!)
	if payload.has("time") and payload["time"] is Dictionary:
		TimeManager.deserialize(payload["time"] as Dictionary)

	# 2. Restore Economy, Inventory, Vitality, World Grid, Social, Quests, Festivals & Audio
	if payload.has("economy") and payload["economy"] is Dictionary:
		EconomyManager.deserialize(payload["economy"] as Dictionary)
	if payload.has("inventory") and payload["inventory"] is Dictionary:
		InventoryManager.deserialize(payload["inventory"] as Dictionary)
	if payload.has("vitality") and payload["vitality"] is Dictionary:
		VitalitySystem.deserialize(payload["vitality"] as Dictionary)
	if payload.has("world_grid") and payload["world_grid"] is Dictionary:
		GridStateManager.deserialize_world_state(payload["world_grid"] as Dictionary)
	if payload.has("social") and payload["social"] is Dictionary:
		SocialManager.deserialize(payload["social"] as Dictionary)
	if payload.has("quests") and payload["quests"] is Dictionary:
		QuestManager.deserialize(payload["quests"] as Dictionary)
	if payload.has("festivals") and payload["festivals"] is Dictionary:
		FestivalManager.deserialize(payload["festivals"] as Dictionary)
	if payload.has("master_volume"):
		AudioManager.set_master_volume(float(payload["master_volume"]))

	# 3. Restore SceneTransition return metadata & pending player coordinates
	var ret_scene: String = String(payload.get("return_scene", FARM_SCENE_PATH))
	if not ret_scene.is_empty():
		SceneTransition.active_return_scene = ret_scene
	if payload.has("return_pos") and payload["return_pos"] is Dictionary:
		var rp: Dictionary = payload["return_pos"] as Dictionary
		SceneTransition.active_return_position = Vector2(float(rp.get("x", 0.0)), float(rp.get("y", 0.0)))

	var p_dict: Dictionary = payload.get("player_pos", {}) as Dictionary
	var has_pos: bool = bool(payload.get("has_player_pos", false))
	var saved_pos: Vector2 = Vector2(float(p_dict.get("x", 0.0)), float(p_dict.get("y", 0.0)))
	var saved_floor: int = clampi(int(payload.get("mine_floor", 1)), 1, 3)
	var saved_interior: StringName = StringName(String(payload.get("interior_id", "")))

	_pending_load_state = {
		"valid": has_pos,
		"position": saved_pos,
		"mine_floor": saved_floor,
		"interior_id": saved_interior,
	}
	if saved_interior != &"":
		SceneTransition.pending_interior_id = saved_interior

	active_slot = slot
	EventBus.game_loaded.emit(slot)

	if transition_scene:
		var target_scene: String = String(payload.get("scene_path", FARM_SCENE_PATH))
		if target_scene.is_empty() or not ResourceLoader.exists(target_scene):
			target_scene = FARM_SCENE_PATH
		SceneTransition.transition_to_scene(target_scene, &"from_save", immediate_transition)
	return true


func consume_loaded_player_state() -> Dictionary:
	if _pending_load_state.is_empty() or not bool(_pending_load_state.get("valid", false)):
		return {"valid": false, "position": Vector2.ZERO, "mine_floor": 1, "interior_id": &""}
	var copy: Dictionary = _pending_load_state.duplicate(true)
	_pending_load_state.clear()
	return copy


func delete_slot(slot_idx: int) -> bool:
	if not slot_exists(slot_idx):
		return false
	var abs_path: String = ProjectSettings.globalize_path(get_slot_path(slot_idx))
	return DirAccess.remove_absolute(abs_path) == OK


func start_new_game(slot_idx: int = -1, transition_scene: bool = true, immediate_transition: bool = false) -> void:
	var chosen: int = clampi(slot_idx if slot_idx >= 1 and slot_idx <= MAX_SLOTS else get_first_empty_or_default_slot(), 1, MAX_SLOTS)
	active_slot = chosen
	_pending_load_state.clear()
	GridStateManager.clear_all()
	TimeManager.reset_to_day_one()
	EconomyManager.reset_economy()
	InventoryManager.reset_to_starter_loadout()
	VitalitySystem.restore_full()
	SocialManager.reset_social()
	QuestManager.reset_quests()
	FestivalManager.reset_festivals()
	SceneTransition.has_pending_return_position = false
	SceneTransition.pending_spawn_tag = &""
	SceneTransition.pending_interior_id = &""
	if transition_scene:
		SceneTransition.transition_to_scene(FARM_SCENE_PATH, &"new_game", immediate_transition)


func _read_slot_json(slot_idx: int) -> Dictionary:
	var path: String = get_slot_path(slot_idx)
	if not FileAccess.file_exists(path):
		return {}
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return {}
	var raw: String = fa.get_as_text()
	fa.close()
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
