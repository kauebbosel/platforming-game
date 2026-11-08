# entities/enemies/states/chase.gd
extends EnemyState
## Anda em linha reta até o Valtair, sem flanquear. Ao chegar no alcance, para e ataca
## (se o cooldown deixar). Uma vez que percebeu, só desiste se o Valtair morrer.

## Perto demais do centro do alvo, não troca o lado (evita ficar virando).
const FACING_DEADZONE: float = 2.0


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)

	if not enemy.is_target_alive():
		state_machine.transition_to("idle")
		return

	var offset: Vector2 = enemy.get_target().global_position - enemy.global_position
	if absf(offset.x) > FACING_DEADZONE:
		enemy.set_facing(1 if offset.x > 0.0 else -1)

	if absf(offset.x) <= enemy.data.attack_range:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)
		var level: bool = absf(offset.y) <= enemy.data.attack_vertical_range
		if level and enemy.attack_cooldown_left <= 0.0:
			state_machine.transition_to("attack")
			return
	else:
		enemy.velocity.x = enemy.facing * enemy.data.move_speed

	enemy.move_and_slide()
