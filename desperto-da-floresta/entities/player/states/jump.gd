# entities/player/states/jump.gd
extends PlayerState

func enter() -> void:
	player.start_jump()

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Registra o botão de pulo também durante a subida (buffer para o pouso).
	player.handle_jump_buffer(delta)
	# Altura variável: soltar o botão enquanto sobe corta o pulo (lógica compartilhada no Player).
	player.apply_jump_cut()

	var input_x: float = Input.get_axis("move_left", "move_right")
	player.velocity.x = input_x * player.stats.move_speed
	player.update_facing_direction(input_x)

	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("attack")
		return

	if player.velocity.y >= 0.0:
		state_machine.transition_to("fall")
		return

	player.move_and_slide()
