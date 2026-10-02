extends Node2D
class_name PongBall


signal out_of_bounds(exit_side: int)
signal area_boundary_reached(loser_side: int)

@export var ball_size := Vector2(18.0, 18.0)
@export var ball_speed := 540.0
@export var player_1_color := PongPalette.PLAYER_1
@export var player_2_color := PongPalette.PLAYER_2
@export_range(0.0, 89.0, 1.0) var serve_steering_degrees := 70.0
@export var serve_speed_from_player := 0.18
@export var serve_spin_from_player := 0.02
@export var max_ball_speed := 1100.0
@export var air_drag_coefficient := 0.00009
@export var magnus_strength := 0.035
@export var spin_damping := 1.2
@export var max_spin := 35.0
@export_range(0.0, 1.0, 0.01) var paddle_restitution := 0.9
@export_range(0.0, 1.0, 0.01) var paddle_friction := 0.45
@export var max_paddle_friction_change := 340.0
@export_range(0.0, 1.0, 0.01) var wall_restitution := 0.96
@export_range(0.0, 1.0, 0.01) var wall_friction := 0.18
@export var max_wall_friction_change := 140.0
@export var min_return_horizontal_speed := 180.0
@export var edge_deflection_speed := 90.0

@onready var visual: ColorRect = $Visual

var velocity := Vector2.ZERO
var angular_velocity := 0.0
var playfield_size := PongField.SIZE
var attached := true
var last_hitter_side := PlayerSide.NONE


func _ready() -> void:
	update_visual()


func configure(world_size: Vector2) -> void:
	playfield_size = world_size
	update_visual()


func attach_to_player(player: PongPlayer) -> void:
	attach_to(player.get_ball_anchor(ball_size), player.get_side())


func attach_to(origin: Vector2, player_side: int) -> void:
	assert(PlayerSide.is_valid(player_side))
	position = origin
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	attached = true
	last_hitter_side = player_side
	update_visual()


func serve(server_side: int, server_velocity: Vector2) -> void:
	if not attached:
		return

	assert(PlayerSide.is_valid(server_side))
	attached = false
	var toward_opponent := Vector2(
		PlayerSide.direction_toward_opponent(server_side),
		0.0
	)
	var direction := toward_opponent
	if server_velocity.length() > 0.01:
		var movement_angle := rad_to_deg(toward_opponent.angle_to(server_velocity))
		var steering_angle := clampf(
			movement_angle,
			-serve_steering_degrees,
			serve_steering_degrees
		)
		direction = toward_opponent.rotated(deg_to_rad(steering_angle))

	var launch_speed := clampf(
		ball_speed + server_velocity.length() * serve_speed_from_player,
		ball_speed,
		max_ball_speed
	)
	velocity = direction * launch_speed
	var tangent := Vector2(-direction.y, direction.x)
	angular_velocity = clampf(
		-server_velocity.dot(tangent) * serve_spin_from_player,
		-max_spin * 0.5,
		max_spin * 0.5
	)


func move(
	delta: float,
	player1_rect: Rect2,
	player2_rect: Rect2,
	player1_velocity: Vector2,
	player2_velocity: Vector2
) -> void:
	if attached:
		return

	apply_forces(delta)
	var ball_radius := minf(ball_size.x, ball_size.y) * 0.5
	var travel_distance := velocity.length() * delta
	var substep_count := maxi(1, ceili(travel_distance / ball_radius))
	var substep_delta := delta / float(substep_count)

	for step in substep_count:
		var previous_position := position
		position += velocity * substep_delta
		if check_player_area_vertical_boundary(previous_position, substep_delta):
			return
		bounce_off_player(
			player1_rect,
			PlayerSide.PLAYER_1,
			Vector2(1.0, 0.0),
			player1_velocity
		)
		bounce_off_player(
			player2_rect,
			PlayerSide.PLAYER_2,
			Vector2(-1.0, 0.0),
			player2_velocity
		)

		if is_out_of_playfield():
			var ball_rect := get_rect()
			var exit_side := (
				PlayerSide.PLAYER_1
				if ball_rect.position.x <= 0.0
				else PlayerSide.PLAYER_2
			)
			velocity = Vector2.ZERO
			angular_velocity = 0.0
			out_of_bounds.emit(exit_side)
			return


func apply_forces(delta: float) -> void:
	var speed := velocity.length()
	if speed <= 0.001:
		return

	var drag_change := air_drag_coefficient * speed * speed * delta
	velocity -= velocity / speed * minf(drag_change, speed)

	if not is_zero_approx(angular_velocity):
		var magnus_acceleration := Vector2(
			-angular_velocity * velocity.y,
			angular_velocity * velocity.x
		) * magnus_strength
		velocity += magnus_acceleration * delta

	angular_velocity = move_toward(angular_velocity, 0.0, spin_damping * delta)
	velocity = velocity.limit_length(max_ball_speed)
	rotation += angular_velocity * delta


func check_player_area_vertical_boundary(
	previous_position: Vector2,
	substep_delta: float
) -> bool:
	var ball_rect := get_rect()
	var half_height := ball_size.y * 0.5
	var touches_top := ball_rect.position.y <= 0.0
	var touches_bottom := ball_rect.end.y >= playfield_size.y
	if not touches_top and not touches_bottom:
		return false

	var normal := Vector2.ZERO
	var contact_x := position.x
	if touches_top:
		if velocity.y < -0.001:
			var top_crossing_time := clampf(
				(previous_position.y - half_height) / -velocity.y,
				0.0,
				substep_delta
			)
			contact_x = previous_position.x + velocity.x * top_crossing_time
		position.y = half_height
		normal = Vector2(0.0, 1.0)
	elif touches_bottom:
		if velocity.y > 0.001:
			var bottom_crossing_time := clampf(
				(playfield_size.y - half_height - previous_position.y) / velocity.y,
				0.0,
				substep_delta
			)
			contact_x = previous_position.x + velocity.x * bottom_crossing_time
		position.y = playfield_size.y - half_height
		normal = Vector2(0.0, -1.0)

	var boundary_side := (
		PlayerSide.PLAYER_1
		if contact_x < playfield_size.x * 0.5
		else PlayerSide.PLAYER_2
	)
	if last_hitter_side != PlayerSide.NONE and boundary_side == last_hitter_side:
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		area_boundary_reached.emit(boundary_side)
		return true

	_resolve_surface_collision(
		normal,
		Vector2.ZERO,
		wall_restitution,
		wall_friction,
		max_wall_friction_change
	)
	return false


func bounce_off_player(
	player_rect: Rect2,
	player_side: int,
	normal: Vector2,
	player_velocity: Vector2
) -> bool:
	if not get_rect().intersects(player_rect):
		return false
	if velocity.dot(normal) >= 0.0:
		return false

	last_hitter_side = player_side
	update_visual()
	var half_width := ball_size.x * 0.5
	if normal.x > 0.0:
		position.x = player_rect.end.x + half_width
	else:
		position.x = player_rect.position.x - half_width

	_resolve_surface_collision(
		normal,
		player_velocity,
		paddle_restitution,
		paddle_friction,
		max_paddle_friction_change
	)

	var ball_radius := minf(ball_size.x, ball_size.y) * 0.5
	var contact_offset := clampf(
		(position.y - player_rect.get_center().y) / (player_rect.size.y * 0.5 + ball_radius),
		-1.0,
		1.0
	)
	velocity.y += contact_offset * edge_deflection_speed

	var outward_speed := velocity.dot(normal)
	if outward_speed < min_return_horizontal_speed:
		velocity += normal * (min_return_horizontal_speed - outward_speed)

	velocity = velocity.limit_length(max_ball_speed)
	return true


func _resolve_surface_collision(
	normal: Vector2,
	surface_velocity: Vector2,
	restitution: float,
	friction: float,
	max_tangent_change: float
) -> void:
	normal = normal.normalized()
	var relative_velocity := velocity - surface_velocity
	var normal_speed := relative_velocity.dot(normal)
	if normal_speed >= 0.0:
		return

	var ball_radius := minf(ball_size.x, ball_size.y) * 0.5
	var contact_arm := -normal * ball_radius
	var spin_surface_velocity := Vector2(
		-angular_velocity * contact_arm.y,
		angular_velocity * contact_arm.x
	)
	var contact_velocity := relative_velocity + spin_surface_velocity
	var tangent := Vector2(-normal.y, normal.x)
	var tangent_speed := contact_velocity.dot(tangent)
	var tangent_speed_change := -clampf(
		tangent_speed * friction,
		-max_tangent_change,
		max_tangent_change
	)

	velocity += tangent * tangent_speed_change
	angular_velocity += (
		2.0
		* contact_arm.cross(tangent)
		* tangent_speed_change
		/ (ball_radius * ball_radius)
	)
	angular_velocity = clampf(angular_velocity, -max_spin, max_spin)

	velocity -= normal * (1.0 + restitution) * normal_speed
	velocity = velocity.limit_length(max_ball_speed)


func is_attached() -> bool:
	return attached


func get_rect() -> Rect2:
	return Rect2(position - ball_size * 0.5, ball_size)


func is_out_of_playfield() -> bool:
	var ball_rect := get_rect()
	return ball_rect.position.x <= 0.0 or ball_rect.end.x >= playfield_size.x


func update_visual() -> void:
	if not is_instance_valid(visual):
		return

	visual.position = -ball_size * 0.5
	visual.size = ball_size
	update_ball_color()


func update_ball_color() -> void:
	if not is_instance_valid(visual):
		return

	if last_hitter_side == PlayerSide.PLAYER_1:
		visual.color = player_1_color
	elif last_hitter_side == PlayerSide.PLAYER_2:
		visual.color = player_2_color
	else:
		visual.color = PongPalette.NEUTRAL
