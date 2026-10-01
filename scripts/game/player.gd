extends Node2D
class_name PongPlayer


@export var paddle_size := Vector2(24.0, 120.0)
@export var move_speed := 420.0
@export_enum("WASD", "ArrowKeys") var control_scheme: int = 0

@onready var visual: ColorRect = $Visual

var playfield_size := Vector2(1152.0, 648.0)
var min_center_x := 0.0
var max_center_x := 1152.0
var body_color := Color.WHITE


func _ready() -> void:
	update_visual()


func configure(world_size: Vector2, side: int, divider_rect: Rect2) -> void:
	playfield_size = world_size
	var half_size := paddle_size * 0.5

	if side < 0:
		min_center_x = half_size.x
		max_center_x = divider_rect.position.x - half_size.x
	else:
		min_center_x = divider_rect.end.x + half_size.x
		max_center_x = world_size.x - half_size.x

	update_visual()
	clamp_to_playfield()


func reset_to(center: Vector2) -> void:
	position = center
	clamp_to_playfield()


func apply_character(character: CharacterDef) -> void:
	body_color = character.body_color
	update_visual()


func move(delta: float) -> void:
	var direction := get_move_direction()
	if direction != Vector2.ZERO:
		position += direction.normalized() * move_speed * delta
		clamp_to_playfield()


func get_rect() -> Rect2:
	return Rect2(position - paddle_size * 0.5, paddle_size)


func get_move_direction() -> Vector2:
	if control_scheme == 0:
		return Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		)

	return Vector2(
		float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
	)


func clamp_to_playfield() -> void:
	var half_size := paddle_size * 0.5
	position.x = clampf(position.x, min_center_x, max_center_x)
	position.y = clampf(position.y, half_size.y, playfield_size.y - half_size.y)


func update_visual() -> void:
	visual.position = -paddle_size * 0.5
	visual.size = paddle_size
	visual.color = body_color
