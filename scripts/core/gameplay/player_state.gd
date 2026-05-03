class_name PlayerState
extends RefCounted

var tile_position: Vector2i
var health: PlayerStats
var max_nutrition: float
var current_nutrition: float
var combat_skill: int
var max_temperature: float
var current_temperature: float
var max_hygiene: float
var current_hygiene: float
var max_psyche: float
var current_psyche: float
var equipped_weapon: int

var _damage_buffer: float = 0.0

func _init(
		p_tile_position: Vector2i,
		p_health: PlayerStats,
		p_max_nutrition: float,
		p_current_nutrition: float,
		p_combat_skill: int,
		p_max_temperature: float = 100.0,
		p_current_temperature: float = 70.0,
		p_equipped_weapon: int = EquippedWeapon.Slot.NONE,
		p_max_hygiene: float = 100.0,
		p_current_hygiene: float = 100.0,
		p_max_psyche: float = 100.0,
		p_current_psyche: float = 100.0) -> void:
	assert(p_health != null, "health required")
	assert(p_max_nutrition > 0.0, "max_nutrition must be positive")
	assert(p_current_nutrition >= 0.0 and p_current_nutrition <= p_max_nutrition, "nutrition out of range")
	assert(p_combat_skill >= 0, "combat_skill must be non-negative")
	assert(p_max_temperature > 0.0, "max_temperature must be positive")
	assert(p_current_temperature >= 0.0 and p_current_temperature <= p_max_temperature, "temperature out of range")
	assert(p_max_hygiene > 0.0, "max_hygiene must be positive")
	assert(p_current_hygiene >= 0.0 and p_current_hygiene <= p_max_hygiene, "hygiene out of range")
	assert(p_max_psyche > 0.0, "max_psyche must be positive")
	assert(p_current_psyche >= 0.0 and p_current_psyche <= p_max_psyche, "psyche out of range")
	tile_position = p_tile_position
	health = p_health
	max_nutrition = p_max_nutrition
	current_nutrition = p_current_nutrition
	combat_skill = p_combat_skill
	max_temperature = p_max_temperature
	current_temperature = p_current_temperature
	max_hygiene = p_max_hygiene
	current_hygiene = p_current_hygiene
	max_psyche = p_max_psyche
	current_psyche = p_current_psyche
	equipped_weapon = p_equipped_weapon

func max_hit_points() -> int:
	return health.max_health

func current_hit_points() -> int:
	return health.current_health

func is_alive() -> bool:
	return health.current_health > 0

func combat_power_bonus() -> int:
	if equipped_weapon == EquippedWeapon.Slot.SIMPLE_WEAPON:
		return 2
	return 0

func move_to(p_tile_position: Vector2i) -> void:
	tile_position = p_tile_position

func equip_weapon(p_equipped_weapon: int) -> void:
	equipped_weapon = p_equipped_weapon

func increase_combat_skill(amount: int) -> void:
	assert(amount >= 0, "amount must be non-negative")
	combat_skill += amount

func drain_nutrition(amount: float) -> void:
	assert(amount >= 0.0, "amount must be non-negative")
	current_nutrition = max(0.0, current_nutrition - amount)

func restore_nutrition(amount: float) -> void:
	assert(amount >= 0.0, "amount must be non-negative")
	current_nutrition = min(max_nutrition, current_nutrition + amount)

func reduce_hygiene(amount: float) -> void:
	assert(amount >= 0.0, "amount must be non-negative")
	current_hygiene = max(0.0, current_hygiene - amount)

func restore_hygiene(amount: float) -> void:
	assert(amount >= 0.0, "amount must be non-negative")
	current_hygiene = min(max_hygiene, current_hygiene + amount)

func reduce_psyche(amount: float) -> void:
	assert(amount >= 0.0, "amount must be non-negative")
	current_psyche = max(0.0, current_psyche - amount)

func restore_psyche(amount: float) -> void:
	assert(amount >= 0.0, "amount must be non-negative")
	current_psyche = min(max_psyche, current_psyche + amount)

func move_temperature_toward(target_temperature: float, rate_per_second: float, delta_seconds: float) -> void:
	assert(rate_per_second >= 0.0, "rate must be non-negative")
	assert(delta_seconds >= 0.0, "delta_seconds must be non-negative")
	var max_delta: float = rate_per_second * delta_seconds
	var delta: float = target_temperature - current_temperature
	var clamped_delta: float = clampf(delta, -max_delta, max_delta)
	current_temperature = clampf(current_temperature + clamped_delta, 0.0, max_temperature)

func apply_neglect_damage(damage_amount: float) -> void:
	assert(damage_amount >= 0.0, "damage must be non-negative")
	_damage_buffer += damage_amount
	var whole_damage: int = int(floor(_damage_buffer))
	if whole_damage <= 0:
		return
	health.take_damage(whole_damage)
	_damage_buffer -= whole_damage
