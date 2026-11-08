# entities/enemies/enemy_state_machine.gd
class_name EnemyStateMachine
extends Node
## Máquina de estados dos inimigos. Igual à do Player, mas para EnemyState.
## Se um dia os dois ficarem idênticos de verdade, dá para unificar numa só.

@export var initial_state: EnemyState
var current_state: EnemyState
var states: Dictionary = {}


func init(owner_enemy: EnemyBase) -> void:
	for child in get_children():
		if child is EnemyState:
			states[child.name.to_lower()] = child
			child.enemy = owner_enemy
			child.state_machine = self
	if initial_state:
		current_state = initial_state
		current_state.enter()


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func transition_to(target_state_name: String) -> void:
	var key: String = target_state_name.to_lower()
	if not states.has(key):
		push_warning("EnemyStateMachine: estado não encontrado -> " + target_state_name)
		return
	if current_state:
		current_state.exit()
	current_state = states[key]
	current_state.enter()
