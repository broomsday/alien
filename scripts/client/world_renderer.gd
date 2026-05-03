class_name WorldRenderer
extends Node2D

const _TILE_COLORS: Dictionary = {
	WorldTileType.Kind.AIR: Color8(76, 119, 168),
	WorldTileType.Kind.SOIL: Color8(109, 79, 52),
	WorldTileType.Kind.EXCAVATED_FLOOR: Color8(52, 87, 97),
	WorldTileType.Kind.SCRAP_METAL_WALL: Color8(154, 161, 171),
	WorldTileType.Kind.FURNACE: Color8(167, 96, 57),
}
const _SKY_COLOR: Color = Color8(92, 151, 224)
const _GRASS_COLOR: Color = Color8(103, 166, 82)
const _GROUND_COLOR: Color = Color8(109, 79, 52)
const _PLAYER_COLOR: Color = Color8(241, 240, 197)
const _PLAYER_OUTLINE_COLOR: Color = Color8(34, 48, 54)
const _ACTION_TARGET_COLOR: Color = Color(0.84, 0.73, 0.34, 0.4)
const _HOVER_OK_COLOR: Color = Color(0.36, 0.74, 0.43, 0.43)
const _HOVER_BAD_COLOR: Color = Color(0.77, 0.28, 0.28, 0.43)
const _FURNACE_BURNING_OVERLAY_COLOR: Color = Color(1.0, 0.55, 0.18, 0.45)
const _ENVIRONMENT_TINT_RED: int = 176
const _ENVIRONMENT_TINT_GREEN: int = 214
const _ENVIRONMENT_TINT_BLUE: int = 240
const _WINTER_TINT_BASE_ALPHA: int = 22
const _COLD_AMBIENT_TINT_ALPHA: int = 44
const _CRITICAL_COLD_TINT_ALPHA: int = 84
const _COMBAT_TINT_COLOR: Color = Color(0.45, 0.10, 0.10, 0.20)
const _NIGHT_TINT_COLOR: Color = Color(0.04, 0.06, 0.18, 0.55)
const _WORLD_BORDER_COLOR: Color = Color8(209, 226, 235, 160)
const _GRID_LINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const _GRID_LINE_WIDTH: float = 1.0
const _GRID_DASH_LENGTH: float = 6.0
const _GRID_DASH_GAP: float = 4.0

var state: GameState
var layout: TileLayout
var hovered_tile: Variant = null
var interaction_mode: int = GameInteractionMode.Kind.EXCAVATE

func setup(p_state: GameState, p_layout: TileLayout) -> void:
	state = p_state
	layout = p_layout

func _draw() -> void:
	if state == null or layout == null:
		return
	var visible: Rect2i = layout.visible_world_bounds()
	for y in range(visible.position.y, visible.position.y + visible.size.y):
		for x in range(visible.position.x, visible.position.x + visible.size.x):
			_draw_tile(Vector2i(x, y))
	_draw_active_action_target()
	_draw_active_furnace_overlays()
	_draw_night_tint()
	_draw_environment_tint()
	_draw_combat_tint()
	_draw_hover_overlay()
	_draw_player()
	_draw_grid()

func _draw_tile(tile: Vector2i) -> void:
	var rect: Rect2 = layout.tile_to_rect(tile)
	var kind: int = state.world.get_tile(tile)
	draw_rect(rect, _tile_color(kind, tile), true)

func _draw_active_furnace_overlays() -> void:
	var visible: Rect2i = layout.visible_world_bounds()
	for y in range(visible.position.y, visible.position.y + visible.size.y):
		for x in range(visible.position.x, visible.position.x + visible.size.x):
			var tile: Vector2i = Vector2i(x, y)
			if state.world.get_tile(tile) != WorldTileType.Kind.FURNACE:
				continue
			if not state.has_active_furnace_at(tile):
				continue
			var rect: Rect2 = layout.tile_to_rect(tile)
			var inset: float = rect.size.x * 0.15
			var inner: Rect2 = Rect2(
				rect.position + Vector2(inset, inset),
				rect.size - Vector2(inset * 2, inset * 2))
			draw_rect(inner, _FURNACE_BURNING_OVERLAY_COLOR, true)

func _draw_active_action_target() -> void:
	if state.active_action == null:
		return
	if not (state.active_action.target_tile is Vector2i):
		return
	if not layout.is_visible(state.active_action.target_tile):
		return
	draw_rect(layout.tile_to_rect(state.active_action.target_tile), _ACTION_TARGET_COLOR, true)

func _draw_hover_overlay() -> void:
	if not (hovered_tile is Vector2i):
		return
	var ok: bool = GameActionRules.can_start_action(
		state,
		GameInteractionMode.to_action_kind(interaction_mode),
		hovered_tile)
	draw_rect(layout.tile_to_rect(hovered_tile), _HOVER_OK_COLOR if ok else _HOVER_BAD_COLOR, true)

func _draw_player() -> void:
	if not layout.is_visible(state.player.tile_position):
		return
	var rect: Rect2 = layout.tile_to_rect(state.player.tile_position)
	var player_height: float = rect.size.y * 0.5
	var player_width: float = player_height / 3.0
	var outline_width: float = maxf(2.0, rect.size.x * 0.035)
	var body: Rect2 = Rect2(
		Vector2(
			rect.position.x + (rect.size.x - player_width) * 0.5,
			rect.position.y + rect.size.y - player_height - (rect.size.y * 0.10)),
		Vector2(player_width, player_height))
	draw_rect(body, _PLAYER_OUTLINE_COLOR, true)
	var inner_size: Vector2 = Vector2(
		maxf(1.0, body.size.x - (outline_width * 2.0)),
		maxf(1.0, body.size.y - (outline_width * 2.0)))
	var inner: Rect2 = Rect2(body.position + Vector2(outline_width, outline_width), inner_size)
	draw_rect(inner, _PLAYER_COLOR, true)

func _draw_environment_tint() -> void:
	var alpha: int = 0
	if state.clock.season == Season.Kind.WINTER:
		alpha = _WINTER_TINT_BASE_ALPHA
	if state.current_ambient_temperature <= GameBalance.COLD_AMBIENT_WARNING_THRESHOLD:
		alpha = maxi(alpha, _COLD_AMBIENT_TINT_ALPHA)
	if state.player.current_temperature <= GameBalance.HYPOTHERMIA_DAMAGE_THRESHOLD:
		alpha = maxi(alpha, _CRITICAL_COLD_TINT_ALPHA)
	if alpha <= 0:
		return
	var bounds: Rect2 = _world_bounds()
	draw_rect(bounds, Color8(
		_ENVIRONMENT_TINT_RED,
		_ENVIRONMENT_TINT_GREEN,
		_ENVIRONMENT_TINT_BLUE,
		alpha), true)

func _draw_combat_tint() -> void:
	if state.active_combat == null:
		return
	draw_rect(_world_bounds(), _COMBAT_TINT_COLOR, true)

func _draw_night_tint() -> void:
	var brightness: float = DayNightCycle.get_brightness(state.clock)
	var darkness: float = clampf(1.0 - brightness, 0.0, 1.0)
	if darkness <= 0.0:
		return
	var tint: Color = _NIGHT_TINT_COLOR
	tint.a *= darkness
	draw_rect(_world_bounds(), tint, true)

func _world_bounds() -> Rect2:
	return layout.world_bounds_rect()

func _draw_grid() -> void:
	var bounds: Rect2 = _world_bounds()
	draw_rect(bounds, _WORLD_BORDER_COLOR, false, _GRID_LINE_WIDTH)
	var visible: Rect2i = layout.visible_world_bounds()
	var camera_origin: Vector2 = layout.camera_origin_tile()
	var tile_size_px: float = layout.tile_size_px()
	var bounds_right: float = bounds.position.x + bounds.size.x
	var bounds_bottom: float = bounds.position.y + bounds.size.y
	for tile_x in range(visible.position.x + 1, visible.position.x + visible.size.x):
		var x: float = bounds.position.x + (float(tile_x) - camera_origin.x) * tile_size_px
		if x <= bounds.position.x or x >= bounds_right:
			continue
		_draw_dashed_line(
			Vector2(x, bounds.position.y),
			Vector2(x, bounds_bottom))
	for tile_y in range(visible.position.y + 1, visible.position.y + visible.size.y):
		var y: float = bounds.position.y + (float(tile_y) - camera_origin.y) * tile_size_px
		if y <= bounds.position.y or y >= bounds_bottom:
			continue
		_draw_dashed_line(
			Vector2(bounds.position.x, y),
			Vector2(bounds_right, y))

func _draw_dashed_line(from_point: Vector2, to_point: Vector2) -> void:
	var delta: Vector2 = to_point - from_point
	var total: float = delta.length()
	if total <= 0.0:
		return
	var direction: Vector2 = delta / total
	var pos: float = 0.0
	while pos < total:
		var seg_end: float = minf(pos + _GRID_DASH_LENGTH, total)
		draw_line(
			from_point + direction * pos,
			from_point + direction * seg_end,
			_GRID_LINE_COLOR,
			_GRID_LINE_WIDTH)
		pos = seg_end + _GRID_DASH_GAP

func _tile_color(kind: int, tile: Vector2i) -> Color:
	match kind:
		WorldTileType.Kind.AIR:
			if tile.y == state.world.surface_row - 1:
				return _GRASS_COLOR
			return _SKY_COLOR
		WorldTileType.Kind.SOIL:
			return _GROUND_COLOR
		_:
			return _TILE_COLORS.get(kind, Color.MAGENTA)
