extends Node

## Lightweight retro SFX synthesizer backed by pre-allocated AudioStreamGenerator voices.
## Pre-bakes all PCM buffers once at startup (zero runtime allocations, deterministic noise).

const SAMPLE_RATE: float = 22050.0
const MAX_VOICES: int = 8
const MAX_SAMPLES: int = 8192

var _voices: Array[AudioStreamPlayer] = []
var _voice_cursor: int = 0
var _buffers: Dictionary = {} # StringName -> PackedVector2Array
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _muted: bool = false
var _master_volume: float = 1.0


func _ready() -> void:
	_rng.seed = 20260407
	_muted = DisplayServer.get_name() == "headless"
	_init_voice_pool()
	_prebake_all_sfx()
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.currency_changed.connect(_on_currency_changed)


func _exit_tree() -> void:
	if EventBus.item_picked_up.is_connected(_on_item_picked_up):
		EventBus.item_picked_up.disconnect(_on_item_picked_up)
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)


func set_muted(muted: bool) -> void:
	_muted = muted


func set_master_volume(linear_vol: float) -> void:
	_master_volume = clampf(linear_vol, 0.0, 1.0)


func get_master_volume() -> float:
	return _master_volume


func has_sfx(sfx_id: StringName) -> bool:
	return _buffers.has(sfx_id)


func play_sfx(sfx_id: StringName, volume_db: float = -6.0, pitch_jitter: float = 0.0) -> bool:
	if not _buffers.has(sfx_id):
		return false
	if _muted or _master_volume <= 0.001:
		return true

	var player: AudioStreamPlayer = _voices[_voice_cursor]
	_voice_cursor = (_voice_cursor + 1) % MAX_VOICES

	var frames: PackedVector2Array = _buffers[sfx_id] as PackedVector2Array
	player.stop()
	player.volume_db = volume_db + linear_to_db(_master_volume)
	player.pitch_scale = 1.0 + (_rng.randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 0.0)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		var available: int = playback.get_frames_available()
		var count: int = mini(frames.size(), available)
		if count > 0:
			playback.push_buffer(frames.slice(0, count))
	return true


func _on_item_picked_up(_item_id: StringName, _count: int) -> void:
	play_sfx(&"pickup", -10.0, 0.06)


func _on_currency_changed(_new_balance: int, delta: int) -> void:
	if delta != 0:
		play_sfx(&"coin", -6.0, 0.03)


func _init_voice_pool() -> void:
	_voices.resize(MAX_VOICES)
	for i: int in range(MAX_VOICES):
		var asp: AudioStreamPlayer = AudioStreamPlayer.new()
		asp.name = "SfxVoice_%d" % i
		var gen: AudioStreamGenerator = AudioStreamGenerator.new()
		gen.mix_rate = SAMPLE_RATE
		gen.buffer_length = 0.35
		asp.stream = gen
		add_child(asp)
		_voices[i] = asp


func _prebake_all_sfx() -> void:
	_buffers[&"footstep"] = _bake_footstep()
	_buffers[&"door"] = _bake_door()
	_buffers[&"hoe"] = _bake_hoe()
	_buffers[&"water"] = _bake_water()
	_buffers[&"axe"] = _bake_axe()
	_buffers[&"pickaxe"] = _bake_pickaxe()
	_buffers[&"scythe"] = _bake_scythe()
	_buffers[&"fish_cast"] = _bake_fish_cast()
	_buffers[&"harvest"] = _bake_harvest()
	_buffers[&"plant"] = _bake_plant()
	_buffers[&"pickup"] = _bake_pickup()
	_buffers[&"error"] = _bake_error()
	_buffers[&"coin"] = _bake_coin()
	_buffers[&"craft"] = _bake_craft()
	_buffers[&"place"] = _bake_place()
	_buffers[&"sword_hit"] = _bake_sword_hit()
	_buffers[&"enemy_die"] = _bake_enemy_die()
	_buffers[&"player_hurt"] = _bake_player_hurt()
	_buffers[&"festival"] = _bake_festival()
	_buffers[&"save"] = _bake_save()


func _alloc_samples(duration_sec: float) -> int:
	return clampi(int(roundf(duration_sec * SAMPLE_RATE)), 64, MAX_SAMPLES)


func _bake_footstep() -> PackedVector2Array:
	var n: int = _alloc_samples(0.055)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var prev: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t)
		var thud: float = sin(TAU * 115.0 * (float(i) / SAMPLE_RATE)) * 0.45
		var raw_n: float = _rng.randf_range(-1.0, 1.0)
		prev = prev * 0.72 + raw_n * 0.28
		var s: float = (thud + prev * 0.45) * env * 0.42
		out[i] = Vector2(s, s)
	return out


func _bake_door() -> PackedVector2Array:
	var n: int = _alloc_samples(0.18)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(165.0, 245.0, t) if t < 0.65 else 110.0
		phase += TAU * freq / SAMPLE_RATE
		var click: float = sin(TAU * 420.0 * (float(i) / SAMPLE_RATE)) * exp(-t * 24.0) * 0.45
		var body: float = sin(phase) * (1.0 - t) * 0.45
		var s: float = clampf((body + click) * 0.65, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out


func _bake_hoe() -> PackedVector2Array:
	var n: int = _alloc_samples(0.12)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var prev: float = 0.0
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t)
		var freq: float = lerpf(190.0, 82.0, t)
		phase += TAU * freq / SAMPLE_RATE
		var crunch: float = _rng.randf_range(-1.0, 1.0)
		prev = prev * 0.58 + crunch * 0.42
		var s: float = (sin(phase) * 0.55 + prev * 0.55) * env * 0.68
		out[i] = Vector2(s, s)
	return out


func _bake_water() -> PackedVector2Array:
	var n: int = _alloc_samples(0.18)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var prev: float = 0.0
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var env: float = sin(PI * t) * (1.0 - 0.35 * t)
		var freq: float = lerpf(320.0, 680.0, t) + 75.0 * sin(t * 28.0)
		phase += TAU * freq / SAMPLE_RATE
		var spray: float = _rng.randf_range(-1.0, 1.0)
		prev = prev * 0.45 + spray * 0.55
		var s: float = (sin(phase) * 0.38 + prev * 0.48) * env * 0.58
		out[i] = Vector2(s, s)
	return out


func _bake_axe() -> PackedVector2Array:
	var n: int = _alloc_samples(0.11)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var env: float = exp(-t * 7.5)
		var freq: float = lerpf(280.0, 95.0, minf(1.0, t * 2.2))
		phase += TAU * freq / SAMPLE_RATE
		var knock: float = (2.0 * absf(fmod(phase / TAU, 1.0) - 0.5) - 0.5) * 2.0
		var crack: float = _rng.randf_range(-1.0, 1.0) * exp(-t * 18.0) * 0.45
		var s: float = (knock * 0.65 + crack) * env * 0.72
		out[i] = Vector2(s, s)
	return out


func _bake_pickaxe() -> PackedVector2Array:
	var n: int = _alloc_samples(0.14)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var sec: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 6.8)
		var ping1: float = sin(TAU * 980.0 * sec) * 0.50
		var ping2: float = sin(TAU * 1475.0 * sec) * 0.32
		var spark: float = _rng.randf_range(-1.0, 1.0) * exp(-t * 22.0) * 0.40
		var s: float = (ping1 + ping2 + spark) * env * 0.64
		out[i] = Vector2(s, s)
	return out


func _bake_scythe() -> PackedVector2Array:
	var n: int = _alloc_samples(0.10)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var prev: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var env: float = sin(PI * t)
		var raw_n: float = _rng.randf_range(-1.0, 1.0)
		var hp: float = raw_n - prev * 0.65
		prev = raw_n
		var s: float = clampf(hp * env * 0.42, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out


func _bake_fish_cast() -> PackedVector2Array:
	var n: int = _alloc_samples(0.24)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var s: float = 0.0
		if t < 0.55:
			var u: float = t / 0.55
			var env_w: float = sin(PI * u) * 0.35
			s = _rng.randf_range(-1.0, 1.0) * env_w
		else:
			var u2: float = (t - 0.55) / 0.45
			var freq: float = lerpf(280.0, 640.0, u2)
			phase += TAU * freq / SAMPLE_RATE
			s = sin(phase) * (1.0 - u2) * 0.62
		out[i] = Vector2(s, s)
	return out


func _bake_harvest() -> PackedVector2Array:
	var n: int = _alloc_samples(0.18)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = 523.25 if t < 0.45 else 659.25 # C5 -> E5 cozy chime
		phase += TAU * freq / SAMPLE_RATE
		var env: float = (1.0 - t) * minf(1.0, t * 18.0)
		var s: float = sin(phase) * env * 0.58
		out[i] = Vector2(s, s)
	return out


func _bake_plant() -> PackedVector2Array:
	var n: int = _alloc_samples(0.08)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(260.0, 390.0, t)
		phase += TAU * freq / SAMPLE_RATE
		var s: float = sin(phase) * (1.0 - t) * 0.48
		out[i] = Vector2(s, s)
	return out


func _bake_pickup() -> PackedVector2Array:
	var n: int = _alloc_samples(0.09)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(660.0, 990.0, t)
		phase += TAU * freq / SAMPLE_RATE
		var s: float = sin(phase) * (1.0 - t) * 0.42
		out[i] = Vector2(s, s)
	return out


func _bake_error() -> PackedVector2Array:
	var n: int = _alloc_samples(0.13)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = 155.0 if t < 0.48 else 125.0
		phase += TAU * freq / SAMPLE_RATE
		var pulse: float = sin(PI * fmod(t * 2.0, 1.0))
		var s: float = sin(phase) * pulse * (1.0 - 0.3 * t) * 0.48
		out[i] = Vector2(s, s)
	return out


func _bake_coin() -> PackedVector2Array:
	var n: int = _alloc_samples(0.18)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = 987.77 if t < 0.34 else 1318.51 # B5 -> E6 crisp retro coin chime
		phase += TAU * freq / SAMPLE_RATE
		var env: float = exp(-t * 5.2) * minf(1.0, t * 40.0)
		var s: float = (sin(phase) * 0.7 + sin(phase * 2.0) * 0.2) * env * 0.52
		out[i] = Vector2(s, s)
	return out


func _bake_craft() -> PackedVector2Array:
	var n: int = _alloc_samples(0.16)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var sec: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 6.5)
		var ring: float = sin(TAU * 784.0 * sec) * 0.45 + sin(TAU * 1175.0 * sec) * 0.30
		var tap: float = _rng.randf_range(-1.0, 1.0) * exp(-t * 24.0) * 0.35
		var s: float = (ring + tap) * env * 0.58
		out[i] = Vector2(s, s)
	return out


func _bake_place() -> PackedVector2Array:
	var n: int = _alloc_samples(0.09)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(210.0, 110.0, t)
		phase += TAU * freq / SAMPLE_RATE
		var s: float = sin(phase) * (1.0 - t) * 0.62
		out[i] = Vector2(s, s)
	return out


func _bake_sword_hit() -> PackedVector2Array:
	var n: int = _alloc_samples(0.13)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var sec: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 7.5)
		var freq: float = lerpf(420.0, 120.0, minf(1.0, t * 2.5))
		phase += TAU * freq / SAMPLE_RATE
		var clank: float = sin(TAU * 1140.0 * sec) * exp(-t * 14.0) * 0.42
		var impact: float = sin(phase) * 0.55 + _rng.randf_range(-1.0, 1.0) * exp(-t * 18.0) * 0.38
		var s: float = clampf((impact + clank) * env * 0.72, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out


func _bake_enemy_die() -> PackedVector2Array:
	var n: int = _alloc_samples(0.24)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(480.0, 110.0, t)
		phase += TAU * freq / SAMPLE_RATE
		var rattle: float = _rng.randf_range(-1.0, 1.0) * (0.25 + 0.25 * sin(t * 48.0))
		var s: float = clampf((sin(phase) * 0.45 + rattle) * (1.0 - t) * 0.65, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out


func _bake_player_hurt() -> PackedVector2Array:
	var n: int = _alloc_samples(0.18)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(210.0, 72.0, t)
		phase += TAU * freq / SAMPLE_RATE
		var grit: float = _rng.randf_range(-1.0, 1.0) * exp(-t * 10.0) * 0.35
		var s: float = clampf((sin(phase) * 0.65 + grit) * (1.0 - t) * 0.72, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out


func _bake_festival() -> PackedVector2Array:
	var n: int = _alloc_samples(0.32)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = 523.25 if t < 0.30 else (659.25 if t < 0.60 else 783.99)
		phase += TAU * freq / SAMPLE_RATE
		var env: float = (1.0 - 0.55 * t) * minf(1.0, t * 25.0)
		var s: float = (sin(phase) * 0.65 + sin(phase * 2.0) * 0.18) * env * 0.55
		out[i] = Vector2(s, s)
	return out


func _bake_save() -> PackedVector2Array:
	var n: int = _alloc_samples(0.20)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var freq: float = 587.33 if t < 0.45 else 880.0
		phase += TAU * freq / SAMPLE_RATE
		var env: float = exp(-t * 4.5) * minf(1.0, t * 30.0)
		var s: float = sin(phase) * env * 0.50
		out[i] = Vector2(s, s)
	return out
