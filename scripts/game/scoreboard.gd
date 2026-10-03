extends Node2D
class_name PongScoreboard


const LABEL_SIZE := Vector2(96.0, 96.0)
const TOP_MARGIN := 16.0
const CENTER_GAP := 24.0

@onready var player1_label: Label = $Player1Score
@onready var player2_label: Label = $Player2Score

var _player1_score := 0
var _player2_score := 0


func configure(playfield_size: Vector2) -> void:
	player1_label.add_theme_color_override("font_color", PongPalette.SCORE)
	player2_label.add_theme_color_override("font_color", PongPalette.SCORE)

	var center_x := playfield_size.x * 0.5
	player1_label.size = LABEL_SIZE
	player2_label.size = LABEL_SIZE
	player1_label.position = Vector2(center_x - CENTER_GAP * 0.5 - LABEL_SIZE.x, TOP_MARGIN)
	player2_label.position = Vector2(center_x + CENTER_GAP * 0.5, TOP_MARGIN)
	update_visuals()


func reset_scores() -> void:
	_player1_score = 0
	_player2_score = 0
	update_visuals()


func add_point(player_side: int) -> void:
	assert(PlayerSide.is_valid(player_side))
	if player_side == PlayerSide.PLAYER_1:
		_player1_score += 1
	else:
		_player2_score += 1
	update_visuals()


func set_scores(player1_score: int, player2_score: int) -> void:
	_player1_score = maxi(player1_score, 0)
	_player2_score = maxi(player2_score, 0)
	update_visuals()


func get_player1_score() -> int:
	return _player1_score


func get_player2_score() -> int:
	return _player2_score


func update_visuals() -> void:
	player1_label.text = str(_player1_score)
	player2_label.text = str(_player2_score)
