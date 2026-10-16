# entities/player/player_state.gd
class_name PlayerState
extends Node
## Classe base abstrata para todos os estados do jogador (Player).

var player: CharacterBody2D
var state_machine: Node

func enter() -> void:
	pass

func exit() -> void:
	pass

func process_input(_event: InputEvent) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
