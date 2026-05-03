extends SceneTree

const ClockStateScript = preload("res://scripts/core/time/clock_state.gd")
const SeasonScript = preload("res://scripts/core/time/season.gd")
const GameBalanceScript = preload("res://scripts/core/simulation/game_balance.gd")

func _init() -> void:
	_test_advance_crossing_day_boundary_rolls_into_next_season()
	_test_advance_with_configured_scale_advances_one_full_day_in_two_real_minutes()
	_test_get_days_until_winter_from_summer_start_returns_sixty_days()
	print("test_clock_state: ok")
	quit(0)

func _test_advance_crossing_day_boundary_rolls_into_next_season() -> void:
	var clock: ClockState = ClockStateScript.new(
		SeasonScript.Kind.SUMMER,
		ClockStateScript.DAYS_PER_SEASON,
		ClockStateScript.SECONDS_PER_DAY - 60.0)
	clock.advance(120.0)
	assert(clock.season == SeasonScript.Kind.AUTUMN, "expected autumn after rollover")
	assert(clock.day_of_season == 1, "expected day 1, got %d" % clock.day_of_season)
	assert(absf(clock.time_of_day_seconds - 60.0) < 0.001,
		"expected 60.0s leftover, got %f" % clock.time_of_day_seconds)

func _test_advance_with_configured_scale_advances_one_full_day_in_two_real_minutes() -> void:
	var clock: ClockState = ClockStateScript.new(
		SeasonScript.Kind.SUMMER,
		1,
		6.0 * 60.0 * 60.0)
	clock.advance(2.0 * 60.0 * GameBalanceScript.CLOCK_SECONDS_PER_REAL_SECOND)
	assert(clock.season == SeasonScript.Kind.SUMMER, "expected still summer")
	assert(clock.day_of_season == 2, "expected day 2, got %d" % clock.day_of_season)
	assert(absf(clock.time_of_day_hours() - 6.0) < 0.001,
		"expected 06:00, got %f" % clock.time_of_day_hours())

func _test_get_days_until_winter_from_summer_start_returns_sixty_days() -> void:
	var clock: ClockState = ClockStateScript.new(SeasonScript.Kind.SUMMER, 1, 0.0)
	var days: int = clock.get_days_until_season(SeasonScript.Kind.WINTER)
	assert(days == 60, "expected 60 days to winter, got %d" % days)
