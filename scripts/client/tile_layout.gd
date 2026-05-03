class_name TileLayout
extends RefCounted

const BASE_VISIBLE_TILE_COLUMNS: int = 7
const BASE_VISIBLE_TILE_ROWS: int = 4
const FULL_GRID_COLUMNS: int = 21
const FULL_GRID_ROWS: int = 12
const _ZOOM_STEP: float = 0.25

var world: WorldGrid
var _play_area_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(800.0, 600.0))
var _draw_origin_tile: Vector2i = Vector2i.ZERO
var _draw_tile_columns: int = BASE_VISIBLE_TILE_COLUMNS
var _draw_tile_rows: int = BASE_VISIBLE_TILE_ROWS
var _visible_tile_span: Vector2 = Vector2(
	float(BASE_VISIBLE_TILE_COLUMNS),
	float(BASE_VISIBLE_TILE_ROWS))
var _tile_pitch_px: Vector2 = Vector2(64.0, 64.0)
var _tile_draw_size_px: Vector2 = Vector2(63.0, 63.0)
var _origin_px: Vector2 = Vector2.ZERO
var _focus_tile: Vector2i = Vector2i.ZERO
var _camera_origin_tile: Vector2 = Vector2.ZERO
var _zoom_out_factor: float = 1.0

func _init(p_world: WorldGrid) -> void:
	assert(p_world != null, "world required")
	world = p_world
	_focus_tile = Vector2i(p_world.width / 2, p_world.height / 2)
	_recalculate_metrics()
	_recenter_view()

func set_play_area(rect: Rect2) -> void:
	_play_area_rect = rect
	_recalculate_metrics()
	_recenter_view()

func set_focus_tile(tile_position: Vector2i) -> void:
	_focus_tile = tile_position
	_recenter_view()

func visible_tile_columns() -> int:
	return _draw_tile_columns

func visible_tile_rows() -> int:
	return _draw_tile_rows

func tile_size_px() -> float:
	return _tile_pitch_px.x

func camera_origin_tile() -> Vector2:
	return _camera_origin_tile

func adjust_zoom_steps(delta_steps: int) -> bool:
	if delta_steps == 0:
		return false
	var previous_zoom: float = _zoom_out_factor
	_zoom_out_factor = clampf(
		_zoom_out_factor + (float(delta_steps) * _ZOOM_STEP),
		1.0,
		_max_zoom_out_factor())
	if is_equal_approx(previous_zoom, _zoom_out_factor):
		return false
	_recalculate_metrics()
	_recenter_view()
	return true

func visible_world_bounds() -> Rect2i:
	return Rect2i(
		_draw_origin_tile,
		Vector2i(
			_draw_tile_columns,
			_draw_tile_rows))

func world_bounds_rect() -> Rect2:
	return Rect2(
		_origin_px,
		Vector2(
			_tile_pitch_px.x * _visible_tile_span.x,
			_tile_pitch_px.y * _visible_tile_span.y))

func tile_to_rect(tile: Vector2i) -> Rect2:
	return Rect2(
		Vector2(
			_origin_px.x + (float(tile.x) - _camera_origin_tile.x) * _tile_pitch_px.x,
			_origin_px.y + (float(tile.y) - _camera_origin_tile.y) * _tile_pitch_px.y),
		_tile_draw_size_px)

func pixel_to_tile(p: Vector2) -> Variant:
	if not world_bounds_rect().has_point(p):
		return null
	var local: Vector2 = p - _origin_px
	var t: Vector2i = Vector2i(
		int(floor((local.x / _tile_pitch_px.x) + _camera_origin_tile.x)),
		int(floor((local.y / _tile_pitch_px.y) + _camera_origin_tile.y)))
	return t if world.is_within_bounds(t) else null

func is_visible(tile: Vector2i) -> bool:
	return tile_to_rect(tile).intersects(world_bounds_rect())

func _recalculate_metrics() -> void:
	var target_full_span: Vector2 = _target_full_tile_span()
	var tile_size_px: float = maxf(1.0, floor(minf(
		_play_area_rect.size.x / target_full_span.x,
		_play_area_rect.size.y / target_full_span.y)))
	_tile_pitch_px = Vector2(tile_size_px, tile_size_px)
	_tile_draw_size_px = Vector2(maxf(1.0, tile_size_px - 1.0), maxf(1.0, tile_size_px - 1.0))
	var max_visible_span: Vector2 = _max_visible_tile_span()
	_visible_tile_span = Vector2(
		minf(_play_area_rect.size.x / tile_size_px, max_visible_span.x),
		minf(_play_area_rect.size.y / tile_size_px, max_visible_span.y))
	var world_bounds_size: Vector2 = Vector2(
		tile_size_px * _visible_tile_span.x,
		tile_size_px * _visible_tile_span.y)
	_origin_px = (_play_area_rect.position + ((_play_area_rect.size - world_bounds_size) * 0.5)).floor()

func _recenter_view() -> void:
	var target_full_span: Vector2 = _target_full_tile_span()
	var full_columns: int = maxi(1, int(floor(target_full_span.x)))
	var full_rows: int = maxi(1, int(floor(target_full_span.y)))
	var base_origin_tile: Vector2i = Vector2i(
		clampi(_focus_tile.x - (full_columns / 2), 0, maxi(0, world.width - full_columns)),
		clampi(_focus_tile.y - (full_rows / 2), 0, maxi(0, world.height - full_rows)))
	var extra_span: Vector2 = Vector2(
		maxf(0.0, _visible_tile_span.x - target_full_span.x),
		maxf(0.0, _visible_tile_span.y - target_full_span.y))
	var max_left: float = maxf(0.0, float(world.width) - _visible_tile_span.x)
	var max_top: float = maxf(0.0, float(world.height) - _visible_tile_span.y)
	_camera_origin_tile = Vector2(
		clampf(float(base_origin_tile.x) - (extra_span.x * 0.5), 0.0, max_left),
		clampf(float(base_origin_tile.y) - (extra_span.y * 0.5), 0.0, max_top))
	_draw_origin_tile = Vector2i(
		int(floor(_camera_origin_tile.x)),
		int(floor(_camera_origin_tile.y)))
	var draw_end_tile: Vector2i = Vector2i(
		mini(world.width, int(ceil(_camera_origin_tile.x + _visible_tile_span.x))),
		mini(world.height, int(ceil(_camera_origin_tile.y + _visible_tile_span.y))))
	_draw_tile_columns = maxi(0, draw_end_tile.x - _draw_origin_tile.x)
	_draw_tile_rows = maxi(0, draw_end_tile.y - _draw_origin_tile.y)

func _target_full_tile_span() -> Vector2:
	var max_visible_span: Vector2 = _max_visible_tile_span()
	return Vector2(
		minf(max_visible_span.x, float(BASE_VISIBLE_TILE_COLUMNS) * _zoom_out_factor),
		minf(max_visible_span.y, float(BASE_VISIBLE_TILE_ROWS) * _zoom_out_factor))

func _max_visible_tile_span() -> Vector2:
	return Vector2(
		minf(float(world.width), float(FULL_GRID_COLUMNS)),
		minf(float(world.height), float(FULL_GRID_ROWS)))

func _max_zoom_out_factor() -> float:
	var max_visible_span: Vector2 = _max_visible_tile_span()
	return maxf(1.0, minf(
		max_visible_span.x / float(BASE_VISIBLE_TILE_COLUMNS),
		max_visible_span.y / float(BASE_VISIBLE_TILE_ROWS)))
