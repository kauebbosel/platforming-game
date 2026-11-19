# entities/enemies/states/seeds.gd
extends EnemyState
## Disparo de sementes do Curupira (GDD 9.4.2). Para, prepara (sprite amarelado: o tempo de
## ler o ataque), dispara um leque de `seed_count` sementes mirado no Valtair e fica parado
## um instante. As sementes seguem reto: dá para desviar andando, saltando ou com dash.
## Precisa de um RangedAttackComponent com cooldown 0 (vários tiros no mesmo instante).

const TELEGRAPH_COLOR: Color = Color(0.95, 0.85, 0.4)
## Ponto do Valtair que ele mira (o peito; a origem do Valtair fica nos pés).
const AIM_OFFSET: Vector2 = Vector2(0.0, -14.0)

var _time_left: float = 0.0
var _fired: bool = false


func enter() -> void:
	_fired = false
	_time_left = enemy.data.shoot_windup
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
	var dx: float = target.global_position.x - enemy.global_position.x
	if absf(dx) > 4.0 and not _fired:
		enemy.set_facing(1 if dx > 0.0 else -1)

	_time_left -= delta
	if _time_left > 0.0:
		return

	if not _fired:
		_fired = true
		enemy.sprite.modulate = Color.WHITE
		_fire_fan(target)
		_time_left = enemy.data.shoot_recover
	else:
		enemy.attack_cooldown_left = enemy.data.attack_cooldown
		state_machine.transition_to("chase")


func _fire_fan(target: Node2D) -> void:
	var ranged: RangedAttackComponent = enemy.ranged
	var side: int = 1 if target.global_position.x >= enemy.global_position.x else -1
	var origin: Vector2 = enemy.global_position + Vector2(ranged.muzzle_offset.x * side, ranged.muzzle_offset.y)
	var base: Vector2 = target.global_position + AIM_OFFSET - origin
	var count: int = maxi(1, enemy.data.seed_count)
	var step: float = deg_to_rad(enemy.data.seed_spread_degrees)
	for i in count:
		var angle: float = (i - (count - 1) / 2.0) * step
		ranged.try_fire_toward(base.rotated(angle))
