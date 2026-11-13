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
## Multiplicador do dano recebido (relíquias do Valtair; os inimigos ficam em 1.0).
var damage_taken_mult: float = 1.0

func _ready() -> void:
	health = max_health


func take_damage(amount: int, source: Node = null) -> void:
	if health <= 0:
		return
		
	if not is_equal_approx(damage_taken_mult, 1.0):
		amount = maxi(1, roundi(amount * damage_taken_mult))
	
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

## Define a vida atual sem passar por dano (ex.: voltar com a vida que se tinha ao entrar
## numa sala). Não mata: o mínimo é 1; para matar use take_damage().
func set_current(value: int) -> void:
	health = clampi(value, 1, max_health)
	changed.emit(health, max_health)

## Restaura a vida máxima (ex.: boneco de treino renascendo, nova run).
func reset() -> void:
	health = max_health
	changed.emit(health, max_health)
