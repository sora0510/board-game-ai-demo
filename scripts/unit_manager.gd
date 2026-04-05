extends Node2D

var units = []

func cleanup_units():
	units = units.filter(func(u): return is_instance_valid(u))

func spawn_unit(unit_data, grid_pos, team):
	var unit_scene: PackedScene = load(unit_data) #unit_data is form "res://rifleman.tscn"
	var unit = unit_scene.instantiate()
	
	unit.team = team
	unit.position_on_grid = grid_pos
	unit.z_index = 10
	
	add_child(unit)
	units.append(unit)
	
	return unit

func get_units_for_team(team):
	cleanup_units()
	return units.filter(func(u): return u.team == team)

func get_unit_at(grid_pos: Vector2i):
	cleanup_units()
	for unit in units:
		if unit.position_on_grid == grid_pos:
			return unit

	return null
