extends Ability
@export var attack_range := 5
@export var damage := 3

func _init() -> void:
	display_name = "Shoot"
	target_mode = TARGET_UNIT

func get_valid_targets(user: Unit, _map_manager, unit_manager, team_ap: int = -1) -> Array:
	var targets: Array = []
	if team_ap >= 0 and team_ap < 1:
		return targets
	for target_unit in unit_manager.get_units_for_team(1 - user.team):
		if user.position_on_grid.distance_to(target_unit.position_on_grid) <= attack_range and not _is_path_blocked(user.position_on_grid, target_unit.position_on_grid, _map_manager):
			targets.append(target_unit.position_on_grid)

	return targets

func execute(user: Unit, target: Unit) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if user.position_on_grid.distance_to(target.position_on_grid) > attack_range:
		return false

	var scene = user.get_tree().current_scene
	if scene == null or not scene.has_node("MapManager"):
		return false

	var map_manager = scene.get_node("MapManager")
	if _is_path_blocked(user.position_on_grid, target.position_on_grid, map_manager):
		return false
	
	target.health -= damage
	
	if target.health <= 0:
		target.queue_free() #death
	
	return true

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
