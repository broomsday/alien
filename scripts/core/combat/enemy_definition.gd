class_name EnemyDefinition
extends RefCounted

var kind: int
var name: String
var max_health: int
var minimum_damage: int
var maximum_damage: int
var hit_chance_percent: int

func _init(
		p_kind: int,
		p_name: String,
		p_max_health: int,
		p_minimum_damage: int,
		p_maximum_damage: int,
		p_hit_chance_percent: int) -> void:
	assert(not p_name.strip_edges().is_empty(), "name required")
	assert(p_max_health > 0, "max_health must be positive")
	assert(p_minimum_damage >= 0, "minimum_damage must be non-negative")
	assert(p_maximum_damage >= p_minimum_damage, "maximum_damage must be >= minimum_damage")
	assert(p_hit_chance_percent >= 0 and p_hit_chance_percent <= 100,
		"hit_chance_percent must be in [0, 100]")
	kind = p_kind
	name = p_name
	max_health = p_max_health
	minimum_damage = p_minimum_damage
	maximum_damage = p_maximum_damage
	hit_chance_percent = p_hit_chance_percent
