extends Node2D

var grid_size: Vector2i
var tiles = {} # Dictionary<Vector2i, Tile>

func load_map(map_data):
	grid_size = map_data.size
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile = preload("res://scenes/tile.tscn").instantiate() #TODO: make this scene
			tile.grid_pos = Vector2i(x, y)
			tile.terrain_type = map_data.tiles[y][x]
			
			add_child(tile)
			tiles[tile.grid_pos] = tile

func get_tile(pos: Vector2i) -> Tile:
	return tiles.get(pos, null)
