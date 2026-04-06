class_name Unit
extends Control

var team: int #player is team 0
var display_name := "Unit"
var health: int = 10
var max_health: int = 10
var active: int = 1 #0 means normally inactive; other integers can mean inactive due to other things
var action_points: int = 0
var scene_path := ""

var position_on_grid: Vector2i

var abilities = [] #for now each unit has only 1 ability
var team_textures: Dictionary = {}

@onready var shadow: ColorRect = $Shadow
@onready var frame: ColorRect = $Frame
@onready var core: ColorRect = $Core
@onready var badge: Label = $Badge
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar_back: ColorRect = $HealthBarBack
@onready var health_bar_fill: ColorRect = $HealthBarBack/HealthBarFill

func can_act():
	return active == 1 and action_points > 0

func perform_ability(ability, target):
	if not can_act():
		return false
	
	if ability.execute(self, target):
		return true
	
	return false

func to_dict() -> Dictionary:
	var ability_list := []
	for ability in abilities:
		if ability != null:
			ability_list.append(_ability_to_dict(ability))

	return {
		"scene_path": scene_path,
		"team": team,
		"display_name": display_name,
		"health": health,
		"active": active,
		"action_points": action_points,
		"position_on_grid": [position_on_grid.x, position_on_grid.y],
		"abilities": ability_list,
	}

func _ability_to_dict(ability: Ability) -> Dictionary:
	var script = ability.get_script()
	var script_path := ""
	if script != null:
		script_path = script.resource_path

	var data := {
		"script_path": script_path,
	}

	for prop in ability.get_property_list():
		if prop.has("usage") and (prop["usage"] & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var name = prop["name"]
		if name in ["script", "owner", "owner_id", "name"]:
			continue
		var value = ability.get(name)
		var t = typeof(value)
		if t in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_COLOR, TYPE_ARRAY, TYPE_DICTIONARY]:
			data[name] = value

	return data

func from_dict(data: Dictionary) -> void:
	if data.has("scene_path"):
		scene_path = String(data["scene_path"])

	if data.has("team"):
		team = int(data["team"])

	if data.has("display_name"):
		display_name = String(data["display_name"])

	if data.has("health"):
		health = int(data["health"])

	if data.has("active"):
		active = int(data["active"])

	if data.has("action_points"):
		action_points = int(data["action_points"])

	if data.has("position_on_grid"):
		var pos = data["position_on_grid"]
		if pos is Array and pos.size() == 2:
			position_on_grid = Vector2i(int(pos[0]), int(pos[1]))
		elif pos is Dictionary:
			position_on_grid = Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))

	abilities.clear()
	if data.has("abilities") and data["abilities"] is Array:
		for ability_data in data["abilities"]:
			if ability_data is Dictionary:
				var ability = _ability_from_dict(ability_data)
				if ability != null:
					abilities.append(ability)

	update_visual()

func _ability_from_dict(data: Dictionary):
	if not data.has("script_path"):
		return null

	var script_path = String(data["script_path"])
	if script_path == "":
		return null

	var script = load(script_path)
	if script == null:
		return null

	var ability = script.new()
	if ability == null:
		return null

	var property_names := []
	for prop in ability.get_property_list():
		property_names.append(prop["name"])

	for key in data.keys():
		if key == "script_path":
			continue
		if key in property_names:
			ability.set(key, data[key])

	return ability

static func new_from_dict(data: Dictionary) -> Unit:
	var unit: Unit = null
	if data.has("scene_path"):
		var path := String(data["scene_path"])
		if path != "":
			var scene = load(path)
			if scene is PackedScene:
				unit = scene.instantiate() as Unit
	if unit == null:
		unit = Unit.new()
	unit.from_dict(data)
	return unit

func update_visual():
	position = position_on_grid * 100
	z_index = 20 if team == 0 else 21
	if shadow != null:
		shadow.visible = true
	if frame != null:
		frame.visible = true
	if core != null:
		core.visible = true
	if sprite != null:
		sprite.visible = true
		sprite.z_index = z_index + 1
	if health_bar_back != null:
		health_bar_back.visible = true
		health_bar_back.z_index = z_index + 2
	if health_bar_fill != null:
		health_bar_fill.visible = true
		health_bar_fill.z_index = z_index + 3

	var shadow_color := Color(0, 0, 0, 0.20)
	var frame_color := Color(0.12, 0.12, 0.12, 1.0)
	var core_color := Color.WHITE
	var sprite_color := Color(1, 1, 1, 0.75)

	match team:
		0:
			core_color = Color(0.35, 0.80, 1.0)
			frame_color = Color(0.08, 0.30, 0.48)
			shadow_color = Color(0.0, 0.0, 0.0, 0.26)
			sprite_color = Color(0.55, 0.86, 1.0, 0.78)
		1:
			core_color = Color(1.0, 0.42, 0.42)
			frame_color = Color(0.45, 0.08, 0.08)
			shadow_color = Color(0.0, 0.0, 0.0, 0.26)
			sprite_color = Color(1.0, 0.55, 0.55, 0.78)
		_:
			core_color = Color(0.92, 0.92, 0.92)

	if shadow != null:
		shadow.color = shadow_color
	if frame != null:
		frame.color = frame_color
	if core != null:
		core.color = core_color
	if sprite != null:
		sprite.modulate = sprite_color
		var team_texture = team_textures.get(team)
		if team_texture != null:
			sprite.texture = team_texture
	_update_health_bar()

func _update_health_bar() -> void:
	if health_bar_back == null or health_bar_fill == null:
		return

	var bar_position := Vector2(12, 10)
	var bar_size := Vector2(76, 8)
	var health_ratio := 1.0
	if max_health > 0:
		health_ratio = clampf(float(health) / float(max_health), 0.0, 1.0)

	health_bar_back.position = bar_position
	health_bar_back.size = bar_size
	health_bar_back.color = Color(0.10, 0.12, 0.10, 0.88)

	health_bar_fill.position = Vector2.ZERO
	health_bar_fill.size = Vector2(bar_size.x * health_ratio, bar_size.y)
	health_bar_fill.color = Color(0.20, 0.88, 0.24, 0.96)

func _process(delta: float) -> void:
	update_visual()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	max_health = max(health, 1)
	if sprite != null:
		sprite.position = Vector2(50, 50)
		sprite.scale = Vector2(0.21, 0.21)
	if shadow != null:
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if frame != null:
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if core != null:
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if badge != null:
		badge.visible = false
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_health_bar()
