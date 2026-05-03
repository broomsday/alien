class_name DayNightCycle
extends RefCounted

# Daylight schedule:
#   * Spring/Autumn middle day (day 15): 12 hours light + 12 hours dark.
#   * Summer middle day: 16 hours light + 8 hours dark.
#   * Winter middle day: 8 hours light + 16 hours dark.
# Each transition (sunrise / sunset) spans TRANSITION_HOURS, centered such that
# brightness ramps from 0->1 across sunrise and 1->0 across sunset. The "light"
# count includes the transition windows on both ends.

const TRANSITION_HOURS: float = 2.0

const SUMMER_MID_LIGHT_HOURS: float = 16.0
const AUTUMN_MID_LIGHT_HOURS: float = 12.0
const WINTER_MID_LIGHT_HOURS: float = 8.0
const SPRING_MID_LIGHT_HOURS: float = 12.0

const _MIDDLE_DAY_OFFSET: float = 14.0  # day 15 -> zero-based offset 14

enum Phase {
	NIGHT,
	SUNRISE,
	DAY,
	SUNSET,
}

static func get_light_hours(season: int, day_of_season: int) -> float:
	assert(day_of_season >= 1 and day_of_season <= ClockState.DAYS_PER_SEASON,
		"day_of_season out of range")
	var year_day: float = float(_season_to_index(season) * ClockState.DAYS_PER_SEASON
		+ (day_of_season - 1))
	return _interpolate_light_hours(year_day)

static func get_brightness(clock: ClockState) -> float:
	assert(clock != null, "clock required")
	var light_hours: float = get_light_hours(clock.season, clock.day_of_season)
	return _compute_brightness(clock.time_of_day_hours(), light_hours)

static func get_phase(clock: ClockState) -> int:
	assert(clock != null, "clock required")
	var light_hours: float = get_light_hours(clock.season, clock.day_of_season)
	var t: float = clock.time_of_day_hours()
	var sunrise_center: float = 12.0 - (light_hours - TRANSITION_HOURS) * 0.5
	var sunset_center: float = 12.0 + (light_hours - TRANSITION_HOURS) * 0.5
	var half: float = TRANSITION_HOURS * 0.5
	if t < sunrise_center - half or t >= sunset_center + half:
		return Phase.NIGHT
	if t < sunrise_center + half:
		return Phase.SUNRISE
	if t < sunset_center - half:
		return Phase.DAY
	return Phase.SUNSET

static func get_sunrise_hour(clock: ClockState) -> float:
	var light_hours: float = get_light_hours(clock.season, clock.day_of_season)
	return 12.0 - (light_hours - TRANSITION_HOURS) * 0.5

static func get_sunset_hour(clock: ClockState) -> float:
	var light_hours: float = get_light_hours(clock.season, clock.day_of_season)
	return 12.0 + (light_hours - TRANSITION_HOURS) * 0.5

static func phase_label(phase: int) -> String:
	match phase:
		Phase.NIGHT:
			return "Night"
		Phase.SUNRISE:
			return "Sunrise"
		Phase.DAY:
			return "Day"
		Phase.SUNSET:
			return "Sunset"
		_:
			return "Day"

static func _season_to_index(season: int) -> int:
	# Mirror ClockState's progression: SUMMER -> AUTUMN -> WINTER -> SPRING.
	match season:
		Season.Kind.SUMMER:
			return 0
		Season.Kind.AUTUMN:
			return 1
		Season.Kind.WINTER:
			return 2
		Season.Kind.SPRING:
			return 3
		_:
			return 0

static func _interpolate_light_hours(year_day: float) -> float:
	var anchors: Array[float] = [
		SUMMER_MID_LIGHT_HOURS,
		AUTUMN_MID_LIGHT_HOURS,
		WINTER_MID_LIGHT_HOURS,
		SPRING_MID_LIGHT_HOURS,
	]
	var year_length: float = float(ClockState.DAYS_PER_SEASON * 4)
	var spacing: float = float(ClockState.DAYS_PER_SEASON)
	var pos: float = year_day - _MIDDLE_DAY_OFFSET
	pos = fposmod(pos, year_length)
	var segment_index: int = int(floor(pos / spacing)) % 4
	var t: float = (pos - float(segment_index) * spacing) / spacing
	return lerp(anchors[segment_index], anchors[(segment_index + 1) % 4], t)

static func _compute_brightness(time_of_day_hours: float, light_hours: float) -> float:
	# Center the light window on noon; transitions extend half-on-each-side of
	# sunrise/sunset and are counted INSIDE light_hours, so the daylight bracket
	# spans (sunrise_center - half, sunset_center + half) = light_hours wide.
	var half: float = TRANSITION_HOURS * 0.5
	var sunrise_center: float = 12.0 - (light_hours - TRANSITION_HOURS) * 0.5
	var sunset_center: float = 12.0 + (light_hours - TRANSITION_HOURS) * 0.5
	var sunrise_start: float = sunrise_center - half
	var sunrise_end: float = sunrise_center + half
	var sunset_start: float = sunset_center - half
	var sunset_end: float = sunset_center + half
	if time_of_day_hours < sunrise_start or time_of_day_hours >= sunset_end:
		return 0.0
	if time_of_day_hours < sunrise_end:
		return clampf((time_of_day_hours - sunrise_start) / TRANSITION_HOURS, 0.0, 1.0)
	if time_of_day_hours < sunset_start:
		return 1.0
	return clampf(1.0 - (time_of_day_hours - sunset_start) / TRANSITION_HOURS, 0.0, 1.0)
