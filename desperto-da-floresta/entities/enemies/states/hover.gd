# entities/enemies/states/hover.gd
extends EnemyState
## Perseguição do voador (o nó se chama "Chase", como em todo inimigo, mas o script é este).
## Paira acima do Valtair e mantém uma faixa de distância horizontal: recua se ele chega
## perto demais, se aproxima se ele se afasta. Quando está no alcance e o cooldown acabou,
## aciona o estado de ataque (EnemyData.attack_state).

const FACING_DEADZONE: float = 4.0
const BOB_AMPLITUDE: float = 4.0
const BOB_SPEED: float = 3.0
## Ganho do controle de altura: quanto maior, mais rápido ele corrige a diferença.
const HEIGHT_GAIN: float = 4.0

var _t: float = 0.0


func enter() -> void:
	_t = randf() * TAU  # cada voador oscila em fase diferente


func physics_update(delta: float) -> void:
	if not enemy.is_target_alive():
		state_machine.transition_to("idle")
		return

	var data: EnemyData = enemy.data
	var target: Node2D = enemy.get_target()
	var to_target: Vector2 = target.global_position - enemy.global_position
	if absf(to_target.x) > FACING_DEADZONE:
		enemy.set_facing(1 if to_target.x > 0.0 else -1)

	# Horizontal: aproxima, recua ou mantém conforme a faixa de distância.
	var want_x: float = 0.0
	var dx: float = absf(to_target.x)
	if dx > data.keep_distance_max:
		want_x = signf(to_target.x) * data.move_speed
	elif dx < data.keep_distance_min:
		want_x = -signf(to_target.x) * data.move_speed

	# Vertical: altura fixa acima dos pés do alvo, com uma leve oscilação.
	_t += delta
	var goal_y: float = target.global_position.y - data.hover_height + sin(_t * BOB_SPEED) * BOB_AMPLITUDE
	var want_y: float = clampf((goal_y - enemy.global_position.y) * HEIGHT_GAIN, -data.move_speed, data.move_speed)

	enemy.velocity = enemy.velocity.move_toward(Vector2(want_x, want_y), data.fly_acceleration * delta)
	enemy.move_and_slide()

	if enemy.attack_cooldown_left <= 0.0 and dx <= data.attack_range:
		state_machine.transition_to(data.attack_state)
