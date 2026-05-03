extends SceneTree

const ClockStateScript = preload("res://scripts/core/time/clock_state.gd")
const SeasonScript = preload("res://scripts/core/time/season.gd")
const DayNightCycleScript = preload("res://scripts/core/time/day_night_cycle.gd")

func _init() -> void:
	_test_middle_day_light_hours_match_seasonal_anchors()
	_test_light_hours_interpolate_linearly_between_seasons()
	_test_brightness_zero_at_midnight_one_at_noon()
	_test_phase_progression_through_a_day()
	_test_summer_day_is_longer_than_winter_day_at_same_time()
	print("test_day_night_cycle: ok")
	quit(0)

func _test_middle_day_light_hours_match_seasonal_anchors() -> void:
	_assert_close(
		DayNightCycleScript.get_light_hours(SeasonScript.Kind.SUMMER, 15), 16.0,
		"summer middle day expected 16h light")
	_assert_close(
		DayNightCycleScript.get_light_hours(SeasonScript.Kind.WINTER, 15), 8.0,
		"winter middle day expected 8h light")
	_assert_close(
		DayNightCycleScript.get_light_hours(SeasonScript.Kind.SPRING, 15), 12.0,
		"spring middle day expected 12h light")
	_assert_close(
		DayNightCycleScript.get_light_hours(SeasonScript.Kind.AUTUMN, 15), 12.0,
		"autumn middle day expected 12h light")

func _test_light_hours_interpolate_linearly_between_seasons() -> void:
	# Halfway from summer mid (16h) to autumn mid (12h) → 14h.
	# That's day 30 of summer (15 days past summer middle).
	_assert_close(
		DayNightCycleScript.get_light_hours(SeasonScript.Kind.SUMMER, 30), 14.0,
		"summer day 30 expected 14h light (linear lerp summer↔autumn)")
	# Halfway between winter (8h) and spring (12h) is winter day 30 → 10h.
	_assert_close(
		DayNightCycleScript.get_light_hours(SeasonScript.Kind.WINTER, 30), 10.0,
		"winter day 30 expected 10h light (linear lerp winter↔spring)")

func _test_brightness_zero_at_midnight_one_at_noon() -> void:
	var midnight: ClockState = ClockStateScript.new(SeasonScript.Kind.SPRING, 15, 0.0)
	var noon: ClockState = ClockStateScript.new(SeasonScript.Kind.SPRING, 15, 12.0 * 3600.0)
	_assert_close(DayNightCycleScript.get_brightness(midnight), 0.0,
		"expected brightness 0 at midnight")
	_assert_close(DayNightCycleScript.get_brightness(noon), 1.0,
		"expected brightness 1 at noon")

func _test_phase_progression_through_a_day() -> void:
	# Spring middle day: light 12h spans 06-18, with transitions 06-08 and 16-18.
	_assert_phase(SeasonScript.Kind.SPRING, 15, 3.0, DayNightCycleScript.Phase.NIGHT,
		"spring 03:00 should be night")
	_assert_phase(SeasonScript.Kind.SPRING, 15, 6.5, DayNightCycleScript.Phase.SUNRISE,
		"spring 06:30 should be sunrise transition")
	_assert_phase(SeasonScript.Kind.SPRING, 15, 12.0, DayNightCycleScript.Phase.DAY,
		"spring noon should be full day")
	_assert_phase(SeasonScript.Kind.SPRING, 15, 17.0, DayNightCycleScript.Phase.SUNSET,
		"spring 17:00 should be sunset transition")
	_assert_phase(SeasonScript.Kind.SPRING, 15, 22.0, DayNightCycleScript.Phase.NIGHT,
		"spring 22:00 should be night")

func _test_summer_day_is_longer_than_winter_day_at_same_time() -> void:
	# At 05:00 the sun is already up in summer (sunrise center ~05:00) but not in winter.
	var summer_dawn: ClockState = ClockStateScript.new(SeasonScript.Kind.SUMMER, 15, 5.0 * 3600.0)
	var winter_dawn: ClockState = ClockStateScript.new(SeasonScript.Kind.WINTER, 15, 5.0 * 3600.0)
	var summer_b: float = DayNightCycleScript.get_brightness(summer_dawn)
	var winter_b: float = DayNightCycleScript.get_brightness(winter_dawn)
	assert(summer_b > winter_b,
		"expected summer brightness (%f) > winter brightness (%f) at 05:00 mid-season day"
			% [summer_b, winter_b])
	assert(winter_b == 0.0, "expected winter to still be night at 05:00, got %f" % winter_b)

func _assert_phase(season: int, day: int, hour: float, expected_phase: int, message: String) -> void:
	var clock: ClockState = ClockStateScript.new(season, day, hour * 3600.0)
	var actual: int = DayNightCycleScript.get_phase(clock)
	assert(actual == expected_phase,
		"%s — expected phase %d, got %d" % [message, expected_phase, actual])

func _assert_close(actual: float, expected: float, message: String) -> void:
	assert(absf(actual - expected) < 0.001, "%s — expected %f, got %f" % [message, expected, actual])
