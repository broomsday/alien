extends Node2D

var _session: GameSession
var _layout: TileLayout
var _renderer: WorldRenderer
var _input_reader: InputReader
var _hud: Hud

func _ready() -> void:
	_session = GameSession.new()
	add_child(_session)

	_layout = TileLayout.new(_session.state.world)

	_renderer = WorldRenderer.new()
	_renderer.setup(_session.state, _layout)
	add_child(_renderer)

	_input_reader = InputReader.new()
	_input_reader.setup(_session, _layout)
	add_child(_input_reader)

	_hud = Hud.new()
	add_child(_hud)
	_hud.play_area_changed.connect(_on_play_area_changed)
	_hud.start_expedition_requested.connect(_on_start_expedition_requested)
	_hud.craft_weapon_requested.connect(_on_craft_weapon_requested)
	_sync_layout_from_hud()
	_hud.refresh(_session.state, _input_reader.interaction_mode)

	print("alien_godot: phase 7 boot ok — mode=%s clock=%.2fh day=%d season=%s player=%s" % [
		GameInteractionMode.display_name(_input_reader.interaction_mode),
		_session.state.clock.time_of_day_hours(),
		_session.state.clock.day_of_season,
		Season.Kind.keys()[_session.state.clock.season],
		_session.state.player.tile_position,
	])

func _process(delta: float) -> void:
	var commands: Array[GameCommand] = _input_reader.take_commands()
	_session.update(delta, commands)
	_layout.set_focus_tile(_session.state.player.tile_position)
	_input_reader.refresh_hovered_tile()
	_renderer.hovered_tile = _input_reader.hovered_tile
	_renderer.interaction_mode = _input_reader.interaction_mode
	_renderer.queue_redraw()
	_hud.refresh(_session.state, _input_reader.interaction_mode)

func _unhandled_input(event: InputEvent) -> void:
	if _layout == null or _hud == null:
		return
	if not (event is InputEventMouseButton):
		return
	var button_event: InputEventMouseButton = event
	if not button_event.pressed:
		return
	var zoom_steps: int = _zoom_steps_for_mouse_button(button_event.button_index)
	if zoom_steps == 0:
		return
	if _hud.get_world_viewport_rect().has_point(button_event.position):
		if _layout.adjust_zoom_steps(zoom_steps):
			_sync_layout_from_hud()
			get_viewport().set_input_as_handled()
		return
	if _hud.get_crew_panel_rect().has_point(button_event.position):
		if _hud.adjust_crew_zoom_steps(zoom_steps):
			_hud.refresh(_session.state, _input_reader.interaction_mode)
			get_viewport().set_input_as_handled()

func _on_play_area_changed(_play_area_rect: Rect2) -> void:
	_sync_layout_from_hud()

func _on_start_expedition_requested() -> void:
	if _session.state.active_combat != null:
		_input_reader.queue_command(StartActionCommand.new(GameActionKind.Kind.ATTACK, null))
	else:
		_input_reader.queue_command(StartActionCommand.new(GameActionKind.Kind.EXPEDITION, null))

func _on_craft_weapon_requested() -> void:
	_input_reader.queue_command(CraftRecipeCommand.new(RecipeId.Id.SIMPLE_WEAPON))

func _sync_layout_from_hud() -> void:
	_layout.set_play_area(_hud.get_world_viewport_rect())
	_layout.set_focus_tile(_session.state.player.tile_position)
	_hud.set_world_display_rect(_layout.world_bounds_rect())
	_input_reader.refresh_hovered_tile()
	_renderer.queue_redraw()

func _zoom_steps_for_mouse_button(button_index: MouseButton) -> int:
	if button_index == MOUSE_BUTTON_WHEEL_DOWN:
		return 1
	if button_index == MOUSE_BUTTON_WHEEL_UP:
		return -1
	return 0
