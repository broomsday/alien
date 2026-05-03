class_name ExpeditionResolver
extends RefCounted

static func resolve(state: GameState) -> ExpeditionOutcome:
	assert(state != null, "state required")

	var scrap_metal: int = 1 + state.next_random_int(4)
	var fuel: int = state.next_random_int(3)
	var canned_food: int = state.next_random_int(3)

	if fuel == 0 and canned_food == 0:
		canned_food = 1

	var encounter_kind: int = (
		ExpeditionEncounterKind.Kind.HOSTILE_ANIMAL
		if state.next_random_int(100) < 35
		else ExpeditionEncounterKind.Kind.NONE)

	return ExpeditionOutcome.new(scrap_metal, fuel, canned_food, encounter_kind)
