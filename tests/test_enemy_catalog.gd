extends SceneTree

const EnemyCatalogScript = preload("res://scripts/core/combat/enemy_catalog.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const ExpeditionEncounterKindScript = preload("res://scripts/core/simulation/expedition_encounter_kind.gd")

func _init() -> void:
	_test_get_hostile_animal_returns_razor_maw_with_canonical_tunables()
	_test_get_for_encounter_routes_hostile_animal_to_razor_maw()
	print("test_enemy_catalog: ok")
	quit(0)

func _test_get_hostile_animal_returns_razor_maw_with_canonical_tunables() -> void:
	var enemy = EnemyCatalogScript.get_hostile_animal()
	assert(enemy.kind == EnemyKindScript.Kind.RAZOR_MAW, "expected RAZOR_MAW")
	assert(enemy.name == "Razor Maw", "expected name 'Razor Maw', got %s" % enemy.name)
	assert(enemy.max_health == 7, "expected max_health 7, got %d" % enemy.max_health)
	assert(enemy.minimum_damage == 14, "expected minimum_damage 14")
	assert(enemy.maximum_damage == 20, "expected maximum_damage 20")
	assert(enemy.hit_chance_percent == 62, "expected hit_chance_percent 62")
	assert(EnemyCatalogScript.get_hostile_animal() == enemy,
		"expected catalog to cache the EnemyDefinition")

func _test_get_for_encounter_routes_hostile_animal_to_razor_maw() -> void:
	var enemy = EnemyCatalogScript.get_for_encounter(
		ExpeditionEncounterKindScript.Kind.HOSTILE_ANIMAL)
	assert(enemy != null, "expected an enemy for HOSTILE_ANIMAL")
	assert(enemy.kind == EnemyKindScript.Kind.RAZOR_MAW, "expected RAZOR_MAW")
