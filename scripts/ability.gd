class_name Ability
#base ability
const TARGET_TILE := 0
const TARGET_UNIT := 1

var display_name := "Ability"
var target_mode := TARGET_TILE
@export var action_cost := 1

func get_display_name() -> String:
	return display_name

func get_target_mode() -> int:
	return target_mode

func get_action_cost(user: Unit = null, target = null, map_manager = null) -> int:
	return action_cost

func get_valid_targets(user: Unit, map_manager, unit_manager, team_ap: int = -1) -> Array:
	return []

func execute(user: Unit, target) -> bool:
	return false
