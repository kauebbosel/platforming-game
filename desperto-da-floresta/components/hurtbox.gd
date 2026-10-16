class_name Hurtbox
extends Area2D
## Área que RECEBE dano. Coloque em qualquer coisa que possa ser atingida.
## `team` evita fogo amigo: um Hitbox só atinge Hurtboxes de outro time.

signal hit_received(damage: int, source: Node, knockback: Vector2)

@export var team: StringName = &"enemy"
## Opcional. Se vazio, procura um irmão chamado "Health".
@export var health: HealthComponent


func _ready() -> void:
	monitoring = false  # só precisa ser detectada, não detecta nada
	if health == null and get_parent():
		health = get_parent().get_node_or_null("Health") as HealthComponent


func receive_hit(damage: int, source: Node, knockback: Vector2) -> void:
	if health:
		health.take_damage(damage, source)
	hit_received.emit(damage, source, knockback)
