class_name Unit
extends Control

var team: int #player is team 0
var display_name := "Unit"
var health: int = 10
var active: int = 1 #0 means normally inactive; other integers can mean inactive due to other things
var action_points: int = 0

var position_on_grid: Vector2i

var abilities = [] #for now each unit has only 1 ability

@onready var shadow: ColorRect = $Shadow
@onready var frame: ColorRect = $Frame
@onready var core: ColorRect = $Core
@onready var badge: Label = $Badge
@onready var sprite: Sprite2D = $Sprite2D

func can_act():
	return active == 1 and action_points > 0

func perform_ability(ability, target):
	if not can_act():
		return false
	
	if ability.execute(self, target):
		action_points = maxi(action_points - 1, 0)
		return true
	
	return false

func update_visual():
	position = position_on_grid * 100
	z_index = 20 if team == 0 else 21
	if shadow != null:
		shadow.visible = true
	if frame != null:
		frame.visible = true
	if core != null:
		core.visible = true
	if badge != null:
		badge.visible = true
	if sprite != null:
		sprite.visible = true
		sprite.z_index = z_index + 1

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
	if badge != null:
		badge.z_index = z_index + 2
		badge.text = "P" if team == 0 else "A"
		badge.add_theme_color_override("font_color", Color(1, 1, 1))
	if sprite != null:
		sprite.modulate = sprite_color

func _process(delta: float) -> void:
	update_visual()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sprite != null:
		sprite.position = Vector2(50, 50)
		sprite.scale = Vector2(0.18, 0.18)
	if shadow != null:
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if frame != null:
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if core != null:
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if badge != null:
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
