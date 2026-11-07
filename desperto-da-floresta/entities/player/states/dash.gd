# entities/player/states/dash.gd
extends PlayerState
## Dash horizontal curto. Sem i-frames (decisão de design): só reposiciona o Valtair.
## Cancela o golpe corpo a corpo (decisão provisória): ao sair do estado Attack, o
## attack.gd chama cancel() no componente. A entrada neste estado é feita pelo Player
## (ver Player._physics_process), por isso nenhum outro estado precisa checar o botão.

var _time_left: float = 0.0
var _direction: float = 1.0

func enter() -> void:
	# Direção: a do input, se houver; senão, a que o Valtair está olhando.
	var input_x: float = Input.get_axis("move_left", "move_right")
	_direction = signf(input_x) if input_x != 0.0 else float(player.facing)
	player.update_facing_direction(_direction)

	_time_left = player.stats.dash_duration
	player.dash_cooldown_left = player.stats.dash_cooldown
	if not player.is_on_floor():
		player.air_dashes_left -= 1

func physics_update(delta: float) -> void:
	player.velocity.x = _direction * (player.stats.dash_distance / player.stats.dash_duration)

	# 0 = dash reto, sem cair durante ele.
	if player.stats.dash_gravity_multiplier <= 0.0:
		player.velocity.y = 0.0
	else:
		player.apply_gravity(delta * player.stats.dash_gravity_multiplier)

	_time_left -= delta
	if _time_left <= 0.0:
		if not player.is_on_floor():
			state_machine.transition_to("fall")
		elif Input.get_axis("move_left", "move_right") != 0.0:
			state_machine.transition_to("run")
		else:
			state_machine.transition_to("idle")
		return

	player.move_and_slide()
