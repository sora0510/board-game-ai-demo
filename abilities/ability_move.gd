extends Ability
@export var move_range := 3

func _init() -> void:
	display_name = "Move"
	target_mode = TARGET_TILE

func get_valid_targets(_user: Unit, map_manager, unit_manager, team_ap: int = -1) -> Array:
	var targets: Array = []
	for y in range(map_manager.grid_size.y):
		for x in range(map_manager.grid_size.x):
			var target_pos := Vector2i(x, y)
			if _user.position_on_grid.distance_to(target_pos) > move_range:
				continue

			if target_pos == _user.position_on_grid:
				continue

			var tile: Tile = map_manager.get_tile(target_pos)
			if tile == null:
				continue

			var movement_cost: int = tile.get_movement_cost()
			if movement_cost < 0:
				continue

			if team_ap >= 0 and movement_cost > team_ap:
				continue

			if _is_path_blocked(_user.position_on_grid, target_pos, map_manager):
				continue

			if unit_manager.get_unit_at(target_pos) != null:
				continue

			targets.append(target_pos)

	return targets

func execute(user: Unit, target_pos: Vector2i) -> bool:
	var distance = user.position_on_grid.distance_to(target_pos)
	
	if distance > move_range:
		return false

	var game = user.get_tree().current_scene
	if game == null or not game.has_node("MapManager"):
		return false

	var map_manager = game.get_node("MapManager")
	if _is_path_blocked(user.position_on_grid, target_pos, map_manager):
		return false

	var tile: Tile = map_manager.get_tile(target_pos)
	if tile == null:
		return false

	if game.has_method("get_team_action_points"):
		var team_ap := int(game.get_team_action_points(user.team))
		if tile.get_movement_cost() > team_ap:
			return false
	
	user.position_on_grid = target_pos
	
	return true

func get_action_cost(user: Unit = null, target = null, map_manager = null) -> int:
	if target is Vector2i and map_manager != null:
		var tile: Tile = map_manager.get_tile(target)
		if tile != null:
			return max(tile.get_movement_cost(), 0)

	return 1

func _is_path_blocked(start_pos: Vector2i, end_pos: Vector2i, map_manager) -> bool:
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

		var tile: Tile = map_manager.get_tile(Vector2i(x, y))
		if tile != null and tile.get_movement_cost() < 0:
			return true

	return false
