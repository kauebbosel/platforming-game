# entities/enemies/states/dead.gd
extends EnemyState
## Morte do inimigo: solta uma nuvem de pedaços, fica parado e cinza e vai sumindo aos poucos
## durante `death_linger`; depois é removido.

var _time_left: float = 0.0
var _total: float = 1.0


func enter() -> void:
	_time_left = enemy.data.death_linger
	_total = maxf(0.01, _time_left)
	enemy.velocity.x = 0.0
	enemy.sprite.modulate = Color(0.45, 0.45, 0.45)
	DeathPuff.spawn(enemy.get_parent(), enemy.global_position + Vector2(0.0, -12.0), 2.0 if enemy.data.max_health >= 100 else 1.0)
	# O corpo deixa de ser alvo. Adiado: a morte acontece dentro de um callback de física.
	enemy.hurtbox.set_deferred("monitorable", false)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_and_slide()
	_time_left -= delta
	# Some aos poucos: nos primeiros 40% do tempo fica inteiro, depois vai sumindo.
	var fade: float = clampf(_time_left / (_total * 0.6), 0.0, 1.0)
	enemy.sprite.modulate = Color(0.45, 0.45, 0.45, fade)
	if _time_left <= 0.0:
		enemy.queue_free()
