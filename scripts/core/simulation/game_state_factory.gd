class_name GameStateFactory
extends RefCounted

const _DEFAULT_SEED: int = 0x00C0FFEE

static func create_new(p_random_seed: int = _DEFAULT_SEED) -> GameState:
	var world: WorldGrid = WorldGrid.create_default(21, 12, 4)

	var player: PlayerState = PlayerState.new(
		Vector2i(world.width / 2, world.surface_row - 1),
		PlayerStats.new(100),
		100.0, 100.0,
		0,
		100.0, 72.0,
		EquippedWeapon.Slot.NONE,
		100.0, 100.0,
		100.0, 100.0)

	var inventory: InventoryState = InventoryState.new()
	inventory.add(ItemId.Id.SCRAP_METAL, 8)
	inventory.add(ItemId.Id.FUEL, 3)
	inventory.add(ItemId.Id.CANNED_FOOD, 4)

	var clock: ClockState = ClockState.new(Season.Kind.SUMMER, 1, 6.0 * 60.0 * 60.0)

	var state: GameState = GameState.new(player, world, inventory, clock, p_random_seed)
	SurvivalRules.bootstrap_outdoor_temperature(state)
	state.set_environment_status(
		SurvivalRules.get_ambient_temperature(state),
		false, false,
		SurvivalRules.get_ambient_gas(state))
	return state
