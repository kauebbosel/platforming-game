# entities/player/states/attack.gd
extends PlayerState

var attack_timer: float = 0.0
@export var attack_duration: float = 0.25

func enter() -> void:
	attack_timer = attack_duration
	if player.is_on_floor():
		player.velocity.x = 0.0

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	attack_timer -= delta
	
	if attack_timer <= 0.0:
		if player.is_on_floor():
			state_machine.transition_to("idle")
		else:
			state_machine.transition_to("fall")
		return
		
	player.move_and_slide()
