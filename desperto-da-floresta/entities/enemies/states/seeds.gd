# entities/enemies/states/seeds.gd
extends EnemyState
## Disparo de sementes do Curupira (GDD 9.4.2). Três fases:
##   WINDUP  = para e se prepara (sprite amarelado): o tempo de ler o ataque.
##   FIRE    = solta `seed_count` sementes em RAJADA, uma a cada BURST_INTERVAL, cada uma
##             mirada no Valtair NAQUELE instante (com uma pequena variação de ângulo).
##   RECOVER = fica parado um instante (janela para o Valtair atacar).
## Por que rajada e não leque: num leque as sementes de baixo vão direto para o chão.
## As sementes seguem reto; dá para desviar andando, saltando ou com dash.
## Precisa de um RangedAttackComponent com cooldown 0 (vários tiros em sequência).

const TELEGRAPH_COLOR: Color = Color(0.95, 0.85, 0.4)
## Ponto do Valtair que ele mira (o meio do corpo; a origem do Valtair fica nos pés).
const AIM_OFFSET: Vector2 = Vector2(0.0, -16.0)
## Tempo entre uma semente e a seguinte, em segundos.
const BURST_INTERVAL: float = 0.14
## Variação aleatória do ângulo de cada semente, em graus (para mais ou para menos).
## Mantenha pequena: ângulos grandes mandam a semente para o chão ou para o teto.
const JITTER_DEGREES: float = 2.0

enum Phase { WINDUP, FIRE, RECOVER }

var _phase: Phase = Phase.WINDUP
var _time_left: float = 0.0
var _shots_left: int = 0


func enter() -> void:
	_phase = Phase.WINDUP
	_time_left = enemy.data.shoot_windup
	_shots_left = maxi(1, enemy.data.seed_count)
	enemy.velocity.x = 0.0
	enemy.sprite.modulate = TELEGRAPH_COLOR


func exit() -> void:
	enemy.sprite.modulate = Color.WHITE


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.data.friction * delta)
	enemy.move_and_slide()

	if not enemy.is_target_alive():
		state_machine.transition_to("idle")
		return

	var target: Node2D = enemy.get_target()
	if _phase != Phase.RECOVER:
		var dx: float = target.global_position.x - enemy.global_position.x
		if absf(dx) > 4.0:
			enemy.set_facing(1 if dx > 0.0 else -1)

	_time_left -= delta
	if _time_left > 0.0:
		return

	match _phase:
		Phase.WINDUP:
			enemy.sprite.modulate = Color.WHITE
			_phase = Phase.FIRE
			_fire_one(target)
			_after_shot()
		Phase.FIRE:
			_fire_one(target)
			_after_shot()
		Phase.RECOVER:
			enemy.attack_cooldown_left = enemy.data.attack_cooldown
			state_machine.transition_to("chase")


func _after_shot() -> void:
	_shots_left -= 1
	if _shots_left > 0:
		_time_left = BURST_INTERVAL
	else:
		_phase = Phase.RECOVER
		_time_left = enemy.data.shoot_recover


func _fire_one(target: Node2D) -> void:
	var ranged: RangedAttackComponent = enemy.ranged
	var side: int = 1 if target.global_position.x >= enemy.global_position.x else -1
	var origin: Vector2 = enemy.global_position + Vector2(ranged.muzzle_offset.x * side, ranged.muzzle_offset.y)
	var aim: Vector2 = target.global_position + AIM_OFFSET - origin
	aim = aim.rotated(deg_to_rad(randf_range(-JITTER_DEGREES, JITTER_DEGREES)))
	ranged.try_fire_toward(aim)
