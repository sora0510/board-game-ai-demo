class_name Tile
extends Control
#a map is a grid of square Tiles
#note: the map itself can be irregular but each tile is a square

const HIGHLIGHT_NONE := 0
const HIGHLIGHT_SELECTED := 1
const HIGHLIGHT_MOVE := 2
const HIGHLIGHT_TARGET := 3

var grid_pos: Vector2i
var terrain_type: int
var highlight_state := HIGHLIGHT_NONE

@onready var border: ColorRect = $Border
@onready var fill: ColorRect = $Fill
@onready var sprite: Sprite2D = $Sprite2D

func set_highlight(state: int) -> void:
	highlight_state = state
	update_visual()

func get_movement_cost() -> int:
	if terrain_type < 0:
		return 1

	match terrain_type:
		GameEnums.TerrainType.PLAIN: return 1
		GameEnums.TerrainType.FOREST: return 2
		GameEnums.TerrainType.HOUSE: return 2
		GameEnums.TerrainType.ROAD: return 1
		GameEnums.TerrainType.VICTORY: return 1
		GameEnums.TerrainType.IMPASSABLE: return -1

	return 1

func update_visual():
	position = grid_pos * 100
	if sprite != null:
		sprite.visible = false

	if border == null or fill == null:
		return

	var fill_color := Color(1, 1, 1)
	var border_color := Color(0.12, 0.12, 0.12, 1.0)
	match terrain_type:
		GameEnums.TerrainType.PLAIN:
			fill_color = Color(0.92, 0.89, 0.75)
			border_color = Color(0.34, 0.28, 0.16)
		GameEnums.TerrainType.FOREST:
			fill_color = Color(0.56, 0.72, 0.46)
			border_color = Color(0.16, 0.28, 0.12)
		GameEnums.TerrainType.HOUSE:
			fill_color = Color(0.82, 0.67, 0.50)
			border_color = Color(0.38, 0.22, 0.14)
		GameEnums.TerrainType.ROAD:
			fill_color = Color(0.70, 0.67, 0.59)
			border_color = Color(0.28, 0.25, 0.20)
		GameEnums.TerrainType.VICTORY:
			fill_color = Color(0.97, 0.86, 0.38)
			border_color = Color(0.62, 0.46, 0.08)
		GameEnums.TerrainType.IMPASSABLE:
			fill_color = Color(0.34, 0.34, 0.34)
			border_color = Color(0.10, 0.10, 0.10)

	match highlight_state:
		HIGHLIGHT_SELECTED:
			fill_color = fill_color.lerp(Color(0.40, 0.75, 1.0), 0.35)
			border_color = Color(0.12, 0.75, 1.0)
		HIGHLIGHT_MOVE:
			fill_color = fill_color.lerp(Color(0.58, 1.0, 0.58), 0.42)
			border_color = Color(0.22, 0.95, 0.30)
		HIGHLIGHT_TARGET:
			fill_color = fill_color.lerp(Color(1.0, 0.54, 0.54), 0.42)
			border_color = Color(1.0, 0.20, 0.20)

	fill.color = fill_color
	border.color = border_color

func _process(delta: float) -> void:
	update_visual()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if border != null:
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fill != null:
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
