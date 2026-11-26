# entities/effects/death_puff.gd
class_name DeathPuff
extends CPUParticles2D
## Pequena nuvem de pedaços quando um inimigo morre. Não usa arte: são quadradinhos de 2 a 3 px.
## Some sozinha. Uso: DeathPuff.spawn(parent, posição_global, tamanho)  (tamanho 1.0 = normal).

const LIFETIME: float = 0.5


static func spawn(parent: Node, at: Vector2, size: float = 1.0) -> void:
	if parent == null:
		return
	var puff: DeathPuff = DeathPuff.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = int(12 * size)
	puff.lifetime = LIFETIME
	puff.explosiveness = 0.95
	puff.direction = Vector2(0, -1)
	puff.spread = 180.0
	puff.initial_velocity_min = 30.0 * size
	puff.initial_velocity_max = 80.0 * size
	puff.gravity = Vector2(0, 140)
	puff.scale_amount_min = 2.0
	puff.scale_amount_max = 3.0
	puff.z_index = 20
	var fade: Gradient = Gradient.new()
	fade.colors = PackedColorArray([Color(0.95, 0.9, 0.75, 1.0), Color(0.6, 0.55, 0.5, 0.0)])
	puff.color_ramp = fade
	parent.add_child(puff)
	puff.global_position = at
	puff.restart()
	puff.emitting = true
	puff.get_tree().create_timer(LIFETIME + 0.3).timeout.connect(func() -> void:
		if is_instance_valid(puff):
			puff.queue_free()
	)
