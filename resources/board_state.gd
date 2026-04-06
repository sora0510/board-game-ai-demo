@tool
extends Resource
class_name BoardState

@export var board: Dictionary
@export var current_team: int = 0
@export var team_no: int = 2
@export var team_vp: Array = []
@export var team_ap: Array = []
@export var defeated_teams: Array = []
@export var team_won: int = -1
@export var status_message: String = ""
@export var units: Dictionary
