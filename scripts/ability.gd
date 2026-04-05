class_name Ability
#base ability
const TARGET_TILE := 0
const TARGET_UNIT := 1

var display_name := "Ability"
var target_mode := TARGET_TILE

func get_display_name() -> String:
	return display_name

func get_target_mode() -> int:
	return target_mode

func get_valid_targets(user: Unit, map_manager, unit_manager) -> Array:
	return []

func execute(user: Unit, target) -> bool:
	return false
