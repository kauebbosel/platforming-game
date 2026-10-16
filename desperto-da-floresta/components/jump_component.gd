class_name JumpComponent
extends Node
## Movimento VERTICAL: gravidade + pulo. O pai precisa ser um CharacterBody2D.
## Cada "truque" de game feel pode ser desligado pelo Inspector:
##  - altura variável: variable_height = false
##  - coyote time:     coyote_time = 0
##  - jump buffer:     jump_buffer_time = 0
##  - pulo duplo:      max_jumps = 2

signal jumped
signal landed

@export var jump_velocity: float = -340.0  # negativo = para cima (Y cresce para baixo)
@export var gravity: float = 900.0
## Cair mais rápido do que subir deixa o pulo menos "flutuante".
@export var fall_gravity_multiplier: float = 1.5
@export var max_fall_speed: float = 600.0
@export_group("Game feel")
@export var variable_height: bool = true
## Ao soltar o botão subindo, a velocidade vertical é multiplicada por isso.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.4
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10
@export var max_jumps: int = 1

@onready var body: CharacterBody2D = get_parent() as CharacterBody2D

var _coyote: float = 0.0
var _buffer: float = 0.0
var _air_jumps_left: int = 0
var _was_on_floor: bool = false


func update(delta: float) -> void:
	_apply_gravity(delta)
	_update_timers(delta)
	_try_jump()
	_apply_jump_cut()
	_was_on_floor = body.is_on_floor()


func _apply_gravity(delta: float) -> void:
	if body.is_on_floor():
		return
	var g := gravity
	if body.velocity.y > 0.0:
		g *= fall_gravity_multiplier
	body.velocity.y = minf(body.velocity.y + g * delta, max_fall_speed)


func _update_timers(delta: float) -> void:
	if body.is_on_floor():
		_coyote = coyote_time
		_air_jumps_left = maxi(max_jumps - 1, 0)
		if not _was_on_floor:
			landed.emit()
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	_buffer = maxf(_buffer - delta, 0.0)
	if Input.is_action_just_pressed(&"jump"):
		_buffer = maxf(jump_buffer_time, delta)  # garante pelo menos este frame


func _try_jump() -> void:
	if _buffer <= 0.0:
		return
	if _coyote > 0.0 or body.is_on_floor():
		_do_jump()
	elif _air_jumps_left > 0:
		_air_jumps_left -= 1
		_do_jump()


func _do_jump() -> void:
	body.velocity.y = jump_velocity
	_coyote = 0.0
	_buffer = 0.0
	jumped.emit()


func _apply_jump_cut() -> void:
	if variable_height and Input.is_action_just_released(&"jump") and body.velocity.y < 0.0:
		body.velocity.y *= jump_cut_multiplier
