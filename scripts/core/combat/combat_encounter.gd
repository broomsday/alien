class_name CombatEncounter
extends RefCounted

var enemy
var current_health: int

func _init(p_enemy, p_current_health: Variant = null) -> void:
	assert(p_enemy != null, "enemy required")
	enemy = p_enemy
	var resolved: int = p_enemy.max_health if p_current_health == null else int(p_current_health)
	assert(resolved > 0 and resolved <= p_enemy.max_health,
		"current_health must be in (0, max_health]; got %d" % resolved)
	current_health = resolved

func max_health() -> int:
	return enemy.max_health

func is_defeated() -> bool:
	return current_health <= 0

func take_damage(damage: int) -> void:
	assert(damage >= 0, "damage must be non-negative")
	current_health = maxi(0, current_health - damage)
