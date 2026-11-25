# entities/player/states/climb.gd
extends PlayerState
## Subir e descer em cipós. [W] sobe, [S] desce, [Espaço] solta o cipó com um pulo (e dá para
## pular para o lado segurando A/D), [Shift] (dash) também solta. Ao chegar no topo o Valtair
## sobe para a plataforma; ao chegar embaixo, cai ou pousa no chão.
## Quem inicia este estado é o Player (_try_start_climb), perto de um Vine.

const CLIMB_SPEED: float = 70.0
## Impulso para cima ao chegar no topo, para passar da borda da plataforma.
const TOP_HOP: float = -90.0
## Tempo em que não dá para agarrar o cipó de novo depois de soltá-lo.
const REGRAB_COOLDOWN: float = 0.3

var _vine: Node2D


func enter() -> void:
	_vine = player.nearby_vine
	player.velocity = Vector2.ZERO
	player.jump_cut_available = false
	player.air_dashes_left = player.stats.max_air_dashes
	if _vine != null:
		player.global_position.x = _vine.global_position.x
	# Começou a descer em cima de uma plataforma fina: atravessa ela para poder descer.
	if player.is_on_floor() and Input.is_action_pressed(&"move_down"):
		player.drop_through_floor(0.45)


func exit() -> void:
	player.climb_regrab_left = REGRAB_COOLDOWN


func physics_update(_delta: float) -> void:
	if _vine == null or not is_instance_valid(_vine) or player.nearby_vine != _vine:
		state_machine.transition_to("fall")
		return

	if Input.is_action_just_pressed(&"jump"):
		state_machine.transition_to("jump")  # o estado Jump dá o pulo e aceita A/D no ar
		return

	var dir: float = Input.get_axis(&"move_up", &"move_down")
	player.velocity = Vector2(0.0, dir * CLIMB_SPEED)
	player.move_and_slide()

	var feet_y: float = player.global_position.y
	if dir < 0.0 and feet_y <= _vine.get_top_y():
		player.velocity = Vector2(0.0, TOP_HOP)
		state_machine.transition_to("fall")
	elif dir > 0.0 and (feet_y >= _vine.get_bottom_y() or player.is_on_floor()):
		state_machine.transition_to("fall" if not player.is_on_floor() else "idle")
