extends Node2D
class_name PongGame


const PLAYFIELD_SIZE := PongField.SIZE
const HIT_EFFECT_SCENE := preload("res://scenes/game/hit_effect.tscn")

@onready var background: PongBackground = $Background
@onready var divider: PongDivider = $Divider
@onready var scoreboard: PongScoreboard = $Scoreboard
@onready var player1: PongPlayer = $Player1
@onready var player2: PongPlayer = $Player2
@onready var ball: PongBall = $Ball
@onready var effects: Node2D = $Effects

var serving_side := PlayerSide.PLAYER_1


func _ready() -> void:
	RenderingServer.set_default_clear_color(PongPalette.BACKGROUND)
	background.configure(PLAYFIELD_SIZE)
	divider.configure(PLAYFIELD_SIZE)
	scoreboard.configure(PLAYFIELD_SIZE)

	player1.setup(
		CharacterLibrary.get_by_id(GameSession.get_character_id(PlayerSide.PLAYER_1)),
		PlayerSide.PLAYER_1
	)
	player2.setup(
		CharacterLibrary.get_by_id(GameSession.get_character_id(PlayerSide.PLAYER_2)),
		PlayerSide.PLAYER_2
	)
	ball.configure(PLAYFIELD_SIZE)
	ball.out_of_bounds.connect(_on_ball_out_of_bounds)
	ball.area_boundary_reached.connect(_on_player_area_boundary_reached)
	ball.double_hit.connect(_on_ball_double_hit)
	ball.paddle_contact.connect(_on_ball_paddle_contact)
	reset_game()


func _physics_process(delta: float) -> void:
	player1.move(delta)
	player2.move(delta)

	if ball.is_attached():
		position_ball_on_server()
	else:
		ball.move(
			delta,
			player1.get_rect(),
			player2.get_rect(),
			player1.get_velocity(),
			player2.get_velocity()
		)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if _is_player_action_key(key_event, PlayerSide.PLAYER_1):
		_handle_player_action(PlayerSide.PLAYER_1)
		get_viewport().set_input_as_handled()
	elif _is_player_action_key(key_event, PlayerSide.PLAYER_2):
		_handle_player_action(PlayerSide.PLAYER_2)
		get_viewport().set_input_as_handled()


func _is_player_action_key(event: InputEventKey, side: int) -> bool:
	if side == PlayerSide.PLAYER_1:
		return event.keycode == KEY_J or event.physical_keycode == KEY_J

	return event.keycode == KEY_KP_1 or event.physical_keycode == KEY_KP_1


func _handle_player_action(side: int) -> void:
	var player := player1 if side == PlayerSide.PLAYER_1 else player2
	if ball.is_attached() and serving_side == side:
		ball.serve(side, player.get_velocity())
	else:
		player.try_activate_skill()


func reset_game() -> void:
	scoreboard.reset_scores()
	start_round(PlayerSide.PLAYER_1)


func start_round(server_side: int) -> void:
	assert(PlayerSide.is_valid(server_side))
	serving_side = server_side
	player1.reset_for_round()
	player2.reset_for_round()
	position_ball_on_server()


func position_ball_on_server() -> void:
	var server := player1 if serving_side == PlayerSide.PLAYER_1 else player2
	ball.attach_to_player(server)


func _on_ball_out_of_bounds(exit_side: int) -> void:
	award_point_and_start_round(PlayerSide.opponent(exit_side))


func _on_player_area_boundary_reached(loser_side: int) -> void:
	award_point_and_start_round(PlayerSide.opponent(loser_side))


func _on_ball_double_hit(loser_side: int) -> void:
	award_point_and_start_round(PlayerSide.opponent(loser_side))


func _on_ball_paddle_contact(
	player_side: int,
	contact_position: Vector2,
	surface_normal: Vector2
) -> void:
	var player := player1 if player_side == PlayerSide.PLAYER_1 else player2
	player.play_hit_feedback()

	var effect: PongHitEffect = HIT_EFFECT_SCENE.instantiate()
	effects.add_child(effect)
	effect.play(contact_position, ball.get_last_hitter_color(), surface_normal)


func award_point_and_start_round(winner_side: int) -> void:
	assert(PlayerSide.is_valid(winner_side))
	scoreboard.add_point(winner_side)
	start_round(winner_side)
