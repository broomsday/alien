extends SceneTree

const GameStateFactoryScript = preload("res://scripts/core/simulation/game_state_factory.gd")
const SeasonScript = preload("res://scripts/core/time/season.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")

func _init() -> void:
	_test_create_new_creates_expected_starting_state()
	_test_create_new_starts_outside_combat()
	print("test_game_state_factory: ok")
	quit(0)

func _test_create_new_creates_expected_starting_state() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	assert(state.clock.season == SeasonScript.Kind.SUMMER, "expected summer")
	assert(state.clock.day_of_season == 1, "expected day 1, got %d" % state.clock.day_of_season)
	assert(absf(state.clock.time_of_day_hours() - 6.0) < 0.001,
		"expected 06:00, got %f" % state.clock.time_of_day_hours())
	assert(state.world.is_within_bounds(state.player.tile_position),
		"player position out of bounds: %s" % state.player.tile_position)
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 8,
		"expected 8 scrap, got %d" % state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))
	assert(state.inventory.get_count(ItemIdScript.Id.FUEL) == 3,
		"expected 3 fuel, got %d" % state.inventory.get_count(ItemIdScript.Id.FUEL))
	assert(state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD) == 4,
		"expected 4 food, got %d" % state.inventory.get_count(ItemIdScript.Id.CANNED_FOOD))
	assert(state.player.max_hit_points() == 100, "expected 100 max HP")
	assert(state.player.current_hit_points() == 100, "expected 100 current HP")
	assert(absf(state.player.current_temperature - 72.0) < 0.001,
		"expected 72 temp, got %f" % state.player.current_temperature)
	assert(absf(state.player.current_hygiene - 100.0) < 0.001, "expected 100 hygiene")
	assert(absf(state.player.current_psyche - 100.0) < 0.001, "expected 100 psyche")
	assert(state.active_action == null, "expected no active action")

func _test_create_new_starts_outside_combat() -> void:
	var state: GameState = GameStateFactoryScript.create_new()
	assert(state.active_combat == null, "expected fresh state with no active combat")
	assert(state.last_combat_round_outcome == null, "expected no prior combat round")
	assert(state.combat_encounters_won == 0, "expected 0 victories on a fresh state")
