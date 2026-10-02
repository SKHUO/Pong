extends Node2D
class_name PongBackground


@onready var visual: ColorRect = $Visual


func configure(playfield_size: Vector2) -> void:
	visual.color = PongPalette.BACKGROUND
	visual.position = Vector2.ZERO
	visual.size = playfield_size
