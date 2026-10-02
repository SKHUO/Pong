class_name PongField

const SIZE := Vector2(1800.0, 720.0)
const CENTER_X := SIZE.x * 0.5
const LEFT_HALF_CENTER := Vector2(SIZE.x * 0.25, SIZE.y * 0.5)
const RIGHT_HALF_CENTER := Vector2(SIZE.x * 0.75, SIZE.y * 0.5)


static func get_half_center(side: int) -> Vector2:
	assert(PlayerSide.is_valid(side))
	return LEFT_HALF_CENTER if side == PlayerSide.PLAYER_1 else RIGHT_HALF_CENTER
