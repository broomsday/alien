extends SceneTree

const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const ExpeditionResolverScript = preload("res://scripts/core/simulation/expedition_resolver.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")
const ExpeditionOutcomeScript = preload("res://scripts/core/simulation/expedition_outcome.gd")
const InventoryStateScript = preload("res://scripts/core/inventory/inventory_state.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")

func _init() -> void:
	_test_resolve_uses_only_allowed_mvp_reward_types()
	_test_resolve_across_seeds_can_generate_hostile_animal_encounter()
	_test_outcome_apply_to_increments_inventory_for_positive_counts_only()
	print("test_expedition_resolver: ok")
	quit(0)

func _test_resolve_uses_only_allowed_mvp_reward_types() -> void:
	var state: GameState = GameStateFactoryScript.create_new(1)
	var outcome: ExpeditionOutcome = ExpeditionResolverScript.resolve(state)
	assert(outcome.scrap_metal >= 0, "scrap_metal must be non-negative")
	assert(outcome.fuel >= 0, "fuel must be non-negative")
	assert(outcome.canned_food >= 0, "canned_food must be non-negative")
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 0,
		"resolver must not yield a SIMPLE_WEAPON in MVP")
	assert(
		outcome.encounter_kind == ExpeditionEncounterKindScript.Kind.NONE
		or outcome.encounter_kind == ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL,
		"encounter_kind must be one of the two enum values")

func _test_resolve_across_seeds_can_generate_hostile_animal_encounter() -> void:
	var found_hostile: bool = false
	for seed in range(1, 13):
		var state: GameState = GameStateFactoryScript.create_new(seed)
		var outcome: ExpeditionOutcome = ExpeditionResolverScript.resolve(state)
		if outcome.encounter_kind == ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL:
			found_hostile = true
			break
	assert(found_hostile, "expected at least one hostile encounter across seeds 1..12")

func _test_outcome_apply_to_increments_inventory_for_positive_counts_only() -> void:
	var inventory: InventoryState = InventoryStateScript.new()
	# Zero food; non-zero scrap+fuel. apply_to must not call inventory.add(0).
	var outcome: ExpeditionOutcome = ExpeditionOutcomeScript.new(
		2, 1, 0, ExpeditionEncounterKindScript.Kind.NONE)
	outcome.apply_to(inventory)
	assert(inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 2,
		"expected 2 scrap, got %d" % inventory.get_count(ItemIdScript.Id.SCRAP_METAL))
	assert(inventory.get_count(ItemIdScript.Id.FUEL) == 1,
		"expected 1 fuel, got %d" % inventory.get_count(ItemIdScript.Id.FUEL))
	assert(inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == 0,
		"expected 0 food, got %d" % inventory.get_count(ItemIdScript.Id.CANNED_FOOD))
