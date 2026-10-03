extends Node2D
class_name PongPlayer


@export var paddle_size := Vector2(18.0, 80.0)
@export var move_speed := 420.0
@export var skill_speed_multiplier := 1.0
@export var skill_duration := 0.0
@export var skill_cooldown := 0.0
@export var hit_shake_duration := 0.13
@export var hit_shake_strength := 4.0
@export var hit_shake_frequency := 42.0
@export_enum("WASD", "ArrowKeys") var control_scheme: int = 0

@onready var skill_trail: SkillTrail = $SkillTrail
@onready var visual: ColorRect = $Visual

var playfield_size := PongField.SIZE
var player_side := PlayerSide.NONE
var min_center_x := 0.0
var max_center_x := PongField.SIZE.x
var body_color := Color.WHITE
var velocity := Vector2.ZERO
var _skill_time_remaining := 0.0
var _skill_cooldown_remaining := 0.0
var _hit_shake_time_remaining := 0.0
var _hit_shake_phase := 0.0
var _network_controlled := false
var _network_has_target := false
var _network_snap_pending := false
var _network_target_position := Vector2.ZERO
var _network_target_velocity := Vector2.ZERO


func _ready() -> void:
	update_visual()
	set_process(false)


func _process(delta: float) -> void:
	if not _network_controlled or not _network_has_target:
		return

	if _network_snap_pending:
		position = _network_target_position
		_network_snap_pending = false
	else:
		position = position.lerp(_network_target_position, clampf(delta * 18.0, 0.0, 1.0))
	velocity = _network_target_velocity

	if is_instance_valid(skill_trail):
		skill_trail.update_trail(
			delta,
			is_skill_active(),
			global_position,
			body_color,
			paddle_size
		)
	_update_hit_shake(delta)


func setup(character: CharacterDef, side: int) -> void:
	assert(PlayerSide.is_valid(side))
	player_side = side
	_apply_character(character)
	_configure_bounds()
	clamp_to_playfield()


func reset_for_round() -> void:
	assert(PlayerSide.is_valid(player_side))
	position = PongField.get_half_center(player_side)
	velocity = Vector2.ZERO
	_reset_hit_shake()
	if is_instance_valid(skill_trail):
		skill_trail.clear()
	clamp_to_playfield()


func move(delta: float) -> void:
	move_with_input(delta, get_move_direction())


func move_with_input(delta: float, direction: Vector2) -> void:
	var previous_position := position
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
	_update_hit_shake(delta)


func set_network_controlled(enabled: bool) -> void:
	_network_controlled = enabled
	_network_has_target = false
	_network_snap_pending = false
	set_process(enabled)


func apply_network_state(state: Dictionary, snap: bool) -> void:
	_network_target_position = state.get("position", position)
	_network_target_velocity = state.get("velocity", Vector2.ZERO)
	_skill_time_remaining = float(state.get("skill_time_remaining", 0.0))
	_skill_cooldown_remaining = float(state.get("skill_cooldown_remaining", 0.0))
	_hit_shake_time_remaining = float(state.get("hit_shake_time_remaining", 0.0))
	_hit_shake_phase = float(state.get("hit_shake_phase", 0.0))
	if snap or not _network_has_target:
		position = _network_target_position
		_network_snap_pending = true
	_network_has_target = true


func get_network_state() -> Dictionary:
	return {
		"position": position,
		"velocity": velocity,
		"skill_time_remaining": _skill_time_remaining,
		"skill_cooldown_remaining": _skill_cooldown_remaining,
		"hit_shake_time_remaining": _hit_shake_time_remaining,
		"hit_shake_phase": _hit_shake_phase,
	}


func get_velocity() -> Vector2:
	return velocity


func get_side() -> int:
	return player_side


func play_hit_feedback() -> void:
	_hit_shake_time_remaining = hit_shake_duration
	_hit_shake_phase = 0.0


func get_ball_anchor(ball_size: Vector2) -> Vector2:
	assert(PlayerSide.is_valid(player_side))
	var offset_x := (paddle_size.x + ball_size.x) * 0.5
	return position + Vector2(
		PlayerSide.direction_toward_opponent(player_side) * offset_x,
		0.0
	)


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


func _apply_character(character: CharacterDef) -> void:
	body_color = character.body_color
	paddle_size = character.paddle_size
	skill_speed_multiplier = character.skill_speed_multiplier
	skill_duration = character.skill_duration
	skill_cooldown = character.skill_cooldown
	update_visual()


func _configure_bounds() -> void:
	var half_size := paddle_size * 0.5
	if player_side == PlayerSide.PLAYER_1:
		min_center_x = half_size.x
		max_center_x = PongField.CENTER_X - half_size.x
	else:
		min_center_x = PongField.CENTER_X + half_size.x
		max_center_x = PongField.SIZE.x - half_size.x


func _update_skill_timers(delta: float) -> void:
	_skill_time_remaining = maxf(_skill_time_remaining - delta, 0.0)
	_skill_cooldown_remaining = maxf(_skill_cooldown_remaining - delta, 0.0)
	if is_zero_approx(_skill_time_remaining):
		_skill_time_remaining = 0.0
	if is_zero_approx(_skill_cooldown_remaining):
		_skill_cooldown_remaining = 0.0


func _update_hit_shake(delta: float) -> void:
	if not is_instance_valid(visual):
		return

	var base_position := -paddle_size * 0.5
	if _hit_shake_time_remaining <= 0.0:
		visual.position = base_position
		return

	_hit_shake_time_remaining = maxf(_hit_shake_time_remaining - delta, 0.0)
	var duration := maxf(hit_shake_duration, 0.001)
	var strength_ratio := _hit_shake_time_remaining / duration
	_hit_shake_phase += delta * hit_shake_frequency * TAU
	var shake_offset := Vector2(
		sin(_hit_shake_phase),
		sin(_hit_shake_phase * 0.73 + PI)
	) * hit_shake_strength * strength_ratio
	visual.position = base_position + shake_offset


func _reset_hit_shake() -> void:
	_hit_shake_time_remaining = 0.0
	_hit_shake_phase = 0.0
	if is_instance_valid(visual):
		visual.position = -paddle_size * 0.5


func update_visual() -> void:
	if not is_instance_valid(visual):
		return

	visual.position = -paddle_size * 0.5
	visual.size = paddle_size
	visual.color = body_color
