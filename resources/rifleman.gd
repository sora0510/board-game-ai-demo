extends Unit
#platonic rifleman

func _ready():
	display_name = "Rifleman"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 10
	
	abilities = [
		preload("res://abilities/ability_shoot.gd").new(),
		preload("res://abilities/ability_move.gd").new()
	]
