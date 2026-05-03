class_name EnemyCatalog
extends RefCounted

const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")

static var _razor_maw = null

static func get_hostile_animal():
	if _razor_maw == null:
		_razor_maw = EnemyDefinitionScript.new(
			EnemyKindScript.Kind.RAZOR_MAW,
			"Razor Maw",
			7,
			14,
			20,
			62)
	return _razor_maw

static func get_for_encounter(encounter_kind: int):
	match encounter_kind:
		ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL:
			return get_hostile_animal()
		_:
			assert(false, "no enemy for encounter_kind %d" % encounter_kind)
			return null
