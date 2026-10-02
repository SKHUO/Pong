extends Node2D
class_name PongDivider


@export var line_width: float = 4.0

@onready var visual: ColorRect = $Visual


func configure(playfield_size: Vector2) -> void:
	visual.color = PongPalette.DIVIDER
	visual.size = Vector2(line_width, playfield_size.y)
	visual.position = Vector2(-line_width * 0.5, 0.0)
	position = Vector2(playfield_size.x * 0.5, 0.0)


func get_playfield_rect() -> Rect2:
	return Rect2(position + visual.position, visual.size)
