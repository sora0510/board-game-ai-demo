extends Unit
#platonic sniper

func _ready():
	display_name = "Sniper"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 6
	
	var shoot = preload("res://abilities/ability_shoot.gd").new()
	shoot.attack_range = 8
	shoot.damage = 5
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.move_range = 1
	
	abilities = [
		shoot,
		move
	]
