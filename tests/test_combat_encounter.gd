extends SceneTree

const EnemyDefinitionScript = preload("res://scripts/core/combat/enemy_definition.gd")
const EnemyKindScript = preload("res://scripts/core/combat/enemy_kind.gd")
const CombatEncounterScript = preload("res://scripts/core/combat/combat_encounter.gd")

func _init() -> void:
	_test_default_current_health_uses_enemy_max_health()
	_test_explicit_current_health_is_honoured()
	_test_take_damage_clamps_to_zero_and_marks_defeated()
	print("test_combat_encounter: ok")
	quit(0)

func _test_default_current_health_uses_enemy_max_health() -> void:
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Default", 7, 1, 2, 50)
	var encounter = CombatEncounterScript.new(enemy)
	assert(encounter.current_health == 7,
		"expected current_health == max_health 7, got %d" % encounter.current_health)
	assert(encounter.max_health() == 7, "expected max_health() == 7")
	assert(not encounter.is_defeated(), "fresh encounter should not be defeated")

func _test_explicit_current_health_is_honoured() -> void:
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Wounded", 10, 0, 0, 0)
	var encounter = CombatEncounterScript.new(enemy, 3)
	assert(encounter.current_health == 3,
		"expected explicit current_health 3, got %d" % encounter.current_health)
	assert(encounter.max_health() == 10, "expected max_health() unchanged")

func _test_take_damage_clamps_to_zero_and_marks_defeated() -> void:
	var enemy = EnemyDefinitionScript.new(
		EnemyKindScript.Kind.RAZOR_MAW, "Glass", 5, 0, 0, 0)
	var encounter = CombatEncounterScript.new(enemy)
	encounter.take_damage(3)
	assert(encounter.current_health == 2,
		"expected health 2 after 3 damage, got %d" % encounter.current_health)
	assert(not encounter.is_defeated(), "still alive at health 2")
	encounter.take_damage(99)
	assert(encounter.current_health == 0,
		"expected health 0 after overkill, got %d" % encounter.current_health)
	assert(encounter.is_defeated(), "expected defeated at health 0")
