extends Resource
class_name CharacterDef


@export var id: StringName = &""
@export var display_name: String = ""
@export var body_color: Color = Color.WHITE
@export var skill_speed_multiplier := 1.0
@export var skill_duration := 0.0
@export var skill_cooldown := 0.0


func has_active_skill() -> bool:
	return skill_speed_multiplier > 1.0 and skill_duration > 0.0 and skill_cooldown > 0.0
