class_name AttackComponent
extends Node2D
## Ataque melee em 3 fases: STARTUP (preparação) -> ACTIVE (hitbox ligada) -> RECOVERY (recuperação).
## É um Node2D (e não Node) para o Hitbox filho herdar posição/flip do Valtair.
## O pai precisa ser um CharacterBody2D e deve existir um filho Hitbox chamado "Hitbox".
##
## COM sprites/animação: desmarque `timer_driven` e chame enter_active(), enter_recovery()
## e finish() a partir de uma "Call Method Track" no AnimationPlayer.

signal attack_started
signal active_started
signal active_ended
signal attack_finished
signal hit_landed(hurtbox: Hurtbox)

enum State { IDLE, STARTUP, ACTIVE, RECOVERY }

@export var timer_driven: bool = true
@export var startup: float = 0.06
@export var active: float = 0.10
@export var recovery: float = 0.16
@export var damage: int = 1
## Velocidade horizontal durante o ataque (0 = para totalmente, 1 = normal).
@export_range(0.0, 1.0) var move_multiplier: float = 0.3
## Tempo em que um clique antecipado ainda vale (encadeia ataques sem "engolir" botão).
@export var buffer_time: float = 0.12

@onready var body: CharacterBody2D = get_parent() as CharacterBody2D
@onready var hitbox: Hitbox = $Hitbox as Hitbox

var state: State = State.IDLE
var _timer: float = 0.0
var _buffer: float = 0.0


func _ready() -> void:
	hitbox.source = body
	hitbox.damage = damage
	hitbox.hit_landed.connect(func(h: Hurtbox) -> void: hit_landed.emit(h))


func is_attacking() -> bool:
	return state != State.IDLE


## Multiplicador de velocidade para o MovementComponent.
func movement_multiplier() -> float:
	return move_multiplier if is_attacking() else 1.0


func set_facing(facing: int) -> void:
	scale.x = float(facing)


func update(delta: float) -> void:
	_buffer = maxf(_buffer - delta, 0.0)
	if Input.is_action_just_pressed(&"attack"):
		_buffer = maxf(buffer_time, delta)

	if state == State.IDLE:
		if _buffer > 0.0:
			_begin()
		return

	if not timer_driven:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match state:
		State.STARTUP: enter_active()
		State.ACTIVE: enter_recovery()
		State.RECOVERY: finish()


func _begin() -> void:
	_buffer = 0.0
	state = State.STARTUP
	_timer = startup
	attack_started.emit()
	if timer_driven and startup <= 0.0:
		enter_active()


## --- Públicos: o AnimationPlayer pode chamar estes três ---
func enter_active() -> void:
	state = State.ACTIVE
	_timer = active
	hitbox.damage = damage
	hitbox.activate()
	active_started.emit()


func enter_recovery() -> void:
	state = State.RECOVERY
	_timer = recovery
	hitbox.deactivate()
	active_ended.emit()


func finish() -> void:
	state = State.IDLE
	hitbox.deactivate()
	attack_finished.emit()
