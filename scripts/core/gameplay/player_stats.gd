class_name PlayerStats
extends RefCounted

var max_integrity: int
var current_integrity: int

func _init(p_max_integrity: int) -> void:
	assert(p_max_integrity > 0, "max_integrity must be positive")
	max_integrity = p_max_integrity
	current_integrity = p_max_integrity

func is_dead() -> bool:
	return current_integrity <= 0

func take_damage(amount: int) -> void:
	assert(amount >= 0, "damage must be non-negative")
	current_integrity = max(0, current_integrity - amount)
