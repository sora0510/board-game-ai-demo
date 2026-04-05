extends Unit
#platonic scout

func _ready():
	display_name = "Scout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 7
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.move_range = 5
	
	abilities = [
		move
	]
