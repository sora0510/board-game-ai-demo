extends Control

@onready var UnitManager = $UnitManager


var unit_pool = [
	#add scenes of the units in here and add their costs e.g
	#{"scene": "res://rifleman.tscn", "cost": 3},
	#{"scene": "res://sniper.tscn", "cost": 5}
]

var current_team = 0
var team_no = 2 #in the future maybe more than 2 teams
var selected_unit = null

func generate_army(points: int, team: int):
	var remaining = points
	
	while remaining > 0:
		var choice = unit_pool.pick_random()
		
		if choice.cost <= remaining:
			#var pos = get_random_spawn(team) TODO
			#UnitManager.spawn_unit(choice, pos, team)
			remaining -= choice.cost

func _input(event):
	if event is InputEventMouseButton:
		var grid_pos = event.position
		
		if selected_unit == null:
			#selected_unit = get_unit_at(grid_pos) TODO
			return
		else:
			selected_unit.perform_ability(
				selected_unit.abilities[0],
				grid_pos
			)
			selected_unit = null

func start_turn():
	for unit in UnitManager.get_units_for_team(current_team):
		unit.action_points = 1

func end_turn():
	current_team = (current_team + 1) % team_no #next team, wrap if last team
	start_turn()
