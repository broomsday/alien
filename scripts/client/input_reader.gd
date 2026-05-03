class_name InputReader
extends Node

var session: GameSession
var layout: TileLayout
var interaction_mode: int = GameInteractionMode.Kind.EXCAVATE
var hovered_tile: Variant = null
var _pending: Array[GameCommand] = []

func setup(p_session: GameSession, p_layout: TileLayout) -> void:
	session = p_session
	layout = p_layout

func take_commands() -> Array[GameCommand]:
	var out: Array[GameCommand] = _pending
	_pending = []
	return out

func queue_command(command: GameCommand) -> void:
	assert(command != null, "command required")
	_pending.append(command)

func refresh_hovered_tile() -> void:
	if layout == null or get_viewport() == null:
		return
	hovered_tile = layout.pixel_to_tile(get_viewport().get_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if session == null or layout == null:
		return
	if event is InputEventMouseMotion:
		hovered_tile = layout.pixel_to_tile(event.position)
		return
	if event is InputEventMouseButton:
		hovered_tile = layout.pixel_to_tile(event.position)
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_on_left_click()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_on_right_click()
		return
	if event.is_action_pressed("mode_excavate"):
		interaction_mode = GameInteractionMode.Kind.EXCAVATE
	elif event.is_action_pressed("mode_build_wall"):
		interaction_mode = GameInteractionMode.Kind.BUILD_WALL
	elif event.is_action_pressed("mode_build_furnace"):
		interaction_mode = GameInteractionMode.Kind.BUILD_FURNACE
	elif event.is_action_pressed("cancel_action"):
		_pending.append(CancelActionCommand.new())
	elif event.is_action_pressed("start_expedition"):
		if session.state.active_combat != null:
			_pending.append(StartActionCommand.new(GameActionKind.Kind.ATTACK, null))
		else:
			_pending.append(StartActionCommand.new(GameActionKind.Kind.EXPEDITION, null))
	elif event.is_action_pressed("attack"):
		if session.state.active_combat != null:
			_pending.append(StartActionCommand.new(GameActionKind.Kind.ATTACK, null))

func _on_left_click() -> void:
	if not (hovered_tile is Vector2i):
		return
	if session.state.active_combat != null:
		return
	if hovered_tile == session.state.player.tile_position:
		_pending.append(ConsumeFoodCommand.new())
	else:
		_pending.append(MovePlayerCommand.new(hovered_tile))

func _on_right_click() -> void:
	if not (hovered_tile is Vector2i):
		return
	if session.state.active_combat != null:
		return
	# Right-click on a furnace tile fuels it regardless of interaction mode —
	# diverges from the C# port's BuildFurnace-mode gate to remove a usability
	# papercut (no other action targets furnace tiles, so the click is otherwise
	# silently dropped).
	if session.state.world.get_tile(hovered_tile) == WorldTileType.Kind.FURNACE:
		_pending.append(FuelFurnaceCommand.new(hovered_tile))
		return
	var kind: int = GameInteractionMode.to_action_kind(interaction_mode)
	_pending.append(StartActionCommand.new(kind, hovered_tile))
