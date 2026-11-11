# entities/enemies/states/hurt.gd
extends EnemyState
## Reação ao dano: recua levemente e perde a ação em andamento (o Attack cancela o golpe
## ao sair). Voltar a perseguir é natural: quem apanha de longe também passa a perseguir.

const HURT_COLOR: Color = Color(1.0, 0.35, 0.35)

var _time_left: float = 0.0


func enter() -> void:
	_time_left = enemy.data.hurt_duration
	enemy.velocity = enemy.last_knockback * enemy.data.knockback_scale
	enemy.sprite.modulate = HURT_COLOR


func exit() -> void:
	enemy.sprite.modulate = Color.WHITE


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	if enemy.data.flying:
		enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.data.friction * delta)
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)
	enemy.move_and_slide()
	_time_left -= delta
	if _time_left <= 0.0:
		state_machine.transition_to("chase")
