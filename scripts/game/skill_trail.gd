extends Node2D
class_name SkillTrail


@export_range(0.05, 1.0, 0.01) var afterimage_lifetime := 0.22
@export_range(0.01, 0.2, 0.005) var spawn_interval := 0.035
@export var min_spawn_distance := 6.0
@export_range(0.0, 1.0, 0.01) var initial_opacity := 0.48

var _afterimages: Array[Dictionary] = []
var _spawn_elapsed := 0.0
var _last_spawn_position := Vector2.ZERO
var _has_last_spawn_position := false
var _was_active := false


func update_trail(
	delta: float,
	is_active: bool,
	world_position: Vector2,
	color: Color,
	size: Vector2
) -> void:
	var changed := _advance(delta)

	if is_active and not _was_active:
		_spawn_elapsed = spawn_interval
		_last_spawn_position = world_position
		_has_last_spawn_position = true

	if is_active:
		_spawn_elapsed += delta
		var far_enough := (
			not _has_last_spawn_position
			or world_position.distance_squared_to(_last_spawn_position) >= min_spawn_distance * min_spawn_distance
		)
		if _spawn_elapsed >= spawn_interval and far_enough:
			_afterimages.append({
				"world_position": world_position,
				"color": color,
				"size": size,
				"age": 0.0,
			})
			_last_spawn_position = world_position
			_has_last_spawn_position = true
			_spawn_elapsed = 0.0
			changed = true

	_was_active = is_active
	if changed:
		queue_redraw()


func clear() -> void:
	_afterimages.clear()
	_spawn_elapsed = 0.0
	_has_last_spawn_position = false
	_was_active = false
	queue_redraw()


func get_afterimage_count() -> int:
	return _afterimages.size()


func _advance(delta: float) -> bool:
	var changed := false
	for index in range(_afterimages.size() - 1, -1, -1):
		_afterimages[index]["age"] = float(_afterimages[index]["age"]) + delta
		if float(_afterimages[index]["age"]) >= afterimage_lifetime:
			_afterimages.remove_at(index)
		changed = true
	return changed


func _draw() -> void:
	for afterimage in _afterimages:
		var age := float(afterimage["age"])
		var fade := pow(1.0 - clampf(age / afterimage_lifetime, 0.0, 1.0), 1.5)
		var afterimage_color: Color = afterimage["color"]
		var image_size: Vector2 = afterimage["size"]
		var image_center := to_local(afterimage["world_position"])
		var image_rect := Rect2(image_center - image_size * 0.5, image_size)
		var fill_color := Color(
			afterimage_color.r,
			afterimage_color.g,
			afterimage_color.b,
			initial_opacity * fade * 0.35
		)
		var edge_color := Color(
			afterimage_color.r,
			afterimage_color.g,
			afterimage_color.b,
			initial_opacity * fade
		)
		draw_rect(image_rect, fill_color, true)
		draw_rect(image_rect, edge_color, false, 1.0)
