# entities/player/states/run.gd
extends PlayerState

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.handle_jump_buffer(delta)
	
	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("attack")
		return
		
	var input_x: float = Input.get_axis("move_left", "move_right")
	if input_x == 0.0:
		state_machine.transition_to("idle")
		return
		
	player.velocity.x = input_x * player.stats.move_speed
	player.update_facing_direction(input_x)
	
	if player.can_jump() and player.jump_buffered:
		state_machine.transition_to("jump")
		return
		
	if not player.is_on_floor():
		player.start_coyote_timer()
		state_machine.transition_to("fall")
		return
		
	player.move_and_slide()
