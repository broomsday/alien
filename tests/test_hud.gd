extends SceneTree

const HudScript = preload("res://scripts/client/hud.gd")

func _init() -> void:
	if not _test_shell_layout_uses_percentage_panels():
		return
	if not _test_backdrop_rects_leave_play_area_clear():
		return
	if not _test_crew_card_layout_preserves_the_default_aspect_ratio():
		return
	if not _test_single_active_crew_card_uses_the_two_slot_stack():
		return
	if not _test_crew_card_zoom_out_chooses_a_smaller_grid_fit():
		return
	if not _test_context_menu_layout_flips_actor_panel_inside_the_viewport():
		return
	if not _test_context_menu_stays_open_while_child_is_hovered():
		return
	print("test_hud: ok")
	quit(0)

func _test_shell_layout_uses_percentage_panels() -> bool:
	var viewport_size: Vector2 = Vector2(1600.0, 900.0)
	var shell_layout: Dictionary = HudScript.calculate_shell_layout(viewport_size)
	var crew_rect: Rect2 = shell_layout["crew_rect"]
	var top_rect: Rect2 = shell_layout["top_rect"]
	var ui_scale: float = shell_layout["ui_scale"]

	if not _require(is_equal_approx(crew_rect.size.x, 240.0),
		"expected left panel width 240, got %s" % crew_rect.size.x):
		return false
	if not _require(is_equal_approx(top_rect.size.y, 67.5),
		"expected top panel height 67.5, got %s" % top_rect.size.y):
		return false
	if not _require(is_equal_approx(ui_scale, 0.8333333),
		"expected ui scale near 0.8333, got %s" % ui_scale):
		return false
	return true

func _test_backdrop_rects_leave_play_area_clear() -> bool:
	var viewport_size: Vector2 = Vector2(1920.0, 1080.0)
	var play_area_rect: Rect2 = Rect2(Vector2(424.0, 98.0), Vector2(1496.0, 982.0))
	var backdrop_rects: Array[Rect2] = HudScript.calculate_backdrop_rects(viewport_size, play_area_rect)

	if not _require(backdrop_rects.size() == 4,
		"expected four backdrop rects, got %d" % backdrop_rects.size()):
		return false
	if not _require(backdrop_rects[0] == Rect2(Vector2.ZERO, Vector2(1920.0, 98.0)),
		"top backdrop rect wrong: %s" % backdrop_rects[0]):
		return false
	if not _require(backdrop_rects[1] == Rect2(Vector2.ZERO, Vector2(424.0, 1080.0)),
		"left backdrop rect wrong: %s" % backdrop_rects[1]):
		return false
	if not _require(backdrop_rects[2] == Rect2(Vector2(1920.0, 0.0), Vector2(0.0, 1080.0)),
		"right backdrop rect wrong: %s" % backdrop_rects[2]):
		return false
	if not _require(backdrop_rects[3] == Rect2(Vector2(0.0, 1080.0), Vector2(1920.0, 0.0)),
		"bottom backdrop rect wrong: %s" % backdrop_rects[3]):
		return false

	for rect in backdrop_rects:
		if not _require(not rect.intersects(play_area_rect),
			"backdrop rect overlaps play area: %s" % rect):
			return false
	return true

func _test_crew_card_layout_preserves_the_default_aspect_ratio() -> bool:
	var panel_size: Vector2 = Vector2(264.0, 1056.0)
	var card_aspect_ratio: float = HudScript.calculate_default_crew_card_aspect_ratio(panel_size)
	var layout: Dictionary = HudScript.calculate_crew_card_layout(panel_size, 8, card_aspect_ratio, 1.0)
	var card_size: Vector2 = layout["card_size"]

	if not _require(layout["columns"] == 2 and layout["rows"] == 4,
		"expected the default crew grid to remain 2x4, got %sx%s" % [layout["columns"], layout["rows"]]):
		return false
	if not _require(is_equal_approx(card_size.x / card_size.y, card_aspect_ratio),
		"expected card aspect ratio %s, got %s" % [card_aspect_ratio, card_size.x / card_size.y]):
		return false
	return true

func _test_single_active_crew_card_uses_the_two_slot_stack() -> bool:
	var panel_size: Vector2 = Vector2(264.0, 1056.0)
	var card_aspect_ratio: float = HudScript.calculate_default_crew_card_aspect_ratio(panel_size)
	var layout_card_count: int = HudScript.calculate_crew_layout_card_count(1)
	var layout: Dictionary = HudScript.calculate_crew_card_layout(
		panel_size,
		layout_card_count,
		card_aspect_ratio,
		1.0)

	if not _require(layout_card_count == 2,
		"expected one active crew card to reserve a two-card stack, got %d slots" % layout_card_count):
		return false
	if not _require(layout["columns"] == 1 and layout["rows"] == 2,
		"expected one active crew card to use a 1x2 layout, got %sx%s" % [layout["columns"], layout["rows"]]):
		return false
	return true

func _test_crew_card_zoom_out_chooses_a_smaller_grid_fit() -> bool:
	var panel_size: Vector2 = Vector2(264.0, 1056.0)
	var card_aspect_ratio: float = HudScript.calculate_default_crew_card_aspect_ratio(panel_size)
	var base_layout: Dictionary = HudScript.calculate_crew_card_layout(panel_size, 8, card_aspect_ratio, 1.0)
	var zoomed_layout: Dictionary = HudScript.calculate_crew_card_layout(panel_size, 8, card_aspect_ratio, 1.5)
	var base_card_size: Vector2 = base_layout["card_size"]
	var zoomed_card_size: Vector2 = zoomed_layout["card_size"]

	if not _require(zoomed_card_size.y < base_card_size.y,
		"expected zoomed-out cards to be shorter than %s, got %s" % [base_card_size, zoomed_card_size]):
		return false
	if not _require(
		zoomed_layout["columns"] != base_layout["columns"]
			or zoomed_layout["rows"] != base_layout["rows"],
		"expected zoomed-out crew layout to change its row/column arrangement"):
		return false
	return true

func _test_context_menu_layout_flips_actor_panel_inside_the_viewport() -> bool:
	var layout: Dictionary = HudScript.calculate_context_menu_layout(
		Vector2(640.0, 360.0),
		Vector2(590.0, 320.0),
		Vector2(180.0, 120.0),
		Vector2(200.0, 150.0),
		12.0,
		10.0)
	var action_position: Vector2 = layout["action_position"]
	var actor_position: Vector2 = layout["actor_position"]

	if not _require(action_position.x >= 0.0 and action_position.y >= 0.0,
		"expected action panel clamped into viewport, got %s" % [action_position]):
		return false
	if not _require(actor_position.x >= 0.0 and actor_position.y >= 0.0,
		"expected actor panel clamped into viewport, got %s" % [actor_position]):
		return false
	if not _require(actor_position.x < action_position.x,
		"expected actor panel to flip left of the action panel, got %s vs %s" % [actor_position, action_position]):
		return false
	return true

func _test_context_menu_stays_open_while_child_is_hovered() -> bool:
	var parent_rect: Rect2 = Rect2(Vector2(100.0, 100.0), Vector2(180.0, 120.0))
	var child_rect: Rect2 = Rect2(Vector2(292.0, 100.0), Vector2(200.0, 150.0))
	var child_hover: Vector2 = Vector2(350.0, 130.0)
	var gap_hover: Vector2 = Vector2(286.0, 130.0)
	var outside_hover: Vector2 = Vector2(80.0, 80.0)

	if not _require(HudScript.should_keep_context_menu_open(child_hover, parent_rect, true, child_rect),
		"expected child hover to keep the menu open"):
		return false
	if not _require(HudScript.should_keep_context_menu_open(gap_hover, parent_rect, true, child_rect),
		"expected the gap between parent and child to keep the menu open"):
		return false
	if not _require(not HudScript.should_keep_context_menu_open(outside_hover, parent_rect, true, child_rect),
		"expected outside hover to close the menu"):
		return false
	return true

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
