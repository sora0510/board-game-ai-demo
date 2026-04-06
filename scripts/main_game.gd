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
@onready var VictoryOverlay = $UI/VictoryOverlay
@onready var VictoryLabel: Label = $UI/VictoryOverlay/CenterContainer/VictoryPanel/MarginContainer/VBoxContainer/VictoryLabel
@onready var VictorySubtitle: Label = $UI/VictoryOverlay/CenterContainer/VictoryPanel/MarginContainer/VBoxContainer/VictorySubtitle
@onready var PlayAgainButton: Button = $UI/VictoryOverlay/CenterContainer/VictoryPanel/MarginContainer/VBoxContainer/PlayAgainButton

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
var status_message := ""
var board_origin: Vector2 = Vector2.ZERO
var team_vp = []
var team_ap = []
var vt = []
var team_won: int = -1
var game_over := false
var action_log_tween: Tween = null
var map_visual_scale: float = 1.0

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
	VictoryOverlay.process_mode = Node.PROCESS_MODE_ALWAYS
	PlayAgainButton.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseButton.texture_normal = _load_icon(PAUSE_ICON_PATH)
	ResumeButton.texture_normal = _load_icon(RESUME_ICON_PATH)
	PauseButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ResumeButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	EndTurnButton.pressed.connect(_on_end_turn_button_pressed)
	PauseButton.pressed.connect(_on_pause_button_pressed)
	ResumeButton.pressed.connect(_on_pause_button_pressed)
	PlayAgainButton.pressed.connect(_on_play_again_button_pressed)
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
		team_ap.insert(i, 0)
	vt = MapManager.get_all_victory_tiles()
	_sync_victory_overlay()
	start_turn()

func _layout_ui() -> void:
	if MapManager == null or HUDPanel == null or PauseButton == null:
		return

	if MapManager.grid_size == Vector2i.ZERO:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var base_map_size: Vector2 = Vector2(MapManager.grid_size.x * TILE_SIZE, MapManager.grid_size.y * TILE_SIZE)
	var panel_size: Vector2 = HUDPanel.custom_minimum_size
	var available_map_width: float = maxf(viewport_size.x - panel_size.x - UI_GAP - float(UI_PADDING) * 2.0, 1.0)
	var available_map_height: float = maxf(viewport_size.y - float(UI_PADDING) * 2.0, 1.0)
	map_visual_scale = minf(1.0, minf(available_map_width / base_map_size.x, available_map_height / base_map_size.y))
	var map_size: Vector2 = base_map_size * map_visual_scale
	var total_width: float = map_size.x + UI_GAP + panel_size.x
	var origin_x: float = maxf((viewport_size.x - total_width) * 0.5, float(UI_PADDING))
	var origin_y: float = maxf((viewport_size.y - map_size.y) * 0.5, float(UI_PADDING))
	var map_origin: Vector2 = Vector2(origin_x, origin_y)

	MapManager.position = map_origin
	UnitManager.position = map_origin
	MapManager.scale = Vector2.ONE * map_visual_scale
	UnitManager.scale = Vector2.ONE * map_visual_scale
	HUDPanel.position = Vector2(origin_x + map_size.x + UI_GAP, origin_y)
	PauseButton.position = HUDPanel.position + Vector2(0.0, HUDPanel.get_combined_minimum_size().y + UI_GAP)
	if ActionLogPanel != null and ActionLogPanel.visible:
		var action_log_size: Vector2 = ActionLogPanel.get_combined_minimum_size()
		ActionLogPanel.position = map_origin + Vector2(16, 16)
		ActionLogPanel.size = action_log_size
	board_origin = map_origin
	PauseOverlay.position = Vector2.ZERO
	if VictoryOverlay != null:
		VictoryOverlay.position = Vector2.ZERO

func show_action_log(message: String, board_pos: Vector2i) -> void:
	if ActionLogPanel == null or ActionLogLabel == null:
		return

	ActionLogLabel.text = message
	ActionLogPanel.visible = true
	ActionLogPanel.modulate = Color(1, 1, 1, 1)
	ActionLogPanel.z_index = 1000
	ActionLogPanel.size = ActionLogPanel.get_combined_minimum_size()

	var scaled_tile_size: float = float(TILE_SIZE) * map_visual_scale
	var map_size: Vector2 = Vector2(MapManager.grid_size.x * scaled_tile_size, MapManager.grid_size.y * scaled_tile_size)
	var desired_position: Vector2 = board_origin + Vector2(board_pos.x * scaled_tile_size + 12.0, board_pos.y * scaled_tile_size + 12.0)
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

func announce_action(message: String, board_pos: Vector2i) -> void:
	status_message = message
	show_action_log(message, board_pos)
	_update_ui()

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
	if game_over or team_won != -1:
		game_over = true
		status_message = _victory_message(team_won)
		_sync_victory_overlay()
		_refresh_ability_panel()
		_refresh_highlights()
		_update_ui()
		return

	selected_unit = null
	selected_ability = null
	status_message = "AI is thinking..." if current_team == AI_TEAM else "Blue units are yours. Click a blue unit, then choose an ability."
	if current_team >= 0 and current_team < team_ap.size():
		team_ap[current_team] = UnitManager.get_units_for_team(current_team).size()
		for unit in UnitManager.get_units_for_team(current_team):
			unit.action_points = 1
	
	_sync_defeated_teams()
	if _check_elimination_victory():
		return
	
	if team_won == current_team:
		status_message = _victory_message(current_team)
		game_over = true
		_sync_victory_overlay()
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

	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

	if current_team == AI_TEAM and not get_tree().paused:
		AiController.call_deferred("take_turn")

func end_turn():
	if game_over:
		return

	selected_unit = null
	selected_ability = null
	#count Victory points at the end of turn
	for pos in vt:
		var capturing_unit = UnitManager.get_unit_at(pos)
		if capturing_unit:
			if capturing_unit.team == current_team:
				team_vp[current_team] = team_vp[current_team] + 1
	#if enough VP => WIN
	if team_vp[current_team] >= VP_COND:
		team_won = current_team
		game_over = true
		status_message = _victory_message(team_won)
		_sync_victory_overlay()
		_refresh_ability_panel()
		_refresh_highlights()
		_update_ui()
		return

	_sync_defeated_teams()
	if _check_elimination_victory():
		return

	current_team = (current_team + 1) % team_no #next team, wrap if last team
	start_turn()

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				save_board_state()
				status_message = "Game saved."
				_update_ui()
			KEY_F9:
				if load_board_state():
					status_message = "Game loaded."
				else:
					status_message = "Load failed."
				_update_ui()

func _unhandled_input(event):
	if game_over or get_tree().paused or current_team != HUMAN_TEAM or _get_team_action_points(current_team) <= 0:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position - board_origin
		if local_pos.x < 0 or local_pos.y < 0:
			return

		var scaled_tile_size: float = float(TILE_SIZE) * map_visual_scale
		if local_pos.x >= float(MapManager.grid_size.x) * scaled_tile_size or local_pos.y >= float(MapManager.grid_size.y) * scaled_tile_size:
			return

		var grid_pos := Vector2i(
			int(floor(local_pos.x / scaled_tile_size)),
			int(floor(local_pos.y / scaled_tile_size))
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

	var valid_targets = selected_ability.get_valid_targets(selected_unit, MapManager, UnitManager, _get_team_action_points(current_team))
	if not valid_targets.has(grid_pos):
		status_message = "Invalid target."
		_update_ui()
		return

	var action_cost := _get_action_cost_for_selection(selected_ability, grid_pos, clicked_unit)
	if action_cost > _get_team_action_points(current_team):
		status_message = "Not enough Team AP."
		_update_ui()
		return

	var success := false
	var action_message := _build_action_message(selected_unit, selected_ability, grid_pos, clicked_unit, action_cost)
	match selected_ability.get_target_mode():
		Ability.TARGET_TILE:
			success = selected_unit.perform_ability(selected_ability, grid_pos)
		Ability.TARGET_UNIT:
			if clicked_unit != null:
				success = selected_unit.perform_ability(selected_ability, clicked_unit)

	if success:
		announce_action(action_message, grid_pos if clicked_unit == null else clicked_unit.position_on_grid)
		_complete_action(action_cost, action_message)
	else:
		status_message = "Ability failed."
		_update_ui()

func select_unit(unit: Unit) -> void:
	if unit == null or unit.team != current_team or not unit.can_act() or _get_team_action_points(current_team) <= 0:
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

func _complete_action(cost: int, action_message: String = "") -> void:
	spend_team_action_points(current_team, cost)
	selected_unit = null
	selected_ability = null
	if action_message != "":
		status_message = action_message
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

	if _get_team_action_points(current_team) <= 0 and not game_over:
		end_turn()

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

	var valid_targets = selected_ability.get_valid_targets(selected_unit, MapManager, UnitManager, _get_team_action_points(current_team))
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
	PauseButton.visible = not get_tree().paused and not game_over
	PauseOverlay.visible = get_tree().paused
	if VictoryOverlay != null:
		VictoryOverlay.visible = game_over
		if game_over and VictoryLabel != null:
			VictoryLabel.text = _victory_message(team_won)
			VictoryLabel.add_theme_color_override("font_color", _victory_color(team_won))
		if game_over and VictorySubtitle != null:
			VictorySubtitle.text = "Game over"
		if PlayAgainButton != null:
			PlayAgainButton.visible = game_over
	EndTurnButton.disabled = current_team != HUMAN_TEAM or get_tree().paused or game_over or _get_team_action_points(current_team) <= 0

func _selection_text() -> String:
	if selected_unit == null:
		return "Unit: none"

	return "Unit: %s | HP: %d | AP: %d" % [selected_unit.display_name, selected_unit.health, selected_unit.action_points]

func _mode_text() -> String:
	if get_tree().paused:
		return "Mode: paused"

	if _get_team_action_points(current_team) <= 0:
		return "Mode: AP exhausted, ending turn"

	if current_team == AI_TEAM:
		return "Mode: AI is thinking... (%s)" % AiController.get_mode_name()

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

func _victory_message(team: int) -> String:
	if team == HUMAN_TEAM:
		return "YOU WIN!"
	if team == AI_TEAM:
		return "AI WINS!"

	return "%s WINS!" % _team_name(team)

func _victory_color(team: int) -> Color:
	if team == HUMAN_TEAM:
		return Color(1.0, 0.85, 0.2)
	if team == AI_TEAM:
		return Color(1.0, 0.25, 0.25)

	return Color.WHITE

func _get_team_action_points(team: int) -> int:
	if team < 0 or team >= team_ap.size():
		return 0

	return int(team_ap[team])

func get_team_action_points(team: int) -> int:
	return _get_team_action_points(team)

func spend_team_action_points(team: int, amount: int) -> void:
	if team < 0 or team >= team_ap.size():
		return

	team_ap[team] = maxi(int(team_ap[team]) - maxi(amount, 0), 0)
	if team_ap[team] <= 0:
		for unit in UnitManager.get_units_for_team(team):
			unit.action_points = 0

func _get_action_cost_for_selection(ability: Ability, grid_pos: Vector2i, clicked_unit) -> int:
	if ability == null:
		return 1

	if ability.get_target_mode() == Ability.TARGET_TILE:
		return ability.get_action_cost(selected_unit, grid_pos, MapManager)

	if ability.get_target_mode() == Ability.TARGET_UNIT and clicked_unit != null:
		return ability.get_action_cost(selected_unit, clicked_unit, MapManager)

	return ability.get_action_cost(selected_unit, null, MapManager)

func _build_action_message(actor: Unit, ability: Ability, target_pos: Vector2i, target_unit: Unit, cost: int) -> String:
	if actor == null or ability == null:
		return "Action complete."

	var actor_team := "Blue" if actor.team == HUMAN_TEAM else "Red"
	var cost_text := "%d AP" % cost

	match ability.get_target_mode():
		Ability.TARGET_TILE:
			return "%s %s moved to (%d, %d) (-%s)" % [actor_team, actor.display_name, target_pos.x, target_pos.y, cost_text]
		Ability.TARGET_UNIT:
			if target_unit != null:
				var target_team := "Blue" if target_unit.team == HUMAN_TEAM else "Red"
				return "%s %s shot %s %s (-%s)" % [actor_team, actor.display_name, target_team, target_unit.display_name, cost_text]

	return "%s %s acted (-%s)" % [actor_team, actor.display_name, cost_text]

func _sync_defeated_teams() -> void:
	for team in range(team_no):
		if UnitManager.get_units_for_team(team).is_empty() and defeated_teams.find(team) == -1:
			defeated_teams.append(team)

func _check_elimination_victory() -> bool:
	if team_won != -1:
		game_over = true
		status_message = _victory_message(team_won)
		_sync_victory_overlay()
		_refresh_ability_panel()
		_refresh_highlights()
		_update_ui()
		return true

	if defeated_teams.size() < team_no - 1:
		return false

	var surviving_team := -1
	for team in range(team_no):
		if defeated_teams.find(team) == -1:
			if surviving_team != -1:
				return false
			surviving_team = team

	if surviving_team == -1:
		return false

	if team_won == surviving_team:
		game_over = true
		status_message = _victory_message(team_won)
		_sync_victory_overlay()
		_refresh_ability_panel()
		_refresh_highlights()
		_update_ui()
		return true

	if defeated_teams.size() != team_no - 1:
		return false

	team_won = surviving_team
	game_over = true
	status_message = _victory_message(team_won)
	_sync_victory_overlay()
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()
	return true

func _on_end_turn_button_pressed() -> void:
	if current_team == HUMAN_TEAM and not get_tree().paused and not game_over:
		status_message = "Ending turn..."
		end_turn()

func _on_pause_button_pressed() -> void:
	if game_over:
		return

	get_tree().paused = not get_tree().paused
	status_message = "Paused. Press Continue to resume." if get_tree().paused else "Resumed."
	_update_ui()

	if not get_tree().paused and current_team == AI_TEAM:
		AiController.call_deferred("take_turn")

func _on_play_again_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func to_dict() -> Dictionary:
	return {
		"board": MapManager.to_dict(),
		"current_team": current_team,
		"team_no": team_no,
		"team_vp": team_vp.duplicate(),
		"team_ap": team_ap.duplicate(),
		"defeated_teams": defeated_teams.duplicate(),
		"team_won": team_won,
		"status_message": status_message,
		"units": UnitManager.to_dict(),
	}

func from_dict(data: Dictionary) -> void:
	current_team = int(data.get("current_team", current_team))
	team_no = int(data.get("team_no", team_no))
	team_vp = data.get("team_vp", []) if data.has("team_vp") else []
	team_ap = data.get("team_ap", []) if data.has("team_ap") else []
	defeated_teams = data.get("defeated_teams", []) if data.has("defeated_teams") else []
	team_won = int(data.get("team_won", team_won))
	status_message = String(data.get("status_message", status_message))

	if data.has("board") and data["board"] is Dictionary:
		MapManager.from_dict(data["board"])
	vt = MapManager.get_all_victory_tiles()

	if data.has("units") and data["units"] is Dictionary:
		UnitManager.from_dict(data["units"])

	if team_ap.size() < team_no:
		team_ap.resize(team_no)
		for i in range(team_no):
			if i >= team_ap.size() or team_ap[i] == null:
				team_ap[i] = UnitManager.get_units_for_team(i).size()

	selected_unit = null
	selected_ability = null
	game_over = team_won != -1
	if game_over:
		status_message = _victory_message(team_won)
	_sync_victory_overlay()

	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

func _sync_victory_overlay() -> void:
	if VictoryOverlay == null:
		return

	VictoryOverlay.visible = game_over
	if not game_over:
		return

	if VictoryLabel != null:
		VictoryLabel.text = _victory_message(team_won)
	if VictorySubtitle != null:
		VictorySubtitle.text = "Game over"

func save_board_state(path: String = "user://board_save.tres"):
	var state = BoardState.new()
	var data = to_dict()
	state.board = data["board"]
	state.current_team = data["current_team"]
	state.team_no = data["team_no"]
	state.team_vp = data["team_vp"]
	state.team_ap = data["team_ap"]
	state.defeated_teams = data["defeated_teams"]
	state.team_won = data["team_won"]
	state.status_message = data["status_message"]
	state.units = data["units"]
	ResourceSaver.save(state, path)

func load_board_state(path: String = "user://board_save.tres") -> bool:
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is BoardState:
		return false

	var data := {
		"board": resource.board,
		"current_team": resource.current_team,
		"team_no": resource.team_no,
		"team_vp": resource.team_vp,
		"team_ap": resource.team_ap,
		"defeated_teams": resource.defeated_teams,
		"team_won": resource.team_won,
		"status_message": resource.status_message,
		"units": resource.units,
	}
	from_dict(data)
	return true
