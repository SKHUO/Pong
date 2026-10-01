extends Node2D
class_name PongPlayer


@export var paddle_size := Vector2(18.0, 80.0)
@export var move_speed := 420.0
@export var skill_speed_multiplier := 1.0
@export var skill_duration := 0.0
@export var skill_cooldown := 0.0
@export_enum("WASD", "ArrowKeys") var control_scheme: int = 0

@onready var skill_trail: SkillTrail = $SkillTrail
@onready var visual: ColorRect = $Visual

var playfield_size := Vector2(1800.0, 720.0)
var min_center_x := 0.0
var max_center_x := 1800.0
var body_color := Color.WHITE
var velocity := Vector2.ZERO
var _skill_time_remaining := 0.0
var _skill_cooldown_remaining := 0.0


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
	velocity = Vector2.ZERO
	if is_instance_valid(skill_trail):
		skill_trail.clear()
	clamp_to_playfield()


func apply_character(character: CharacterDef) -> void:
	body_color = character.body_color
	paddle_size = character.paddle_size
	skill_speed_multiplier = character.skill_speed_multiplier
	skill_duration = character.skill_duration
	skill_cooldown = character.skill_cooldown
	update_visual()


func move(delta: float) -> void:
	var previous_position := position
	var direction := get_move_direction()
	if direction != Vector2.ZERO:
		position += direction.normalized() * get_current_move_speed() * delta
		clamp_to_playfield()

	if delta > 0.0:
		velocity = (position - previous_position) / delta
	else:
		velocity = Vector2.ZERO

	_update_skill_timers(delta)
	if is_instance_valid(skill_trail):
		skill_trail.update_trail(
			delta,
			is_skill_active(),
			global_position,
			body_color,
			paddle_size
		)


func get_velocity() -> Vector2:
	return velocity


func try_activate_skill() -> bool:
	if not has_active_skill() or _skill_cooldown_remaining > 0.0:
		return false

	_skill_time_remaining = skill_duration
	_skill_cooldown_remaining = skill_cooldown
	return true


func has_active_skill() -> bool:
	return skill_speed_multiplier > 1.0 and skill_duration > 0.0 and skill_cooldown > 0.0


func get_current_move_speed() -> float:
	if _skill_time_remaining > 0.0:
		return move_speed * skill_speed_multiplier
	return move_speed


func is_skill_active() -> bool:
	return _skill_time_remaining > 0.0


func get_skill_cooldown_remaining() -> float:
	return _skill_cooldown_remaining


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


func _update_skill_timers(delta: float) -> void:
	_skill_time_remaining = maxf(_skill_time_remaining - delta, 0.0)
	_skill_cooldown_remaining = maxf(_skill_cooldown_remaining - delta, 0.0)
	if is_zero_approx(_skill_time_remaining):
		_skill_time_remaining = 0.0
	if is_zero_approx(_skill_cooldown_remaining):
		_skill_cooldown_remaining = 0.0


func update_visual() -> void:
	visual.position = -paddle_size * 0.5
	visual.size = paddle_size
	visual.color = body_color
