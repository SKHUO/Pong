class_name CharacterLibrary


const DEFAULT_ID := &"white"

static var _characters: Array[CharacterDef] = []


static func get_all() -> Array[CharacterDef]:
	if _characters.is_empty():
		_characters = [
			_build(&"white", "白色角色", Color(1.0, 1.0, 1.0)),
			_build(&"red", "红色角色", Color(0.9, 0.2, 0.2)),
		]
	return _characters


static func get_by_id(id: StringName) -> CharacterDef:
	for character in get_all():
		if character.id == id:
			return character
	return get_all()[0]


static func _build(id: StringName, display_name: String, body_color: Color) -> CharacterDef:
	var character := CharacterDef.new()
	character.id = id
	character.display_name = display_name
	character.body_color = body_color
	return character
