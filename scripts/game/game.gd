extends Node2D
class_name PongGame


const PLAYFIELD_SIZE := Vector2(1280.0, 720.0)
const BACKGROUND_COLOR := Color.BLACK
const PADDLE_OFFSET_FROM_CENTER := 170.0

@onready var background: PongBackground = $Background
@onready var divider: PongDivider = $Divider
@onready var player1: PongPlayer = $Player1
@onready var player2: PongPlayer = $Player2
@onready var ball: PongBall = $Ball


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	background.configure(PLAYFIELD_SIZE)
	divider.configure(PLAYFIELD_SIZE)

	var divider_rect := divider.get_playfield_rect()
	player1.configure(PLAYFIELD_SIZE, -1, divider_rect)
	player2.configure(PLAYFIELD_SIZE, 1, divider_rect)
	player1.apply_character(GameSession.get_character(0))
	player2.apply_character(GameSession.get_character(1))
	ball.configure(PLAYFIELD_SIZE)
	ball.out_of_bounds.connect(_on_ball_out_of_bounds)
	reset_game()


func _physics_process(delta: float) -> void:
	player1.move(delta)
	player2.move(delta)
	ball.move(delta, player1.get_rect(), player2.get_rect())


func reset_game() -> void:
	var center := PLAYFIELD_SIZE * 0.5
	player1.reset_to(center + Vector2(-PADDLE_OFFSET_FROM_CENTER, 0.0))
	player2.reset_to(center + Vector2(PADDLE_OFFSET_FROM_CENTER, 0.0))

	var serve_origin := player1.position + Vector2(
		player1.paddle_size.x * 0.5 + ball.ball_size.x * 0.5 + 2.0,
		0.0
	)
	ball.serve(serve_origin)


func _on_ball_out_of_bounds() -> void:
	reset_game()
