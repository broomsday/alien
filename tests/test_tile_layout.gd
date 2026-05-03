extends SceneTree

const TileLayoutScript = preload("res://scripts/client/tile_layout.gd")
const WorldGridScript = preload("res://scripts/core/world/world_grid.gd")

func _init() -> void:
	_test_default_view_uses_extra_space_for_partial_tiles()
	_test_zoomed_out_view_can_show_the_full_21x12_grid()
	_test_visible_window_clamps_at_world_edges()
	_test_pixel_mapping_tracks_current_view()
	print("test_tile_layout: ok")
	quit(0)

func _test_default_view_uses_extra_space_for_partial_tiles() -> void:
	var world: WorldGrid = WorldGridScript.create_default(21, 12, 4)
	var layout: TileLayout = TileLayoutScript.new(world)
	var play_area_rect: Rect2 = Rect2(Vector2(100.0, 60.0), Vector2(1600.0, 820.0))
	layout.set_play_area(play_area_rect)
	layout.set_focus_tile(Vector2i(10, 5))

	var visible: Rect2i = layout.visible_world_bounds()
	assert(visible.position == Vector2i(6, 3),
		"expected draw origin at 6,3, got %s" % visible.position)
	assert(visible.size == Vector2i(9, 4),
		"expected partial-overflow draw size 9x4, got %s" % visible.size)
	assert(layout.world_bounds_rect() == play_area_rect,
		"expected default zoom to consume the full play area, got %s" % layout.world_bounds_rect())
	var first_tile_rect: Rect2 = layout.tile_to_rect(visible.position)
	assert(is_equal_approx(first_tile_rect.size.x, first_tile_rect.size.y),
		"expected square tiles, got %s" % first_tile_rect.size)
	assert(first_tile_rect.position.x < play_area_rect.position.x,
		"expected the first tile to be partially clipped on the left, got %s" % first_tile_rect.position)

func _test_zoomed_out_view_can_show_the_full_21x12_grid() -> void:
	var world: WorldGrid = WorldGridScript.create_default(21, 12, 4)
	var layout: TileLayout = TileLayoutScript.new(world)
	var play_area_rect: Rect2 = Rect2(Vector2(100.0, 60.0), Vector2(1600.0, 820.0))
	layout.set_play_area(play_area_rect)
	layout.set_focus_tile(Vector2i(10, 5))
	for _zoom_step in range(8):
		layout.adjust_zoom_steps(1)

	var visible: Rect2i = layout.visible_world_bounds()
	assert(visible.position == Vector2i.ZERO,
		"expected the full-grid zoom to start at world origin, got %s" % visible.position)
	assert(visible.size == Vector2i(21, 12),
		"expected the full 21x12 world at max zoom, got %s" % visible.size)
	var world_rect: Rect2 = layout.world_bounds_rect()
	assert(world_rect.size.x < play_area_rect.size.x or world_rect.size.y < play_area_rect.size.y,
		"expected the full-grid zoom to center within the play area, got %s" % world_rect)
	assert(world_rect.position.x > play_area_rect.position.x or world_rect.position.y > play_area_rect.position.y,
		"expected centered world rect at max zoom, got %s" % world_rect.position)

func _test_visible_window_clamps_at_world_edges() -> void:
	var world: WorldGrid = WorldGridScript.create_default(21, 12, 4)
	var layout: TileLayout = TileLayoutScript.new(world)
	layout.set_play_area(Rect2(Vector2.ZERO, Vector2(1600.0, 820.0)))
	layout.set_focus_tile(Vector2i(1, 1))
	assert(layout.visible_world_bounds().position == Vector2i.ZERO,
		"expected top-left clamp at world origin")

	layout.set_focus_tile(Vector2i(20, 11))
	var last_tile: Vector2i = Vector2i(20, 11)
	assert(layout.is_visible(last_tile), "expected bottom-right tile to remain visible")
	var last_tile_rect: Rect2 = layout.tile_to_rect(last_tile)
	var world_rect: Rect2 = layout.world_bounds_rect()
	assert(last_tile_rect.position.x + last_tile_rect.size.x <= world_rect.position.x + world_rect.size.x + 0.001,
		"expected bottom-right tile to clamp inside world bounds, got %s vs %s" % [last_tile_rect, world_rect])
	assert(last_tile_rect.position.y + last_tile_rect.size.y <= world_rect.position.y + world_rect.size.y + 0.001,
		"expected bottom-right tile to clamp inside world bounds, got %s vs %s" % [last_tile_rect, world_rect])

func _test_pixel_mapping_tracks_current_view() -> void:
	var world: WorldGrid = WorldGridScript.create_default(21, 12, 4)
	var layout: TileLayout = TileLayoutScript.new(world)
	layout.set_play_area(Rect2(Vector2(200.0, 100.0), Vector2(1400.0, 760.0)))
	layout.set_focus_tile(Vector2i(10, 5))

	var first_visible_tile: Vector2i = layout.visible_world_bounds().position
	var first_rect: Rect2 = layout.tile_to_rect(first_visible_tile)
	var bounds: Rect2 = layout.world_bounds_rect()
	var mapped_tile: Variant = layout.pixel_to_tile(Vector2(
		maxf(first_rect.position.x, bounds.position.x) + 8.0,
		first_rect.position.y + (first_rect.size.y * 0.5)))
	assert(mapped_tile == first_visible_tile,
		"expected click at first tile to map back to %s, got %s" % [first_visible_tile, mapped_tile])
	var partial_left_sample: Vector2 = Vector2(
		bounds.position.x + 8.0,
		first_rect.position.y + (first_rect.size.y * 0.5))
	assert(layout.pixel_to_tile(partial_left_sample) == first_visible_tile,
		"expected a point inside the partial leading tile to map back to %s" % first_visible_tile)
	assert(layout.pixel_to_tile(first_rect.position - Vector2(12.0, 12.0)) == null,
		"expected point outside playfield to map to null")
