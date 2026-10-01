extends Node


var _character_ids: Array[StringName] = [
	CharacterLibrary.DEFAULT_ID,
	CharacterLibrary.DEFAULT_ID,
]


func set_characters(player1_id: StringName, player2_id: StringName) -> void:
	_character_ids[0] = player1_id
	_character_ids[1] = player2_id


func get_character(player_index: int) -> CharacterDef:
	var index := clampi(player_index, 0, _character_ids.size() - 1)
	return CharacterLibrary.get_by_id(_character_ids[index])
