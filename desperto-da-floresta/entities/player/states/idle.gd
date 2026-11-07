# entities/player/states/idle.gd
extends PlayerState

func enter() -> void:
	player.velocity.x = 0.0

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.handle_jump_buffer(delta)
	
	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("attack")
		return
		
	if player.can_jump() and player.jump_buffered:
		state_machine.transition_to("jump")
		return
		
	var input_x: float = Input.get_axis("move_left", "move_right")
	if input_x != 0.0:
		state_machine.transition_to("run")
		return
		
	if not player.is_on_floor():
		state_machine.transition_to("fall")
		return
		
	player.move_and_slide()
