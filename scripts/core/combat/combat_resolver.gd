class_name CombatResolver
extends RefCounted

const CombatRoundOutcomeScript = preload("res://scripts/core/combat/combat_round_outcome.gd")
const CombatResolutionScript = preload("res://scripts/core/combat/combat_resolution.gd")

static func resolve_attack(state: GameState):
	assert(state != null, "state required")
	assert(state.player.is_alive(), "the player cannot attack after death")
	assert(state.active_combat != null, "no combat encounter is active")

	var encounter = state.active_combat
	var combat_skill_gained: int = 0
	var player_hit: bool = _roll_percent(state, _get_player_hit_chance_percent(state))
	var player_damage: int = 0

	if player_hit:
		player_damage = 2 + state.player.combat_power_bonus() \
			+ (state.player.combat_skill / 3) + state.next_random_int(2)
		encounter.take_damage(player_damage)
		state.player.increase_combat_skill(1)
		combat_skill_gained += 1

	if encounter.is_defeated():
		state.player.increase_combat_skill(1)
		combat_skill_gained += 1

		var victory = CombatRoundOutcomeScript.new(
			encounter.enemy.name,
			encounter.max_health(),
			encounter.current_health,
			player_hit,
			player_damage,
			false,
			0,
			state.player.current_hit_points(),
			combat_skill_gained,
			CombatResolutionScript.Kind.ENEMY_DEFEATED)
		state.win_combat(victory)
		return victory

	var enemy_hit: bool = _roll_percent(state, encounter.enemy.hit_chance_percent)
	var enemy_damage: int = 0

	if enemy_hit:
		enemy_damage = _roll_inclusive(state,
			encounter.enemy.minimum_damage,
			encounter.enemy.maximum_damage)
		state.player.health.take_damage(enemy_damage)

	var resolution: int = (
		CombatResolutionScript.Kind.ONGOING
		if state.player.is_alive()
		else CombatResolutionScript.Kind.PLAYER_DIED)

	var round_outcome = CombatRoundOutcomeScript.new(
		encounter.enemy.name,
		encounter.max_health(),
		encounter.current_health,
		player_hit,
		player_damage,
		enemy_hit,
		enemy_damage,
		state.player.current_hit_points(),
		combat_skill_gained,
		resolution)

	if state.player.is_alive():
		state.record_combat_round(round_outcome)
	else:
		state.lose_combat(round_outcome)
	return round_outcome

static func _get_player_hit_chance_percent(state: GameState) -> int:
	var hit_chance: int = 55 \
		+ (state.player.combat_skill * 3) \
		+ (state.player.combat_power_bonus() * 8)
	return clampi(hit_chance, 25, 95)

static func _roll_percent(state: GameState, chance_percent: int) -> bool:
	return state.next_random_int(100) < chance_percent

static func _roll_inclusive(state: GameState, minimum: int, maximum: int) -> int:
	return minimum + state.next_random_int((maximum - minimum) + 1)
