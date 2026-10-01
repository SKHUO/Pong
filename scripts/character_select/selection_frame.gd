extends Node2D
class_name SelectionFrame


@export var padding := 10.0

@onready var rect: ReferenceRect = $Rect

var frame_color := Color(0.2, 0.55, 1.0)


func _ready() -> void:
	rect.border_color = frame_color


func set_frame_color(color: Color) -> void:
	frame_color = color
	if is_node_ready():
		rect.border_color = frame_color


func wrap(target_rect: Rect2) -> void:
	rect.position = target_rect.position - Vector2.ONE * padding
	rect.size = target_rect.size + Vector2.ONE * padding * 2.0
