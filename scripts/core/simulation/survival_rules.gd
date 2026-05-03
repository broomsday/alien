class_name SurvivalRules
extends RefCounted

const EnvironmentDangerLevelScript = preload("res://scripts/core/simulation/environment_danger_level.gd")

static func update(state: GameState, delta_seconds: float) -> void:
	assert(state != null, "state required")
	assert(delta_seconds >= 0.0, "delta_seconds must be non-negative")

	advance_outdoor_temperature(state, delta_seconds)

	var ambient_temperature: float = get_ambient_temperature(state)
	var ambient_gas: float = get_ambient_gas(state)
	var is_underground: bool = state.player.tile_position.y >= state.world.surface_row
	var is_indoors: bool = state.world.is_walkable(state.player.tile_position) \
			and state.world.is_indoors(state.player.tile_position)

	state.set_environment_status(ambient_temperature, is_indoors, is_underground, ambient_gas)

	state.player.drain_nutrition(GameBalance.NUTRITION_DECAY_PER_SECOND * delta_seconds)
	state.player.reduce_hygiene(GameBalance.HYGIENE_DECAY_PER_SECOND * delta_seconds)
	state.player.move_temperature_toward(
			ambient_temperature,
			_get_temperature_adjust_rate(state, is_indoors, is_underground),
			delta_seconds)
	_update_psyche(state, delta_seconds)

	if state.player.current_nutrition <= GameBalance.STARVATION_CRITICAL_THRESHOLD:
		state.player.apply_neglect_damage(GameBalance.STARVATION_DAMAGE_PER_SECOND * delta_seconds)
	if state.player.current_temperature <= GameBalance.HYPOTHERMIA_DAMAGE_THRESHOLD:
		state.player.apply_neglect_damage(GameBalance.HYPOTHERMIA_DAMAGE_PER_SECOND * delta_seconds)

static func try_consume_canned_food(state: GameState) -> bool:
	assert(state != null, "state required")
	if state.player.current_nutrition >= state.player.max_nutrition:
		return false
	if not state.inventory.try_remove(ItemId.Id.CANNED_FOOD, 1):
		return false
	state.player.restore_nutrition(GameBalance.CANNED_FOOD_NUTRITION_RESTORE)
	return true

static func get_danger_level(state: GameState) -> int:
	assert(state != null, "state required")
	if not state.player.is_alive():
		return EnvironmentDangerLevelScript.Kind.DEAD
	if state.player.current_temperature <= GameBalance.HYPOTHERMIA_DAMAGE_THRESHOLD:
		return EnvironmentDangerLevelScript.Kind.CRITICAL_COLD

	var ambient_temperature: float = get_ambient_temperature(state)
	if ambient_temperature <= GameBalance.COLD_AMBIENT_WARNING_THRESHOLD:
		return EnvironmentDangerLevelScript.Kind.WINTER_EXPOSURE
	if state.clock.season != Season.Kind.WINTER \
			and state.clock.get_days_until_season(Season.Kind.WINTER) <= GameBalance.PREPARE_FOR_WINTER_DAYS:
		return EnvironmentDangerLevelScript.Kind.PREPARE_FOR_WINTER
	return EnvironmentDangerLevelScript.Kind.STABLE

static func get_outdoor_temperature(state: GameState) -> float:
	assert(state != null, "state required")
	return state.current_outdoor_temperature

static func get_ambient_gas(state: GameState) -> float:
	assert(state != null, "state required")
	return 0.0

static func get_ambient_temperature(state: GameState) -> float:
	assert(state != null, "state required")
	if state.active_action != null and state.active_action.kind == GameActionKind.Kind.EXPEDITION:
		var expedition_ambient: float = state.current_outdoor_temperature
		if state.clock.season == Season.Kind.WINTER:
			expedition_ambient -= GameBalance.WINTER_EXPEDITION_WINDCHILL
		return expedition_ambient

	var player_tile: Vector2i = state.player.tile_position
	var is_underground: bool = player_tile.y >= state.world.surface_row
	var is_indoors: bool = state.world.is_walkable(player_tile) and state.world.is_indoors(player_tile)

	if is_underground:
		return min(100.0,
				_get_underground_ambient_temperature(state.clock.season, is_indoors)
				+ state.get_furnace_heat_bonus(player_tile))
	return min(100.0,
			state.current_outdoor_temperature
			+ state.get_furnace_heat_bonus(player_tile))

static func bootstrap_outdoor_temperature(state: GameState) -> void:
	assert(state != null, "state required")
	state.current_outdoor_temperature = _get_seasonal_initial_outdoor_temperature(state.clock.season)

static func advance_outdoor_temperature(state: GameState, delta_seconds: float) -> void:
	assert(state != null, "state required")
	assert(delta_seconds >= 0.0, "delta_seconds must be non-negative")
	if delta_seconds == 0.0:
		return
	var brightness: float = DayNightCycle.get_brightness(state.clock)
	var warm_rate: float = _get_seasonal_warm_rate(state.clock.season)
	var cool_rate: float = _get_seasonal_cool_rate(state.clock.season)
	var rate_per_hour: float = brightness * warm_rate - (1.0 - brightness) * cool_rate
	var game_hours: float = (delta_seconds * GameBalance.CLOCK_SECONDS_PER_REAL_SECOND) / 3600.0
	var floor_temp: float = _get_seasonal_floor_temperature(state.clock.season)
	var ceiling_temp: float = _get_seasonal_ceiling_temperature(state.clock.season)
	state.current_outdoor_temperature = clampf(
		state.current_outdoor_temperature + rate_per_hour * game_hours,
		floor_temp,
		ceiling_temp)

static func _get_temperature_adjust_rate(state: GameState, is_indoors: bool, is_underground: bool) -> float:
	if state.active_action != null and state.active_action.kind == GameActionKind.Kind.EXPEDITION:
		return GameBalance.EXPEDITION_TEMPERATURE_ADJUST_RATE_PER_SECOND
	if is_indoors:
		return GameBalance.SHELTERED_TEMPERATURE_ADJUST_RATE_PER_SECOND
	if is_underground:
		return GameBalance.UNDERGROUND_TEMPERATURE_ADJUST_RATE_PER_SECOND
	return GameBalance.SURFACE_TEMPERATURE_ADJUST_RATE_PER_SECOND

static func _update_psyche(state: GameState, delta_seconds: float) -> void:
	var penalty_per_second: float = 0.0
	if state.player.current_nutrition <= GameBalance.LOW_NUTRITION_PSYCHE_THRESHOLD:
		penalty_per_second += GameBalance.LOW_NUTRITION_PSYCHE_PENALTY_PER_SECOND
	if state.player.current_temperature <= GameBalance.LOW_TEMPERATURE_PSYCHE_THRESHOLD:
		penalty_per_second += GameBalance.LOW_TEMPERATURE_PSYCHE_PENALTY_PER_SECOND
	if state.player.current_hygiene <= GameBalance.LOW_HYGIENE_PSYCHE_THRESHOLD:
		penalty_per_second += GameBalance.LOW_HYGIENE_PSYCHE_PENALTY_PER_SECOND
	if penalty_per_second > 0.0:
		state.player.reduce_psyche(penalty_per_second * delta_seconds)
		return
	state.player.restore_psyche(GameBalance.BASE_PSYCHE_RECOVERY_PER_SECOND * delta_seconds)

static func _get_underground_ambient_temperature(season: int, is_indoors: bool) -> float:
	match season:
		Season.Kind.SUMMER:
			return GameBalance.SUMMER_UNDERGROUND_INDOORS_AMBIENT if is_indoors else GameBalance.SUMMER_UNDERGROUND_OPEN_AMBIENT
		Season.Kind.AUTUMN:
			return GameBalance.AUTUMN_UNDERGROUND_INDOORS_AMBIENT if is_indoors else GameBalance.AUTUMN_UNDERGROUND_OPEN_AMBIENT
		Season.Kind.WINTER:
			return GameBalance.WINTER_UNDERGROUND_INDOORS_AMBIENT if is_indoors else GameBalance.WINTER_UNDERGROUND_OPEN_AMBIENT
		Season.Kind.SPRING:
			return GameBalance.SPRING_UNDERGROUND_INDOORS_AMBIENT if is_indoors else GameBalance.SPRING_UNDERGROUND_OPEN_AMBIENT
		_:
			return 44.0

static func _get_seasonal_initial_outdoor_temperature(season: int) -> float:
	match season:
		Season.Kind.SUMMER:
			return GameBalance.SUMMER_OUTDOOR_INITIAL_TEMP
		Season.Kind.AUTUMN:
			return GameBalance.AUTUMN_OUTDOOR_INITIAL_TEMP
		Season.Kind.WINTER:
			return GameBalance.WINTER_OUTDOOR_INITIAL_TEMP
		Season.Kind.SPRING:
			return GameBalance.SPRING_OUTDOOR_INITIAL_TEMP
		_:
			return 50.0

static func _get_seasonal_floor_temperature(season: int) -> float:
	match season:
		Season.Kind.SUMMER:
			return GameBalance.SUMMER_OUTDOOR_FLOOR
		Season.Kind.AUTUMN:
			return GameBalance.AUTUMN_OUTDOOR_FLOOR
		Season.Kind.WINTER:
			return GameBalance.WINTER_OUTDOOR_FLOOR
		Season.Kind.SPRING:
			return GameBalance.SPRING_OUTDOOR_FLOOR
		_:
			return 0.0

static func _get_seasonal_ceiling_temperature(season: int) -> float:
	match season:
		Season.Kind.SUMMER:
			return GameBalance.SUMMER_OUTDOOR_CEILING
		Season.Kind.AUTUMN:
			return GameBalance.AUTUMN_OUTDOOR_CEILING
		Season.Kind.WINTER:
			return GameBalance.WINTER_OUTDOOR_CEILING
		Season.Kind.SPRING:
			return GameBalance.SPRING_OUTDOOR_CEILING
		_:
			return 100.0

static func _get_seasonal_warm_rate(season: int) -> float:
	match season:
		Season.Kind.SUMMER:
			return GameBalance.SUMMER_WARM_RATE_PER_HOUR
		Season.Kind.AUTUMN:
			return GameBalance.AUTUMN_WARM_RATE_PER_HOUR
		Season.Kind.WINTER:
			return GameBalance.WINTER_WARM_RATE_PER_HOUR
		Season.Kind.SPRING:
			return GameBalance.SPRING_WARM_RATE_PER_HOUR
		_:
			return 0.0

static func _get_seasonal_cool_rate(season: int) -> float:
	match season:
		Season.Kind.SUMMER:
			return GameBalance.SUMMER_COOL_RATE_PER_HOUR
		Season.Kind.AUTUMN:
			return GameBalance.AUTUMN_COOL_RATE_PER_HOUR
		Season.Kind.WINTER:
			return GameBalance.WINTER_COOL_RATE_PER_HOUR
		Season.Kind.SPRING:
			return GameBalance.SPRING_COOL_RATE_PER_HOUR
		_:
			return 0.0
