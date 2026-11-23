class_name MineEnemy
extends CharacterBody2D

## Subterranean Pebblefern Mine cave enemy powered by 100% real Sunnyside World V2.1
## Skeleton animation strips (96x64 frames: IDLE 6, WALK 8, ATTACK 7, HURT 7, DEATH 10).
## Supports 5-state AI (IDLE -> CHASE -> ATTACK -> HURT -> DEAD), directional knockback,
## hit flash, overhead Sunnyside redbar HP gauge, Vitality contact/attack damage, and pooled loot drops.

const AP := preload("res://scripts/core/asset_paths.gd")

enum AiState {
	IDLE = 0,
	CHASE = 1,
	ATTACK = 2,
	HURT = 3,
	DEAD = 4,
}

const AGGRO_RADIUS_PX: float = 112.0
const ATTACK_RANGE_PX: float = 19.0
const CONTACT_DAMAGE_DIST_PX: float = 14.0
const ATTACK_COOLDOWN_SEC: float = 0.95
const KNOCKBACK_DECAY: float = 520.0

var enemy_kind: StringName = &"cave_skeleton"
var floor_level: int = 1
var max_hp: int = 3
var current_hp: int = 3
var move_speed: float = 36.0
var contact_damage: float = 14.0
var base_tint: Color = Color.WHITE
var drop_primary_id: StringName = &"copper_ore"
var drop_secondary_id: StringName = &"shadow_shard"

var _state: int = AiState.IDLE
var _facing_left: bool = false
var _anim_time: float = 0.0
var _anim_frame: int = 0
var _attack_cooldown: float = 0.0
var _attack_hit_fired: bool = false
var _knockback_vel: Vector2 = Vector2.ZERO
var _home_pos: Vector2 = Vector2.ZERO
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_wait: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _paused: bool = false

var _sprite: Sprite2D = null
var _hp_bar: Sprite2D = null
var _col_shape: CollisionShape2D = null
var _hit_particles: CPUParticles2D = null
var _flash_tween: Tween = null
var _player_ref: Player = null

var _textures: Array[Texture2D] = []
var _frame_counts: PackedInt32Array = PackedInt32Array([6, 8, 7, 7, 10])
var _frame_rates: PackedFloat32Array = PackedFloat32Array([7.0, 9.5, 13.0, 14.0, 11.0])
var _redbars: Array[Texture2D] = []


func _ready() -> void:
	add_to_group(&"mine_enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 8
	collision_mask = 1
	y_sort_enabled = true

	_home_pos = global_position
	_patrol_target = _home_pos
	_preload_assets()
	_build_nodes()
	_apply_state(AiState.IDLE)


func configure_for_floor(p_floor: int, seed_val: int, player_node: Player) -> void:
	floor_level = clampi(p_floor, 1, 3)
	_player_ref = player_node
	_rng.seed = seed_val
	_home_pos = global_position
	_patrol_target = _home_pos

	match floor_level:
		1:
			enemy_kind = &"cave_skeleton"
			max_hp = 3
			move_speed = 35.0
			contact_damage = 14.0
			base_tint = Color.WHITE
			drop_primary_id = &"copper_ore"
			drop_secondary_id = &"shadow_shard"
		2:
			enemy_kind = &"iron_skeleton"
			max_hp = 4
			move_speed = 41.0
			contact_damage = 18.0
			base_tint = Color(0.84, 0.90, 1.0, 1.0)
			drop_primary_id = &"iron_ore"
			drop_secondary_id = &"shadow_shard"
		_:
			enemy_kind = &"crystal_skeleton"
			max_hp = 5
			move_speed = 45.0
			contact_damage = 22.0
			base_tint = Color(0.76, 1.0, 0.98, 1.0)
			drop_primary_id = &"cave_crystal"
			drop_secondary_id = &"shadow_shard"

	current_hp = max_hp
	if _sprite != null:
		_sprite.modulate = base_tint
	_refresh_hp_bar()


func set_ai_paused(paused: bool) -> void:
	_paused = paused


func is_alive() -> bool:
	return _state != AiState.DEAD


func get_ai_state() -> int:
	return _state


func _preload_assets() -> void:
	var paths: PackedStringArray = [
		AP.SKELETON_IDLE_STRIP6,
		AP.SKELETON_WALK_STRIP8,
		AP.SKELETON_ATTACK_STRIP7,
		AP.SKELETON_HURT_STRIP7,
		AP.SKELETON_DEATH_STRIP10,
	]
	_textures.resize(paths.size())
	for i: int in range(paths.size()):
		var t: Texture2D = load(paths[i]) as Texture2D
		assert(t != null, "MineEnemy missing Skeleton strip: %s" % paths[i])
		_textures[i] = t

	_redbars.clear()
	for rp: String in AP.REDBAR_PATHS:
		var rb: Texture2D = load(rp) as Texture2D
		assert(rb != null, "MineEnemy missing redbar PNG: %s" % rp)
		_redbars.append(rb)


func _build_nodes() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "SkeletonSprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0.0, -6.0)
	_sprite.modulate = base_tint
	add_child(_sprite)

	_col_shape = CollisionShape2D.new()
	_col_shape.name = "BodyCollider"
	var circ: CircleShape2D = CircleShape2D.new()
	circ.radius = 5.5
	_col_shape.shape = circ
	add_child(_col_shape)

	_hp_bar = Sprite2D.new()
	_hp_bar.name = "HpBar"
	_hp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_bar.position = Vector2(0.0, -19.0)
	_hp_bar.scale = Vector2(0.45, 0.45)
	_hp_bar.z_index = 8
	_hp_bar.visible = false
	add_child(_hp_bar)

	var glint_tex: Texture2D = load(AP.ITEM_ROCK) as Texture2D
	_hit_particles = CPUParticles2D.new()
	_hit_particles.name = "CombatSparks"
	_hit_particles.texture = glint_tex
	_hit_particles.emitting = false
	_hit_particles.one_shot = true
	_hit_particles.explosiveness = 0.92
	_hit_particles.amount = 7
	_hit_particles.lifetime = 0.28
	_hit_particles.direction = Vector2(0.0, -1.0)
	_hit_particles.spread = 110.0
	_hit_particles.gravity = Vector2(0.0, 210.0)
	_hit_particles.initial_velocity_min = 34.0
	_hit_particles.initial_velocity_max = 78.0
	_hit_particles.scale_amount_min = 0.22
	_hit_particles.scale_amount_max = 0.36
	_hit_particles.z_index = 6
	add_child(_hit_particles)


func take_sword_hit(damage: int, from_world_pos: Vector2, drop_pool: DroppedItemPool, player_ref: Node2D) -> bool:
	if _state == AiState.DEAD:
		return false
	assert(damage > 0, "Sword damage must be positive.")

	current_hp = maxi(0, current_hp - damage)
	var away: Vector2 = global_position - from_world_pos
	if away.length_squared() < 0.01:
		away = Vector2(1.0, 0.0)
	_knockback_vel = away.normalized() * 160.0

	if _hit_particles != null:
		_hit_particles.restart()
		_hit_particles.emitting = true
	_play_hit_flash()
	_refresh_hp_bar()

	if current_hp <= 0:
		_die(drop_pool, player_ref)
	else:
		AudioManager.play_sfx(&"sword_hit", -4.0, 0.06)
		_apply_state(AiState.HURT)
	return true


func _die(drop_pool: DroppedItemPool, player_ref: Node2D) -> void:
	_state = AiState.DEAD
	_apply_state(AiState.DEAD)
	if _col_shape != null:
		_col_shape.set_deferred("disabled", true)
	if _hp_bar != null:
		_hp_bar.visible = false
	AudioManager.play_sfx(&"enemy_die", -3.5, 0.05)

	if drop_pool != null:
		drop_pool.spawn_scatter_drops(global_position, drop_primary_id, 1, player_ref)
		drop_pool.spawn_scatter_drops(global_position + Vector2(3.0, -2.0), drop_secondary_id, 1, player_ref)
	EventBus.enemy_defeated.emit(enemy_kind, global_position)


func _play_hit_flash() -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = Color(2.4, 2.4, 2.4, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", base_tint, 0.14)


func _refresh_hp_bar() -> void:
	if _hp_bar == null or _redbars.is_empty():
		return
	if current_hp >= max_hp or _state == AiState.DEAD:
		_hp_bar.visible = false
		return
	_hp_bar.visible = true
	var ratio: float = clampf(float(current_hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	var idx: int = clampi(int(roundf(ratio * float(_redbars.size() - 1))), 0, _redbars.size() - 1)
	_hp_bar.texture = _redbars[idx]


func _apply_state(next_state: int) -> void:
	_state = next_state
	_anim_time = 0.0
	_anim_frame = 0
	if next_state == AiState.ATTACK:
		_attack_hit_fired = false
	if _sprite == null:
		return
	var tex_idx: int = clampi(next_state, 0, _textures.size() - 1)
	_sprite.texture = _textures[tex_idx]
	_sprite.hframes = _frame_counts[tex_idx]
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.flip_h = _facing_left


func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	if _paused or TimeManager.is_paused():
		return

	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - dt)

	if _state == AiState.DEAD:
		_step_animation(dt)
		return

	if _state == AiState.HURT:
		velocity = _knockback_vel
		move_and_slide()
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * dt)
		_step_animation(dt)
		return

	if _state == AiState.ATTACK:
		velocity = _knockback_vel
		if velocity.length_squared() > 1.0:
			move_and_slide()
			_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * dt)
		_step_animation(dt)
		return

	var has_player: bool = (_player_ref != null and is_instance_valid(_player_ref))
	var dist_to_player: float = 9999.0
	var to_player: Vector2 = Vector2.ZERO
	if has_player:
		to_player = _player_ref.global_position - global_position
		dist_to_player = to_player.length()

	if has_player and dist_to_player <= ATTACK_RANGE_PX and _attack_cooldown <= 0.0:
		_facing_left = to_player.x < -1.0
		_attack_cooldown = ATTACK_COOLDOWN_SEC
		_apply_state(AiState.ATTACK)
		return

	if has_player and dist_to_player <= AGGRO_RADIUS_PX:
		var dir: Vector2 = to_player.normalized() if dist_to_player > 0.5 else Vector2.ZERO
		velocity = dir * move_speed + _knockback_vel
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * dt)
		if dir.x < -0.05:
			_facing_left = true
		elif dir.x > 0.05:
			_facing_left = false
		if _state != AiState.CHASE:
			_apply_state(AiState.CHASE)
		move_and_slide()
		if dist_to_player <= CONTACT_DAMAGE_DIST_PX and not _player_ref.is_hurt_invulnerable():
			_player_ref.apply_damage_and_knockback(contact_damage * 0.65, global_position)
	else:
		# Gentle short cave patrol near spawn
		var to_patrol: Vector2 = _patrol_target - global_position
		if to_patrol.length() <= 4.0:
			velocity = _knockback_vel
			_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * dt)
			if _state != AiState.IDLE:
				_apply_state(AiState.IDLE)
			_patrol_wait -= dt
			if _patrol_wait <= 0.0:
				_patrol_wait = _rng.randf_range(1.4, 2.8)
				_patrol_target = _home_pos + Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(-18.0, 18.0))
		else:
			var pdir: Vector2 = to_patrol.normalized()
			velocity = pdir * (move_speed * 0.55) + _knockback_vel
			_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * dt)
			if pdir.x < -0.05:
				_facing_left = true
			elif pdir.x > 0.05:
				_facing_left = false
			if _state != AiState.CHASE:
				_apply_state(AiState.CHASE)
			move_and_slide()

	_step_animation(dt)


func _step_animation(dt: float) -> void:
	if _sprite == null:
		return
	var idx: int = clampi(_state, 0, _frame_counts.size() - 1)
	var count: int = _frame_counts[idx]
	var fps: float = _frame_rates[idx]
	_anim_time += dt
	var next_f: int = int(_anim_time * fps)

	if _state == AiState.IDLE or _state == AiState.CHASE:
		_anim_frame = next_f % count
	elif next_f >= count:
		if _state == AiState.DEAD:
			_anim_frame = count - 1
			_sprite.frame = _anim_frame
			queue_free()
			return
		_apply_state(AiState.IDLE)
		return
	else:
		_anim_frame = next_f

	_sprite.frame = _anim_frame
	_sprite.flip_h = _facing_left

	# Strike frame of skeleton_attack_strip7 (frame 3) deals melee damage!
	if _state == AiState.ATTACK and not _attack_hit_fired and _anim_frame >= 3:
		_attack_hit_fired = true
		if _player_ref != null and is_instance_valid(_player_ref):
			if _player_ref.global_position.distance_to(global_position) <= ATTACK_RANGE_PX + 7.0:
				_player_ref.apply_damage_and_knockback(contact_damage, global_position)
