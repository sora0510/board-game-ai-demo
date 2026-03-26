extends Control
#basic AI hook
@onready var UnitManager = $"../UnitManager"

func take_turn():
	var units = UnitManager.get_units_for_team(1)
	
	for unit in units:
		if not unit.can_act():
			continue
		
		# random move for now
		var target = unit.position_on_grid + Vector2i(
			randi_range(-1, 1),
			randi_range(-1, 1)
		)
		
		unit.perform_ability(unit.abilities[0], target)
