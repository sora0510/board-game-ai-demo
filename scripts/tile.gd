class_name Tile
extends Node2D
#a map is a grid of square Tiles
#note: the map itself can be irregular but each tile is a square

var grid_pos: Vector2i
var terrain_type: int

func get_movement_cost():
	match terrain_type:
		GameEnums.TerrainType.PLAIN: return 1
		GameEnums.TerrainType.FOREST: return 2
		GameEnums.TerrainType.HOUSE: return 2
		GameEnums.TerrainType.ROAD: return 1
		GameEnums.TerrainType.IMPASSABLE: return -1
