extends Ability
var move_range := 3

func _init() -> void:
	display_name = "Move"
	target_mode = TARGET_TILE

func get_valid_targets(_user: Unit, map_manager, unit_manager) -> Array:
	var targets: Array = []
	for y in range(map_manager.grid_size.y):
		for x in range(map_manager.grid_size.x):
			var target_pos := Vector2i(x, y)
			if _user.position_on_grid.distance_to(target_pos) > move_range:
				continue

			var tile: Tile = map_manager.get_tile(target_pos)
			if tile == null:
				continue

			var movement_cost: int = tile.get_movement_cost()
			if movement_cost < 0:
				continue

			if unit_manager.get_unit_at(target_pos) != null:
				continue

			targets.append(target_pos)

	return targets

func execute(user: Unit, target_pos: Vector2i) -> bool:
	var distance = user.position_on_grid.distance_to(target_pos)
	
	if distance > move_range:
		return false
	
	user.position_on_grid = target_pos
	
	return true
