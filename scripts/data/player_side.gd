class_name PlayerSide

const NONE := 0
const PLAYER_1 := -1
const PLAYER_2 := 1


static func is_valid(side: int) -> bool:
	return side == PLAYER_1 or side == PLAYER_2


static func opponent(side: int) -> int:
	assert(is_valid(side))
	return PLAYER_2 if side == PLAYER_1 else PLAYER_1


static func direction_toward_opponent(side: int) -> float:
	return float(opponent(side))


static func from_index(index: int) -> int:
	assert(index == 0 or index == 1)
	return PLAYER_1 if index == 0 else PLAYER_2


static func to_index(side: int) -> int:
	assert(is_valid(side))
	return 0 if side == PLAYER_1 else 1
