extends Node2D
class_name PongGame


const PLAYFIELD_SIZE := Vector2(1280.0, 720.0)
const BACKGROUND_COLOR := Color.BLACK
const PADDLE_OFFSET_FROM_CENTER := 170.0
const PLAYER_1_SIDE := -1
const PLAYER_2_SIDE := 1

@onready var background: PongBackground = $Background
@onready var divider: PongDivider = $Divider
@onready var player1: PongPlayer = $Player1
@onready var player2: PongPlayer = $Player2
@onready var ball: PongBall = $Ball

var serving_side := PLAYER_1_SIDE


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	background.configure(PLAYFIELD_SIZE)
	divider.configure(PLAYFIELD_SIZE)

	var divider_rect := divider.get_playfield_rect()
	player1.configure(PLAYFIELD_SIZE, PLAYER_1_SIDE, divider_rect)
	player2.configure(PLAYFIELD_SIZE, PLAYER_2_SIDE, divider_rect)
	player1.apply_character(GameSession.get_character(0))
	player2.apply_character(GameSession.get_character(1))
	ball.configure(PLAYFIELD_SIZE)
	ball.out_of_bounds.connect(_on_ball_out_of_bounds)
	reset_game()


func _physics_process(delta: float) -> void:
	player1.move(delta)
	player2.move(delta)

	if ball.is_attached():
		position_ball_on_server()
	else:
		ball.move(delta, player1.get_rect(), player2.get_rect())


func _unhandled_input(event: InputEvent) -> void:
	if not ball.is_attached() or not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var can_serve := (
		serving_side == PLAYER_1_SIDE
		and (key_event.keycode == KEY_J or key_event.physical_keycode == KEY_J)
	) or (
		serving_side == PLAYER_2_SIDE
		and (key_event.keycode == KEY_KP_1 or key_event.physical_keycode == KEY_KP_1)
	)

	if can_serve:
		ball.serve(-serving_side)
		get_viewport().set_input_as_handled()


func reset_game() -> void:
	start_round(PLAYER_1_SIDE)


func start_round(server_side: int) -> void:
	serving_side = server_side
	var center := PLAYFIELD_SIZE * 0.5
	player1.reset_to(center + Vector2(-PADDLE_OFFSET_FROM_CENTER, 0.0))
	player2.reset_to(center + Vector2(PADDLE_OFFSET_FROM_CENTER, 0.0))
	position_ball_on_server()


func position_ball_on_server() -> void:
	var server := player1 if serving_side == PLAYER_1_SIDE else player2
	var toward_opponent := float(-serving_side)
	var offset_x := (server.paddle_size.x + ball.ball_size.x) * 0.5
	ball.attach_to(server.position + Vector2(toward_opponent * offset_x, 0.0))


func _on_ball_out_of_bounds(exit_side: int) -> void:
	var winner_side := -exit_side
	start_round(winner_side)
