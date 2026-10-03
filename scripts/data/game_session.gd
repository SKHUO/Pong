extends Node

enum Mode {
	OFFLINE,
	ONLINE,
}

var mode := Mode.OFFLINE
var local_side := PlayerSide.PLAYER_1

var _character_ids: Array[StringName] = [
	CharacterLibrary.DEFAULT_ID,
	CharacterLibrary.DEFAULT_ID,
]


func set_offline_mode() -> void:
	mode = Mode.OFFLINE
	local_side = PlayerSide.PLAYER_1


func set_online_mode(side: int) -> void:
	assert(PlayerSide.is_valid(side))
	mode = Mode.ONLINE
	local_side = side


func is_online() -> bool:
	return mode == Mode.ONLINE


func get_local_side() -> int:
	return local_side


func set_characters(player1_id: StringName, player2_id: StringName) -> void:
	_character_ids[PlayerSide.to_index(PlayerSide.PLAYER_1)] = player1_id
	_character_ids[PlayerSide.to_index(PlayerSide.PLAYER_2)] = player2_id


func set_character_id(side: int, character_id: StringName) -> void:
	_character_ids[PlayerSide.to_index(side)] = character_id


func get_character_id(side: int) -> StringName:
	return _character_ids[PlayerSide.to_index(side)]
