extends Node

## Manages Pebblefern's clock (06:00 AM - 02:00 AM, 0.7s per in-game minute, 10-min HUD ticks),
## 28-day 4-season calendar (Bloom, Sun, Harvest, Frost), deterministic weather, and day transitions.

const SEASON_NAMES: PackedStringArray = ["Bloom", "Sun", "Harvest", "Frost"]
const DAYS_PER_SEASON: int = 28
const SEASONS_PER_YEAR: int = 4

const START_MINUTE: int = 6 * 60       # 06:00 AM (360)
const PASS_OUT_MINUTE: int = 26 * 60   # 02:00 AM next calendar day (1560)
const SECONDS_PER_GAME_MINUTE: float = 0.7
const HUD_TICK_MINUTES: int = 10
const MAX_SIM_STEPS_PER_FRAME: int = 16

const WEATHER_SUNNY: StringName = &"sunny"
const WEATHER_RAIN: StringName = &"rain"
const WEATHER_SNOW: StringName = &"snow"

var current_year: int = 1
var current_season: int = 0 # 0=Bloom, 1=Sun, 2=Harvest, 3=Frost
var current_day: int = 1    # 1..28
var current_weather: StringName = WEATHER_SUNNY

var _minute_of_day: int = START_MINUTE
var _minute_accum: float = 0.0
var _last_hud_bucket: int = START_MINUTE
var _is_paused: bool = false
var _is_transitioning_day: bool = false
var _pass_out_emitted: bool = false
var _weather_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_weather_rng.seed = 20260407
	reset_to_day_one()


func reset_to_day_one() -> void:
	current_year = 1
	current_season = 0
	current_day = 1
	current_weather = WEATHER_SUNNY
	_minute_of_day = START_MINUTE
	_minute_accum = 0.0
	_last_hud_bucket = START_MINUTE
	_is_paused = false
	_is_transitioning_day = false
	_pass_out_emitted = false
	_emit_time_tick()
	EventBus.day_started.emit(current_day, current_season, current_year, current_weather)


func _process(delta: float) -> void:
	if _is_paused or _is_transitioning_day or _pass_out_emitted:
		return
	var dt: float = minf(delta, 0.25)
	_minute_accum += dt
	var steps: int = 0
	while _minute_accum >= SECONDS_PER_GAME_MINUTE and steps < MAX_SIM_STEPS_PER_FRAME:
		_minute_accum -= SECONDS_PER_GAME_MINUTE
		_minute_of_day += 1
		steps += 1

		var bucket: int = floori(float(_minute_of_day) / float(HUD_TICK_MINUTES)) * HUD_TICK_MINUTES
		if bucket != _last_hud_bucket:
			_last_hud_bucket = bucket
			_emit_time_tick()

		if _minute_of_day >= PASS_OUT_MINUTE:
			_minute_of_day = PASS_OUT_MINUTE
			_pass_out_emitted = true
			_emit_time_tick()
			EventBus.pass_out_triggered.emit()
			break


func set_paused(paused: bool) -> void:
	_is_paused = paused


func is_paused() -> bool:
	return _is_paused


func is_transitioning_day() -> bool:
	return _is_transitioning_day


func get_season_name(season_idx: int = -1) -> String:
	var idx: int = current_season if season_idx < 0 else season_idx
	assert(idx >= 0 and idx < SEASON_NAMES.size(), "Season index out of bounds: %d" % idx)
	return SEASON_NAMES[idx]


func get_hour() -> int:
	return floori(float(_minute_of_day) / 60.0) % 24


func get_minute() -> int:
	return _minute_of_day % 60


func get_hud_minute() -> int:
	return floori(float(_minute_of_day % 60) / float(HUD_TICK_MINUTES)) * HUD_TICK_MINUTES


func get_minute_of_day() -> int:
	return _minute_of_day


## Returns continuous floating hour in [6.0 .. 26.0] (e.g. 24.5 = 12:30 AM) for smooth lighting gradients.
func get_hour_float() -> float:
	return (float(_minute_of_day) + (_minute_accum / SECONDS_PER_GAME_MINUTE)) / 60.0


## Returns normalized day progress in [0.0 .. 1.0] from 06:00 AM to 02:00 AM.
func get_day_progress() -> float:
	var span: float = float(PASS_OUT_MINUTE - START_MINUTE)
	return clampf((float(_minute_of_day - START_MINUTE) + (_minute_accum / SECONDS_PER_GAME_MINUTE)) / span, 0.0, 1.0)


func get_formatted_time() -> String:
	var hr24: int = get_hour()
	var mn: int = get_hud_minute()
	var suffix: String = "AM" if hr24 < 12 else "PM"
	var hr12: int = hr24 % 12
	if hr12 == 0:
		hr12 = 12
	return "%02d:%02d %s" % [hr12, mn, suffix]


func get_formatted_date() -> String:
	return "%s %d" % [get_season_name(), current_day]


func is_raining() -> bool:
	return current_weather == WEATHER_RAIN


func is_snowing() -> bool:
	return current_weather == WEATHER_SNOW


## Directly sets the time of day (hours in [6..26], minutes in [0..59]) for deterministic tests and lighting previews.
func set_time(hour_extended: int, minute: int = 0) -> void:
	var target_min: int = clampi(hour_extended * 60 + clampi(minute, 0, 59), START_MINUTE, PASS_OUT_MINUTE)
	_minute_of_day = target_min
	_minute_accum = 0.0
	_last_hud_bucket = floori(float(_minute_of_day) / float(HUD_TICK_MINUTES)) * HUD_TICK_MINUTES
	_pass_out_emitted = _minute_of_day >= PASS_OUT_MINUTE
	_emit_time_tick()


func set_season(season_idx: int) -> void:
	var clamped: int = clampi(season_idx, 0, SEASONS_PER_YEAR - 1)
	if clamped == current_season:
		return
	current_season = clamped
	if current_season == 3 and current_weather == WEATHER_RAIN:
		set_weather(WEATHER_SNOW)
	elif current_season != 3 and current_weather == WEATHER_SNOW:
		set_weather(WEATHER_SUNNY)
	EventBus.season_changed.emit(current_season)
	_emit_time_tick()


func set_weather(new_weather: StringName) -> void:
	assert(
		new_weather == WEATHER_SUNNY or new_weather == WEATHER_RAIN or new_weather == WEATHER_SNOW,
		"Invalid weather type: %s" % String(new_weather)
	)
	if new_weather == current_weather:
		return
	current_weather = new_weather
	EventBus.weather_changed.emit(current_weather)


func seed_weather_rng(new_seed: int) -> void:
	_weather_rng.seed = new_seed


## Atomically advances to the next morning (06:00 AM), guarded by a strict transition lock.
## Grows watered crops, withers out-of-season crops, auto-waters soil on rainy mornings, and restores Vitality.
func sleep_to_next_day(forced_weather: StringName = &"") -> bool:
	if _is_transitioning_day:
		return false
	_is_transitioning_day = true

	var prev_season: int = current_season
	current_day += 1
	if current_day > DAYS_PER_SEASON:
		current_day = 1
		current_season = (current_season + 1) % SEASONS_PER_YEAR
		if current_season == 0:
			current_year += 1

	if forced_weather != &"":
		current_weather = forced_weather
	else:
		current_weather = _roll_weather_for_season(current_season)

	_minute_of_day = START_MINUTE
	_minute_accum = 0.0
	_last_hud_bucket = START_MINUTE
	_pass_out_emitted = false

	# Advance persistent world crops & soil moisture across all scenes, then restore Vitality
	GridStateManager.advance_day(current_season, is_raining())
	VitalitySystem.restore_full()

	_is_transitioning_day = false

	if current_season != prev_season:
		EventBus.season_changed.emit(current_season)
	EventBus.weather_changed.emit(current_weather)
	EventBus.day_started.emit(current_day, current_season, current_year, current_weather)
	_emit_time_tick()
	return true


func _roll_weather_for_season(season_idx: int) -> StringName:
	var roll: float = _weather_rng.randf()
	match season_idx:
		0: # Bloom
			return WEATHER_RAIN if roll < 0.28 else WEATHER_SUNNY
		1: # Sun
			return WEATHER_RAIN if roll < 0.18 else WEATHER_SUNNY
		2: # Harvest
			return WEATHER_RAIN if roll < 0.25 else WEATHER_SUNNY
		3: # Frost
			return WEATHER_SNOW if roll < 0.40 else WEATHER_SUNNY
		_:
			return WEATHER_SUNNY


func _emit_time_tick() -> void:
	EventBus.time_ticked.emit(current_day, current_season, get_hour(), get_hud_minute())


func serialize() -> Dictionary:
	return {
		"year": current_year,
		"season": current_season,
		"day": current_day,
		"minute_of_day": _minute_of_day,
		"weather": String(current_weather),
	}


func deserialize(data: Dictionary) -> void:
	current_year = maxi(1, int(data.get("year", 1)))
	current_season = clampi(int(data.get("season", 0)), 0, SEASONS_PER_YEAR - 1)
	current_day = clampi(int(data.get("day", 1)), 1, DAYS_PER_SEASON)
	_minute_of_day = clampi(int(data.get("minute_of_day", START_MINUTE)), START_MINUTE, PASS_OUT_MINUTE)
	_minute_accum = 0.0
	_last_hud_bucket = floori(float(_minute_of_day) / float(HUD_TICK_MINUTES)) * HUD_TICK_MINUTES
	_pass_out_emitted = false
	_is_transitioning_day = false
	var w_str: String = String(data.get("weather", "sunny"))
	if w_str == "rain":
		current_weather = WEATHER_RAIN
	elif w_str == "snow":
		current_weather = WEATHER_SNOW
	else:
		current_weather = WEATHER_SUNNY
	EventBus.season_changed.emit(current_season)
	EventBus.weather_changed.emit(current_weather)
	EventBus.day_started.emit(current_day, current_season, current_year, current_weather)
	_emit_time_tick()
