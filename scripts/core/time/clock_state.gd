class_name ClockState
extends RefCounted

const SECONDS_PER_DAY: float = 24.0 * 60.0 * 60.0
const DAYS_PER_SEASON: int = 30

var season: int
var day_of_season: int
var time_of_day_seconds: float
var year: int

func _init(p_season: int, p_day_of_season: int, p_time_of_day_seconds: float, p_year: int = 1) -> void:
	assert(p_day_of_season >= 1 and p_day_of_season <= DAYS_PER_SEASON, "day_of_season out of range")
	assert(p_time_of_day_seconds >= 0.0 and p_time_of_day_seconds < SECONDS_PER_DAY, "time_of_day_seconds out of range")
	assert(p_year > 0, "year must be positive")
	season = p_season
	day_of_season = p_day_of_season
	time_of_day_seconds = p_time_of_day_seconds
	year = p_year

func time_of_day_hours() -> float:
	return time_of_day_seconds / (60.0 * 60.0)

func day_progress() -> float:
	return time_of_day_seconds / SECONDS_PER_DAY

func get_days_until_season(target_season: int) -> int:
	if season == target_season:
		return 0
	var days_remaining: int = (DAYS_PER_SEASON - day_of_season) + 1
	var cursor: int = _get_next_season(season)
	while cursor != target_season:
		days_remaining += DAYS_PER_SEASON
		cursor = _get_next_season(cursor)
	return days_remaining

func advance(delta_seconds: float) -> void:
	assert(delta_seconds >= 0.0, "delta_seconds must be non-negative")
	time_of_day_seconds += delta_seconds
	while time_of_day_seconds >= SECONDS_PER_DAY:
		time_of_day_seconds -= SECONDS_PER_DAY
		_advance_day()

func _advance_day() -> void:
	day_of_season += 1
	if day_of_season <= DAYS_PER_SEASON:
		return
	day_of_season = 1
	var previous_season: int = season
	season = _get_next_season(season)
	if previous_season == Season.Kind.SPRING:
		year += 1

static func _get_next_season(s: int) -> int:
	match s:
		Season.Kind.SUMMER:
			return Season.Kind.AUTUMN
		Season.Kind.AUTUMN:
			return Season.Kind.WINTER
		Season.Kind.WINTER:
			return Season.Kind.SPRING
		_:
			return Season.Kind.SUMMER
