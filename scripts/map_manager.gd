extends Node2D

var grid_size: Vector2i
var tiles = {} #Dictionary<Vector2i, Tile>

#MAP DATA RULE: negative values are spawns
#if there are more players than the map can support then some teams share spawns

func load_map(map_data):
	var newmap = load(map_data)
	var mapmaker = newmap.new()
	grid_size = mapmaker.my_map.size
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile = preload("res://scenes/tile.tscn").instantiate()
			tile.grid_pos = Vector2i(x, y)
			tile.terrain_type = mapmaker.my_map.tiles[y][x]
			
			add_child(tile)
			tiles[tile.grid_pos] = tile

func get_tile(pos: Vector2i) -> Tile:
	return tiles.get(pos, null)

func get_random_spawn(team: int, unit_manager) -> Vector2i:
	var teamspawns = [] #Vector2i
	var spawn_id := -(team + 1)
	for pos in tiles:
		if tiles[pos].terrain_type == spawn_id and unit_manager.get_unit_at(pos) == null:
			#team 0 uses -1, team 1 uses -2, etc.
			teamspawns.append(pos)

	if teamspawns.is_empty():
		return Vector2i(-1, -1)

	return teamspawns.pick_random()
