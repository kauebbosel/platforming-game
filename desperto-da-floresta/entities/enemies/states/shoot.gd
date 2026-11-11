# entities/enemies/states/shoot.gd
extends EnemyState
## Tiro do voador: para no ar, prepara (sprite roxo, o tempo de ler o ataque), dispara UM
## projétil mirado no Valtair no fim da preparação e fica parado um instante antes de
## voltar a se mover. Dano na preparação interrompe (o Hurt tira este estado).

const TELEGRAPH_COLOR: Color = Color(0.8, 0.5, 1.0)
## Ponto do Valtair que ele mira (o peito; a origem do Valtair fica nos pés).
const AIM_OFFSET: Vector2 = Vector2(0.0, -14.0)

var _time_left: float = 0.0
var _fired: bool = false


func enter() -> void:
	_fired = false
	_time_left = enemy.data.shoot_windup
	enemy.sprite.modulate = TELEGRAPH_COLOR


func exit() -> void:
	enemy.sprite.modulate = Color.WHITE


func physics_update(delta: float) -> void:
	# Freia, mas continua flutuando (sem gravidade).
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.data.friction * delta)
	enemy.move_and_slide()

	if not enemy.is_target_alive():
		state_machine.transition_to("idle")
		return

	var target: Node2D = enemy.get_target()
	var dx: float = target.global_position.x - enemy.global_position.x
	if absf(dx) > 4.0:
		enemy.set_facing(1 if dx > 0.0 else -1)

	_time_left -= delta
	if _time_left > 0.0:
		return

	if not _fired:
		_fired = true
		enemy.sprite.modulate = Color.WHITE
		_fire_at(target)
		_time_left = enemy.data.shoot_recover
	else:
		enemy.attack_cooldown_left = enemy.data.attack_cooldown
		state_machine.transition_to("chase")


func _fire_at(target: Node2D) -> void:
	var ranged: RangedAttackComponent = enemy.ranged
	var side: int = 1 if target.global_position.x >= enemy.global_position.x else -1
	var origin: Vector2 = enemy.global_position + Vector2(ranged.muzzle_offset.x * side, ranged.muzzle_offset.y)
	ranged.try_fire_toward(target.global_position + AIM_OFFSET - origin)
