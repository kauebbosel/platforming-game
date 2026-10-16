# entities/player/player.gd
class_name Player
extends CharacterBody2D
## Controlador principal do Player.

@export var stats: PlayerStats

@onready var state_machine: StateMachine = $StateMachine
@onready var sprite: Sprite2D = $Visual/Sprite2D

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jump_buffered: bool = false

func _ready() -> void:
	assert(stats != null, "ERRO: O recurso PlayerStats.tres precisa ser atribuído no Inspetor do Player!")
	state_machine.init(self)

func _physics_process(delta: float) -> void:
	if coyote_timer > 0.0:
		coyote_timer -= delta

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, stats.max_fall_speed, stats.gravity * delta)

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
	if input_x > 0.0:
		sprite.flip_h = false
	elif input_x < 0.0:
		sprite.flip_h = true
