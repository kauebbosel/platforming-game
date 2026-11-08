# entities/enemies/enemy_state.gd
class_name EnemyState
extends Node
## Classe base dos estados de inimigos. Mesmo contrato do PlayerState: um nó por estado,
## estado novo = arquivo novo. Os nomes dos nós de estado são os da transition_to().

var enemy: EnemyBase
var state_machine: EnemyStateMachine


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
