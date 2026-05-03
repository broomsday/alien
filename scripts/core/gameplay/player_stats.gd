class_name PlayerStats
extends RefCounted

var max_health: int
var current_health: int

func _init(p_max_health: int) -> void:
	assert(p_max_health > 0, "max_health must be positive")
	max_health = p_max_health
	current_health = p_max_health

func is_dead() -> bool:
	return current_health <= 0

func take_damage(amount: int) -> void:
	assert(amount >= 0, "damage must be non-negative")
	current_health = max(0, current_health - amount)
