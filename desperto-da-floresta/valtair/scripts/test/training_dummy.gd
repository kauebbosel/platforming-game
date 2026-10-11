extends Node2D
## Boneco de treino: pisca ao ser atingido e "renasce" ao morrer.
## Serve para testar o ataque do Valtair antes de existir qualquer inimigo.

@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var shape: Polygon2D = $Shape

var _base_color: Color


func _ready() -> void:
	_base_color = shape.color
	hurtbox.hit_received.connect(_on_hit)
	health.died.connect(_on_died)


func _on_hit(damage: int, _source: Node, _knockback: Vector2) -> void:
	print("Boneco levou ", damage, " de dano. Vida: ", health.health, "/", health.max_health)
	shape.color = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	shape.color = _base_color


func _on_died() -> void:
	await get_tree().create_timer(0.6).timeout
	health.health = health.max_health
