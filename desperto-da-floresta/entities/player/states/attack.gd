# entities/player/states/attack.gd
extends PlayerState
## O AttackComponent é dono do tempo e do dano do golpe.
## Este estado só controla o movimento e decide para onde voltar quando o golpe termina.

var _queued: bool = false

func enter() -> void:
	_queued = false
	if player.is_on_floor():
		player.velocity.x = 0.0
	player.attack.start()

func exit() -> void:
	# Se saiu no meio do golpe (ex.: tomar dano no futuro), garante a hitbox desligada.
	player.attack.cancel()

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

	# Botão apertado durante o golpe: encadeia o próximo quando este terminar.
	if Input.is_action_just_pressed("attack"):
		_queued = true

	player.attack.update(delta)

	if not player.attack.is_attacking():
		if _queued:
			_queued = false
			player.attack.start()
		else:
			state_machine.transition_to("idle" if player.is_on_floor() else "fall")
			return

	player.move_and_slide()
