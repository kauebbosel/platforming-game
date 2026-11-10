# entities/enemies/states/charge.gd
extends EnemyState
## Investida da Mula (GDD 6.2.3). Reaproveita as 3 fases do AttackComponent:
##   STARTUP  = para e se prepara (sprite alaranjado). A direção trava AQUI: o jogador lê
##              para onde ela vai vir e desvia.
##   ACTIVE   = avança em linha reta, sem corrigir a direção; a hitbox fica ligada.
##   RECOVERY = perde o equilíbrio, parada e acinzentada: a janela para o jogador atacar.
## Quem entra aqui é o Chase, via EnemyData.attack_state = "charge".

const TELEGRAPH_COLOR: Color = Color(1.0, 0.45, 0.2)
const RECOVERY_COLOR: Color = Color(0.7, 0.7, 0.7)

var _dir: int = 1
var _hit_wall: bool = false


func enter() -> void:
	# Vira para onde o alvo está agora e trava essa direção até o fim.
	if enemy.is_target_alive():
		var dx: float = enemy.get_target().global_position.x - enemy.global_position.x
		if absf(dx) > 2.0:
			enemy.set_facing(1 if dx > 0.0 else -1)
	_dir = enemy.facing
	_hit_wall = false
	enemy.velocity.x = 0.0
	enemy.attack.start()


func exit() -> void:
	enemy.attack.cancel()
	enemy.sprite.modulate = Color.WHITE


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)

	match enemy.attack.state:
		AttackComponent.State.ACTIVE:
			enemy.sprite.modulate = Color.WHITE
			enemy.velocity.x = 0.0 if _hit_wall else _dir * enemy.data.charge_speed
		AttackComponent.State.RECOVERY:
			enemy.sprite.modulate = RECOVERY_COLOR
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)
		_:
			enemy.sprite.modulate = TELEGRAPH_COLOR
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)

	enemy.attack.update(delta)
	enemy.move_and_slide()

	# Bateu na parede: para de empurrar; as fases seguem até a recuperação.
	if enemy.attack.state == AttackComponent.State.ACTIVE and enemy.is_on_wall():
		_hit_wall = true

	if not enemy.attack.is_attacking():
		enemy.attack_cooldown_left = enemy.data.attack_cooldown
		state_machine.transition_to("chase")
