extends Node2D
class_name CharacterSelect


const PLAYFIELD_SIZE := Vector2(1152.0, 648.0)
const BACKGROUND_COLOR := Color.BLACK
const GAME_SCENE_PATH := "res://scenes/game/game.tscn"
const CHARACTER_OPTION_SCENE := preload("res://scenes/character_select/character_option.tscn")
const GRID_COLUMNS := 2
const OPTION_SIZE := Vector2(88.0, 88.0)
const OPTION_GAP := 32.0
const FOOTER_HEIGHT := 64.0
const PLAYER_COLORS := [Color(0.2, 0.55, 1.0), Color(0.2, 0.9, 0.4)]

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


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	background.configure(PLAYFIELD_SIZE)
	divider.configure(PLAYFIELD_SIZE)
	_layout_footer()

	_characters = CharacterLibrary.get_all()
	for side in area_nodes.size():
		_setup_area(side)
	_refresh_selection()


func _unhandled_input(event: InputEvent) -> void:
	if _starting or not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_W:
			_move_selection(0, Vector2i(0, -1))
		KEY_S:
			_move_selection(0, Vector2i(0, 1))
		KEY_A:
			_move_selection(0, Vector2i(-1, 0))
		KEY_D:
			_move_selection(0, Vector2i(1, 0))
		KEY_UP:
			_move_selection(1, Vector2i(0, -1))
		KEY_DOWN:
			_move_selection(1, Vector2i(0, 1))
		KEY_LEFT:
			_move_selection(1, Vector2i(-1, 0))
		KEY_RIGHT:
			_move_selection(1, Vector2i(1, 0))
		KEY_SPACE:
			_start_game()


func _setup_area(side: int) -> void:
	var area := area_nodes[side]
	var frame := frame_nodes[side]
	var player_color: Color = PLAYER_COLORS[side]

	area.get_node("Title").add_theme_color_override("font_color", player_color)
	area.get_node("KeyHint").add_theme_color_override("font_color", player_color.darkened(0.2))
	frame.set_frame_color(player_color)

	var options_holder: Node2D = area.get_node("Options")
	var side_options := []
	for index in _characters.size():
		var option: CharacterOption = CHARACTER_OPTION_SCENE.instantiate()
		options_holder.add_child(option)
		option.option_size = OPTION_SIZE
		option.position = _option_position(side, index)
		option.setup(_characters[index])
		side_options.append(option)
	_option_nodes.append(side_options)


func _option_position(side: int, index: int) -> Vector2:
	var grid_size := Vector2(
		GRID_COLUMNS * OPTION_SIZE.x + (GRID_COLUMNS - 1) * OPTION_GAP,
		_grid_rows() * OPTION_SIZE.y + (_grid_rows() - 1) * OPTION_GAP
	)
	var side_center := Vector2(
		PLAYFIELD_SIZE.x * 0.5 * (float(side) + 0.5),
		PLAYFIELD_SIZE.y * 0.5
	)
	var column := index % GRID_COLUMNS
	var row := floori(float(index) / float(GRID_COLUMNS))

	return side_center - grid_size * 0.5 + Vector2(
		column * (OPTION_SIZE.x + OPTION_GAP),
		row * (OPTION_SIZE.y + OPTION_GAP)
	) + OPTION_SIZE * 0.5


func _grid_rows() -> int:
	return ceili(float(_characters.size()) / float(GRID_COLUMNS))


func _move_selection(side: int, direction: Vector2i) -> void:
	var index: int = _selected_indices[side]
	var row := floori(float(index) / float(GRID_COLUMNS))
	var target_row := row + direction.y
	if target_row < 0 or target_row >= _grid_rows():
		return

	var first_index := target_row * GRID_COLUMNS
	var last_index := mini(first_index + GRID_COLUMNS, _characters.size()) - 1
	var target_index := clampi(first_index + index % GRID_COLUMNS + direction.x, first_index, last_index)
	if target_index == index:
		return

	_selected_indices[side] = target_index
	_refresh_selection()


func _refresh_selection() -> void:
	for side in _option_nodes.size():
		var option: CharacterOption = _option_nodes[side][_selected_indices[side]]
		frame_nodes[side].wrap(option.get_rect())


func _start_game() -> void:
	_starting = true
	GameSession.set_characters(
		_characters[_selected_indices[0]].id,
		_characters[_selected_indices[1]].id
	)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _layout_footer() -> void:
	footer_bar.position = Vector2(0.0, PLAYFIELD_SIZE.y - FOOTER_HEIGHT)
	footer_bar.size = Vector2(PLAYFIELD_SIZE.x, FOOTER_HEIGHT)
	hint.position = footer_bar.position
	hint.size = footer_bar.size
