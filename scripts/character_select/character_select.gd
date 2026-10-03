extends Node2D
class_name CharacterSelect


const PLAYFIELD_SIZE := PongField.SIZE
const GAME_SCENE_PATH := "res://scenes/game/game.tscn"
const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select/mode_select.tscn"
const CHARACTER_OPTION_SCENE := preload("res://scenes/character_select/character_option.tscn")
const GRID_COLUMNS := 2
const OPTION_SIZE := Vector2(88.0, 88.0)
const OPTION_GAP := 32.0
const FOOTER_HEIGHT := 64.0

@onready var background: PongBackground = $Background
@onready var divider: PongDivider = $Divider
@onready var footer_bar: ColorRect = $FooterBar
@onready var hint: Label = $Hint
@onready var area_nodes: Array[Node2D] = [$Player1Area, $Player2Area]
@onready var frame_nodes: Array[SelectionFrame] = [$Player1Area/Frame, $Player2Area/Frame]

var _characters: Array[CharacterDef] = []
var _option_nodes: Array = []
var _selected_indices := [0, 0]
var _starting := false
var _online := false
var _local_player_index := 0
var _online_ready := [false, false]
var _online_character_ids: Array[StringName] = [
	CharacterLibrary.DEFAULT_ID,
	CharacterLibrary.DEFAULT_ID,
]


func _ready() -> void:
	RenderingServer.set_default_clear_color(PongPalette.BACKGROUND)
	background.configure(PLAYFIELD_SIZE)
	divider.configure(PLAYFIELD_SIZE)
	_layout_footer()

	_characters = CharacterLibrary.get_all()
	_online = GameSession.is_online()
	if _online:
		_local_player_index = PlayerSide.to_index(GameSession.get_local_side())
		_online_character_ids[0] = GameSession.get_character_id(PlayerSide.PLAYER_1)
		_online_character_ids[1] = GameSession.get_character_id(PlayerSide.PLAYER_2)
		_selected_indices[0] = _find_character_index(_online_character_ids[0])
		_selected_indices[1] = _find_character_index(_online_character_ids[1])
		NetworkManager.session_ended.connect(_on_session_ended)

	for area_index in area_nodes.size():
		_setup_area(area_index)
	if _online:
		_configure_online_ui()
		_submit_online_selection()
	_refresh_selection()


func _unhandled_input(event: InputEvent) -> void:
	if _starting or not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key_event := event as InputEventKey
	if _online:
		_handle_online_input(key_event)
		return

	if _event_matches_key(key_event, KEY_W):
		_move_selection(0, Vector2i(0, -1))
	elif _event_matches_key(key_event, KEY_S):
		_move_selection(0, Vector2i(0, 1))
	elif _event_matches_key(key_event, KEY_A):
		_move_selection(0, Vector2i(-1, 0))
	elif _event_matches_key(key_event, KEY_D):
		_move_selection(0, Vector2i(1, 0))
	elif _event_matches_key(key_event, KEY_UP):
		_move_selection(1, Vector2i(0, -1))
	elif _event_matches_key(key_event, KEY_DOWN):
		_move_selection(1, Vector2i(0, 1))
	elif _event_matches_key(key_event, KEY_LEFT):
		_move_selection(1, Vector2i(-1, 0))
	elif _event_matches_key(key_event, KEY_RIGHT):
		_move_selection(1, Vector2i(1, 0))
	elif _event_matches_key(key_event, KEY_SPACE):
		_start_game()


func _handle_online_input(event: InputEventKey) -> void:
	var direction := Vector2i.ZERO
	if _event_matches_key(event, KEY_W):
		direction = Vector2i(0, -1)
	elif _event_matches_key(event, KEY_S):
		direction = Vector2i(0, 1)
	elif _event_matches_key(event, KEY_A):
		direction = Vector2i(-1, 0)
	elif _event_matches_key(event, KEY_D):
		direction = Vector2i(1, 0)
	elif _event_matches_key(event, KEY_J):
		_toggle_online_ready()
		get_viewport().set_input_as_handled()
		return

	if direction != Vector2i.ZERO and _move_selection(_local_player_index, direction):
		_online_ready[_local_player_index] = false
		_submit_online_selection()
		get_viewport().set_input_as_handled()


func _setup_area(area_index: int) -> void:
	var area := area_nodes[area_index]
	var frame := frame_nodes[area_index]
	var player_color := PongPalette.get_player_color(PlayerSide.from_index(area_index))

	area.get_node("Title").add_theme_color_override("font_color", player_color)
	area.get_node("KeyHint").add_theme_color_override("font_color", player_color.darkened(0.2))
	frame.set_frame_color(player_color)

	var options_holder: Node2D = area.get_node("Options")
	var area_options := []
	for index in _characters.size():
		var option: CharacterOption = CHARACTER_OPTION_SCENE.instantiate()
		options_holder.add_child(option)
		option.option_size = OPTION_SIZE
		option.position = _option_position(area_index, index)
		option.setup(_characters[index])
		area_options.append(option)
	_option_nodes.append(area_options)


func _option_position(area_index: int, index: int) -> Vector2:
	var grid_size := Vector2(
		GRID_COLUMNS * OPTION_SIZE.x + (GRID_COLUMNS - 1) * OPTION_GAP,
		_grid_rows() * OPTION_SIZE.y + (_grid_rows() - 1) * OPTION_GAP
	)
	var area_center := Vector2(
		PLAYFIELD_SIZE.x * 0.5 * (float(area_index) + 0.5),
		PLAYFIELD_SIZE.y * 0.5
	)
	var column := index % GRID_COLUMNS
	var row := floori(float(index) / float(GRID_COLUMNS))

	return area_center - grid_size * 0.5 + Vector2(
		column * (OPTION_SIZE.x + OPTION_GAP),
		row * (OPTION_SIZE.y + OPTION_GAP)
	) + OPTION_SIZE * 0.5


func _grid_rows() -> int:
	return ceili(float(_characters.size()) / float(GRID_COLUMNS))


func _move_selection(player_index: int, direction: Vector2i) -> bool:
	var index: int = _selected_indices[player_index]
	var row := floori(float(index) / float(GRID_COLUMNS))
	var target_row := row + direction.y
	if target_row < 0 or target_row >= _grid_rows():
		return false

	var first_index := target_row * GRID_COLUMNS
	var last_index := mini(first_index + GRID_COLUMNS, _characters.size()) - 1
	var target_index := clampi(first_index + index % GRID_COLUMNS + direction.x, first_index, last_index)
	if target_index == index:
		return false

	_selected_indices[player_index] = target_index
	_refresh_selection()
	return true


func _refresh_selection() -> void:
	for player_index in _option_nodes.size():
		var option: CharacterOption = _option_nodes[player_index][_selected_indices[player_index]]
		frame_nodes[player_index].wrap(option.get_rect())


func _configure_online_ui() -> void:
	var local_side := GameSession.get_local_side()
	var opponent_side := PlayerSide.opponent(local_side)
	area_nodes[_local_player_index].get_node("Title").text = "你 · PLAYER %d" % (PlayerSide.to_index(local_side) + 1)
	area_nodes[PlayerSide.to_index(opponent_side)].get_node("Title").text = "对手 · PLAYER %d" % (
		PlayerSide.to_index(opponent_side) + 1
	)
	for area in area_nodes:
		area.get_node("KeyHint").text = "WASD 选择 · J 准备"
	_refresh_online_hint()


func _refresh_online_hint() -> void:
	if _online_ready[_local_player_index]:
		hint.text = "已准备，等待对手"
	elif _online_ready[PlayerSide.to_index(PlayerSide.opponent(GameSession.get_local_side()))]:
		hint.text = "对手已准备 · 按 J 确认"
	else:
		hint.text = "WASD 选择 · J 准备"


func _toggle_online_ready() -> void:
	_online_ready[_local_player_index] = not _online_ready[_local_player_index]
	_submit_online_selection()


func _submit_online_selection() -> void:
	var side := GameSession.get_local_side()
	var character_id := _characters[_selected_indices[_local_player_index]].id
	_online_character_ids[_local_player_index] = character_id
	GameSession.set_character_id(side, character_id)
	var ready: bool = _online_ready[_local_player_index]

	if NetworkManager.is_host():
		_server_set_online_selection(side, character_id, ready)
	else:
		rpc_id(1, "_receive_online_selection_submission", String(character_id), ready)


@rpc("any_peer", "call_remote", "reliable")
func _receive_online_selection_submission(character_id: String, ready: bool) -> void:
	if not _online or not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != NetworkManager.get_connected_peer_id():
		return
	_server_set_online_selection(PlayerSide.PLAYER_2, StringName(character_id), ready)


func _server_set_online_selection(side: int, character_id: StringName, ready: bool) -> void:
	var player_index := PlayerSide.to_index(side)
	var resolved_character := CharacterLibrary.get_by_id(character_id)
	_online_character_ids[player_index] = resolved_character.id
	_online_ready[player_index] = ready
	GameSession.set_character_id(side, resolved_character.id)

	if _online_ready[0] and _online_ready[1]:
		_start_online_game()
		return

	_broadcast_online_selection()


func _broadcast_online_selection() -> void:
	rpc(
		"_receive_online_selection",
		String(_online_character_ids[0]),
		String(_online_character_ids[1]),
		_online_ready[0],
		_online_ready[1]
	)
	_refresh_online_hint()


@rpc("authority", "call_remote", "reliable")
func _receive_online_selection(
	player1_id: String,
	player2_id: String,
	player1_ready: bool,
	player2_ready: bool
) -> void:
	if NetworkManager.is_host():
		return
	_online_character_ids[0] = StringName(player1_id)
	_online_character_ids[1] = StringName(player2_id)
	_online_ready[0] = player1_ready
	_online_ready[1] = player2_ready
	_selected_indices[0] = _find_character_index(_online_character_ids[0])
	_selected_indices[1] = _find_character_index(_online_character_ids[1])
	GameSession.set_characters(_online_character_ids[0], _online_character_ids[1])
	_refresh_selection()
	_refresh_online_hint()


func _start_online_game() -> void:
	if _starting:
		return
	_starting = true
	GameSession.set_characters(_online_character_ids[0], _online_character_ids[1])
	rpc(
		"_receive_online_start",
		String(_online_character_ids[0]),
		String(_online_character_ids[1])
	)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


@rpc("authority", "call_remote", "reliable")
func _receive_online_start(player1_id: String, player2_id: String) -> void:
	if NetworkManager.is_host() or _starting:
		return
	_starting = true
	GameSession.set_characters(StringName(player1_id), StringName(player2_id))
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _start_game() -> void:
	_starting = true
	GameSession.set_characters(
		_characters[_selected_indices[0]].id,
		_characters[_selected_indices[1]].id
	)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _find_character_index(character_id: StringName) -> int:
	for index in _characters.size():
		if _characters[index].id == character_id:
			return index
	return 0


func _event_matches_key(event: InputEventKey, keycode: Key) -> bool:
	return event.keycode == keycode or event.physical_keycode == keycode


func _on_session_ended(_message: String) -> void:
	if _starting:
		return
	_starting = true
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


func _layout_footer() -> void:
	footer_bar.position = Vector2(0.0, PLAYFIELD_SIZE.y - FOOTER_HEIGHT)
	footer_bar.size = Vector2(PLAYFIELD_SIZE.x, FOOTER_HEIGHT)
	hint.position = footer_bar.position
	hint.size = footer_bar.size
