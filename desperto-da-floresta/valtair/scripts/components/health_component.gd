class_name HealthComponent
extends Node
## Vida genérica. Serve para o Valtair, para os inimigos e para o boneco de treino.

signal damaged(amount: int, source: Node)
signal died

@export var max_health: int = 5

var health: int


func _ready() -> void:
	health = max_health


func take_damage(amount: int, source: Node = null) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	damaged.emit(amount, source)
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
