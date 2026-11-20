# entities/enemies/states/slam.gd
extends EnemyState
## Salto descendente do Curupira (GDD 9.4.2). Três fases:
##   WINDUP = agacha e se prepara (sprite esverdeado): dá tempo de ler o ataque.
##   AIR    = salta em arco até onde o Valtair ESTAVA no fim da preparação.
##   LAND   = ao pousar, a SlamAttack (AttackComponent chamado "SlamAttack") machuca uma área
##            ao redor; depois fica parado e acinzentado, a janela para o Valtair atacar.

const TELEGRAPH_COLOR: Color = Color(0.6, 1.0, 0.5)
const RECOVERY_COLOR: Color = Color(0.7, 0.7, 0.7)
## Se não pousar nesse tempo (preso em algo), considera que pousou.
const MAX_AIR_TIME: float = 1.6

enum Phase { WINDUP, AIR, LAND }

var _slam: AttackComponent
var _phase: Phase = Phase.WINDUP
var _time: float = 0.0


func enter() -> void:
	_slam = enemy.get_node_or_null("SlamAttack") as AttackComponent
	if _slam == null:
		push_warning("Slam: o inimigo precisa de um AttackComponent chamado SlamAttack.")
		state_machine.transition_to("chase")
		return
	_phase = Phase.WINDUP
	_time = enemy.data.slam_windup
	enemy.velocity.x = 0.0
	enemy.sprite.modulate = TELEGRAPH_COLOR


func exit() -> void:
	if _slam != null:
		_slam.cancel()
	enemy.sprite.modulate = Color.WHITE


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)

	match _phase:
		Phase.WINDUP:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)
			_face_target()
			_time -= delta
			if _time <= 0.0:
				_launch()
		Phase.AIR:
			_time += delta
			var landed: bool = enemy.is_on_floor() and enemy.velocity.y >= 0.0 and _time > 0.1
			if landed or _time > MAX_AIR_TIME:
				_land()
		Phase.LAND:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)
			_slam.update(delta)
			var recovering: bool = _slam.state == AttackComponent.State.RECOVERY
			enemy.sprite.modulate = RECOVERY_COLOR if recovering else Color.WHITE
			if not _slam.is_attacking():
				enemy.attack_cooldown_left = enemy.data.attack_cooldown
				state_machine.transition_to("chase")
				return

	enemy.move_and_slide()


func _face_target() -> void:
	if not enemy.is_target_alive():
		return
	var dx: float = enemy.get_target().global_position.x - enemy.global_position.x
	if absf(dx) > 2.0:
		enemy.set_facing(1 if dx > 0.0 else -1)


## Salta de modo a pousar em cima de onde o Valtair está agora.
func _launch() -> void:
	var target_x: float = enemy.global_position.x
	if enemy.is_target_alive():
		target_x = enemy.get_target().global_position.x
	var vy: float = enemy.data.slam_jump_speed
	var flight_time: float = 2.0 * absf(vy) / enemy.data.gravity
	var max_vx: float = enemy.data.slam_max_air_speed
	var vx: float = clampf((target_x - enemy.global_position.x) / flight_time, -max_vx, max_vx)
	enemy.velocity = Vector2(vx, vy)
	enemy.sprite.modulate = Color.WHITE
	_phase = Phase.AIR
	_time = 0.0


func _land() -> void:
	enemy.velocity.x = 0.0
	_phase = Phase.LAND
	_slam.start()
