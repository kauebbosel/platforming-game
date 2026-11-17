# entities/player/states/attack.gd
extends PlayerState
## O AttackComponent é dono do tempo e do dano do golpe.
## Este estado controla o movimento (valores no AttackData) e decide para onde voltar quando o golpe termina.

var _queued: bool = false
## Para que lado o jogador queria virar quando apertou o botão do próximo golpe (0 = nenhum).
var _queued_dir: int = 0

func enter() -> void:
	_queued = false
	_queued_dir = 0
	# O 1º golpe também sai para o lado que o jogador segura agora (ex.: parado, aperta esquerda
	# e ataque no mesmo instante). A transição para cá acontece antes de o estado anterior virar o sprite.
	var held: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(held):
		player.update_facing_direction(held)
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
	# O lado do Valtair não muda DURANTE o golpe (a hitbox não vira no meio do ataque), mas ele
	# pode andar para o outro lado. Cada golpe da sequência escolhe o seu lado ao começar.
	var data: AttackData = player.attack.attack_data
	var input_x: float = Input.get_axis("move_left", "move_right")
	var multiplier: float = data.ground_move_multiplier if player.is_on_floor() else data.air_move_multiplier
	player.velocity.x = input_x * player.stats.move_speed * multiplier

	# Botão apertado durante o golpe: encadeia o próximo quando este terminar.
	if Input.is_action_just_pressed("attack"):
		_queued = true
		if not is_zero_approx(input_x):
			_queued_dir = 1 if input_x > 0.0 else -1

	player.attack.update(delta)

	if not player.attack.is_attacking():
		if _queued:
			_queued = false
			_turn_for_next_swing(input_x)
			player.attack.start()
		else:
			# Se um pulo começou neste frame (velocity.y < 0), vai para Fall mesmo com o chão do frame anterior.
			var grounded: bool = player.is_on_floor() and player.velocity.y >= 0.0
			state_machine.transition_to("idle" if grounded else "fall")
			return

	player.move_and_slide()


## O próximo golpe da sequência sai para o lado que o jogador está segurando agora; se ele já
## soltou a direção, vale a que ele segurava ao apertar o botão; sem nenhuma, mantém o lado.
## O golpe anterior já terminou, então virar a hitbox aqui é seguro.
func _turn_for_next_swing(input_x: float) -> void:
	var direction: float = input_x if not is_zero_approx(input_x) else float(_queued_dir)
	_queued_dir = 0
	if not is_zero_approx(direction):
		player.update_facing_direction(direction)
