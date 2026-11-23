@tool
class_name StripSprite2D
extends Sprite2D

## Zero-allocation horizontal strip animator for Sunnyside World *_stripN.png assets.
## Slices by hframes = frame_count, vframes = 1; renders frame 0 live in the Godot 4.7 2D Editor.

@export var frame_rate: float = 5.0
@export var random_start_phase: bool = false
@export var phase_seed: int = 0

var _elapsed: float = 0.0
var _frame_duration: float = 0.2


func _ready() -> void:
	if hframes < 1:
		hframes = 1
	vframes = 1
	if Engine.is_editor_hint():
		frame = 0
		return
	assert(frame_rate > 0.0, "StripSprite2D requires frame_rate > 0.0")
	_frame_duration = 1.0 / frame_rate
	if random_start_phase and hframes > 1:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = phase_seed if phase_seed != 0 else int(global_position.x * 73.0 + global_position.y * 197.0)
		frame = rng.randi_range(0, hframes - 1)
		_elapsed = rng.randf_range(0.0, _frame_duration)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or hframes <= 1 or not visible:
		return
	_elapsed += minf(delta, 0.1)
	if _elapsed >= _frame_duration:
		var advance: int = int(_elapsed / _frame_duration)
		_elapsed -= float(advance) * _frame_duration
		frame = (frame + advance) % hframes
