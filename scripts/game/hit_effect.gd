extends Node2D
class_name PongHitEffect


@onready var particles: CPUParticles2D = $Particles


func play(
	contact_position: Vector2,
	contact_color: Color,
	surface_normal: Vector2
) -> void:
	global_position = contact_position
	particles.direction = surface_normal.normalized()
	particles.color = contact_color
	particles.emitting = true

	await get_tree().create_timer(particles.lifetime + 0.15).timeout
	queue_free()
