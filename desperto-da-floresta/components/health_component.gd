# components/health_component.gd
class_name HealthComponent
extends Node
## Vida genérica. Serve para o Valtair, para os inimigos e para o boneco de treino.

signal damaged(amount: int, source: Node)
## Emitido sempre que a vida muda (dano, cura ou reset). É o sinal que o HUD usa.
signal changed(current: int, maximum: int)
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
	changed.emit(health, max_health)
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	if health <= 0:
		return  # curar não ressuscita; para isso existe reset()
	health = mini(health + amount, max_health)
	changed.emit(health, max_health)


## Restaura a vida máxima (ex.: boneco de treino renascendo, nova run).
func reset() -> void:
	health = max_health
	changed.emit(health, max_health)
