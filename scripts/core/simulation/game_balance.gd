class_name GameBalance
extends RefCounted

# Calendar pacing.
const CLOCK_SECONDS_PER_REAL_SECOND: float = 720.0
const PREPARE_FOR_WINTER_DAYS: int = 10

# Survival decay and recovery.
const NUTRITION_DECAY_PER_SECOND: float = 0.12
const CANNED_FOOD_NUTRITION_RESTORE: float = 35.0
const STARVATION_CRITICAL_THRESHOLD: float = 5.0
const STARVATION_DAMAGE_PER_SECOND: float = 3.0
const HYPOTHERMIA_DAMAGE_THRESHOLD: float = 20.0
const HYPOTHERMIA_DAMAGE_PER_SECOND: float = 2.5
const HYGIENE_DECAY_PER_SECOND: float = 0.03
const BASE_PSYCHE_RECOVERY_PER_SECOND: float = 0.08
const LOW_NUTRITION_PSYCHE_PENALTY_PER_SECOND: float = 0.18
const LOW_TEMPERATURE_PSYCHE_PENALTY_PER_SECOND: float = 0.22
const LOW_HYGIENE_PSYCHE_PENALTY_PER_SECOND: float = 0.10

# Temperature warning thresholds.
const COLD_AMBIENT_WARNING_THRESHOLD: float = 12.0
const LOW_NUTRITION_PSYCHE_THRESHOLD: float = 25.0
const LOW_TEMPERATURE_PSYCHE_THRESHOLD: float = 35.0
const LOW_HYGIENE_PSYCHE_THRESHOLD: float = 30.0

# Body-temperature adjustment rates.
const SURFACE_TEMPERATURE_ADJUST_RATE_PER_SECOND: float = 2.5
const EXPEDITION_TEMPERATURE_ADJUST_RATE_PER_SECOND: float = 4.0
const SHELTERED_TEMPERATURE_ADJUST_RATE_PER_SECOND: float = 1.8
const UNDERGROUND_TEMPERATURE_ADJUST_RATE_PER_SECOND: float = 2.2

# Outdoor temperature day/night model.
# Each season carries its own warm-rate (Y, °/game-hour at full daylight) and
# cool-rate (X, °/game-hour at full darkness). X dominates in winter, Y in
# summer; the spring/autumn equinoxes balance. Outdoor temperature is
# integrated over time and clamped to the season's [floor, ceiling].
const SUMMER_OUTDOOR_INITIAL_TEMP: float = 52.0
const AUTUMN_OUTDOOR_INITIAL_TEMP: float = 24.0
const WINTER_OUTDOOR_INITIAL_TEMP: float = -10.0
const SPRING_OUTDOOR_INITIAL_TEMP: float = 30.0

const SUMMER_OUTDOOR_FLOOR: float = 44.0
const SUMMER_OUTDOOR_CEILING: float = 92.0
const AUTUMN_OUTDOOR_FLOOR: float = 12.0
const AUTUMN_OUTDOOR_CEILING: float = 56.0
const WINTER_OUTDOOR_FLOOR: float = -28.0
const WINTER_OUTDOOR_CEILING: float = 20.0
const SPRING_OUTDOOR_FLOOR: float = 18.0
const SPRING_OUTDOOR_CEILING: float = 60.0

const SUMMER_WARM_RATE_PER_HOUR: float = 6.0
const AUTUMN_WARM_RATE_PER_HOUR: float = 3.5
const WINTER_WARM_RATE_PER_HOUR: float = 2.0
const SPRING_WARM_RATE_PER_HOUR: float = 4.5

const SUMMER_COOL_RATE_PER_HOUR: float = 2.0
const AUTUMN_COOL_RATE_PER_HOUR: float = 3.5
const WINTER_COOL_RATE_PER_HOUR: float = 6.0
const SPRING_COOL_RATE_PER_HOUR: float = 3.0

# Underground ambient anchors.
const SUMMER_UNDERGROUND_OPEN_AMBIENT: float = 50.0
const SUMMER_UNDERGROUND_INDOORS_AMBIENT: float = 58.0
const AUTUMN_UNDERGROUND_OPEN_AMBIENT: float = 34.0
const AUTUMN_UNDERGROUND_INDOORS_AMBIENT: float = 42.0
const WINTER_UNDERGROUND_OPEN_AMBIENT: float = 10.0
const WINTER_UNDERGROUND_INDOORS_AMBIENT: float = 22.0
const SPRING_UNDERGROUND_OPEN_AMBIENT: float = 38.0
const SPRING_UNDERGROUND_INDOORS_AMBIENT: float = 46.0

# Winter-only modifiers.
const WINTER_EXPEDITION_WINDCHILL: float = 8.0
