class_name PongPalette

const BACKGROUND := Color(0.0, 0.0, 0.0, 1.0)
const DIVIDER := Color(1.0, 1.0, 1.0, 1.0)
const SCORE := Color(1.0, 1.0, 1.0, 1.0)
const NEUTRAL := Color(1.0, 1.0, 1.0, 1.0)
const PLAYER_1 := Color(
	108.0 / 255.0,
	166.0 / 255.0,
	217.0 / 255.0,
	1.0
)
const PLAYER_2 := Color(
	103.0 / 255.0,
	199.0 / 255.0,
	149.0 / 255.0,
	1.0
)


static func get_player_color(side: int) -> Color:
	if side == PlayerSide.PLAYER_1:
		return PLAYER_1
	if side == PlayerSide.PLAYER_2:
		return PLAYER_2
	return NEUTRAL
