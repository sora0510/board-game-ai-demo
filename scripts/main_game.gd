extends Control

const TILE_SIZE := 100
const HUMAN_TEAM := 0
const AI_TEAM := 1
const UI_GAP := 12
const UI_PADDING := 12

@export var TEAM0_POINTS := 20
@export var TEAM1_POINTS := 20
@export var VP_COND := 2

@onready var UnitManager = $UnitManager
@onready var MapManager = $MapManager
@onready var AiController = $AiController

@onready var HUDPanel = $UI/HUDPanel
@onready var TurnLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/TurnLabel
@onready var SelectionLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/SelectionLabel
@onready var APLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/APLabel
@onready var ModeLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/ModeLabel
@onready var StatusLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var AbilityTitle = $UI/HUDPanel/MarginContainer/VBoxContainer/AbilityTitle
@onready var AbilityButtons = $UI/HUDPanel/MarginContainer/VBoxContainer/AbilityButtons
@onready var EndTurnButton = $UI/HUDPanel/MarginContainer/VBoxContainer/ButtonRow/EndTurnButton
@onready var PauseButton: TextureButton = $UI/PauseButton
@onready var PauseOverlay = $UI/PauseOverlay
@onready var ResumeButton: TextureButton = $UI/PauseOverlay/CenterContainer/ResumeButton
@onready var ActionLogPanel: PanelContainer = $UI/ActionLogPanel
@onready var ActionLogLabel: Label = $UI/ActionLogPanel/MarginContainer/ActionLogLabel

const PAUSE_ICON_PATH := "res://assets/pause.png"
const RESUME_ICON_PATH := "res://assets/resume.png"


var unit_pool = [
	{"scene": "res://scenes/rifleman.tscn", "cost": 3},
	{"scene": "res://scenes/sniper.tscn", "cost": 5},
	{"scene": "res://scenes/scout.tscn", "cost": 2},
	{"scene": "res://scenes/rusher.tscn", "cost": 7}
]

var current_team = HUMAN_TEAM
var team_no = 2 #in the future maybe more than 2 teams
var defeated_teams = []
var selected_unit: Unit = null
var selected_ability: Ability = null
var turn_action_used := false
var status_message := ""
var board_origin: Vector2 = Vector2.ZERO
var team_vp = []
var vt = []
var team_won: int = -1
var action_log_tween: Tween = null

func generate_army(points: int, team: int):
	var remaining = points
	var available_choices: Array = []

	for unit in unit_pool:
		if unit["cost"] <= remaining:
			available_choices.append(unit)

	while not available_choices.is_empty():
		var choice = available_choices.pick_random()
		var pos = MapManager.get_random_spawn(team, UnitManager)
		if pos == Vector2i(-1, -1):
			break
		UnitManager.spawn_unit(choice["scene"], pos, team)
		remaining -= choice["cost"]

		available_choices.clear()
		for unit in unit_pool:
			if unit["cost"] <= remaining:
				available_choices.append(unit)

func _ready() -> void:
	HUDPanel.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseButton.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseOverlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ResumeButton.process_mode = Node.PROCESS_MODE_ALWAYS
	ActionLogPanel.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseButton.texture_normal = _load_icon(PAUSE_ICON_PATH)
	ResumeButton.texture_normal = _load_icon(RESUME_ICON_PATH)
	PauseButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ResumeButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	EndTurnButton.pressed.connect(_on_end_turn_button_pressed)
	PauseButton.pressed.connect(_on_pause_button_pressed)
	ResumeButton.pressed.connect(_on_pause_button_pressed)
	PauseButton.mouse_entered.connect(_on_pause_button_mouse_entered)
	PauseButton.mouse_exited.connect(_on_pause_button_mouse_exited)
	ResumeButton.mouse_entered.connect(_on_resume_button_mouse_entered)
	ResumeButton.mouse_exited.connect(_on_resume_button_mouse_exited)
	get_viewport().size_changed.connect(_layout_ui)

	MapManager.load_map("res://resources/map_big.gd")
	_layout_ui()
	generate_army(TEAM0_POINTS, HUMAN_TEAM)
	generate_army(TEAM1_POINTS, AI_TEAM)
	for i in range(team_no): #from 0 to team_no - 1
		team_vp.insert(i, 0)
	vt = MapManager.get_all_victory_tiles()
	start_turn()

func _layout_ui() -> void:
	if MapManager == null or HUDPanel == null or PauseButton == null:
		return

	if MapManager.grid_size == Vector2i.ZERO:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var map_size: Vector2 = Vector2(MapManager.grid_size.x * TILE_SIZE, MapManager.grid_size.y * TILE_SIZE)
	var panel_size: Vector2 = HUDPanel.custom_minimum_size
	var total_width: float = map_size.x + UI_GAP + panel_size.x
	var origin_x: float = maxf((viewport_size.x - total_width) * 0.5, float(UI_PADDING))
	var origin_y: float = maxf((viewport_size.y - map_size.y) * 0.5, float(UI_PADDING))
	var map_origin: Vector2 = Vector2(origin_x, origin_y)

	MapManager.position = map_origin
	UnitManager.position = map_origin
	HUDPanel.position = Vector2(origin_x + map_size.x + UI_GAP, origin_y)
	PauseButton.position = map_origin + Vector2(UI_PADDING, 4.0)
	if ActionLogPanel != null and ActionLogPanel.visible:
		var action_log_size: Vector2 = ActionLogPanel.get_combined_minimum_size()
		ActionLogPanel.position = map_origin + Vector2(16, 16)
		ActionLogPanel.size = action_log_size
	board_origin = map_origin
	PauseOverlay.position = Vector2.ZERO

func show_action_log(message: String, board_pos: Vector2i) -> void:
	if ActionLogPanel == null or ActionLogLabel == null:
		return

	ActionLogLabel.text = message
	ActionLogPanel.visible = true
	ActionLogPanel.modulate = Color(1, 1, 1, 1)
	ActionLogPanel.z_index = 1000
	ActionLogPanel.size = ActionLogPanel.get_combined_minimum_size()

	var map_size: Vector2 = Vector2(MapManager.grid_size.x * TILE_SIZE, MapManager.grid_size.y * TILE_SIZE)
	var desired_position: Vector2 = board_origin + Vector2(board_pos.x * TILE_SIZE + 12.0, board_pos.y * TILE_SIZE + 12.0)
	var max_x: float = board_origin.x + map_size.x - ActionLogPanel.size.x
	var max_y: float = board_origin.y + map_size.y - ActionLogPanel.size.y
	ActionLogPanel.position.x = clampf(desired_position.x, board_origin.x, max_x)
	ActionLogPanel.position.y = clampf(desired_position.y, board_origin.y, max_y)

	if action_log_tween != null and is_instance_valid(action_log_tween):
		action_log_tween.kill()

	action_log_tween = create_tween()
	action_log_tween.tween_interval(2.3)
	action_log_tween.tween_property(ActionLogPanel, "modulate", Color(1, 1, 1, 0), 0.35)
	action_log_tween.tween_callback(_hide_action_log)

func _hide_action_log() -> void:
	if ActionLogPanel == null:
		return

	ActionLogPanel.visible = false
	ActionLogPanel.modulate = Color(1, 1, 1, 1)

func _load_icon(path: String) -> Texture2D:
	var image: Image = Image.load_from_file(path)
	if image == null:
		return null

	return ImageTexture.create_from_image(image)

func _set_button_scale(button: TextureButton, target_scale: Vector2) -> void:
	if button == null:
		return

	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.12)

func _on_pause_button_mouse_entered() -> void:
	_set_button_scale(PauseButton, Vector2(1.06, 1.06))

func _on_pause_button_mouse_exited() -> void:
	_set_button_scale(PauseButton, Vector2(1.0, 1.0))

func _on_resume_button_mouse_entered() -> void:
	_set_button_scale(ResumeButton, Vector2(1.06, 1.06))

func _on_resume_button_mouse_exited() -> void:
	_set_button_scale(ResumeButton, Vector2(1.0, 1.0))

func start_turn():
	turn_action_used = false
	selected_unit = null
	selected_ability = null
	status_message = "Blue units are yours. Click a blue unit, then choose an ability."
	
	if UnitManager.get_units_for_team(current_team) == [] && (defeated_teams.find(current_team) == -1):
		defeated_teams.append(current_team) #push this team into defeated teams if it has no units
	
	if defeated_teams.size() == (team_no - 1) && (defeated_teams.find(current_team) == -1):
		team_won = current_team
	
	if team_won == current_team:
		status_message = "YOU WIN!" #team wins if there are no other teams
		_refresh_ability_panel()
		_refresh_highlights()
		_update_ui()
		return
	
	if defeated_teams.find(current_team) != -1:
		status_message = "You have lost!" #if team is defeated then it cant do anything
		_refresh_ability_panel()
		_refresh_highlights()
		_update_ui()
		if current_team != AI_TEAM: #AI still has to continue
			return

	for unit in UnitManager.get_units_for_team(current_team):
		unit.action_points = 1

	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

	if current_team == AI_TEAM and not get_tree().paused:
		AiController.call_deferred("take_turn")

func end_turn():
	selected_unit = null
	selected_ability = null
	turn_action_used = false
	#count Victory points at the end of turn
	for pos in vt:
		var capturing_unit = UnitManager.get_unit_at(pos)
		if capturing_unit:
			if capturing_unit.team == current_team:
				team_vp[current_team] = team_vp[current_team] + 1
	#if enough VP => WIN
	if team_vp[current_team] >= VP_COND:
		team_won = current_team
	current_team = (current_team + 1) % team_no #next team, wrap if last team
	start_turn()

func _unhandled_input(event):
	if get_tree().paused or current_team != HUMAN_TEAM or turn_action_used:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position - board_origin
		if local_pos.x < 0 or local_pos.y < 0:
			return

		if local_pos.x >= float(MapManager.grid_size.x * TILE_SIZE) or local_pos.y >= float(MapManager.grid_size.y * TILE_SIZE):
			return

		var grid_pos := Vector2i(
			int(floor(local_pos.x / TILE_SIZE)),
			int(floor(local_pos.y / TILE_SIZE))
		)
		handle_board_click(grid_pos)

func handle_board_click(grid_pos: Vector2i) -> void:
	var clicked_unit = UnitManager.get_unit_at(grid_pos)

	if selected_unit == null:
		if clicked_unit != null and clicked_unit.team == current_team and clicked_unit.can_act():
			select_unit(clicked_unit)
		return

	if clicked_unit != null and clicked_unit.team == current_team and clicked_unit.can_act():
		select_unit(clicked_unit)
		return

	if selected_ability == null:
		status_message = "Choose an ability first."
		_update_ui()
		return

	var valid_targets = selected_ability.get_valid_targets(selected_unit, MapManager, UnitManager)
	if not valid_targets.has(grid_pos):
		status_message = "Invalid target."
		_update_ui()
		return

	var success := false
	match selected_ability.get_target_mode():
		Ability.TARGET_TILE:
			success = selected_unit.perform_ability(selected_ability, grid_pos)
		Ability.TARGET_UNIT:
			if clicked_unit != null:
				success = selected_unit.perform_ability(selected_ability, clicked_unit)

	if success:
		_complete_action()
	else:
		status_message = "Ability failed."
		_update_ui()

func select_unit(unit: Unit) -> void:
	if unit == null or unit.team != current_team or not unit.can_act() or turn_action_used:
		return

	if selected_unit == unit:
		selected_unit = null
		selected_ability = null
		status_message = "Unit deselected."
	else:
		selected_unit = unit
		selected_ability = unit.abilities[0] if unit.abilities.size() > 0 else null
		status_message = "%s selected." % unit.display_name

	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

func select_ability_by_ability(ability: Ability) -> void:
	if selected_unit == null:
		return

	if ability == null or not is_instance_valid(ability):
		return

	selected_ability = ability
	status_message = "%s ready. Click a valid target." % selected_ability.get_display_name()
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

func _complete_action() -> void:
	for unit in UnitManager.get_units_for_team(current_team):
		unit.action_points = 0

	turn_action_used = true
	selected_unit = null
	selected_ability = null
	status_message = "Action complete. Press End Turn."
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

func _refresh_ability_panel() -> void:
	for child in AbilityButtons.get_children():
		child.queue_free()

	if selected_unit == null:
		var prompt = Label.new()
		prompt.text = "Select a unit to see abilities."
		AbilityButtons.add_child(prompt)
		AbilityTitle.text = "Abilities"
		return

	AbilityTitle.text = "%s abilities" % selected_unit.display_name

	for i in range(selected_unit.abilities.size()):
		var ability = selected_unit.abilities[i]
		var button = Button.new()
		button.text = ability.get_display_name()
		if ability == selected_ability:
			button.text = "► %s" % button.text
		button.pressed.connect(select_ability_by_ability.bind(ability))
		AbilityButtons.add_child(button)

	if selected_unit.abilities.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No abilities available."
		AbilityButtons.add_child(empty_label)

func _refresh_highlights() -> void:
	if MapManager == null:
		return

	for tile in MapManager.tiles.values():
		tile.set_highlight(Tile.HIGHLIGHT_NONE)

	if selected_unit == null:
		return

	var selected_tile = MapManager.get_tile(selected_unit.position_on_grid)
	if selected_tile != null:
		selected_tile.set_highlight(Tile.HIGHLIGHT_SELECTED)

	if selected_ability == null:
		return

	var valid_targets = selected_ability.get_valid_targets(selected_unit, MapManager, UnitManager)
	for target_pos in valid_targets:
		var target_tile = MapManager.get_tile(target_pos)
		if target_tile == null:
			continue

		match selected_ability.get_target_mode():
			Ability.TARGET_TILE:
				target_tile.set_highlight(Tile.HIGHLIGHT_MOVE)
			Ability.TARGET_UNIT:
				target_tile.set_highlight(Tile.HIGHLIGHT_TARGET)

func _update_ui() -> void:
	TurnLabel.text = "Turn: %s" % _team_name(current_team)
	SelectionLabel.text = _selection_text()
	APLabel.text = "Team AP: %d" % _get_team_action_points(current_team)
	ModeLabel.text = _mode_text()
	StatusLabel.text = status_message
	PauseButton.visible = not get_tree().paused
	PauseOverlay.visible = get_tree().paused
	EndTurnButton.disabled = current_team != HUMAN_TEAM or get_tree().paused

func _selection_text() -> String:
	if selected_unit == null:
		return "Unit: none"

	return "Unit: %s | HP: %d | AP: %d" % [selected_unit.display_name, selected_unit.health, selected_unit.action_points]

func _mode_text() -> String:
	if get_tree().paused:
		return "Mode: paused"

	if current_team == AI_TEAM:
		return "Mode: AI is thinking..."

	if turn_action_used:
		return "Mode: action spent, end the turn"

	if selected_unit == null:
		return "Mode: select a unit"

	if selected_ability == null:
		return "Mode: choose an ability"

	match selected_ability.get_target_mode():
		Ability.TARGET_TILE:
			return "Mode: click a reachable tile"
		Ability.TARGET_UNIT:
			return "Mode: click an enemy unit"

	return "Mode: ready"

func _team_name(team: int) -> String:
	match team:
		HUMAN_TEAM:
			return "Player"
		AI_TEAM:
			return "AI"
		_:
			return "Team %d" % team

func _get_team_action_points(team: int) -> int:
	var total := 0
	for unit in UnitManager.get_units_for_team(team):
		total += unit.action_points
	return total

func _on_end_turn_button_pressed() -> void:
	if current_team == HUMAN_TEAM and not get_tree().paused:
		status_message = "Ending turn..."
		end_turn()

func _on_pause_button_pressed() -> void:
	get_tree().paused = not get_tree().paused
	status_message = "Paused. Press Continue to resume." if get_tree().paused else "Resumed."
	_update_ui()

	if not get_tree().paused and current_team == AI_TEAM:
		AiController.call_deferred("take_turn")
