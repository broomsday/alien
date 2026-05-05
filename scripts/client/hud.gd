class_name Hud
extends Control

signal start_expedition_requested
signal craft_weapon_requested
signal play_area_changed(play_area_rect: Rect2)
signal world_object_action_requested(action_kind: int, target_tile: Vector2i, actor_slot: int)

const EnvironmentDangerLevelScript = preload("res://scripts/core/simulation/environment_danger_level.gd")
const ActorActionRulesScript = preload("res://scripts/core/simulation/actor_action_rules.gd")
const GameActionKindScript = preload("res://scripts/core/simulation/game_action_kind.gd")
const WorldObjectKindScript = preload("res://scripts/core/world/world_object_kind.gd")

const _BASE_VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const _LEFT_PANEL_WIDTH_RATIO: float = 0.15
const _TOP_PANEL_HEIGHT_RATIO: float = 0.075
const _BASE_PANEL_GAP_PX: float = 2.0
const _PLAY_AREA_PADDING_PX: int = 0
const _BASE_PANEL_CONTENT_MARGIN_PX: float = 12.0
const _BASE_CARD_MIN_HEIGHT_PX: float = 120.0
const _BASE_CARD_INSET_PX: float = 6.0
const _BASE_CARD_BOX_SEPARATION_PX: int = 4
const _BASE_METRIC_BOX_SEPARATION_PX: int = 3
const _BASE_BAR_HEIGHT_PX: float = 18.0
const _BASE_TOP_ROW_SEPARATION_PX: int = 8
const _BASE_POPUP_SEPARATION_PX: int = 8
const _BASE_STAT_CHIP_MIN_WIDTH_PX: float = 132.0
const _BASE_BUTTON_MIN_WIDTH_PX: float = 116.0
const _BASE_BUTTON_MIN_HEIGHT_PX: float = 40.0
const _BASE_POPUP_TITLE_FONT_SIZE: int = 22
const _BASE_POPUP_CLOSE_BUTTON_SIZE_PX: float = 36.0
const _BASE_CONTEXT_PANEL_WIDTH_PX: float = 220.0
const _BASE_CONTEXT_PANEL_GAP_PX: float = 10.0
const _BASE_CONTEXT_ANCHOR_OFFSET_PX: float = -12.0
const _CARD_TITLE_FONT_SIZE: int = 16
const _BODY_FONT_SIZE: int = 15
const _STAT_TITLE_FONT_SIZE: int = 11
const _STAT_VALUE_FONT_SIZE: int = 18
const _BUTTON_FONT_SIZE: int = 15
const _LABEL_FONT_SIZE: int = 15
const _SHELL_BG_COLOR: Color = Color(0.05, 0.08, 0.10, 0.86)
const _BACKDROP_COLOR: Color = Color8(134, 168, 181)
const _GAS_SAFE_COLOR: Color = Color8(94, 200, 132)
const _GAS_WARNING_COLOR: Color = Color8(242, 182, 88)
const _GAS_CRITICAL_COLOR: Color = Color8(225, 86, 86)
const _CARD_BG_COLOR: Color = Color(0.08, 0.12, 0.15, 0.96)
const _PLAY_AREA_BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const _PANEL_BORDER_COLOR: Color = Color8(134, 168, 181)
const _CARD_BORDER_COLOR: Color = Color8(108, 135, 147)
const _SAFE_TEMPERATURE_COLOR: Color = Color8(94, 165, 255)
const _COOL_TEMPERATURE_COLOR: Color = Color8(181, 220, 255)
const _WARNING_TEMPERATURE_COLOR: Color = Color8(242, 182, 88)
const _CRITICAL_TEMPERATURE_COLOR: Color = Color8(225, 86, 86)
const _SUMMER_SEASON_COLOR: Color = Color8(226, 191, 92)
const _AUTUMN_SEASON_COLOR: Color = Color8(192, 114, 68)
const _WINTER_SEASON_COLOR: Color = Color8(160, 208, 255)
const _SPRING_SEASON_COLOR: Color = Color8(121, 196, 104)
const _PORTRAIT_BG_COLOR: Color = Color8(58, 66, 71)
const _PORTRAIT_BORDER_COLOR: Color = Color8(128, 143, 151)
const _BAR_BG_COLOR: Color = Color8(45, 51, 56)
const _INTEGRITY_BAR_COLOR: Color = Color8(207, 72, 72)
const _ENERGY_BAR_COLOR: Color = Color8(220, 191, 73)
const _PSYCHE_BAR_COLOR: Color = Color8(214, 88, 198)

const _PORTRAIT_BASE_PATH: String = "res://resources/sprites/characters/portraits/"
const _DEFAULT_PORTRAIT_FILENAME: String = "Unknown.png"

const _CREW_SLOT_COUNT: int = 8
const _CREW_DEFAULT_COLUMNS: int = 2
const _CREW_DEFAULT_ROWS: int = 4
const _CREW_ZOOM_STEP: float = 0.25
const _CREW_MAX_ZOOM_OUT_FACTOR: float = 3.0

enum TemperatureUnit {
	FAHRENHEIT,
	KELVIN,
	CELSIUS,
}

enum ContextSourceKind {
	NONE,
	WORLD_OBJECT,
	ACTOR,
}

var _backdrop_panels: Array[ColorRect] = []
var _crew_panel: PanelContainer
var _top_panel: PanelContainer
var _top_row: HBoxContainer
var _play_area_panel: PanelContainer
var _world_display_rect: Rect2 = Rect2()
var _crew_slots_root: Control
var _crew_card_boxes: Array[VBoxContainer] = []
var _crew_card_aspect_ratio: float = 0.0
var _crew_zoom_out_factor: float = 1.0
var _active_crew_card_count: int = 1
var _date_value_label: Label
var _outdoor_temperature_value_label: Label
var _stat_chip_title_labels: Array[Label] = []
var _stat_chips: Array[PanelContainer] = []
var _outdoor_temperature_chip: PanelContainer
var _ambient_gas_value_label: Label
var _day_night_value_label: Label
var _temperature_unit: int = TemperatureUnit.FAHRENHEIT
var _crew_cards: Array[Control] = []
var _crew_separators: Array[ColorRect] = []
var _crew_name_labels: Array[Label] = []
var _crew_metric_boxes: Array[VBoxContainer] = []
var _crew_metric_title_labels: Array[Label] = []
var _crew_integrity_value_labels: Array[Label] = []
var _crew_energy_value_labels: Array[Label] = []
var _crew_psyche_value_labels: Array[Label] = []
var _crew_integrity_bars: Array[ProgressBar] = []
var _crew_energy_bars: Array[ProgressBar] = []
var _crew_psyche_bars: Array[ProgressBar] = []
var _crew_portrait_textures: Array[TextureRect] = []
var _portrait_cache: Dictionary = {}
var _expedition_button: Button
var _crafting_button: Button
var _inventory_button: Button
var _assignments_button: Button
var _main_menu_button: Button
var _top_buttons: Array[Button] = []
var _popup_root: Control
var _popup_panel: PanelContainer
var _popup_box: VBoxContainer
var _popup_title_label: Label
var _popup_close_button: Button
var _popup_character_view: VBoxContainer
var _popup_character_portrait: TextureRect
var _popup_character_physique_label: Label
var _popup_character_aptitude_label: Label
var _popup_character_slot: int = -1
var _latest_state: GameState
var _context_menu_root: Control
var _context_action_panel: PanelContainer
var _context_action_box: VBoxContainer
var _context_action_title_label: Label
var _context_action_list: VBoxContainer
var _context_actor_panel: PanelContainer
var _context_actor_box: VBoxContainer
var _context_actor_title_label: Label
var _context_actor_list: VBoxContainer
var _context_action_buttons: Array[Button] = []
var _context_actor_buttons: Array[Button] = []
var _context_source_kind: int = ContextSourceKind.NONE
var _context_actor_slot: int = -1
var _context_target_tile: Variant = null
var _context_object_kind: Variant = null
var _context_hover_action_kind: Variant = null
var _context_anchor_position: Vector2 = Vector2.ZERO
var _context_secondary_list_action_kind: Variant = null
var _context_secondary_list_target_tile: Variant = null
var _context_secondary_list_actor_slot: int = -1
var _context_secondary_list_source_kind: int = ContextSourceKind.NONE
var _context_opened_at_msec: int = 0
var _context_has_been_hovered: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_sync_to_viewport()
	get_viewport().size_changed.connect(_sync_to_viewport)

	_build_shell()
	_update_layout()
	resized.connect(_on_resized)

func refresh(state: GameState, interaction_mode: int) -> void:
	_latest_state = state
	var outdoor_temperature: float = SurvivalRules.get_outdoor_temperature(state)
	var phase: int = DayNightCycle.get_phase(state.clock)
	# Phase 7 only exposes the player card; future crew members can raise this count.
	_set_active_crew_card_count(1)
	_date_value_label.text = "%s  %s Day %02d" % [
		_time_of_day_text(state.clock),
		Season.Kind.keys()[state.clock.season].capitalize(),
		state.clock.day_of_season,
	]
	_outdoor_temperature_value_label.text = _format_temperature(outdoor_temperature)
	_ambient_gas_value_label.text = "%0.0f ppm" % state.current_ambient_gas
	_day_night_value_label.text = DayNightCycle.phase_label(phase)
	_day_night_value_label.add_theme_color_override("font_color", _day_night_color(phase))
	_crew_name_labels[0].text = "Crew 01"
	_crew_portrait_textures[0].texture = _get_portrait_texture(state.player.portrait_filename)
	_set_metric_bar(
		_crew_integrity_bars[0],
		_crew_integrity_value_labels[0],
		float(state.player.current_integrity()),
		float(state.player.max_integrity()),
		"%d / %d" % [state.player.current_integrity(), state.player.max_integrity()])
	_set_metric_bar(
		_crew_energy_bars[0],
		_crew_energy_value_labels[0],
		state.player.current_energy,
		state.player.max_energy,
		"%0.0f / %0.0f" % [state.player.current_energy, state.player.max_energy])
	_set_metric_bar(
		_crew_psyche_bars[0],
		_crew_psyche_value_labels[0],
		state.player.current_psyche,
		state.player.max_psyche,
		"%0.0f / %0.0f" % [state.player.current_psyche, state.player.max_psyche])
	var unknown_portrait: Texture2D = _get_portrait_texture(_DEFAULT_PORTRAIT_FILENAME)
	for slot_index in range(1, _CREW_SLOT_COUNT):
		_crew_name_labels[slot_index].text = "Crew %02d" % [slot_index + 1]
		_crew_portrait_textures[slot_index].texture = unknown_portrait
		_set_metric_bar(_crew_integrity_bars[slot_index], _crew_integrity_value_labels[slot_index], 0.0, 0.0, "0 / 0")
		_set_metric_bar(_crew_energy_bars[slot_index], _crew_energy_value_labels[slot_index], 0.0, 0.0, "0 / 0")
		_set_metric_bar(_crew_psyche_bars[slot_index], _crew_psyche_value_labels[slot_index], 0.0, 0.0, "0 / 0")
	if _popup_character_slot >= 0:
		_refresh_character_popup(state)
	var season_color: Color = _season_color(state.clock.season)
	_date_value_label.add_theme_color_override("font_color", season_color)
	_outdoor_temperature_value_label.add_theme_color_override("font_color", _temperature_color(state.player))
	_ambient_gas_value_label.add_theme_color_override("font_color", _gas_color(state.current_ambient_gas))
	if state.active_combat != null:
		_expedition_button.text = "Attack"
		_expedition_button.disabled = not GameActionRules.can_start_action(
			state,
			GameActionKind.Kind.ATTACK,
			null)
	else:
		_expedition_button.text = "Expedition"
		_expedition_button.disabled = not _can_start_expedition(state)
	_crafting_button.disabled = not _can_craft_weapon(state)
	_inventory_button.disabled = false
	_assignments_button.disabled = false
	_refresh_context_menu(state)

func get_world_viewport_rect() -> Rect2:
	if _play_area_panel == null:
		return Rect2()
	var padding: Vector2 = Vector2(_PLAY_AREA_PADDING_PX, _PLAY_AREA_PADDING_PX)
	var inner_size: Vector2 = _play_area_panel.size - (padding * 2.0)
	return Rect2(
		_play_area_panel.position + padding,
		Vector2(maxf(0.0, inner_size.x), maxf(0.0, inner_size.y)))

func get_crew_panel_rect() -> Rect2:
	if _crew_panel == null:
		return Rect2()
	return _crew_panel.get_rect()

func set_world_display_rect(rect: Rect2) -> void:
	_world_display_rect = rect
	_layout_backdrop(_world_display_rect)

func adjust_crew_zoom_steps(delta_steps: int) -> bool:
	if delta_steps == 0:
		return false
	var previous_zoom: float = _crew_zoom_out_factor
	_crew_zoom_out_factor = clampf(
		_crew_zoom_out_factor + (float(delta_steps) * _CREW_ZOOM_STEP),
		1.0,
		_CREW_MAX_ZOOM_OUT_FACTOR)
	if is_equal_approx(previous_zoom, _crew_zoom_out_factor):
		return false
	_layout_crew_cards()
	return true

func _set_active_crew_card_count(card_count: int) -> void:
	var clamped_count: int = clampi(card_count, 0, _crew_cards.size())
	if clamped_count == _active_crew_card_count:
		return
	_active_crew_card_count = clamped_count
	_layout_crew_cards()

func _on_expedition_button_pressed() -> void:
	_open_popup("Expedition")

func _on_craft_weapon_pressed() -> void:
	_open_popup("Crafting")

func _on_inventory_button_pressed() -> void:
	_open_popup("Inventory")

func _on_assignments_button_pressed() -> void:
	_open_popup("Assignments")

func _on_main_menu_button_pressed() -> void:
	_open_popup("Main Menu")

func _on_resized() -> void:
	_update_layout()

func _sync_to_viewport() -> void:
	var rect: Rect2 = get_viewport().get_visible_rect()
	position = rect.position
	size = rect.size

func _build_shell() -> void:
	for _panel_index in range(4):
		var backdrop_panel: ColorRect = ColorRect.new()
		backdrop_panel.color = _BACKDROP_COLOR
		backdrop_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop_panel)
		_backdrop_panels.append(backdrop_panel)

	_crew_panel = PanelContainer.new()
	_crew_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crew_panel.clip_contents = true
	_crew_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, 0, _BASE_PANEL_CONTENT_MARGIN_PX, 0))
	add_child(_crew_panel)

	_crew_slots_root = Control.new()
	_crew_slots_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crew_panel.add_child(_crew_slots_root)

	for slot_index in range(_CREW_SLOT_COUNT):
		var card_parts: Dictionary = _make_crew_card(_crew_slots_root, slot_index)
		_crew_cards.append(card_parts["card"])
		_crew_name_labels.append(card_parts["name"])
		_crew_metric_boxes.append(card_parts["metrics"])
		_crew_integrity_value_labels.append(card_parts["integrity_value"])
		_crew_energy_value_labels.append(card_parts["energy_value"])
		_crew_psyche_value_labels.append(card_parts["psyche_value"])
		_crew_integrity_bars.append(card_parts["integrity_bar"])
		_crew_energy_bars.append(card_parts["energy_bar"])
		_crew_psyche_bars.append(card_parts["psyche_bar"])

	_top_panel = PanelContainer.new()
	_top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_panel.clip_contents = true
	_top_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, 0, _BASE_PANEL_CONTENT_MARGIN_PX, 0))
	add_child(_top_panel)

	_top_row = HBoxContainer.new()
	_top_row.add_theme_constant_override("separation", _BASE_TOP_ROW_SEPARATION_PX)
	_top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_top_panel.add_child(_top_row)

	_date_value_label = _make_stat_chip(_top_row, "Date")
	_day_night_value_label = _make_stat_chip(_top_row, "Sky")
	_outdoor_temperature_value_label = _make_stat_chip(_top_row, "Outdoor Temp")
	_outdoor_temperature_chip = _outdoor_temperature_value_label.get_parent().get_parent() as PanelContainer
	_outdoor_temperature_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	_outdoor_temperature_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_outdoor_temperature_chip.gui_input.connect(_on_temperature_chip_input)
	_ambient_gas_value_label = _make_stat_chip(_top_row, "Toxic Gas")

	var button_spacer: Control = Control.new()
	button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_row.add_child(button_spacer)

	_inventory_button = _make_top_button(_top_row, "Inventory", _on_inventory_button_pressed)
	_crafting_button = _make_top_button(_top_row, "Crafting", _on_craft_weapon_pressed)
	_expedition_button = _make_top_button(_top_row, "Expedition", _on_expedition_button_pressed)
	_assignments_button = _make_top_button(_top_row, "Assignments", _on_assignments_button_pressed)
	_main_menu_button = _make_top_button(_top_row, "Main Menu", _on_main_menu_button_pressed)

	_play_area_panel = PanelContainer.new()
	_play_area_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area_panel.clip_contents = true
	_play_area_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_PLAY_AREA_BG_COLOR, _PANEL_BORDER_COLOR, 0, 0.0, 0))
	add_child(_play_area_panel)

	_build_popup()
	_build_context_menu()

func _build_popup() -> void:
	_popup_root = Control.new()
	_popup_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_root.visible = false
	add_child(_popup_root)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	_popup_root.add_child(dim)

	_popup_panel = PanelContainer.new()
	_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, 8, 0.0, 2))
	_popup_root.add_child(_popup_panel)

	_popup_box = VBoxContainer.new()
	_popup_box.add_theme_constant_override("separation", _BASE_POPUP_SEPARATION_PX)
	_popup_panel.add_child(_popup_box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", _BASE_POPUP_SEPARATION_PX)
	_popup_box.add_child(header)

	_popup_title_label = Label.new()
	_popup_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_title_label.add_theme_font_size_override("font_size", _BASE_POPUP_TITLE_FONT_SIZE)
	header.add_child(_popup_title_label)

	_popup_close_button = Button.new()
	_popup_close_button.text = "X"
	_popup_close_button.custom_minimum_size = Vector2(
		_BASE_POPUP_CLOSE_BUTTON_SIZE_PX,
		_BASE_POPUP_CLOSE_BUTTON_SIZE_PX)
	_popup_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_close_button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
	_popup_close_button.pressed.connect(_close_popup)
	header.add_child(_popup_close_button)

	_popup_character_view = VBoxContainer.new()
	_popup_character_view.visible = false
	_popup_character_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_character_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_popup_character_view.add_theme_constant_override("separation", _BASE_POPUP_SEPARATION_PX)
	_popup_box.add_child(_popup_character_view)

	_popup_character_portrait = TextureRect.new()
	_popup_character_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_character_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_popup_character_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_popup_character_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_character_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_popup_character_view.add_child(_popup_character_portrait)

	_popup_character_physique_label = Label.new()
	_popup_character_physique_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_character_physique_label.add_theme_font_size_override("font_size", _LABEL_FONT_SIZE)
	_popup_character_view.add_child(_popup_character_physique_label)

	_popup_character_aptitude_label = Label.new()
	_popup_character_aptitude_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_character_aptitude_label.add_theme_font_size_override("font_size", _LABEL_FONT_SIZE)
	_popup_character_view.add_child(_popup_character_aptitude_label)

func _build_context_menu() -> void:
	_context_menu_root = Control.new()
	_context_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_menu_root.visible = false
	add_child(_context_menu_root)

	_context_action_panel = PanelContainer.new()
	_context_action_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_context_action_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, 8, 10.0, 2))
	_context_menu_root.add_child(_context_action_panel)

	_context_action_box = VBoxContainer.new()
	_context_action_box.add_theme_constant_override("separation", _BASE_POPUP_SEPARATION_PX)
	_context_action_panel.add_child(_context_action_box)

	_context_action_title_label = Label.new()
	_context_action_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_action_title_label.add_theme_font_size_override("font_size", _CARD_TITLE_FONT_SIZE)
	_context_action_box.add_child(_context_action_title_label)

	_context_action_list = VBoxContainer.new()
	_context_action_list.add_theme_constant_override("separation", _BASE_CARD_BOX_SEPARATION_PX)
	_context_action_box.add_child(_context_action_list)

	_context_actor_panel = PanelContainer.new()
	_context_actor_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_context_actor_panel.visible = false
	_context_actor_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, 8, 10.0, 2))
	_context_menu_root.add_child(_context_actor_panel)

	_context_actor_box = VBoxContainer.new()
	_context_actor_box.add_theme_constant_override("separation", _BASE_POPUP_SEPARATION_PX)
	_context_actor_panel.add_child(_context_actor_box)

	_context_actor_title_label = Label.new()
	_context_actor_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_actor_title_label.text = "Capable Crew"
	_context_actor_title_label.add_theme_font_size_override("font_size", _CARD_TITLE_FONT_SIZE)
	_context_actor_box.add_child(_context_actor_title_label)

	_context_actor_list = VBoxContainer.new()
	_context_actor_list.add_theme_constant_override("separation", _BASE_CARD_BOX_SEPARATION_PX)
	_context_actor_box.add_child(_context_actor_list)

func _open_popup(title: String) -> void:
	hide_world_object_actions()
	_popup_character_slot = -1
	_popup_character_view.visible = false
	_popup_title_label.text = title
	_popup_root.visible = true

func _open_character_popup(slot_index: int) -> void:
	hide_world_object_actions()
	_popup_character_slot = slot_index
	_popup_character_view.visible = true
	_popup_title_label.text = _crew_name_labels[slot_index].text
	_popup_root.visible = true

func _close_popup() -> void:
	_popup_character_slot = -1
	_popup_character_view.visible = false
	_popup_root.visible = false

func show_world_object_actions(state: GameState, anchor_position: Vector2, target_tile: Vector2i, object_kind: int) -> void:
	_latest_state = state
	_close_popup()
	_context_source_kind = ContextSourceKind.WORLD_OBJECT
	_context_actor_slot = -1
	_context_target_tile = target_tile
	_context_object_kind = object_kind
	_context_hover_action_kind = null
	_context_anchor_position = anchor_position
	_context_secondary_list_action_kind = null
	_context_secondary_list_target_tile = null
	_context_secondary_list_actor_slot = -1
	_context_secondary_list_source_kind = ContextSourceKind.NONE
	_context_opened_at_msec = Time.get_ticks_msec()
	_context_has_been_hovered = false
	_context_actor_panel.visible = false
	_rebuild_context_action_buttons()
	_context_menu_root.visible = true
	_refresh_context_menu(state)

func show_actor_actions(state: GameState, anchor_position: Vector2, actor_slot: int) -> void:
	_latest_state = state
	_close_popup()
	_context_source_kind = ContextSourceKind.ACTOR
	_context_actor_slot = actor_slot
	_context_target_tile = null
	_context_object_kind = null
	_context_hover_action_kind = null
	_context_anchor_position = anchor_position
	_context_secondary_list_action_kind = null
	_context_secondary_list_target_tile = null
	_context_secondary_list_actor_slot = -1
	_context_secondary_list_source_kind = ContextSourceKind.NONE
	_context_opened_at_msec = Time.get_ticks_msec()
	_context_has_been_hovered = false
	_context_actor_panel.visible = false
	_rebuild_context_action_buttons()
	_context_menu_root.visible = true
	_refresh_context_menu(state)

func hide_world_object_actions() -> void:
	_context_source_kind = ContextSourceKind.NONE
	_context_actor_slot = -1
	_context_target_tile = null
	_context_object_kind = null
	_context_hover_action_kind = null
	_context_secondary_list_action_kind = null
	_context_secondary_list_target_tile = null
	_context_secondary_list_actor_slot = -1
	_context_secondary_list_source_kind = ContextSourceKind.NONE
	_context_has_been_hovered = false
	if _context_actor_panel != null:
		_context_actor_panel.visible = false
	if _context_menu_root != null:
		_context_menu_root.visible = false

func _refresh_character_popup(state: GameState) -> void:
	var portrait_filename: String = _DEFAULT_PORTRAIT_FILENAME
	var physique: int = 0
	var aptitude: int = 0
	if _popup_character_slot == 0:
		portrait_filename = state.player.portrait_filename
		physique = state.player.physique
		aptitude = state.player.aptitude
	_popup_character_portrait.texture = _get_portrait_texture(portrait_filename)
	_popup_character_physique_label.text = "Physique: %d" % physique
	_popup_character_aptitude_label.text = "Aptitude: %d" % aptitude

func _refresh_context_menu(state: GameState) -> void:
	if _context_menu_root == null or not _context_menu_root.visible:
		return
	if not _context_source_is_valid(state):
		hide_world_object_actions()
		return
	_context_action_title_label.text = _context_action_title(state)
	if _context_hover_action_kind != null and _context_secondary_list_needs_rebuild(_context_hover_action_kind):
		_show_context_secondary_panel(state, _context_hover_action_kind)
	_layout_context_menu()
	if _context_panels_ready():
		var keep_open: bool = should_keep_context_menu_open(
			get_viewport().get_mouse_position(),
			_context_action_panel.get_global_rect(),
			_context_actor_panel.visible,
			_context_actor_panel.get_global_rect())
		if keep_open:
			_context_has_been_hovered = true
		elif _context_has_been_hovered and not _is_within_context_open_grace_period():
			hide_world_object_actions()

func _rebuild_context_action_buttons() -> void:
	_clear_context_list(_context_action_list)
	_context_action_buttons.clear()
	match _context_source_kind:
		ContextSourceKind.WORLD_OBJECT:
			if _context_object_kind == WorldObjectKindScript.Kind.FRUIT_BUSH:
				var harvest_button: Button = _make_context_button("Harvest")
				harvest_button.mouse_entered.connect(_on_context_action_hovered.bind(GameActionKindScript.Kind.HARVEST))
				harvest_button.pressed.connect(_on_context_action_hovered.bind(GameActionKindScript.Kind.HARVEST))
				_context_action_list.add_child(harvest_button)
				_context_action_buttons.append(harvest_button)
			else:
				_context_action_list.add_child(_make_context_label("No actions"))
		ContextSourceKind.ACTOR:
			var actor_harvest_button: Button = _make_context_button("Harvest")
			actor_harvest_button.mouse_entered.connect(_on_context_action_hovered.bind(GameActionKindScript.Kind.HARVEST))
			actor_harvest_button.pressed.connect(_on_context_action_hovered.bind(GameActionKindScript.Kind.HARVEST))
			_context_action_list.add_child(actor_harvest_button)
			_context_action_buttons.append(actor_harvest_button)
		_:
			_context_action_list.add_child(_make_context_label("No actions"))

func _show_context_secondary_panel(state: GameState, action_kind: int) -> void:
	_context_hover_action_kind = action_kind
	if _context_secondary_list_needs_rebuild(action_kind):
		_rebuild_context_secondary_buttons(state, action_kind)
	_context_actor_panel.visible = true

func _rebuild_context_secondary_buttons(state: GameState, action_kind: int) -> void:
	_clear_context_list(_context_actor_list)
	_context_actor_buttons.clear()
	_context_secondary_list_action_kind = action_kind
	_context_secondary_list_target_tile = _context_target_tile
	_context_secondary_list_actor_slot = _context_actor_slot
	_context_secondary_list_source_kind = _context_source_kind
	_context_actor_title_label.text = _context_secondary_title()
	match _context_source_kind:
		ContextSourceKind.WORLD_OBJECT:
			var actor_slots: Array[int] = ActorActionRulesScript.get_capable_actor_slots(
				state,
				action_kind,
				_context_target_tile)
			if actor_slots.is_empty():
				_context_actor_list.add_child(_make_context_label("No capable crew"))
				return
			for actor_slot in actor_slots:
				var actor_button: Button = _make_context_button("%s  P%d  A%d" % [
					state.get_actor_display_name(actor_slot),
					state.get_actor_physique(actor_slot),
					state.get_actor_aptitude(actor_slot),
				])
				actor_button.pressed.connect(_on_context_actor_pressed.bind(actor_slot))
				_context_actor_list.add_child(actor_button)
				_context_actor_buttons.append(actor_button)
		ContextSourceKind.ACTOR:
			var object_kinds: Array[int] = ActorActionRulesScript.get_harvestable_object_kinds(state, _context_actor_slot)
			if object_kinds.is_empty():
				_context_actor_list.add_child(_make_context_label("No harvest targets"))
				return
			for object_kind in object_kinds:
				var object_button: Button = _make_context_button(WorldObjectKindScript.display_name(object_kind))
				object_button.pressed.connect(_on_context_object_kind_pressed.bind(object_kind))
				_context_actor_list.add_child(object_button)
				_context_actor_buttons.append(object_button)
		_:
			_context_actor_list.add_child(_make_context_label("No options"))

func _clear_context_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _make_context_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_context_button(button)
	return button

func _make_context_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", _scaled_font(_LABEL_FONT_SIZE, calculate_ui_scale(size), 8))
	return label

func _style_context_button(button: Button) -> void:
	var ui_scale: float = calculate_ui_scale(size)
	button.custom_minimum_size = Vector2(
		_scaled_px(_BASE_CONTEXT_PANEL_WIDTH_PX - 28.0, ui_scale, 140.0),
		_scaled_px(_BASE_BUTTON_MIN_HEIGHT_PX, ui_scale, 24.0))
	button.add_theme_font_size_override("font_size", _scaled_font(_BUTTON_FONT_SIZE, ui_scale, 8))

func _on_context_action_hovered(action_kind: int) -> void:
	if _latest_state == null:
		return
	_show_context_secondary_panel(_latest_state, action_kind)
	_layout_context_menu()

func _on_context_actor_pressed(actor_slot: int) -> void:
	if _context_hover_action_kind == null or not (_context_target_tile is Vector2i):
		return
	world_object_action_requested.emit(_context_hover_action_kind, _context_target_tile, actor_slot)
	hide_world_object_actions()

func _on_context_object_kind_pressed(object_kind: int) -> void:
	if _latest_state == null or _context_hover_action_kind == null or _context_actor_slot < 0:
		return
	var target_tile: Variant = ActorActionRulesScript.find_nearest_harvestable_target_tile(
		_latest_state,
		_context_actor_slot,
		object_kind)
	if not (target_tile is Vector2i):
		return
	world_object_action_requested.emit(_context_hover_action_kind, target_tile, _context_actor_slot)
	hide_world_object_actions()

func _get_portrait_texture(filename: String) -> Texture2D:
	var key: String = filename if not filename.is_empty() else _DEFAULT_PORTRAIT_FILENAME
	if _portrait_cache.has(key):
		return _portrait_cache[key]
	var path: String = _PORTRAIT_BASE_PATH + key
	if not ResourceLoader.exists(path):
		path = _PORTRAIT_BASE_PATH + _DEFAULT_PORTRAIT_FILENAME
	var texture: Texture2D = load(path) as Texture2D
	_portrait_cache[key] = texture
	return texture

func _update_layout() -> void:
	if _crew_panel == null or _top_panel == null or _play_area_panel == null:
		return
	var shell_layout: Dictionary = calculate_shell_layout(size)
	var crew_rect: Rect2 = shell_layout["crew_rect"]
	var top_rect: Rect2 = shell_layout["top_rect"]
	var play_area_rect: Rect2 = shell_layout["play_area_rect"]
	var popup_size: Vector2 = shell_layout["popup_size"]
	var ui_scale: float = shell_layout["ui_scale"]
	var content_margin: float = _scaled_px(_BASE_PANEL_CONTENT_MARGIN_PX, ui_scale, 4.0)

	_apply_responsive_theme(ui_scale)

	_crew_panel.position = crew_rect.position
	_crew_panel.size = crew_rect.size
	_crew_slots_root.position = Vector2(content_margin, content_margin)
	_crew_slots_root.size = Vector2(
		maxf(0.0, crew_rect.size.x - (content_margin * 2.0)),
		maxf(0.0, crew_rect.size.y - (content_margin * 2.0)))
	_layout_crew_cards()

	_top_panel.position = top_rect.position
	_top_panel.size = top_rect.size

	_play_area_panel.position = play_area_rect.position
	_play_area_panel.size = play_area_rect.size
	_world_display_rect = _play_area_panel.get_rect()
	_layout_backdrop(_world_display_rect)

	if _popup_root != null:
		_popup_root.position = Vector2.ZERO
		_popup_root.size = size
		_popup_panel.position = ((size - popup_size) * 0.5).floor()
		_popup_panel.size = popup_size
	if _context_menu_root != null:
		_context_menu_root.position = Vector2.ZERO
		_context_menu_root.size = size
		if _context_menu_root.visible:
			_layout_context_menu()

	play_area_changed.emit(get_world_viewport_rect())

func _layout_context_menu() -> void:
	if _context_menu_root == null or not _context_menu_root.visible:
		return
	var ui_scale: float = calculate_ui_scale(size)
	var panel_gap: float = _scaled_px(_BASE_CONTEXT_PANEL_GAP_PX, ui_scale, 4.0)
	var anchor_offset: float = _scaled_signed_px(_BASE_CONTEXT_ANCHOR_OFFSET_PX, ui_scale)
	var panel_width: float = _scaled_px(_BASE_CONTEXT_PANEL_WIDTH_PX, ui_scale, 160.0)
	_context_action_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_context_actor_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	var action_panel_size: Vector2 = _context_action_panel.get_combined_minimum_size()
	var actor_panel_size: Vector2 = _context_actor_panel.get_combined_minimum_size()
	var menu_layout: Dictionary = calculate_context_menu_layout(
		size,
		_context_anchor_position,
		action_panel_size,
		actor_panel_size,
		panel_gap,
		anchor_offset)
	_context_action_panel.position = menu_layout["action_position"]
	_context_action_panel.size = action_panel_size
	_context_actor_panel.position = menu_layout["actor_position"]
	_context_actor_panel.size = actor_panel_size

func _layout_backdrop(play_area_rect: Rect2) -> void:
	if _backdrop_panels.size() != 4:
		return
	var backdrop_rects: Array[Rect2] = calculate_backdrop_rects(size, play_area_rect)
	for panel_index in range(_backdrop_panels.size()):
		_backdrop_panels[panel_index].position = backdrop_rects[panel_index].position
		_backdrop_panels[panel_index].size = backdrop_rects[panel_index].size

static func calculate_backdrop_rects(viewport_size: Vector2, play_area_rect: Rect2) -> Array[Rect2]:
	var play_area_right: float = play_area_rect.position.x + play_area_rect.size.x
	var play_area_bottom: float = play_area_rect.position.y + play_area_rect.size.y
	return [
		Rect2(Vector2.ZERO, Vector2(viewport_size.x, play_area_rect.position.y)),
		Rect2(Vector2.ZERO, Vector2(play_area_rect.position.x, viewport_size.y)),
		Rect2(Vector2(play_area_right, 0.0), Vector2(maxf(0.0, viewport_size.x - play_area_right), viewport_size.y)),
		Rect2(Vector2(0.0, play_area_bottom), Vector2(viewport_size.x, maxf(0.0, viewport_size.y - play_area_bottom))),
	]

static func calculate_ui_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return minf(
		viewport_size.x / _BASE_VIEWPORT_SIZE.x,
		viewport_size.y / _BASE_VIEWPORT_SIZE.y)

static func calculate_shell_layout(viewport_size: Vector2) -> Dictionary:
	var ui_scale: float = calculate_ui_scale(viewport_size)
	var panel_gap: float = _scaled_px(_BASE_PANEL_GAP_PX, ui_scale, 1.0)
	var left_panel_width: float = viewport_size.x * _LEFT_PANEL_WIDTH_RATIO
	var top_panel_height: float = viewport_size.y * _TOP_PANEL_HEIGHT_RATIO
	var crew_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(left_panel_width, viewport_size.y))
	var right_x: float = crew_rect.size.x + panel_gap
	var right_width: float = maxf(0.0, viewport_size.x - right_x)
	var top_rect: Rect2 = Rect2(Vector2(right_x, 0.0), Vector2(right_width, top_panel_height))
	var play_area_y: float = top_panel_height + panel_gap
	var play_area_rect: Rect2 = Rect2(
		Vector2(right_x, play_area_y),
		Vector2(right_width, maxf(0.0, viewport_size.y - play_area_y)))
	var popup_size: Vector2 = Vector2(
		clampf(viewport_size.x * 0.55, 320.0, 900.0),
		clampf(viewport_size.y * 0.65, 240.0, 720.0))
	return {
		"crew_rect": crew_rect,
		"top_rect": top_rect,
		"play_area_rect": play_area_rect,
		"popup_size": popup_size,
		"ui_scale": ui_scale,
	}

static func calculate_context_menu_layout(
		viewport_size: Vector2,
		anchor_position: Vector2,
		action_panel_size: Vector2,
		actor_panel_size: Vector2,
		panel_gap: float,
		anchor_offset: float = 0.0) -> Dictionary:
	var action_position: Vector2 = anchor_position + Vector2(anchor_offset, anchor_offset)
	action_position.x = clampf(action_position.x, 0.0, maxf(0.0, viewport_size.x - action_panel_size.x))
	action_position.y = clampf(action_position.y, 0.0, maxf(0.0, viewport_size.y - action_panel_size.y))
	var actor_position: Vector2 = Vector2(
		action_position.x + action_panel_size.x + panel_gap,
		action_position.y)
	if actor_position.x + actor_panel_size.x > viewport_size.x:
		actor_position.x = action_position.x - actor_panel_size.x - panel_gap
	actor_position.x = clampf(actor_position.x, 0.0, maxf(0.0, viewport_size.x - actor_panel_size.x))
	actor_position.y = clampf(actor_position.y, 0.0, maxf(0.0, viewport_size.y - actor_panel_size.y))
	return {
		"action_position": action_position.floor(),
		"actor_position": actor_position.floor(),
	}

func _apply_responsive_theme(ui_scale: float) -> void:
	var panel_content_margin: float = _scaled_px(_BASE_PANEL_CONTENT_MARGIN_PX, ui_scale, 4.0)
	var top_row_separation: int = _scaled_font(_BASE_TOP_ROW_SEPARATION_PX, ui_scale, 2)
	var popup_separation: int = _scaled_font(_BASE_POPUP_SEPARATION_PX, ui_scale, 2)
	var card_inset: float = _scaled_px(_BASE_CARD_INSET_PX, ui_scale, 2.0)
	var card_spacing: int = _scaled_font(_BASE_CARD_BOX_SEPARATION_PX, ui_scale, 1)
	var metric_spacing: int = _scaled_font(_BASE_METRIC_BOX_SEPARATION_PX, ui_scale, 1)
	var card_title_font_size: int = _scaled_font(_CARD_TITLE_FONT_SIZE, ui_scale, 9)
	var metric_font_size: int = _scaled_font(_BODY_FONT_SIZE - 2, ui_scale, 7)
	var stat_title_font_size: int = _scaled_font(_STAT_TITLE_FONT_SIZE, ui_scale, 7)
	var stat_value_font_size: int = _scaled_font(_STAT_VALUE_FONT_SIZE, ui_scale, 9)
	var button_font_size: int = _scaled_font(_BUTTON_FONT_SIZE, ui_scale, 8)
	var popup_title_font_size: int = _scaled_font(_BASE_POPUP_TITLE_FONT_SIZE, ui_scale, 12)
	var metric_outline_size: int = _scaled_font(4, ui_scale, 1)
	var bar_height: float = _scaled_px(_BASE_BAR_HEIGHT_PX, ui_scale, 8.0)
	var chip_min_width: float = _scaled_px(_BASE_STAT_CHIP_MIN_WIDTH_PX, ui_scale, 52.0)
	var button_min_width: float = _scaled_px(_BASE_BUTTON_MIN_WIDTH_PX, ui_scale, 52.0)
	var button_min_height: float = _scaled_px(_BASE_BUTTON_MIN_HEIGHT_PX, ui_scale, 24.0)
	var popup_close_button_size: float = _scaled_px(_BASE_POPUP_CLOSE_BUTTON_SIZE_PX, ui_scale, 24.0)
	var card_min_height: float = _scaled_px(_BASE_CARD_MIN_HEIGHT_PX, ui_scale, 56.0)
	var card_panel_radius: int = _scaled_font(8, ui_scale, 4)
	var popup_border_width: int = _scaled_font(2, ui_scale, 1)

	_crew_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, 0, panel_content_margin, 0))
	_top_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, 0, panel_content_margin, 0))
	_play_area_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_PLAY_AREA_BG_COLOR, _PANEL_BORDER_COLOR, 0, 0.0, 0))
	_popup_panel.add_theme_stylebox_override("panel",
		_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, card_panel_radius, 0.0, popup_border_width))
	if _context_action_panel != null:
		_context_action_panel.add_theme_stylebox_override("panel",
			_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, card_panel_radius, panel_content_margin, popup_border_width))
	if _context_actor_panel != null:
		_context_actor_panel.add_theme_stylebox_override("panel",
			_make_panel_style(_SHELL_BG_COLOR, _PANEL_BORDER_COLOR, card_panel_radius, panel_content_margin, popup_border_width))

	if _top_row != null:
		_top_row.add_theme_constant_override("separation", top_row_separation)
	if _popup_box != null:
		_popup_box.add_theme_constant_override("separation", popup_separation)
	if _context_action_box != null:
		_context_action_box.add_theme_constant_override("separation", popup_separation)
	if _context_action_list != null:
		_context_action_list.add_theme_constant_override("separation", card_spacing)
	if _context_actor_box != null:
		_context_actor_box.add_theme_constant_override("separation", popup_separation)
	if _context_actor_list != null:
		_context_actor_list.add_theme_constant_override("separation", card_spacing)

	for chip in _stat_chips:
		chip.custom_minimum_size = Vector2(chip_min_width, 0.0)
		chip.add_theme_stylebox_override("panel",
			_make_panel_style(
				_CARD_BG_COLOR,
				_CARD_BORDER_COLOR,
				card_panel_radius,
				_scaled_px(10.0, ui_scale, 4.0),
				popup_border_width))

	for title_label in _stat_chip_title_labels:
		title_label.add_theme_font_size_override("font_size", stat_title_font_size)
	for value_label in [_date_value_label, _day_night_value_label, _outdoor_temperature_value_label, _ambient_gas_value_label]:
		if value_label != null:
			value_label.add_theme_font_size_override("font_size", stat_value_font_size)

	for button in _top_buttons:
		button.custom_minimum_size = Vector2(button_min_width, button_min_height)
		button.add_theme_font_size_override("font_size", button_font_size)

	for box in _crew_card_boxes:
		box.add_theme_constant_override("separation", card_spacing)
		box.offset_left = card_inset
		box.offset_top = card_inset
		box.offset_right = -card_inset
		box.offset_bottom = -card_inset

	for card in _crew_cards:
		card.custom_minimum_size = Vector2(0.0, card_min_height)

	for metrics_box in _crew_metric_boxes:
		metrics_box.add_theme_constant_override("separation", metric_spacing)

	for label in _crew_name_labels:
		label.add_theme_font_size_override("font_size", card_title_font_size)
	for label in _crew_metric_title_labels:
		_apply_metric_label_style(label, metric_font_size, metric_outline_size)
	for label in _crew_integrity_value_labels:
		_apply_metric_label_style(label, metric_font_size, metric_outline_size)
	for label in _crew_energy_value_labels:
		_apply_metric_label_style(label, metric_font_size, metric_outline_size)
	for label in _crew_psyche_value_labels:
		_apply_metric_label_style(label, metric_font_size, metric_outline_size)

	for bar in _crew_integrity_bars:
		bar.custom_minimum_size = Vector2(0.0, bar_height)
	for bar in _crew_energy_bars:
		bar.custom_minimum_size = Vector2(0.0, bar_height)
	for bar in _crew_psyche_bars:
		bar.custom_minimum_size = Vector2(0.0, bar_height)

	if _popup_title_label != null:
		_popup_title_label.add_theme_font_size_override("font_size", popup_title_font_size)
	if _popup_close_button != null:
		_popup_close_button.custom_minimum_size = Vector2(
			popup_close_button_size,
			popup_close_button_size)
		_popup_close_button.add_theme_font_size_override("font_size", button_font_size)
	if _context_action_title_label != null:
		_context_action_title_label.add_theme_font_size_override("font_size", card_title_font_size)
	if _context_actor_title_label != null:
		_context_actor_title_label.add_theme_font_size_override("font_size", card_title_font_size)
	for button in _context_action_buttons:
		_style_context_button(button)
	for button in _context_actor_buttons:
		_style_context_button(button)

func _context_secondary_list_needs_rebuild(action_kind: int) -> bool:
	return _context_secondary_list_action_kind != action_kind \
		or _context_secondary_list_target_tile != _context_target_tile \
		or _context_secondary_list_actor_slot != _context_actor_slot \
		or _context_secondary_list_source_kind != _context_source_kind \
		or _context_actor_list.get_child_count() == 0

func _context_source_is_valid(state: GameState) -> bool:
	match _context_source_kind:
		ContextSourceKind.WORLD_OBJECT:
			return (_context_target_tile is Vector2i) \
				and _context_object_kind != null \
				and state.get_world_object_kind(_context_target_tile) == _context_object_kind
		ContextSourceKind.ACTOR:
			return state.is_valid_actor_slot(_context_actor_slot) and state.is_actor_alive(_context_actor_slot)
		_:
			return false

func _context_action_title(state: GameState) -> String:
	match _context_source_kind:
		ContextSourceKind.WORLD_OBJECT:
			return WorldObjectKindScript.display_name(_context_object_kind)
		ContextSourceKind.ACTOR:
			return state.get_actor_display_name(_context_actor_slot)
		_:
			return "Actions"

func _context_secondary_title() -> String:
	match _context_source_kind:
		ContextSourceKind.WORLD_OBJECT:
			return "Capable Crew"
		ContextSourceKind.ACTOR:
			return "Harvest Nearby"
		_:
			return "Options"

func _context_panels_ready() -> bool:
	return _context_action_panel != null and _context_action_panel.size.x > 0.0 and _context_action_panel.size.y > 0.0

func _is_within_context_open_grace_period() -> bool:
	return Time.get_ticks_msec() - _context_opened_at_msec <= 250

static func should_keep_context_menu_open(
		mouse_position: Vector2,
		action_panel_rect: Rect2,
		secondary_panel_visible: bool,
		secondary_panel_rect: Rect2) -> bool:
	if action_panel_rect.has_point(mouse_position):
		return true
	if not secondary_panel_visible:
		return false
	return merged_context_menu_hover_rect(action_panel_rect, secondary_panel_rect).has_point(mouse_position)

static func merged_context_menu_hover_rect(action_panel_rect: Rect2, secondary_panel_rect: Rect2) -> Rect2:
	var top_left: Vector2 = Vector2(
		minf(action_panel_rect.position.x, secondary_panel_rect.position.x),
		minf(action_panel_rect.position.y, secondary_panel_rect.position.y))
	var bottom_right: Vector2 = Vector2(
		maxf(
			action_panel_rect.position.x + action_panel_rect.size.x,
			secondary_panel_rect.position.x + secondary_panel_rect.size.x),
		maxf(
			action_panel_rect.position.y + action_panel_rect.size.y,
			secondary_panel_rect.position.y + secondary_panel_rect.size.y))
	return Rect2(top_left, bottom_right - top_left)

func _apply_metric_label_style(label: Label, font_size: int, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", outline_size)

static func _scaled_px(base_px: float, ui_scale: float, min_px: float = 1.0) -> float:
	return maxf(min_px, round(base_px * ui_scale))

static func _scaled_signed_px(base_px: float, ui_scale: float) -> float:
	return round(base_px * ui_scale)

static func _scaled_font(base_size: int, ui_scale: float, min_size: int = 1) -> int:
	return maxi(min_size, int(round(float(base_size) * ui_scale)))

static func _make_label(parent: VBoxContainer) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", _LABEL_FONT_SIZE)
	parent.add_child(label)
	return label

static func _make_panel_style(bg_color: Color, border_color: Color, radius: int, content_margin: float, border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

func _make_crew_card(parent: Control, slot_index: int) -> Dictionary:
	var card: Control = Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.clip_contents = true
	card.custom_minimum_size = Vector2(0.0, _BASE_CARD_MIN_HEIGHT_PX)
	card.gui_input.connect(_on_crew_card_input.bind(slot_index))
	parent.add_child(card)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", _BASE_CARD_BOX_SEPARATION_PX)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = _BASE_CARD_INSET_PX
	box.offset_top = _BASE_CARD_INSET_PX
	box.offset_right = -_BASE_CARD_INSET_PX
	box.offset_bottom = -_BASE_CARD_INSET_PX
	card.add_child(box)
	_crew_card_boxes.append(box)

	var portrait_container: Control = Control.new()
	portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_container.clip_contents = true
	portrait_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(portrait_container)

	var portrait_bg: ColorRect = ColorRect.new()
	portrait_bg.color = _PORTRAIT_BG_COLOR
	portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_container.add_child(portrait_bg)

	var portrait_texture: TextureRect = TextureRect.new()
	portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_container.add_child(portrait_texture)
	_crew_portrait_textures.append(portrait_texture)

	var name_label: Label = Label.new()
	name_label.text = "Crew %02d" % [slot_index + 1]
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", _CARD_TITLE_FONT_SIZE)
	box.add_child(name_label)

	var metrics_box: VBoxContainer = VBoxContainer.new()
	metrics_box.add_theme_constant_override("separation", _BASE_METRIC_BOX_SEPARATION_PX)
	box.add_child(metrics_box)

	var integrity_parts: Array = _make_metric_row(metrics_box, "Integrity", _INTEGRITY_BAR_COLOR)
	var energy_parts: Array = _make_metric_row(metrics_box, "Energy", _ENERGY_BAR_COLOR)
	var psyche_parts: Array = _make_metric_row(metrics_box, "Psyche", _PSYCHE_BAR_COLOR)

	return {
		"card": card,
		"name": name_label,
		"metrics": metrics_box,
		"integrity_value": integrity_parts[0],
		"integrity_bar": integrity_parts[1],
		"energy_value": energy_parts[0],
		"energy_bar": energy_parts[1],
		"psyche_value": psyche_parts[0],
		"psyche_bar": psyche_parts[1],
	}

func _make_metric_row(parent: VBoxContainer, title: String, fill_color: Color) -> Array:
	var bar: ProgressBar = ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(0.0, _BASE_BAR_HEIGHT_PX)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _make_bar_style(_BAR_BG_COLOR))
	bar.add_theme_stylebox_override("fill", _make_bar_style(fill_color))
	parent.add_child(bar)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", _BODY_FONT_SIZE - 2)
	title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.offset_left = _BASE_CARD_INSET_PX
	title_label.offset_right = -_BASE_CARD_INSET_PX
	bar.add_child(title_label)
	_crew_metric_title_labels.append(title_label)

	var value_label: Label = Label.new()
	value_label.text = "--"
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_font_size_override("font_size", _BODY_FONT_SIZE - 2)
	value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.offset_left = _BASE_CARD_INSET_PX
	value_label.offset_right = -_BASE_CARD_INSET_PX
	bar.add_child(value_label)
	return [value_label, bar]

static func _make_bar_style(fill_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_corner_radius_all(4)
	return style

func _layout_crew_cards() -> void:
	if _crew_slots_root == null:
		return
	var panel_size: Vector2 = _crew_slots_root.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return
	var visible_card_count: int = mini(_active_crew_card_count, _crew_cards.size())
	for slot_index in range(_crew_cards.size()):
		_crew_cards[slot_index].visible = slot_index < visible_card_count
	if _crew_cards.is_empty():
		return
	if visible_card_count <= 0:
		_sync_crew_separators(0, 0, Vector2.ZERO, Vector2.ZERO)
		return
	if _crew_card_aspect_ratio <= 0.0:
		_crew_card_aspect_ratio = calculate_default_crew_card_aspect_ratio(panel_size)
	var layout_card_count: int = calculate_crew_layout_card_count(visible_card_count)
	var layout_info: Dictionary = calculate_crew_card_layout(
		panel_size,
		layout_card_count,
		_crew_card_aspect_ratio,
		_crew_zoom_out_factor)
	var columns: int = layout_info["columns"]
	var rows: int = layout_info["rows"]
	var card_size: Vector2 = layout_info["card_size"]
	var grid_position: Vector2 = layout_info["grid_position"]
	for slot_index in range(visible_card_count):
		var column: int = slot_index % columns
		var row: int = slot_index / columns
		var card: Control = _crew_cards[slot_index]
		card.position = grid_position + Vector2(
			card_size.x * float(column),
			card_size.y * float(row))
		card.size = card_size
	if visible_card_count == 1:
		_sync_crew_separators(1, 1, card_size, grid_position)
		return
	_sync_crew_separators(columns, rows, card_size, grid_position)

func _sync_crew_separators(columns: int, rows: int, card_size: Vector2, grid_position: Vector2) -> void:
	var separator_count: int = maxi(0, columns - 1) + maxi(0, rows - 1)
	while _crew_separators.size() < separator_count:
		var separator: ColorRect = ColorRect.new()
		separator.color = _PANEL_BORDER_COLOR
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crew_slots_root.add_child(separator)
		_crew_separators.append(separator)
	while _crew_separators.size() > separator_count:
		var removed_separator: ColorRect = _crew_separators.pop_back()
		removed_separator.queue_free()
	var grid_size: Vector2 = Vector2(
		card_size.x * float(columns),
		card_size.y * float(rows))
	var separator_index: int = 0
	for column in range(1, columns):
		var vertical_separator: ColorRect = _crew_separators[separator_index]
		vertical_separator.position = Vector2(
			grid_position.x + (card_size.x * float(column)) - 1.0,
			grid_position.y)
		vertical_separator.size = Vector2(1.0, grid_size.y)
		separator_index += 1
	for row in range(1, rows):
		var horizontal_separator: ColorRect = _crew_separators[separator_index]
		horizontal_separator.position = Vector2(
			grid_position.x,
			grid_position.y + (card_size.y * float(row)) - 1.0)
		horizontal_separator.size = Vector2(grid_size.x, 1.0)
		separator_index += 1

static func calculate_default_crew_card_aspect_ratio(panel_size: Vector2) -> float:
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return 0.5
	var default_card_width: float = panel_size.x / float(_CREW_DEFAULT_COLUMNS)
	var default_card_height: float = panel_size.y / float(_CREW_DEFAULT_ROWS)
	return default_card_width / maxf(1.0, default_card_height)

static func calculate_crew_layout_card_count(active_card_count: int) -> int:
	if active_card_count <= 0:
		return 0
	if active_card_count == 1:
		return 2
	return active_card_count

static func calculate_crew_card_layout(panel_size: Vector2, card_count: int, card_aspect_ratio: float, zoom_out_factor: float = 1.0) -> Dictionary:
	if card_count <= 0 or panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return {
			"columns": 1,
			"rows": 1,
			"card_size": Vector2.ZERO,
			"grid_position": Vector2.ZERO,
		}
	var safe_aspect_ratio: float = maxf(0.05, card_aspect_ratio)
	var best_fit_height: float = 0.0
	for columns in range(1, card_count + 1):
		var rows: int = int(ceil(float(card_count) / float(columns)))
		var fit_card_size: Vector2 = _fit_crew_card_size(panel_size, columns, rows, safe_aspect_ratio)
		best_fit_height = maxf(best_fit_height, fit_card_size.y)
	var target_card_height: float = best_fit_height / maxf(1.0, zoom_out_factor)
	var panel_aspect_ratio: float = panel_size.x / maxf(1.0, panel_size.y)
	var best_columns: int = 1
	var best_rows: int = card_count
	var best_card_size: Vector2 = _fit_crew_card_size(panel_size, 1, card_count, safe_aspect_ratio)
	var best_height_delta: float = INF
	var best_empty_slots: int = maxi(0, best_columns * best_rows - card_count)
	var best_grid_aspect_delta: float = INF
	var best_grid_area: float = -1.0
	for columns in range(1, card_count + 1):
		var rows: int = int(ceil(float(card_count) / float(columns)))
		var card_size: Vector2 = _fit_crew_card_size(panel_size, columns, rows, safe_aspect_ratio)
		var grid_size: Vector2 = Vector2(
			card_size.x * float(columns),
			card_size.y * float(rows))
		var height_delta: float = absf(card_size.y - target_card_height)
		var empty_slots: int = (columns * rows) - card_count
		var grid_aspect_delta: float = absf(
			(grid_size.x / maxf(1.0, grid_size.y)) - panel_aspect_ratio)
		var grid_area: float = grid_size.x * grid_size.y
		if height_delta < best_height_delta - 0.001:
			best_height_delta = height_delta
			best_empty_slots = empty_slots
			best_grid_aspect_delta = grid_aspect_delta
			best_grid_area = grid_area
			best_columns = columns
			best_rows = rows
			best_card_size = card_size
			continue
		if not is_equal_approx(height_delta, best_height_delta):
			continue
		if empty_slots < best_empty_slots:
			best_empty_slots = empty_slots
			best_grid_aspect_delta = grid_aspect_delta
			best_grid_area = grid_area
			best_columns = columns
			best_rows = rows
			best_card_size = card_size
			continue
		if empty_slots != best_empty_slots:
			continue
		if grid_aspect_delta < best_grid_aspect_delta - 0.001:
			best_grid_aspect_delta = grid_aspect_delta
			best_grid_area = grid_area
			best_columns = columns
			best_rows = rows
			best_card_size = card_size
			continue
		if not is_equal_approx(grid_aspect_delta, best_grid_aspect_delta):
			continue
		if grid_area > best_grid_area + 0.001:
			best_grid_area = grid_area
			best_columns = columns
			best_rows = rows
			best_card_size = card_size
			continue
		if is_equal_approx(grid_area, best_grid_area) and card_size.y > best_card_size.y + 0.001:
			best_columns = columns
			best_rows = rows
			best_card_size = card_size
	var best_grid_size: Vector2 = Vector2(
		best_card_size.x * float(best_columns),
		best_card_size.y * float(best_rows))
	return {
		"columns": best_columns,
		"rows": best_rows,
		"card_size": best_card_size.floor(),
		"grid_position": ((panel_size - best_grid_size) * 0.5).floor(),
	}

static func _fit_crew_card_size(panel_size: Vector2, columns: int, rows: int, card_aspect_ratio: float) -> Vector2:
	var max_card_width: float = panel_size.x / float(columns)
	var max_card_height: float = panel_size.y / float(rows)
	var card_width: float = minf(max_card_width, max_card_height * card_aspect_ratio)
	return Vector2(card_width, card_width / card_aspect_ratio)

func _set_metric_bar(bar: ProgressBar, value_label: Label, value: float, max_value: float, display_text: String) -> void:
	bar.min_value = 0.0
	bar.max_value = maxf(1.0, max_value)
	bar.value = clampf(value, 0.0, bar.max_value)
	value_label.text = display_text

func _make_stat_chip(parent: HBoxContainer, title: String) -> Label:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(_BASE_STAT_CHIP_MIN_WIDTH_PX, 0.0)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel",
		_make_panel_style(_CARD_BG_COLOR, _CARD_BORDER_COLOR, 8, 10.0))
	parent.add_child(chip)
	_stat_chips.append(chip)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	chip.add_child(box)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", _STAT_TITLE_FONT_SIZE)
	box.add_child(title_label)
	_stat_chip_title_labels.append(title_label)

	var value_label: Label = Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_font_size_override("font_size", _STAT_VALUE_FONT_SIZE)
	box.add_child(value_label)
	return value_label

func _make_top_button(parent: HBoxContainer, text: String, pressed_callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(_BASE_BUTTON_MIN_WIDTH_PX, _BASE_BUTTON_MIN_HEIGHT_PX)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
	button.pressed.connect(pressed_callback)
	parent.add_child(button)
	_top_buttons.append(button)
	return button

static func _season_warning_text(clock: ClockState) -> String:
	if clock.season == Season.Kind.WINTER:
		return "Winter day %02d" % clock.day_of_season
	return "Winter in %dd" % clock.get_days_until_season(Season.Kind.WINTER)

static func _season_color(season: int) -> Color:
	match season:
		Season.Kind.SUMMER:
			return _SUMMER_SEASON_COLOR
		Season.Kind.AUTUMN:
			return _AUTUMN_SEASON_COLOR
		Season.Kind.WINTER:
			return _WINTER_SEASON_COLOR
		Season.Kind.SPRING:
			return _SPRING_SEASON_COLOR
		_:
			return Color.WHITE

static func _gas_color(gas_ppm: float) -> Color:
	if gas_ppm >= 200.0:
		return _GAS_CRITICAL_COLOR
	if gas_ppm >= 50.0:
		return _GAS_WARNING_COLOR
	return _GAS_SAFE_COLOR

static func _temperature_color(player: PlayerState) -> Color:
	var progress: float = 0.0
	if player.max_temperature > 0.0:
		progress = player.current_temperature / player.max_temperature
	if progress <= 0.20:
		return _CRITICAL_TEMPERATURE_COLOR
	if progress <= 0.40:
		return _WARNING_TEMPERATURE_COLOR
	if progress <= 0.60:
		return _COOL_TEMPERATURE_COLOR
	return _SAFE_TEMPERATURE_COLOR

static func _danger_text(level: int) -> String:
	match level:
		EnvironmentDangerLevelScript.Kind.PREPARE_FOR_WINTER:
			return "Prepare for winter"
		EnvironmentDangerLevelScript.Kind.WINTER_EXPOSURE:
			return "Winter exposure"
		EnvironmentDangerLevelScript.Kind.CRITICAL_COLD:
			return "Critical cold"
		EnvironmentDangerLevelScript.Kind.DEAD:
			return "Dead"
		_:
			return "Stable"

static func _location_text(state: GameState) -> String:
	if state.is_player_indoors:
		return "indoors"
	if state.is_player_underground:
		return "underground"
	return "surface"

static func _action_text(state: GameState) -> String:
	if state.active_action == null:
		return "Action idle"
	return "Action %s %3.0f%%" % [
		state.active_action.description,
		state.active_action.progress() * 100.0,
	]

static func _last_expedition_text(state: GameState) -> String:
	if state.last_expedition_outcome == null:
		return "Last --"
	var outcome: ExpeditionOutcome = state.last_expedition_outcome
	var encounter_text: String = "calm"
	if outcome.encounter_kind == ExpeditionEncounterKind.Kind.HOSTILE_ANIMAL:
		encounter_text = "hostile animal"
	return "Last +%d scrap, +%d fuel, +%d food (%s)" % [
		outcome.scrap_metal,
		outcome.fuel,
		outcome.canned_food,
		encounter_text,
	]

static func _can_start_expedition(state: GameState) -> bool:
	return GameActionRules.can_start_action(state, GameActionKind.Kind.EXPEDITION, null)

static func _combat_text(state: GameState) -> String:
	if state.active_combat != null:
		var encounter = state.active_combat
		var prefix: String = "Active %s %d/%d" % [
			encounter.enemy.name,
			encounter.current_health,
			encounter.max_health(),
		]
		if state.last_combat_round_outcome == null:
			return prefix
		return "%s\n%s" % [prefix, _last_round_text(state.last_combat_round_outcome)]
	if state.last_combat_round_outcome != null:
		var outcome = state.last_combat_round_outcome
		if outcome.player_died():
			return "Lost to %s" % outcome.enemy_name
		if outcome.enemy_defeated():
			return "Won vs %s" % outcome.enemy_name
	return "Combat idle"

static func _last_round_text(outcome) -> String:
	var player_text: String = (
		"you hit %d" % outcome.player_damage
		if outcome.player_hit
		else "you missed")
	var enemy_text: String = (
		"they hit %d" % outcome.enemy_damage
		if outcome.enemy_hit
		else "they missed")
	var skill_text: String = ""
	if outcome.combat_skill_gained > 0:
		skill_text = "   skill +%d" % outcome.combat_skill_gained
	return "%s   %s%s" % [player_text, enemy_text, skill_text]

static func _weapon_text(state: GameState) -> String:
	if state.player.equipped_weapon == EquippedWeapon.Slot.SIMPLE_WEAPON:
		return "Simple"
	return "--"

static func _can_craft_weapon(state: GameState) -> bool:
	return state.active_action == null and RecipeRules.can_craft(state, RecipeId.Id.SIMPLE_WEAPON)

func _on_temperature_chip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			_cycle_temperature_unit()

func _on_crew_card_input(event: InputEvent, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _active_crew_card_count:
		return
	if not (event is InputEventMouseButton):
		return
	var button_event: InputEventMouseButton = event
	if not button_event.pressed:
		return
	if button_event.button_index == MOUSE_BUTTON_LEFT:
		_open_character_popup(slot_index)
	elif button_event.button_index == MOUSE_BUTTON_RIGHT:
		show_actor_actions(_latest_state, get_viewport().get_mouse_position(), slot_index)

func _on_dim_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event: InputEventMouseButton = event
	if not button_event.pressed:
		return
	var click_pos: Vector2 = button_event.position
	if button_event.button_index == MOUSE_BUTTON_LEFT:
		for top_button in _top_buttons:
			if top_button.get_global_rect().has_point(click_pos):
				top_button.pressed.emit()
				return
	if button_event.button_index == MOUSE_BUTTON_LEFT or button_event.button_index == MOUSE_BUTTON_RIGHT:
		for slot_index in range(_crew_cards.size()):
			if not _crew_cards[slot_index].visible:
				continue
			if _crew_cards[slot_index].get_global_rect().has_point(click_pos):
				_on_crew_card_input(button_event, slot_index)
				return

func _cycle_temperature_unit() -> void:
	_temperature_unit = (_temperature_unit + 1) % TemperatureUnit.size()

func _format_temperature(temp_fahrenheit: float) -> String:
	match _temperature_unit:
		TemperatureUnit.CELSIUS:
			return "%0.1f°C" % _fahrenheit_to_celsius(temp_fahrenheit)
		TemperatureUnit.KELVIN:
			return "%0.1f K" % _fahrenheit_to_kelvin(temp_fahrenheit)
		_:
			return "%0.1f°F" % temp_fahrenheit

static func _fahrenheit_to_celsius(temp_fahrenheit: float) -> float:
	return (temp_fahrenheit - 32.0) * 5.0 / 9.0

static func _fahrenheit_to_kelvin(temp_fahrenheit: float) -> float:
	return _fahrenheit_to_celsius(temp_fahrenheit) + 273.15

static func _time_of_day_text(clock: ClockState) -> String:
	var hours: int = int(floor(clock.time_of_day_seconds / 3600.0)) % 24
	return "%02dh" % hours

static func _day_night_color(phase: int) -> Color:
	match phase:
		DayNightCycle.Phase.DAY:
			return Color8(255, 211, 116)
		DayNightCycle.Phase.SUNRISE:
			return Color8(255, 168, 96)
		DayNightCycle.Phase.SUNSET:
			return Color8(217, 121, 96)
		DayNightCycle.Phase.NIGHT:
			return Color8(140, 168, 224)
		_:
			return Color.WHITE
