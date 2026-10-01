extends Node2D
class_name PongBall


signal out_of_bounds(exit_side: int)

@export var ball_size := Vector2(18.0, 18.0)
@export var ball_speed := 540.0
@export_range(0.0, 80.0, 1.0) var min_serve_angle_degrees := 12.0
@export_range(0.0, 80.0, 1.0) var max_serve_angle_degrees := 35.0

@onready var visual: ColorRect = $Visual

var velocity := Vector2.ZERO
var playfield_size := Vector2(1280.0, 720.0)
var attached := true


func _ready() -> void:
	update_visual()


func configure(world_size: Vector2) -> void:
	playfield_size = world_size
	update_visual()


func attach_to(origin: Vector2) -> void:
	position = origin
	velocity = Vector2.ZERO
	attached = true


func serve(horizontal_direction: float) -> void:
	if not attached:
		return

	attached = false
	var angle_degrees := randf_range(min_serve_angle_degrees, max_serve_angle_degrees)
	if randf() < 0.5:
		angle_degrees = -angle_degrees

	var angle_radians := deg_to_rad(angle_degrees)
	velocity = Vector2(
		cos(angle_radians) * signf(horizontal_direction),
		sin(angle_radians)
	) * ball_speed


func move(delta: float, player1_rect: Rect2, player2_rect: Rect2) -> void:
	if attached:
		return

	position += velocity * delta
	bounce_vertically()
	bounce_off_player(player1_rect, -1.0)
	bounce_off_player(player2_rect, 1.0)

	if is_out_of_playfield():
		var ball_rect := get_rect()
		var exit_side := -1 if ball_rect.position.x <= 0.0 else 1
		velocity = Vector2.ZERO
		out_of_bounds.emit(exit_side)


func is_attached() -> bool:
	return attached


func get_rect() -> Rect2:
	return Rect2(position - ball_size * 0.5, ball_size)


func bounce_vertically() -> void:
	var ball_rect := get_rect()
	var half_height := ball_size.y * 0.5

	if ball_rect.position.y <= 0.0 and velocity.y < 0.0:
		position.y = half_height
		velocity.y = absf(velocity.y)
	elif ball_rect.end.y >= playfield_size.y and velocity.y > 0.0:
		position.y = playfield_size.y - half_height
		velocity.y = -absf(velocity.y)


func bounce_off_player(player_rect: Rect2, player_side: float) -> void:
	if not get_rect().intersects(player_rect):
		return

	var half_width := ball_size.x * 0.5
	if player_side < 0.0 and velocity.x < 0.0:
		position.x = player_rect.end.x + half_width
		velocity.x = absf(velocity.x)
	elif player_side > 0.0 and velocity.x > 0.0:
		position.x = player_rect.position.x - half_width
		velocity.x = -absf(velocity.x)


func is_out_of_playfield() -> bool:
	var ball_rect := get_rect()
	return ball_rect.position.x <= 0.0 or ball_rect.end.x >= playfield_size.x


func update_visual() -> void:
	visual.position = -ball_size * 0.5
	visual.size = ball_size
