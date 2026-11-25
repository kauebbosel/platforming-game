# entities/player/states/fall.gd
extends PlayerState

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Pode chegar aqui ainda subindo (ex.: veio de um ataque no ar).
	player.apply_jump_cut()
	player.handle_jump_buffer(delta)

	var input_x: float = Input.get_axis("move_left", "move_right")
	player.velocity.x = input_x * player.stats.move_speed
	player.update_facing_direction(input_x)

	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("attack")
		return

	if player.can_jump() and player.jump_buffered:
		state_machine.transition_to("jump")
		return

	if player.is_on_floor():
		if input_x != 0.0:
			state_machine.transition_to("run")
		else:
			state_machine.transition_to("idle")
		return

	var was_on_floor: bool = player.is_on_floor()

	player.move_and_slide()

	if not was_on_floor and player.is_on_floor():
		player.get_node("LandingSFX").play(0.5)
