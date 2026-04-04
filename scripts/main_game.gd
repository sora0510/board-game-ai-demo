extends Control

const TILE_SIZE := 100
const HUMAN_TEAM := 0
const AI_TEAM := 1

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
@onready var PauseButton = $UI/HUDPanel/MarginContainer/VBoxContainer/ButtonRow/PauseButton


var unit_pool = [
	{"scene": "res://scenes/rifleman.tscn", "cost": 3}, #TODO TODO
	{"scene": "res://scenes/sniper.tscn", "cost": 5}
]

var current_team = HUMAN_TEAM
var team_no = 2 #in the future maybe more than 2 teams
var selected_unit: Unit = null
var selected_ability: Ability = null
var turn_action_used := false
var status_message := ""

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
	EndTurnButton.pressed.connect(_on_end_turn_button_pressed)
	PauseButton.pressed.connect(_on_pause_button_pressed)

	MapManager.load_map("res://resources/example_map.gd")
	generate_army(20, HUMAN_TEAM)
	generate_army(20, AI_TEAM)
	start_turn()

func start_turn():
	turn_action_used = false
	selected_unit = null
	selected_ability = null
	status_message = "Blue units are yours. Click a blue unit, then choose an ability."

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
	current_team = (current_team + 1) % team_no #next team, wrap if last team
	start_turn()

func _unhandled_input(event):
	if get_tree().paused or current_team != HUMAN_TEAM or turn_action_used:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var grid_pos := Vector2i(
			int(floor(event.position.x / TILE_SIZE)),
			int(floor(event.position.y / TILE_SIZE))
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
	PauseButton.text = "Continue" if get_tree().paused else "Pause"
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
