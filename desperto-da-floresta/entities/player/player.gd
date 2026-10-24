# entities/player/player.gd
class_name Player
extends CharacterBody2D
## Controlador principal do Player: estado compartilhado e utilidades usadas pelos estados.

@export var stats: PlayerStats

@onready var state_machine: StateMachine = $StateMachine
@onready var sprite: Sprite2D = $Visual/Sprite2D
## Nó filho direto do Player, com um filho Hitbox chamado "Hitbox".
@onready var attack: AttackComponent = $AttackComponent

var facing: int = 1  # 1 = direita, -1 = esquerda
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jump_buffered: bool = false

var _was_on_floor: bool = false


func _ready() -> void:
	assert(stats != null, "ERRO: O recurso PlayerStats.tres precisa ser atribuído no Inspetor do Player!")
	state_machine.init(self)


func _physics_process(delta: float) -> void:
	# Coyote time centralizado: começa quando o chão some sem ter sido um pulo (velocity.y >= 0).
	# Assim nenhum estado precisa lembrar de chamar start_coyote_timer().
	var on_floor: bool = is_on_floor()
	if _was_on_floor and not on_floor and velocity.y >= 0.0:
		start_coyote_timer()
	_was_on_floor = on_floor

	if coyote_timer > 0.0:
		coyote_timer -= delta


func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g: float = stats.gravity
	if velocity.y > 0.0:
		g *= stats.fall_gravity_multiplier
	velocity.y = move_toward(velocity.y, stats.max_fall_speed, g * delta)


func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0.0


func start_coyote_timer() -> void:
	coyote_timer = stats.coyote_time


func handle_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = stats.jump_buffer
		jump_buffered = true
	elif jump_buffered:
		jump_buffer_timer -= delta
		if jump_buffer_timer <= 0.0:
			jump_buffered = false


func update_facing_direction(input_x: float) -> void:
	if input_x == 0.0:
		return
	var new_facing: int = 1 if input_x > 0.0 else -1
	if new_facing == facing:
		return
	facing = new_facing
	sprite.flip_h = facing < 0
	attack.set_facing(facing)  # a hitbox acompanha o lado para onde o Valtair olha
