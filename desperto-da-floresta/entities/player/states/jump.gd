# entities/player/states/jump.gd
extends PlayerState

func enter() -> void:
	player.velocity.y = player.stats.jump_velocity
	player.jump_buffered = false
	player.coyote_timer = 0.0

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	if Input.is_action_just_released("jump") and player.velocity.y < 0.0:
		player.velocity.y *= player.stats.jump_cut_multiplier
		
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
