# entities/player/states/jump.gd
extends PlayerState

var _cut_done: bool = false

func enter() -> void:
	player.velocity.y = player.stats.jump_velocity
	player.jump_buffered = false
	player.coyote_timer = 0.0
	_cut_done = false

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Registra o botão de pulo também durante a subida (buffer para o pouso).
	player.handle_jump_buffer(delta)

	# Altura variável: se o botão não está mais pressionado enquanto sobe, corta o pulo (uma vez).
	# Usar "não pressionado" (e não "just_released") cobre toque rápido e pulo vindo do buffer.
	if not _cut_done and not Input.is_action_pressed("jump") and player.velocity.y < 0.0:
		player.velocity.y *= player.stats.jump_cut_multiplier
		_cut_done = true

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
