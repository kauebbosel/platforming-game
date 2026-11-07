# entities/player/state_machine.gd
class_name StateMachine
extends Node
## Gerenciador da Máquina de Estados do Player.

@export var initial_state: PlayerState
var current_state: PlayerState
var states: Dictionary = {}

func init(player: CharacterBody2D) -> void:
	for child in get_children():
		if child is PlayerState:
			states[child.name.to_lower()] = child
			child.player = player
			child.state_machine = self
	
	if initial_state:
		current_state = initial_state
		current_state.enter()

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.process_input(event)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(target_state_name: String) -> void:
	var key: String = target_state_name.to_lower()
	if not states.has(key):
		push_warning("StateMachine: Estado não encontrado -> " + target_state_name)
		return
	
	if current_state:
		current_state.exit()
	
	current_state = states[key]
	current_state.enter()
