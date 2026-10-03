extends Node2D
class_name PongGame


const PLAYFIELD_SIZE := PongField.SIZE
const HIT_EFFECT_SCENE := preload("res://scenes/game/hit_effect.tscn")
const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select/mode_select.tscn"

@onready var background: PongBackground = $Background
@onready var divider: PongDivider = $Divider
@onready var scoreboard: PongScoreboard = $Scoreboard
@onready var player1: PongPlayer = $Player1
@onready var player2: PongPlayer = $Player2
@onready var ball: PongBall = $Ball
@onready var effects: Node2D = $Effects

var serving_side := PlayerSide.PLAYER_1

var _online := false
var _is_host := false
var _remote_direction := Vector2.ZERO
var _round_id := 0
var _network_tick := 0
var _last_network_tick := -1
var _last_received_round_id := -1
var _session_ending := false


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

	_online = GameSession.is_online()
	_is_host = _online and multiplayer.is_server()
	if _online:
		NetworkManager.session_ended.connect(_on_session_ended)
		if not _is_host:
			player1.set_network_controlled(true)
			player2.set_network_controlled(true)
			ball.set_network_controlled(true)

	reset_game()


func _physics_process(delta: float) -> void:
	if _online:
		if _is_host:
			_simulate_online_host(delta)
		else:
			_send_online_input()
		return

	_simulate_ball(delta, true)


func _simulate_online_host(delta: float) -> void:
	if not NetworkManager.is_online() or NetworkManager.get_connected_peer_id() == 0:
		return

	player1.move_with_input(delta, _get_local_online_direction())
	player2.move_with_input(delta, _remote_direction)
	_simulate_ball(delta, false)
	_broadcast_game_state()


func _simulate_ball(delta: float, move_players: bool) -> void:
	if move_players:
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

	if _online:
		if _event_matches_key(key_event, KEY_J):
			if _is_host:
				_handle_player_action(PlayerSide.PLAYER_1)
			else:
				rpc_id(1, "_receive_online_action")
			get_viewport().set_input_as_handled()
		return

	if _is_player_action_key(key_event, PlayerSide.PLAYER_1):
		_handle_player_action(PlayerSide.PLAYER_1)
		get_viewport().set_input_as_handled()
	elif _is_player_action_key(key_event, PlayerSide.PLAYER_2):
		_handle_player_action(PlayerSide.PLAYER_2)
		get_viewport().set_input_as_handled()


func _send_online_input() -> void:
	if NetworkManager.get_connected_peer_id() == 0:
		return
	rpc_id(1, "_receive_online_input", _get_local_online_direction())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_online_input(direction: Vector2) -> void:
	if not _is_host:
		return
	if multiplayer.get_remote_sender_id() != NetworkManager.get_connected_peer_id():
		return
	_remote_direction = direction.limit_length(1.0)


@rpc("any_peer", "call_remote", "reliable")
func _receive_online_action() -> void:
	if not _is_host:
		return
	if multiplayer.get_remote_sender_id() != NetworkManager.get_connected_peer_id():
		return
	_handle_player_action(PlayerSide.PLAYER_2)


func _get_local_online_direction() -> Vector2:
	return Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)


func _broadcast_game_state() -> void:
	_network_tick += 1
	rpc("_receive_game_state", {
		"tick": _network_tick,
		"round_id": _round_id,
		"serving_side": serving_side,
		"player1": player1.get_network_state(),
		"player2": player2.get_network_state(),
		"ball": ball.get_network_state(),
		"score1": scoreboard.get_player1_score(),
		"score2": scoreboard.get_player2_score(),
	})


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_game_state(state: Dictionary) -> void:
	if _is_host:
		return

	var tick := int(state.get("tick", -1))
	if tick <= _last_network_tick:
		return
	_last_network_tick = tick

	var received_round_id := int(state.get("round_id", 0))
	var snap := _last_received_round_id < 0 or received_round_id != _last_received_round_id
	_last_received_round_id = received_round_id

	serving_side = int(state.get("serving_side", PlayerSide.PLAYER_1))
	player1.apply_network_state(state.get("player1", {}), snap)
	player2.apply_network_state(state.get("player2", {}), snap)
	ball.apply_network_state(state.get("ball", {}), snap)
	scoreboard.set_scores(int(state.get("score1", 0)), int(state.get("score2", 0)))


func _is_player_action_key(event: InputEventKey, side: int) -> bool:
	if side == PlayerSide.PLAYER_1:
		return _event_matches_key(event, KEY_J)

	return _event_matches_key(event, KEY_KP_1)


func _event_matches_key(event: InputEventKey, keycode: Key) -> bool:
	return event.keycode == keycode or event.physical_keycode == keycode


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
	_round_id += 1
	player1.reset_for_round()
	player2.reset_for_round()
	position_ball_on_server()


func position_ball_on_server() -> void:
	var server := player1 if serving_side == PlayerSide.PLAYER_1 else player2
	ball.attach_to_player(server)


func _on_ball_out_of_bounds(exit_side: int) -> void:
	if _online and not _is_host:
		return
	award_point_and_start_round(PlayerSide.opponent(exit_side))


func _on_player_area_boundary_reached(loser_side: int) -> void:
	if _online and not _is_host:
		return
	award_point_and_start_round(PlayerSide.opponent(loser_side))


func _on_ball_double_hit(loser_side: int) -> void:
	if _online and not _is_host:
		return
	award_point_and_start_round(PlayerSide.opponent(loser_side))


func _on_ball_paddle_contact(
	player_side: int,
	contact_position: Vector2,
	surface_normal: Vector2
) -> void:
	if _online and not _is_host:
		return

	_play_hit_feedback(player_side, contact_position, surface_normal, ball.get_last_hitter_color())
	if _is_host:
		rpc(
			"_receive_hit_feedback",
			player_side,
			contact_position,
			surface_normal,
			ball.get_last_hitter_color()
		)


@rpc("authority", "call_remote", "reliable")
func _receive_hit_feedback(
	player_side: int,
	contact_position: Vector2,
	surface_normal: Vector2,
	contact_color: Color
) -> void:
	if _is_host:
		return
	_play_hit_feedback(player_side, contact_position, surface_normal, contact_color)


func _play_hit_feedback(
	player_side: int,
	contact_position: Vector2,
	surface_normal: Vector2,
	contact_color: Color
) -> void:
	var player := player1 if player_side == PlayerSide.PLAYER_1 else player2
	player.play_hit_feedback()

	var effect: PongHitEffect = HIT_EFFECT_SCENE.instantiate()
	effects.add_child(effect)
	effect.play(contact_position, contact_color, surface_normal)


func award_point_and_start_round(winner_side: int) -> void:
	assert(PlayerSide.is_valid(winner_side))
	scoreboard.add_point(winner_side)
	start_round(winner_side)


func _on_session_ended(_message: String) -> void:
	if _session_ending:
		return
	_session_ending = true
	set_physics_process(false)
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)
