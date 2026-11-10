# entities/enemies/states/idle.gd
extends EnemyState
## Parado até perceber o Valtair.


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)
	enemy.move_and_slide()
	if enemy.can_see_target():
		state_machine.transition_to("chase")
