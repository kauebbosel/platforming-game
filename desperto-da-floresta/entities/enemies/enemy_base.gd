# entities/enemies/enemy_base.gd
class_name EnemyBase
extends CharacterBody2D
## Base dos inimigos corpo a corpo: estado compartilhado e utilidades usadas pelos estados.
## O que muda de um inimigo para outro fica em dois lugares: o EnemyData (números de
## comportamento) e o AttackData do AttackComponent (o golpe). Estrutura exigida da cena
## (nomes exatos): Sprite2D, Health, Hurtbox, AttackComponent (com Hitbox filho) e
## StateMachine (EnemyStateMachine) com os estados Idle, Chase, Attack, Hurt e Dead.

@export var data: EnemyData
## Marque se a arte original olha para a direita (desmarque se olhar para a esquerda).
@export var art_faces_right: bool = true

@onready var state_machine: EnemyStateMachine = $StateMachine
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack: AttackComponent = $AttackComponent
@onready var sprite: Sprite2D = $Sprite2D

var facing: int = 1
## Tempo restante até poder iniciar outro ataque.
var attack_cooldown_left: float = 0.0
## Último knockback recebido (o estado Hurt aplica).
var last_knockback: Vector2 = Vector2.ZERO

var _target: Node2D


func _ready() -> void:
	assert(data != null, "EnemyBase precisa de um EnemyData atribuído no Inspetor!")
	# A vida vem do EnemyData (uma fonte só); o max_health do Health na cena é ignorado.
	health.max_health = data.max_health
	health.reset()
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	state_machine.init(self)


func _physics_process(delta: float) -> void:
	if attack_cooldown_left > 0.0:
		attack_cooldown_left -= delta


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, data.max_fall_speed, data.gravity * delta)


func is_dead() -> bool:
	return health.health <= 0


## O alvo é quem estiver no grupo "player" (o Player entra nele sozinho).
func get_target() -> Node2D:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player") as Node2D
	return _target


func is_target_alive() -> bool:
	var target: Node2D = get_target()
	if target == null:
		return false
	return not (target.has_method("is_dead") and target.is_dead())


func can_see_target() -> bool:
	if not is_target_alive():
		return false
	return global_position.distance_to(get_target().global_position) <= data.detect_range


func set_facing(dir: int) -> void:
	facing = dir
	sprite.flip_h = (dir < 0) if art_faces_right else (dir > 0)
	# A hitbox não pode virar no meio do golpe.
	if not attack.is_attacking():
		attack.set_facing(dir)


func _on_hit_received(_damage: int, _source: Node, knockback: Vector2) -> void:
	# O golpe fatal emite `died` antes deste sinal; não deixa o Hurt sobrescrever o Dead.
	if is_dead():
		return
	last_knockback = knockback
	state_machine.transition_to("hurt")


func _on_died() -> void:
	state_machine.transition_to("dead")
