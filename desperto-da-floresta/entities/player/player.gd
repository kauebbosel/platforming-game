# entities/player/player.gd
class_name Player
extends CharacterBody2D

signal death_sequence_finished(permanent: bool)

## Controlador principal do Player: estado compartilhado e utilidades usadas pelos estados.

@export var stats: PlayerStats

@onready var state_machine: StateMachine = $StateMachine
@onready var sprite: Sprite2D = $Visual/Sprite2D
## Nós filhos diretos do Player (os nomes precisam ser exatamente estes).
@onready var attack: AttackComponent = $AttackComponent
@onready var health: HealthComponent = $Health
@onready var ammo: AmmoComponent = $AmmoComponent
@onready var ranged: RangedAttackComponent = $RangedAttackComponent
@onready var hurtbox: Hurtbox = $Hurtbox

var permanent_death: bool = false
var facing: int = 1  # 1 = direita, -1 = esquerda
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jump_buffered: bool = false
## Verdadeiro enquanto o corte de pulo ainda pode acontecer (subindo por causa de um pulo).
var jump_cut_available: bool = false
## Tempo restante até poder usar o dash de novo (conta desde o início do dash).
var dash_cooldown_left: float = 0.0
## Dashes no ar ainda disponíveis; recarrega ao tocar o chão.
var air_dashes_left: int = 0
var _was_on_floor: bool = false


func _ready() -> void:
	add_to_group(&"player")  # os inimigos encontram o alvo por este grupo
	assert(stats != null, "ERRO: O recurso PlayerStats.tres precisa ser atribuído no Inspetor do Player!")
	state_machine.init(self)
	_connect_hud_events()
	health.died.connect(_on_health_died)
	_sync_with_run()


func _physics_process(delta: float) -> void:
	# Coyote time centralizado: começa quando o chão some sem ter sido um pulo (velocity.y >= 0).
	# Assim nenhum estado precisa lembrar de chamar start_coyote_timer().
	if is_dead():
		return
	var on_floor: bool = is_on_floor()
	if _was_on_floor and not on_floor and velocity.y >= 0.0:
		start_coyote_timer()
	_was_on_floor = on_floor

	if coyote_timer > 0.0:
		coyote_timer -= delta

	if on_floor:
		air_dashes_left = stats.max_air_dashes
	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta

	# Dash: transição global, vale em qualquer estado (inclusive durante o golpe, que é cancelado).
	# Roda antes dos estados, então a troca já vale neste mesmo frame.
	if Input.is_action_just_pressed("dodge") and can_dash():
		state_machine.transition_to("dash")

	# Ataque ranged: ação paralela, não trava o movimento. Bloqueado durante o golpe corpo a corpo.
	if Input.is_action_just_pressed("ranged_attack") and not attack.is_attacking():
		ranged.try_fire(facing)


func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g: float = stats.gravity
	if velocity.y > 0.0:
		g *= stats.fall_gravity_multiplier
	velocity.y = move_toward(velocity.y, stats.max_fall_speed, g * delta)

## Dentro de uma run, a vida vem do RunState e toda mudança volta para ele.
## (A munição faz o mesmo no próprio AmmoComponent.) Fora de uma run, não faz nada.
func _sync_with_run() -> void:
	if not RunState.run_active:
		return
	if RunState.health >= 0:
		health.set_current(RunState.health)
	RunState.health = health.health
	health.changed.connect(func(current: int, _maximum: int) -> void: RunState.health = current)
	
func is_dead() -> bool:
	return health.health <= 0

func _on_health_died() -> void:
	state_machine.transition_to("dead")

func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0.0


func can_dash() -> bool:
	return dash_cooldown_left <= 0.0 and (is_on_floor() or air_dashes_left > 0)


## Dá o impulso do pulo. Usado pelo estado Jump e pelo Attack (pular durante o golpe
## não cancela o golpe), para o pulo ter uma implementação só.
func start_jump() -> void:
	velocity.y = stats.jump_velocity
	jump_buffered = false
	coyote_timer = 0.0
	jump_cut_available = true


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


## Altura variável do pulo. Chame em TODO estado em que o Valtair pode estar subindo
## (Jump, Attack, Fall), para soltar o botão cortar a subida mesmo atacando no ar.
func apply_jump_cut() -> void:
	if not jump_cut_available:
		return
	if velocity.y >= 0.0:
		jump_cut_available = false  # passou do ápice: não há mais o que cortar
	elif not Input.is_action_pressed("jump"):
		velocity.y *= stats.jump_cut_multiplier
		jump_cut_available = false


func update_facing_direction(input_x: float) -> void:
	if input_x == 0.0:
		return
	var new_facing: int = 1 if input_x > 0.0 else -1
	if new_facing == facing:
		return
	facing = new_facing
	sprite.flip_h = facing < 0
	attack.set_facing(facing)  # a hitbox acompanha o lado para onde o Valtair olha


## O Player é a ponte entre os seus componentes e o HUD: repassa os sinais ao EventBus.
## Os componentes são genéricos (servem também a inimigos), então não falam com o HUD.
func _connect_hud_events() -> void:
	health.changed.connect(EventBus.player_health_changed.emit)
	ammo.changed.connect(EventBus.player_ammo_changed.emit)
	health.died.connect(EventBus.player_died.emit)
	death_sequence_finished.connect(EventBus.player_death_finished.emit)
	# Valores iniciais, depois que todos os nós (inclusive o HUD) terminarem o _ready.
	_emit_hud_state.call_deferred()


func _emit_hud_state() -> void:
	EventBus.player_health_changed.emit(health.health, health.max_health)
	EventBus.player_ammo_changed.emit(ammo.current, ammo.max_ammo)


# TEMPORÁRIO: testa o HUD sem inimigos. Apague quando o Corpo-Seco existir.
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1: hurtbox.receive_hit(10, self, Vector2.ZERO)
		KEY_F2: health.heal(10)
		KEY_F3: ammo.refill()
		KEY_F4:  # morte definitiva (iria ao menu principal, por hora faz a msm coisa)
			permanent_death = true
			health.take_damage(health.health)
		KEY_F5:  # morte normal (reinicia a sala)
			health.take_damage(health.health)
