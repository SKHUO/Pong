extends Node


var _character_ids: Array[StringName] = [
	CharacterLibrary.DEFAULT_ID,
	CharacterLibrary.DEFAULT_ID,
]


func set_characters(player1_id: StringName, player2_id: StringName) -> void:
	_character_ids[PlayerSide.to_index(PlayerSide.PLAYER_1)] = player1_id
	_character_ids[PlayerSide.to_index(PlayerSide.PLAYER_2)] = player2_id


func get_character_id(side: int) -> StringName:
	return _character_ids[PlayerSide.to_index(side)]
