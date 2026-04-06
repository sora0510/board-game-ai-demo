extends Ability
var attack_range := 5
var damage := 3

func _init() -> void:
	display_name = "Shoot"
	target_mode = TARGET_UNIT

func get_valid_targets(user: Unit, _map_manager, unit_manager) -> Array:
	var targets: Array = []
	for target_unit in unit_manager.get_units_for_team(1 - user.team):
		if user.position_on_grid.distance_to(target_unit.position_on_grid) <= attack_range:
			targets.append(target_unit.position_on_grid)

	return targets

func execute(user: Unit, target: Unit) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if user.position_on_grid.distance_to(target.position_on_grid) > attack_range:
		return false

	var attacker_team := "Blue" if user.team == 0 else "Red"
	var target_team := "Blue" if target.team == 0 else "Red"
	var action_log := "%s %s took damage from %s %s" % [target_team, target.display_name, attacker_team, user.display_name]
	var game = user.get_tree().current_scene
	if game != null and game.has_method("show_action_log"):
		game.call_deferred("show_action_log", action_log, target.position_on_grid)
	
	target.health -= damage
	
	if target.health <= 0:
		target.queue_free() #death
	
	return true
