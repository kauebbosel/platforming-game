# entities/player/states/attack.gd
extends PlayerState
## O AttackComponent é dono do tempo e do dano do golpe.
## Este estado controla o movimento (valores no AttackData) e decide para onde voltar quando o golpe termina.

var _queued: bool = false

func enter() -> void:
	_queued = false
	player.attack.start()

func exit() -> void:
	# Se saiu no meio do golpe (ex.: tomar dano no futuro), garante a hitbox desligada.
	player.attack.cancel()

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.handle_jump_buffer(delta)

	# Pular durante o golpe NÃO cancela o ataque: só dá o impulso e o golpe segue até o fim.
	if player.can_jump() and player.jump_buffered:
		player.start_jump()

	# Altura variável continua valendo durante o golpe (soltar o pulo corta a subida).
	player.apply_jump_cut()

	# Movimento horizontal durante o golpe: input do jogador x multiplicador do AttackData.
	# O lado do Valtair não muda durante o golpe, para a hitbox não virar no meio do ataque.
	var data: AttackData = player.attack.attack_data
	var input_x: float = Input.get_axis("move_left", "move_right")
	var multiplier: float = data.ground_move_multiplier if player.is_on_floor() else data.air_move_multiplier
	player.velocity.x = input_x * player.stats.move_speed * multiplier

	# Botão apertado durante o golpe: encadeia o próximo quando este terminar.
	if Input.is_action_just_pressed("attack"):
		_queued = true

	player.attack.update(delta)

	if not player.attack.is_attacking():
		if _queued:
			_queued = false
			player.attack.start()
		else:
			# Se um pulo começou neste frame (velocity.y < 0), vai para Fall mesmo com o chão do frame anterior.
			var grounded: bool = player.is_on_floor() and player.velocity.y >= 0.0
			state_machine.transition_to("idle" if grounded else "fall")
			return

	player.move_and_slide()
