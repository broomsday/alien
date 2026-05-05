class_name GameStateFactory
extends RefCounted

const _DEFAULT_SEED: int = 0x00C0FFEE
const WorldObjectMapScript = preload("res://scripts/core/world/world_object_map.gd")
const WorldObjectKindScript = preload("res://scripts/core/world/world_object_kind.gd")

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
		"Accalia.png",
		5, 5)

	var inventory: InventoryState = InventoryState.new()
	inventory.add(ItemId.Id.SCRAP_METAL, 8)
	inventory.add(ItemId.Id.FUEL, 3)
	inventory.add(ItemId.Id.CANNED_FOOD, 4)

	var world_objects: WorldObjectMapScript = WorldObjectMapScript.new()
	_populate_world_objects(world_objects, world, player.tile_position)

	var clock: ClockState = ClockState.new(Season.Kind.SUMMER, 1, 6.0 * 60.0 * 60.0)

	var state: GameState = GameState.new(player, world, inventory, clock, p_random_seed, world_objects)
	SurvivalRules.bootstrap_outdoor_temperature(state)
	state.set_environment_status(
		SurvivalRules.get_ambient_temperature(state),
		false, false,
		SurvivalRules.get_ambient_gas(state))
	return state

static func _populate_world_objects(world_objects: WorldObjectMapScript, world: WorldGrid, player_tile: Vector2i) -> void:
	var candidate_tiles: Array[Vector2i] = []
	var surface_tile_y: int = world.surface_row - 1
	for x in range(world.width):
		var tile_position: Vector2i = Vector2i(x, surface_tile_y)
		if tile_position == player_tile:
			continue
		if absi(tile_position.x - player_tile.x) <= 1:
			continue
		if world.get_tile(tile_position) != WorldTileType.Kind.AIR:
			continue
		candidate_tiles.append(tile_position)
	var desired_count: int = mini(GameBalance.FRUIT_BUSH_DEFAULT_COUNT, candidate_tiles.size())
	if desired_count <= 0:
		return
	var used_indices: Dictionary = {}
	for bush_index in range(desired_count):
		var ratio: float = float(bush_index + 1) / float(desired_count + 1)
		var candidate_index: int = clampi(
			int(round(ratio * float(candidate_tiles.size() - 1))),
			0,
			candidate_tiles.size() - 1)
		while used_indices.has(candidate_index) and candidate_index < candidate_tiles.size() - 1:
			candidate_index += 1
		while used_indices.has(candidate_index) and candidate_index > 0:
			candidate_index -= 1
		if used_indices.has(candidate_index):
			continue
		used_indices[candidate_index] = true
		world_objects.place_object(candidate_tiles[candidate_index], WorldObjectKindScript.Kind.FRUIT_BUSH)
