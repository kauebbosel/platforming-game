# components/attack_component.gd
class_name AttackComponent
extends Node2D
## Ataque melee em 3 fases: STARTUP (preparação) -> ACTIVE (hitbox ligada) -> RECOVERY (recuperação).
## Quem decide QUANDO atacar é o dono (ex.: o estado Attack do Player), chamando start().
## Este componente só executa as fases, lendo tempos e dano do AttackData.
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

@export var attack_data: AttackData
@export var timer_driven: bool = true
## Efeito visual do golpe (ex.: o nó SlashFX). Fica escondido e só aparece na fase ACTIVE.
@export var vfx: CanvasItem

@onready var body: CharacterBody2D = get_parent() as CharacterBody2D
@onready var hitbox: Hitbox = $Hitbox as Hitbox

var state: State = State.IDLE
var _timer: float = 0.0


func _ready() -> void:
	assert(attack_data != null, "AttackComponent precisa de um AttackData atribuído no Inspetor!")
	hitbox.source = body
	hitbox.damage = attack_data.damage
	hitbox.hit_landed.connect(func(h: Hurtbox) -> void: hit_landed.emit(h))
	_set_vfx_visible(false)


func is_attacking() -> bool:
	return state != State.IDLE


func set_facing(facing: int) -> void:
	scale.x = float(facing)


## Inicia o golpe. Ignorado se já estiver atacando.
func start() -> void:
	if state != State.IDLE:
		return
	state = State.STARTUP
	_timer = attack_data.startup_time()
	attack_started.emit()
	if timer_driven and attack_data.startup_frames <= 0:
		enter_active()


## Deve ser chamado a cada frame de física por quem é dono do ataque.
func update(delta: float) -> void:
	if state == State.IDLE or not timer_driven:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match state:
		State.STARTUP: enter_active()
		State.ACTIVE: enter_recovery()
		State.RECOVERY: finish()


## Interrompe o golpe (ex.: o dono saiu do estado). Seguro de chamar em qualquer momento.
func cancel() -> void:
	if state == State.IDLE:
		return
	finish()


## --- Públicos: o AnimationPlayer pode chamar estes três ---
func enter_active() -> void:
	state = State.ACTIVE
	_timer = attack_data.active_time()
	hitbox.damage = attack_data.damage
	hitbox.activate()
	_set_vfx_visible(true)
	active_started.emit()


func enter_recovery() -> void:
	state = State.RECOVERY
	_timer = attack_data.recovery_time()
	hitbox.deactivate()
	_set_vfx_visible(false)
	active_ended.emit()


func finish() -> void:
	state = State.IDLE
	hitbox.deactivate()
	_set_vfx_visible(false)
	attack_finished.emit()


func _set_vfx_visible(value: bool) -> void:
	if vfx != null:
		vfx.visible = value
