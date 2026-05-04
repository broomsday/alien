extends SceneTree

const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")
const ExpeditionStatusScript = preload("res://scripts/core/simulation/expedition_status.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")
const ExpeditionOutcomeScript = preload("res://scripts/core/simulation/expedition_outcome.gd")
const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")
const CombatResolverScript = preload("res://scripts/core/combat/combat_resolver.gd")
const EquippedWeaponScript = preload("res://scripts/core/gameplay/equipped_weapon.gd")

func _init() -> void:
	_test_resolve_attack_when_enemy_deals_lethal_damage_kills_player_and_drops_pending_loot()
	_test_resolve_attack_with_weapon_defeats_enemy_in_fewer_rounds_than_unarmed()
	_test_resolve_attack_combat_skill_gains_only_for_successful_hits_and_victory()
	_test_resolve_attack_when_combat_starts_from_expedition_holds_rewards_until_victory()
	print("test_combat_resolver: ok")
	quit(0)

func _test_resolve_attack_when_enemy_deals_lethal_damage_kills_player_and_drops_pending_loot() -> void:
	var state: GameState = GameStateFactoryScript.create_new(1)
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var starting_fuel: int = state.inventory.get_count(ItemIdScript.Id.FUEL)
	var starting_food: int = state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD)

	state.player.integrity.take_damage(93)
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Test Hunter", 9, 7, 7, 100)
	state.begin_combat(
		CombatEncounterScript.new(enemy),
		ExpeditionOutcomeScript.new(3, 1, 2, ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL))

	var outcome = CombatResolverScript.resolve_attack(state)

	assert(outcome.player_died(), "expected player_died true")
	assert(not state.player.is_alive(), "expected player dead")
	assert(state.active_combat == null, "expected active_combat cleared on death")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.INTERRUPTED,
		"expected INTERRUPTED, got %d" % state.expedition_status)
	assert(state.last_expedition_outcome == null,
		"expected last_expedition_outcome cleared")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap,
		"expected scrap unchanged on combat loss")
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel,
		"expected fuel unchanged")
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == starting_food,
		"expected food unchanged")

func _test_resolve_attack_with_weapon_defeats_enemy_in_fewer_rounds_than_unarmed() -> void:
	var armed_state: GameState = GameStateFactoryScript.create_new(5)
	var unarmed_state: GameState = GameStateFactoryScript.create_new(5)
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Sparring Beast", 8, 0, 0, 0)

	armed_state.player.equip_weapon(EquippedWeaponScript.Slot.SIMPLE_WEAPON)
	armed_state.begin_combat(CombatEncounterScript.new(enemy))
	unarmed_state.begin_combat(CombatEncounterScript.new(enemy))

	var armed_rounds: int = _resolve_until_combat_ends(armed_state)
	var unarmed_rounds: int = _resolve_until_combat_ends(unarmed_state)

	assert(armed_rounds < unarmed_rounds,
		"expected armed (%d) < unarmed (%d)" % [armed_rounds, unarmed_rounds])

func _test_resolve_attack_combat_skill_gains_only_for_successful_hits_and_victory() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Practice Beast", 7, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy))

	var successful_hits: int = 0
	var final_outcome = null

	while state.active_combat != null:
		final_outcome = CombatResolverScript.resolve_attack(state)
		if final_outcome.player_hit:
			successful_hits += 1

	assert(final_outcome != null, "expected at least one round resolved")
	assert(final_outcome.enemy_defeated(), "expected enemy_defeated on the final round")
	assert(state.player.combat_skill == successful_hits + 1,
		"expected combat_skill == hits+1; got skill=%d, hits=%d" %
			[state.player.combat_skill, successful_hits])

func _test_resolve_attack_when_combat_starts_from_expedition_holds_rewards_until_victory() -> void:
	var state: GameState = GameStateFactoryScript.create_new(5)
	var starting_scrap: int = state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)
	var starting_fuel: int = state.inventory.get_count(ItemIdScript.Id.FUEL)
	var starting_food: int = state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD)
	var pending: ExpeditionOutcome = ExpeditionOutcomeScript.new(
		2, 1, 1, ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL)
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Cave Stalker", 8, 0, 0, 0)
	state.begin_combat(CombatEncounterScript.new(enemy), pending)

	var first = CombatResolverScript.resolve_attack(state)

	assert(state.active_combat != null, "expected combat ongoing after first swing")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.AWAY,
		"expected AWAY mid-fight, got %d" % state.expedition_status)
	assert(state.last_expedition_outcome == null,
		"expected last_expedition_outcome held until victory")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap,
		"expected scrap unchanged mid-fight")
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel,
		"expected fuel unchanged mid-fight")
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == starting_food,
		"expected food unchanged mid-fight")
	assert(not first.enemy_defeated(), "first swing on health-8 beast shouldn't defeat it")

	var final_outcome = first
	while state.active_combat != null:
		final_outcome = CombatResolverScript.resolve_attack(state)

	assert(final_outcome.enemy_defeated(), "expected enemy_defeated by loop end")
	assert(state.expedition_status == ExpeditionStatusScript.Kind.RETURNED,
		"expected RETURNED after victory, got %d" % state.expedition_status)
	assert(state.last_expedition_outcome != null,
		"expected last_expedition_outcome populated on victory")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == starting_scrap + pending.scrap_metal,
		"expected scrap +%d, got %d" %
			[pending.scrap_metal, state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL)])
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == starting_fuel + pending.fuel,
		"expected fuel +%d" % pending.fuel)
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == starting_food + pending.canned_food,
		"expected food +%d" % pending.canned_food)

func _resolve_until_combat_ends(state: GameState) -> int:
	for round in range(1, 21):
		CombatResolverScript.resolve_attack(state)
		if state.active_combat == null:
			return round
	assert(false, "combat did not resolve within 20 rounds")
	return -1
