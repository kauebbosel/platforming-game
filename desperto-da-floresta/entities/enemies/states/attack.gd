# entities/enemies/states/attack.gd
extends EnemyState
## Garra (1 golpe) ou arranhão duplo (2 golpes com intervalo para o jogador esquivar).
## O AttackComponent é dono do tempo e do dano de cada golpe (AttackData da cena).
## A preparação (startup) fica visível: o sprite fica amarelado até o golpe sair.

const TELEGRAPH_COLOR: Color = Color(1.0, 0.85, 0.3)

enum Phase { SWING, GAP }

var _phase: Phase = Phase.SWING
var _hits_left: int = 1
var _gap_left: float = 0.0


func enter() -> void:
	_hits_left = 2 if randf() < enemy.data.double_scratch_chance else 1
	_phase = Phase.SWING
	enemy.velocity.x = 0.0
	enemy.attack.start()


func exit() -> void:
	enemy.attack.cancel()
	enemy.sprite.modulate = Color.WHITE


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)

	match _phase:
		Phase.SWING:
			enemy.attack.update(delta)
			var preparing: bool = enemy.attack.state == AttackComponent.State.STARTUP
			enemy.sprite.modulate = TELEGRAPH_COLOR if preparing else Color.WHITE
			if not enemy.attack.is_attacking():
				_hits_left -= 1
				if _hits_left > 0:
					_phase = Phase.GAP
					_gap_left = enemy.data.double_scratch_gap
				else:
					enemy.attack_cooldown_left = enemy.data.attack_cooldown
					state_machine.transition_to("chase")
					return
		Phase.GAP:
			_gap_left -= delta
			if _gap_left <= 0.0:
				# O segundo golpe mira de novo no lado em que o Valtair está agora.
				if enemy.is_target_alive():
					var dx: float = enemy.get_target().global_position.x - enemy.global_position.x
					if absf(dx) > 2.0:
						enemy.set_facing(1 if dx > 0.0 else -1)
				_phase = Phase.SWING
				enemy.attack.start()

	enemy.move_and_slide()
