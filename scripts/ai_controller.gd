extends Control

const AI_TEAM := 1
const HUMAN_TEAM := 0
const NEG_INF := -1000000000.0
const POS_INF := 1000000000.0
const AI_ACTION_DELAY := 0.85

enum AIMode { RANDOM, MCTS, MINIMAX }

@export_enum("Random", "Monte-Carlo Tree Search", "Minimax") var ai_mode: int = AIMode.RANDOM
@export var minimax_depth := 3
@export var minimax_branch_limit := 12
@export var mcts_iterations := 160
@export var mcts_rollout_depth := 8
@export var mcts_branch_limit := 16

@onready var UnitManager = $"../UnitManager"

func get_mode_name() -> String:
	match ai_mode:
		AIMode.RANDOM:
			return "Random"
		AIMode.MCTS:
			return "MCTS"
		AIMode.MINIMAX:
			return "Minimax"
		_:
			return "Random"

class MCTSNode:
	var state: Dictionary = {}
	var parent = null
	var action: Dictionary = {}
	var children: Array = []
	var untried_actions: Array = []
	var visits := 0
	var total_value := 0.0

	func _init(node_state: Dictionary, node_action: Dictionary = {}, node_parent = null, node_actions: Array = []) -> void:
		state = node_state
		action = node_action
		parent = node_parent
		untried_actions = node_actions

func take_turn() -> void:
	await get_tree().process_frame

	var game_manager = get_parent()
	while not game_manager.game_over and game_manager.current_team == AI_TEAM and game_manager.get_team_action_points(AI_TEAM) > 0:
		var map_manager = game_manager.get_node("MapManager")
		var state = _capture_state(game_manager, map_manager)
		var chosen_action: Dictionary = {}

		match ai_mode:
			AIMode.RANDOM:
				chosen_action = _choose_random_action(state)
			AIMode.MCTS:
				chosen_action = _choose_mcts_action(state)
			AIMode.MINIMAX:
				chosen_action = _choose_minimax_action(state)
			_:
				chosen_action = _choose_random_action(state)

		if chosen_action.is_empty():
			break

		var actor_pos: Vector2i = _dict_to_vector2i(chosen_action.get("actor_pos", Vector2i.ZERO))
		var actor: Unit = UnitManager.get_unit_at(actor_pos)
		if actor == null:
			break

		var ability_index := int(chosen_action.get("ability_index", 0))
		if ability_index < 0 or ability_index >= actor.abilities.size():
			break

		var ability = actor.abilities[ability_index]
		var target_pos: Vector2i = _dict_to_vector2i(chosen_action.get("target_pos", Vector2i.ZERO))
		var target_unit: Unit = null
		if String(chosen_action.get("kind", "")) == "shoot":
			target_unit = UnitManager.get_unit_at(target_pos)

		var spent := _apply_real_action(chosen_action, game_manager)
		if spent <= 0:
			break

		var action_message := _format_action_message(actor, ability, target_pos, target_unit, spent)
		game_manager.announce_action(action_message, target_pos)
		game_manager.spend_team_action_points(AI_TEAM, spent)
		game_manager._update_ui()
		await get_tree().create_timer(AI_ACTION_DELAY).timeout

	if not game_manager.game_over and game_manager.current_team == AI_TEAM:
		game_manager.end_turn()

func _capture_state(game_manager, map_manager) -> Dictionary:
	var team_vp: Array = []
	for i in range(int(game_manager.team_no)):
		if i < game_manager.team_vp.size():
			team_vp.append(int(game_manager.team_vp[i]))
		else:
			team_vp.append(0)

	return {
		"current_team": int(game_manager.current_team),
		"team_no": int(game_manager.team_no),
		"team_vp": team_vp,
		"team_ap": game_manager.team_ap.duplicate(true),
		"defeated_teams": game_manager.defeated_teams.duplicate(true),
		"team_won": int(game_manager.team_won),
		"vp_cond": int(game_manager.VP_COND),
		"grid_size": map_manager.grid_size,
		"tile_map": _build_tile_map(map_manager),
		"victory_tiles": map_manager.get_all_victory_tiles().duplicate(true),
		"units": UnitManager.to_dict().get("units", []).duplicate(true),
	}

func _format_action_message(actor: Unit, ability, target_pos: Vector2i, target_unit: Unit, spent: int) -> String:
	if actor == null or ability == null:
		return "AI acted (-%d AP)" % spent

	var actor_team := "Blue" if actor.team == HUMAN_TEAM else "Red"
	var cost_text := "%d AP" % spent

	match ability.get_target_mode():
		Ability.TARGET_TILE:
			return "%s %s moved to (%d, %d) (-%s)" % [actor_team, actor.display_name, target_pos.x, target_pos.y, cost_text]
		Ability.TARGET_UNIT:
			if target_unit != null:
				var target_team := "Blue" if target_unit.team == HUMAN_TEAM else "Red"
				return "%s %s shot %s %s (-%s)" % [actor_team, actor.display_name, target_team, target_unit.display_name, cost_text]

	return "%s %s acted (-%s)" % [actor_team, actor.display_name, cost_text]

func _build_tile_map(map_manager) -> Dictionary:
	var tile_map: Dictionary = {}
	for pos in map_manager.tiles:
		var tile: Tile = map_manager.tiles[pos]
		if tile != null:
			tile_map[pos] = int(tile.terrain_type)
	return tile_map

func _choose_random_action(state: Dictionary) -> Dictionary:
	var actions = _get_legal_actions(state)
	if actions.is_empty():
		return {}

	return actions.pick_random()

func _choose_minimax_action(state: Dictionary) -> Dictionary:
	var actions = _get_legal_actions(state)
	if actions.is_empty():
		return {}

	var ordered_actions = _order_actions_for_state(state, actions, minimax_branch_limit)
	var best_score := NEG_INF
	var best_actions: Array = []

	for action in ordered_actions:
		var simulated = _simulate_action(state, action)
		var score = _minimax(simulated, minimax_depth - 1, NEG_INF, POS_INF)
		if score > best_score:
			best_score = score
			best_actions = [action]
		elif is_equal_approx(score, best_score):
			best_actions.append(action)

	if best_actions.is_empty():
		return ordered_actions[0]

	return best_actions.pick_random()

func _minimax(state: Dictionary, depth: int, alpha: float, beta: float) -> float:
	if depth <= 0 or _is_terminal(state):
		return _evaluate_state(state)

	var actions = _get_legal_actions(state)
	if actions.is_empty():
		return _minimax(_advance_turn_state(state), depth - 1, alpha, beta)

	var ordered_actions = _order_actions_for_state(state, actions, minimax_branch_limit)
	var current_team = int(state["current_team"])

	if current_team == AI_TEAM:
		var best_value := NEG_INF
		for action in ordered_actions:
			var child_state = _simulate_action(state, action)
			best_value = maxf(best_value, _minimax(child_state, depth - 1, alpha, beta))
			alpha = maxf(alpha, best_value)
			if alpha >= beta:
				break
		return best_value

	var worst_value := POS_INF
	for action in ordered_actions:
		var child_state = _simulate_action(state, action)
		worst_value = minf(worst_value, _minimax(child_state, depth - 1, alpha, beta))
		beta = minf(beta, worst_value)
		if alpha >= beta:
			break
	return worst_value

func _choose_mcts_action(state: Dictionary) -> Dictionary:
	var actions = _get_legal_actions(state)
	if actions.is_empty():
		return {}

	if actions.size() == 1:
		return actions[0]

	var root_actions = _order_actions_for_state(state, actions, mcts_branch_limit)
	var root = MCTSNode.new(_duplicate_state(state), {}, null, root_actions.duplicate(true))

	for _iteration in range(mcts_iterations):
		var node: MCTSNode = root

		while node.untried_actions.is_empty() and not node.children.is_empty() and not _is_terminal(node.state):
			node = _select_mcts_child(node)

		if not _is_terminal(node.state) and not node.untried_actions.is_empty():
			var expand_index := randi() % node.untried_actions.size()
			var action = node.untried_actions.pop_at(expand_index)
			var child_state = _simulate_action(node.state, action)
			var child = MCTSNode.new(child_state, action, node, _order_actions_for_state(child_state, _get_legal_actions(child_state), mcts_branch_limit))
			node.children.append(child)
			node = child

		var reward = _rollout(node.state)
		_backpropagate_mcts(node, reward)

	var best_child = _best_mcts_child(root)
	if best_child == null:
		return root_actions.pick_random()

	return best_child.action

func _select_mcts_child(node: MCTSNode) -> MCTSNode:
	var best_child: MCTSNode = null
	var best_score: float = NEG_INF
	var parent_visits: int = maxi(node.visits, 1)

	for child in node.children:
		if child.visits <= 0:
			return child

		var exploitation: float = child.total_value / float(child.visits)
		var exploration: float = sqrt(log(float(parent_visits)) / float(child.visits))
		var score: float = exploitation + 1.4 * exploration
		if score > best_score:
			best_score = score
			best_child = child

	return best_child

func _best_mcts_child(root: MCTSNode) -> MCTSNode:
	var best_child: MCTSNode = null
	var best_average: float = NEG_INF

	for child in root.children:
		if child.visits <= 0:
			continue

		var average: float = child.total_value / float(child.visits)
		if average > best_average:
			best_average = average
			best_child = child

	return best_child

func _backpropagate_mcts(node: MCTSNode, reward: float) -> void:
	var current: MCTSNode = node
	while current != null:
		current.visits += 1
		current.total_value += reward
		current = current.parent

func _rollout(state: Dictionary) -> float:
	var simulated = _duplicate_state(state)
	for _step in range(mcts_rollout_depth):
		if _is_terminal(simulated):
			break

		var actions = _get_legal_actions(simulated)
		if actions.is_empty():
			simulated = _advance_turn_state(simulated)
			continue

		var action = actions.pick_random()
		simulated = _simulate_action(simulated, action)

	return _evaluate_state(simulated)

func _order_actions_for_state(state: Dictionary, actions: Array, limit: int) -> Array:
	if actions.is_empty():
		return []

	var scored_actions: Array = []
	for action in actions:
		scored_actions.append({
			"action": action,
			"priority": _action_priority(state, action),
		})

	var current_team: int = int(state["current_team"])
	var descending: bool = current_team == AI_TEAM
	scored_actions.sort_custom(func(a, b):
		if descending:
			return float(a["priority"]) > float(b["priority"])
		return float(a["priority"]) < float(b["priority"])
	)

	var ordered_actions: Array = []
	var effective_limit: int = limit
	if effective_limit <= 0 or effective_limit > scored_actions.size():
		effective_limit = scored_actions.size()

	for i in range(effective_limit):
		ordered_actions.append(scored_actions[i]["action"])

	return ordered_actions

func _action_priority(state: Dictionary, action: Dictionary) -> float:
	var simulated: Dictionary = _simulate_action(state, action)
	return _evaluate_state(simulated)

func _get_legal_actions(state: Dictionary) -> Array:
	var actions: Array = []
	var units: Array = _state_units(state)
	var current_team: int = int(state["current_team"])
	var team_ap: Array = state.get("team_ap", [])
	var available_ap: int = int(team_ap[current_team]) if current_team < team_ap.size() else 0
	if available_ap <= 0:
		return actions

	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		if int(unit.get("team", -1)) != current_team:
			continue
		if int(unit.get("active", 0)) != 1:
			continue
		if int(unit.get("action_points", 0)) <= 0:
			continue

		var abilities: Array = unit.get("abilities", [])
		for ability_index in range(abilities.size()):
			var ability: Dictionary = abilities[ability_index]
			match _ability_kind(ability):
				"move":
					actions.append_array(_get_move_actions(state, unit_index, ability_index, ability))
				"shoot":
					actions.append_array(_get_shoot_actions(state, unit_index, ability_index, ability))

	return actions

func _get_move_actions(state: Dictionary, actor_index: int, ability_index: int, ability: Dictionary) -> Array:
	var actions: Array = []
	var units: Array = _state_units(state)
	var actor: Dictionary = units[actor_index]
	var actor_pos: Vector2i = _dict_to_vector2i(actor.get("position_on_grid", Vector2i.ZERO))
	var move_range: int = int(ability.get("move_range", 0))
	var grid_size: Vector2i = state.get("grid_size", Vector2i.ZERO)
	var current_team: int = int(state.get("current_team", 0))
	var team_ap: Array = state.get("team_ap", [])
	var available_ap: int = int(team_ap[current_team]) if current_team < team_ap.size() else 0

	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var target_pos := Vector2i(x, y)
			if actor_pos.distance_to(target_pos) > move_range:
				continue

			if target_pos == actor_pos:
				continue

			if _state_unit_at(state, target_pos) != -1:
				continue

			var movement_cost: int = _tile_movement_cost(state, target_pos)
			if movement_cost < 0 or movement_cost > available_ap:
				continue

			if not _path_is_clear(state, actor_pos, target_pos):
				continue

			actions.append({
				"kind": "move",
				"actor_index": actor_index,
				"actor_pos": actor_pos,
				"ability_index": ability_index,
				"target_pos": target_pos,
			})

	return actions

func _get_shoot_actions(state: Dictionary, actor_index: int, ability_index: int, ability: Dictionary) -> Array:
	var actions: Array = []
	var units: Array = _state_units(state)
	var actor: Dictionary = units[actor_index]
	var actor_pos: Vector2i = _dict_to_vector2i(actor.get("position_on_grid", Vector2i.ZERO))
	var attack_range: float = float(ability.get("attack_range", 0))
	var current_team: int = int(state.get("current_team", 0))
	var team_ap: Array = state.get("team_ap", [])
	var available_ap: int = int(team_ap[current_team]) if current_team < team_ap.size() else 0
	if available_ap < 1:
		return actions

	for target_index in range(units.size()):
		var target: Dictionary = units[target_index]
		if int(target.get("team", -1)) == int(actor.get("team", -1)):
			continue

		var target_pos := _dict_to_vector2i(target.get("position_on_grid", Vector2i.ZERO))
		if actor_pos.distance_to(target_pos) > attack_range:
			continue

		if not _path_is_clear(state, actor_pos, target_pos):
			continue

		actions.append({
			"kind": "shoot",
			"actor_index": actor_index,
			"actor_pos": actor_pos,
			"ability_index": ability_index,
			"target_index": target_index,
			"target_pos": target_pos,
		})

	return actions

func _simulate_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = _duplicate_state(state)
	_apply_action_in_state(next_state, action)
	var current_team: int = int(state.get("current_team", 0))
	var cost := _action_cost_for_state(state, action)
	var team_ap: Array = next_state.get("team_ap", [])
	if current_team < team_ap.size():
		team_ap[current_team] = maxi(int(team_ap[current_team]) - cost, 0)
		next_state["team_ap"] = team_ap
	return _advance_turn_state(next_state)

func _apply_real_action(action: Dictionary, game_manager) -> int:
	var actor_pos: Vector2i = _dict_to_vector2i(action.get("actor_pos", Vector2i.ZERO))
	var actor: Unit = UnitManager.get_unit_at(actor_pos)
	if actor == null:
		return 0

	var ability_index := int(action.get("ability_index", 0))
	if ability_index < 0 or ability_index >= actor.abilities.size():
		return 0

	var ability = actor.abilities[ability_index]
	var map_manager = game_manager.get_node("MapManager")
	var action_cost := int(ability.get_action_cost(actor, action.get("target_pos", Vector2i.ZERO), map_manager))
	var kind: String = String(action.get("kind", ""))
	match kind:
		"move":
			if not actor.perform_ability(ability, action.get("target_pos", Vector2i.ZERO)):
				return 0
		"shoot":
			var target_pos: Vector2i = action.get("target_pos", Vector2i.ZERO)
			var target: Unit = UnitManager.get_unit_at(target_pos)
			if target != null:
				if not actor.perform_ability(ability, target):
					return 0
			else:
				return 0
		_:
			var target = action.get("target_pos", Vector2i.ZERO)
			if not actor.perform_ability(ability, target):
				return 0

	return action_cost

func _action_cost_for_state(state: Dictionary, action: Dictionary) -> int:
	var kind: String = String(action.get("kind", ""))
	if kind == "move":
		var target_pos: Vector2i = _dict_to_vector2i(action.get("target_pos", Vector2i.ZERO))
		return max(_tile_movement_cost(state, target_pos), 0)

	if kind == "shoot":
		return 1

	return 1

func _apply_action_in_state(state: Dictionary, action: Dictionary) -> void:
	var units: Array = _state_units(state)
	var actor_index: int = int(action.get("actor_index", -1))
	if actor_index < 0 or actor_index >= units.size():
		return

	var actor: Dictionary = units[actor_index]
	var actor_team: int = int(actor.get("team", -1))
	var kind: String = String(action.get("kind", ""))

	match kind:
		"move":
			actor["position_on_grid"] = action.get("target_pos", Vector2i.ZERO)
			actor["action_points"] = 0
			units[actor_index] = actor
		"shoot":
			var target_index: int = int(action.get("target_index", -1))
			if target_index >= 0 and target_index < units.size():
				var target: Dictionary = units[target_index]
				var damage: int = _ability_damage(_get_unit_ability(actor, int(action.get("ability_index", 0))))
				target["health"] = int(target.get("health", 0)) - damage
				actor["action_points"] = 0
				units[actor_index] = actor
				if int(target["health"]) <= 0:
					if target_index > actor_index:
						units.remove_at(target_index)
					else:
						units.remove_at(target_index)
				else:
					units[target_index] = target
		_:
			actor["action_points"] = 0
			units[actor_index] = actor

	state["units"] = units

func _advance_turn_state(state: Dictionary) -> Dictionary:
	var next_state: Dictionary = _duplicate_state(state)
	var current_team: int = int(next_state["current_team"])

	if next_state["team_vp"].size() < int(next_state["team_no"]):
		for i in range(int(next_state["team_no"]) - next_state["team_vp"].size()):
			next_state["team_vp"].append(0)

	_count_victory_points(next_state, current_team)
	if int(next_state["team_vp"][current_team]) >= int(next_state["vp_cond"]):
		next_state["team_won"] = current_team

	next_state["current_team"] = (current_team + 1) % int(next_state["team_no"])
	_normalize_turn_state(next_state)
	return next_state

func _normalize_turn_state(state: Dictionary) -> void:
	var current_team: int = int(state["current_team"])
	var units: Array = _state_units(state)
	var defeated: Array = state.get("defeated_teams", [])

	for unit in units:
		unit["action_points"] = 0

	for unit in units:
		if int(unit.get("team", -1)) == current_team:
			unit["action_points"] = 1

	if _state_units_for_team(state, current_team).is_empty() and defeated.find(current_team) == -1:
		defeated.append(current_team)

	var surviving_team := -1
	for team in range(int(state["team_no"])):
		if defeated.find(team) == -1:
			if surviving_team != -1:
				state["defeated_teams"] = defeated
				state["units"] = units
				return
			surviving_team = team

	if surviving_team != -1 and defeated.size() == int(state["team_no"]) - 1:
		state["team_won"] = surviving_team

	state["defeated_teams"] = defeated
	state["units"] = units

func _count_victory_points(state: Dictionary, team: int) -> void:
	var team_vp: Array = state.get("team_vp", [])
	var victory_tiles: Array = state.get("victory_tiles", [])
	var units: Array = _state_units(state)

	for victory_tile in victory_tiles:
		var occupant_index := _state_unit_at(state, victory_tile)
		if occupant_index == -1:
			continue

		var occupant: Dictionary = units[occupant_index]
		if int(occupant.get("team", -1)) == team:
			team_vp[team] = int(team_vp[team]) + 1

	state["team_vp"] = team_vp

func _is_terminal(state: Dictionary) -> bool:
	return int(state.get("team_won", -1)) != -1

func _evaluate_state(state: Dictionary) -> float:
	var team_won: int = int(state.get("team_won", -1))
	if team_won == AI_TEAM:
		return 100000.0
	if team_won == HUMAN_TEAM:
		return -100000.0

	var units: Array = _state_units(state)
	var ai_health := 0.0
	var human_health := 0.0
	var ai_units := 0.0
	var human_units := 0.0
	var ai_on_victory := 0.0
	var human_on_victory := 0.0

	for unit in units:
		var team := int(unit.get("team", -1))
		var health := float(unit.get("health", 0))
		var position := _dict_to_vector2i(unit.get("position_on_grid", Vector2i.ZERO))
		var on_victory := _is_victory_tile(state, position)

		if team == AI_TEAM:
			ai_health += health
			ai_units += 1.0
			if on_victory:
				ai_on_victory += 1.0
		elif team == HUMAN_TEAM:
			human_health += health
			human_units += 1.0
			if on_victory:
				human_on_victory += 1.0

	var team_vp: Array = state.get("team_vp", [])
	var ai_vp: float = float(team_vp[AI_TEAM] if AI_TEAM < team_vp.size() else 0)
	var human_vp: float = float(team_vp[HUMAN_TEAM] if HUMAN_TEAM < team_vp.size() else 0)

	var score: float = 0.0
	score += (ai_health - human_health) * 4.0
	score += (ai_units - human_units) * 55.0
	score += (ai_vp - human_vp) * 120.0
	score += (ai_on_victory - human_on_victory) * 35.0

	var ai_action_count := _state_units_for_team(state, AI_TEAM).size()
	var human_action_count := _state_units_for_team(state, HUMAN_TEAM).size()
	score += float(ai_action_count - human_action_count) * 12.0

	return score

func _is_victory_tile(state: Dictionary, pos: Vector2i) -> bool:
	var victory_tiles: Array = state.get("victory_tiles", [])
	return victory_tiles.has(pos)

func _duplicate_state(state: Dictionary) -> Dictionary:
	return state.duplicate(true)

func _state_units(state: Dictionary) -> Array:
	return state.get("units", [])

func _state_units_for_team(state: Dictionary, team: int) -> Array:
	var filtered: Array = []
	for unit in _state_units(state):
		if int(unit.get("team", -1)) == team:
			filtered.append(unit)
	return filtered

func _state_unit_at(state: Dictionary, grid_pos: Vector2i) -> int:
	var units: Array = _state_units(state)
	for index in range(units.size()):
		if _dict_to_vector2i(units[index].get("position_on_grid", Vector2i.ZERO)) == grid_pos:
			return index
	return -1

func _tile_movement_cost(state: Dictionary, grid_pos: Vector2i) -> int:
	var tile_map: Dictionary = state.get("tile_map", {})
	if not tile_map.has(grid_pos):
		return -1

	var terrain_type := int(tile_map[grid_pos])
	if terrain_type < 0:
		return 1

	match terrain_type:
		0:
			return 1
		1:
			return 2
		2:
			return 2
		3:
			return 1
		4:
			return 1
		5:
			return -1

	return 1

func _path_is_clear(state: Dictionary, start_pos: Vector2i, end_pos: Vector2i) -> bool:
	var x0: int = start_pos.x
	var y0: int = start_pos.y
	var x1: int = end_pos.x
	var y1: int = end_pos.y
	var dx: int = abs(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -abs(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0

	while true:
		if x == x1 and y == y1:
			break

		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

		if x == x1 and y == y1:
			break

		if _tile_movement_cost(state, Vector2i(x, y)) < 0:
			return false

	return true

func _dict_to_vector2i(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Vector2:
		return Vector2i(value)
	return Vector2i.ZERO

func _get_unit_ability(unit_data: Dictionary, ability_index: int) -> Dictionary:
	var abilities: Array = unit_data.get("abilities", [])
	if ability_index < 0 or ability_index >= abilities.size():
		return {}
	return abilities[ability_index]

func _ability_kind(ability_data: Dictionary) -> String:
	var script_path := String(ability_data.get("script_path", ""))
	if script_path.ends_with("ability_move.gd"):
		return "move"
	if script_path.ends_with("ability_shoot.gd"):
		return "shoot"
	return "unknown"

func _ability_damage(ability_data: Dictionary) -> int:
	return int(ability_data.get("damage", 0))
