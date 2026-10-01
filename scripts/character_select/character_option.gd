extends Node2D
class_name CharacterOption


@export var option_size := Vector2(88.0, 88.0)

@onready var visual: ColorRect = $Visual

var character_id: StringName = &""
var body_color := Color.WHITE


func _ready() -> void:
	update_visual()


func setup(character: CharacterDef) -> void:
	character_id = character.id
	body_color = character.body_color
	if is_node_ready():
		update_visual()


func get_rect() -> Rect2:
	return Rect2(position - option_size * 0.5, option_size)


func update_visual() -> void:
	visual.position = -option_size * 0.5
	visual.size = option_size
	visual.color = body_color
