class_name CombatRoundOutcome
extends RefCounted

const CombatResolutionScript = preload("res://scripts/core/combat/combat_resolution.gd")

var enemy_name: String
var enemy_max_health: int
var enemy_health_remaining: int
var player_hit: bool
var player_damage: int
var enemy_hit: bool
var enemy_damage: int
var player_integrity_remaining: int
var combat_skill_gained: int
var resolution: int

func _init(
		p_enemy_name: String,
		p_enemy_max_health: int,
		p_enemy_health_remaining: int,
		p_player_hit: bool,
		p_player_damage: int,
		p_enemy_hit: bool,
		p_enemy_damage: int,
		p_player_integrity_remaining: int,
		p_combat_skill_gained: int,
		p_resolution: int) -> void:
	assert(not p_enemy_name.strip_edges().is_empty(), "enemy_name required")
	assert(p_enemy_max_health > 0, "enemy_max_health must be positive")
	assert(p_enemy_health_remaining >= 0 and p_enemy_health_remaining <= p_enemy_max_health,
		"enemy_health_remaining out of range")
	assert(p_player_damage >= 0, "player_damage must be non-negative")
	assert(p_enemy_damage >= 0, "enemy_damage must be non-negative")
	assert(p_player_integrity_remaining >= 0, "player_integrity_remaining must be non-negative")
	assert(p_combat_skill_gained >= 0, "combat_skill_gained must be non-negative")
	enemy_name = p_enemy_name
	enemy_max_health = p_enemy_max_health
	enemy_health_remaining = p_enemy_health_remaining
	player_hit = p_player_hit
	player_damage = p_player_damage
	enemy_hit = p_enemy_hit
	enemy_damage = p_enemy_damage
	player_integrity_remaining = p_player_integrity_remaining
	combat_skill_gained = p_combat_skill_gained
	resolution = p_resolution

func enemy_defeated() -> bool:
	return resolution == CombatResolutionScript.Kind.ENEMY_DEFEATED

func player_died() -> bool:
	return resolution == CombatResolutionScript.Kind.PLAYER_DIED
