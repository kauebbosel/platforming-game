# components/hurtbox.gd
class_name Hurtbox
extends Area2D
## Área que RECEBE dano. Coloque em qualquer coisa que possa ser atingida.
## `team` evita fogo amigo: um Hitbox só atinge Hurtboxes de outro time.
##
## Invulnerabilidade: depois de levar um golpe, a Hurtbox ignora novos golpes por
## `invulnerability_time` segundos. Com 0 (padrão) ela fica desligada, como no boneco
## de treino. Quem quiser mostrar isso (pisca, som) escuta os sinais; a Hurtbox não
## sabe nada de visual.

signal hit_received(damage: int, source: Node, knockback: Vector2)
signal invulnerability_started(duration: float)
signal invulnerability_ended

@export var team: StringName = &"enemy"
## Opcional. Se vazio, procura um irmão chamado "Health".
@export var health: HealthComponent
## Segundos de invulnerabilidade depois de levar um golpe. 0 = desligado.
@export_range(0.0, 3.0, 0.05, "suffix:s") var invulnerability_time: float = 0.0

var _invulnerable_left: float = 0.0


func _ready() -> void:
	monitoring = false  # só precisa ser detectada, não detecta nada
	set_physics_process(false)  # só liga enquanto houver invulnerabilidade rodando
	if health == null and get_parent():
		health = get_parent().get_node_or_null("Health") as HealthComponent


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func receive_hit(damage: int, source: Node, knockback: Vector2) -> void:
	if is_invulnerable():
		return
	if health:
		health.take_damage(damage, source)
	hit_received.emit(damage, source, knockback)
	# Se o golpe matou, não há por que ficar invulnerável (nem piscar).
	var still_alive: bool = health == null or health.health > 0
	if invulnerability_time > 0.0 and still_alive:
		_start_invulnerability()


func _physics_process(delta: float) -> void:
	_invulnerable_left -= delta
	if _invulnerable_left <= 0.0:
		_invulnerable_left = 0.0
		set_physics_process(false)
		invulnerability_ended.emit()


func _start_invulnerability() -> void:
	_invulnerable_left = invulnerability_time
	set_physics_process(true)
	invulnerability_started.emit(invulnerability_time)
