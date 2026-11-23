extends Node

## Manages player Vitality (stamina: 100 max, 2 cost per tool swing) and Exhausted speed debuff at 0.

const MAX_VITALITY: float = 100.0
const DEFAULT_TOOL_COST: float = 2.0
const EXHAUSTED_SPEED_MULTIPLIER: float = 0.55

var current_vitality: float = MAX_VITALITY
var is_exhausted: bool = false


func _ready() -> void:
	current_vitality = MAX_VITALITY
	is_exhausted = false


func consume(amount: float = DEFAULT_TOOL_COST) -> bool:
	assert(amount >= 0.0, "Vitality consume amount must be non-negative.")
	if amount == 0.0:
		return true
	var prev_exhausted: bool = is_exhausted
	current_vitality = maxf(0.0, current_vitality - amount)
	is_exhausted = current_vitality <= 0.0
	EventBus.vitality_changed.emit(current_vitality, MAX_VITALITY)
	if is_exhausted != prev_exhausted:
		EventBus.exhaustion_changed.emit(is_exhausted)
	return not is_exhausted


func restore(amount: float) -> void:
	assert(amount >= 0.0, "Vitality restore amount must be non-negative.")
	var prev_exhausted: bool = is_exhausted
	current_vitality = minf(MAX_VITALITY, current_vitality + amount)
	is_exhausted = current_vitality <= 0.0
	EventBus.vitality_changed.emit(current_vitality, MAX_VITALITY)
	if is_exhausted != prev_exhausted:
		EventBus.exhaustion_changed.emit(is_exhausted)


func restore_full() -> void:
	var prev_exhausted: bool = is_exhausted
	current_vitality = MAX_VITALITY
	is_exhausted = false
	EventBus.vitality_changed.emit(current_vitality, MAX_VITALITY)
	if is_exhausted != prev_exhausted:
		EventBus.exhaustion_changed.emit(is_exhausted)


func get_ratio() -> float:
	return clampf(current_vitality / MAX_VITALITY, 0.0, 1.0)


func get_speed_multiplier() -> float:
	return EXHAUSTED_SPEED_MULTIPLIER if is_exhausted else 1.0


func serialize() -> Dictionary:
	return {
		"current": current_vitality,
		"exhausted": is_exhausted,
	}


func deserialize(data: Dictionary) -> void:
	current_vitality = clampf(float(data.get("current", MAX_VITALITY)), 0.0, MAX_VITALITY)
	is_exhausted = bool(data.get("exhausted", current_vitality <= 0.0))
	EventBus.vitality_changed.emit(current_vitality, MAX_VITALITY)
	EventBus.exhaustion_changed.emit(is_exhausted)
