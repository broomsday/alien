class_name PlayerState
extends RefCounted

var tile_position: Vector2i
var integrity: PlayerStats
var max_energy: float
var current_energy: float
var combat_skill: int
var max_temperature: float
var current_temperature: float
var max_psyche: float
var current_psyche: float
var equipped_weapon: int
var portrait_filename: String
var physique: int
var aptitude: int

var _damage_buffer: float = 0.0

func _init(
		p_tile_position: Vector2i,
		p_integrity: PlayerStats,
		p_max_energy: float,
		p_current_energy: float,
		p_combat_skill: int,
		p_max_temperature: float = 100.0,
		p_current_temperature: float = 70.0,
		p_equipped_weapon: int = EquippedWeapon.Slot.NONE,
		p_max_psyche: float = 100.0,
		p_current_psyche: float = 100.0,
		p_portrait_filename: String = "Unknown.png",
		p_physique: int = 0,
		p_aptitude: int = 0) -> void:
	assert(p_integrity != null, "integrity required")
	assert(p_max_energy > 0.0, "max_energy must be positive")
	assert(p_current_energy >= 0.0 and p_current_energy <= p_max_energy, "energy out of range")
	assert(p_combat_skill >= 0, "combat_skill must be non-negative")
	assert(p_max_temperature > 0.0, "max_temperature must be positive")
	assert(p_current_temperature >= 0.0 and p_current_temperature <= p_max_temperature, "temperature out of range")
	assert(p_max_psyche > 0.0, "max_psyche must be positive")
	assert(p_current_psyche >= 0.0 and p_current_psyche <= p_max_psyche, "psyche out of range")
	assert(p_physique >= 0, "physique must be non-negative")
	assert(p_aptitude >= 0, "aptitude must be non-negative")
	tile_position = p_tile_position
	integrity = p_integrity
	max_energy = p_max_energy
	current_energy = p_current_energy
	combat_skill = p_combat_skill
	max_temperature = p_max_temperature
	current_temperature = p_current_temperature
	max_psyche = p_max_psyche
	current_psyche = p_current_psyche
	equipped_weapon = p_equipped_weapon
	portrait_filename = p_portrait_filename
	physique = p_physique
	aptitude = p_aptitude

func max_integrity() -> int:
	return integrity.max_integrity

func current_integrity() -> int:
	return integrity.current_integrity

func is_alive() -> bool:
	return integrity.current_integrity > 0

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

func drain_energy(amount: float) -> void:
	assert(amount >= 0.0, "amount must be non-negative")
	current_energy = max(0.0, current_energy - amount)

func restore_energy(amount: float) -> void:
	assert(amount >= 0.0, "amount must be non-negative")
	current_energy = min(max_energy, current_energy + amount)

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
	integrity.take_damage(whole_damage)
	_damage_buffer -= whole_damage
