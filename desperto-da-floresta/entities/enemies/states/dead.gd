# entities/enemies/states/dead.gd
extends EnemyState
## Morte do inimigo: fica parado e cinza por `death_linger` e some.

var _time_left: float = 0.0


func enter() -> void:
	_time_left = enemy.data.death_linger
	enemy.velocity.x = 0.0
	enemy.sprite.modulate = Color(0.45, 0.45, 0.45)
	# O corpo deixa de ser alvo. Adiado: a morte acontece dentro de um callback de física.
	enemy.hurtbox.set_deferred("monitorable", false)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_and_slide()
	_time_left -= delta
	if _time_left <= 0.0:
		enemy.queue_free()
