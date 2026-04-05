extends Control
#basic AI hook
@onready var UnitManager = $"../UnitManager"

func take_turn(): #randomly acting AI
	var game_manager = get_parent()
	var map_manager = game_manager.get_node("MapManager")
	var available_actions: Array = []

	for unit in UnitManager.get_units_for_team(1):
		if not unit.can_act():
			continue

		for ability in unit.abilities:
			var valid_targets = ability.get_valid_targets(unit, map_manager, UnitManager)
			for target_pos in valid_targets:
				available_actions.append({
					"unit": unit,
					"ability": ability,
					"target_pos": target_pos
				})

	if available_actions.is_empty():
		game_manager.end_turn()
		return

	var action = available_actions.pick_random()
	var unit = action.unit
	var ability = action.ability
	var target_pos: Vector2i = action.target_pos
	var target = target_pos

	if ability.get_target_mode() == Ability.TARGET_UNIT:
		target = UnitManager.get_unit_at(target_pos)

	unit.perform_ability(ability, target)
	game_manager.end_turn()
