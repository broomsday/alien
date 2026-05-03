extends SceneTree

const GameStateScript = preload("res://scripts/core/simulation/game_state.gd")
const PlayerStateScript = preload("res://scripts/core/gameplay/player_state.gd")
const PlayerStatsScript = preload("res://scripts/core/gameplay/player_stats.gd")
const InventoryStateScript = preload("res://scripts/core/inventory/inventory_state.gd")
const ClockStateScript = preload("res://scripts/core/time/clock_state.gd")
const WorldGridScript = preload("res://scripts/core/world/world_grid.gd")
const SeasonScript = preload("res://scripts/core/time/season.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")
const EquippedWeaponScript = preload("res://scripts/core/gameplay/equipped_weapon.gd")
const RecipeRulesScript = preload("res://scripts/core/crafting/recipe_rules.gd")
const RecipeIdScript = preload("res://scripts/core/crafting/recipe_id.gd")

func _init() -> void:
	_test_try_craft_when_resources_are_missing_returns_false()
	_test_try_craft_simple_weapon_consumes_scrap_and_equips_weapon()
	_test_try_craft_simple_weapon_when_already_equipped_returns_false()
	_test_can_afford_walls_and_furnaces_against_inventory()
	print("test_recipe_rules: ok")
	quit(0)

func _test_try_craft_when_resources_are_missing_returns_false() -> void:
	var state: GameState = _make_state(2, 0)
	var crafted: bool = RecipeRulesScript.try_craft(state, RecipeIdScript.Id.SIMPLE_WEAPON)
	assert(not crafted, "expected try_craft to fail when scrap is short")
	assert(state.player.equipped_weapon == EquippedWeaponScript.Slot.NONE,
		"expected weapon slot empty after failed craft")
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 0,
		"expected no SIMPLE_WEAPON in inventory")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 2,
		"expected scrap untouched after failed craft, got %d" %
			state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))

func _test_try_craft_simple_weapon_consumes_scrap_and_equips_weapon() -> void:
	var state: GameState = _make_state(6, 0)
	var crafted: bool = RecipeRulesScript.try_craft(state, RecipeIdScript.Id.SIMPLE_WEAPON)
	assert(crafted, "expected try_craft to succeed with 6 scrap")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 3,
		"expected 3 scrap remaining, got %d" %
			state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 1,
		"expected 1 SIMPLE_WEAPON in inventory")
	assert(state.player.equipped_weapon == EquippedWeaponScript.Slot.SIMPLE_WEAPON,
		"expected SIMPLE_WEAPON equipped")
	assert(state.player.combat_power_bonus() == 2,
		"expected combat_power_bonus 2, got %d" % state.player.combat_power_bonus())

func _test_try_craft_simple_weapon_when_already_equipped_returns_false() -> void:
	var state: GameState = _make_state(9, 0)
	var first: bool = RecipeRulesScript.try_craft(state, RecipeIdScript.Id.SIMPLE_WEAPON)
	assert(first, "first craft should succeed")
	var second: bool = RecipeRulesScript.try_craft(state, RecipeIdScript.Id.SIMPLE_WEAPON)
	assert(not second, "second craft should fail — weapon already equipped")
	assert(state.inventory.get_count(ItemIdScript.Id.SIMPLE_WEAPON) == 1,
		"expected SIMPLE_WEAPON count to stay 1")
	assert(state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 6,
		"expected scrap untouched on rejected craft, got %d" %
			state.inventory.get_count(ItemIdScript.Id.SCRAP_METAL))

func _test_can_afford_walls_and_furnaces_against_inventory() -> void:
	var state: GameState = _make_state(4, 1)
	assert(RecipeRulesScript.can_afford(state.inventory, RecipeIdScript.Id.SCRAP_METAL_WALL),
		"4 scrap is enough for a wall")
	assert(RecipeRulesScript.can_afford(state.inventory, RecipeIdScript.Id.FURNACE),
		"4 scrap + 1 fuel is exactly enough for a furnace")
	state.inventory.try_remove(ItemIdScript.Id.FUEL, 1)
	assert(not RecipeRulesScript.can_afford(state.inventory, RecipeIdScript.Id.FURNACE),
		"furnace should fail without fuel even with 4 scrap")

func _make_state(scrap: int = 0, fuel: int = 0) -> GameState:
	var world: WorldGrid = WorldGridScript.create_default(12, 10, 4)
	var player: PlayerState = PlayerStateScript.new(
		Vector2i(5, 3),
		PlayerStatsScript.new(100),
		100.0, 100.0, 0)
	var inventory: InventoryState = InventoryStateScript.new()
	if scrap > 0:
		inventory.add(ItemIdScript.Id.SCRAP_METAL, scrap)
	if fuel > 0:
		inventory.add(ItemIdScript.Id.FUEL, fuel)
	var clock: ClockState = ClockStateScript.new(SeasonScript.Kind.SUMMER, 1, 0.0)
	return GameStateScript.new(player, world, inventory, clock)
