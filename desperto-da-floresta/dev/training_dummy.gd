extends Node2D
## Boneco de treino: pisca ao ser atingido e "renasce" ao morrer.

@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
## O nó visual precisa se chamar "Shape". Pode ser Polygon2D, Sprite2D ou AnimatedSprite2D.
@onready var shape: CanvasItem = $Shape


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hit)
	health.died.connect(_on_died)


func _on_hit(damage: int, _source: Node, _knockback: Vector2) -> void:
	print("Boneco levou ", damage, " de dano. Vida: ", health.health, "/", health.max_health)
	shape.modulate = Color(1.0, 0.35, 0.35)
	await get_tree().create_timer(0.08).timeout
	shape.modulate = Color.WHITE


func _on_died() -> void:
	await get_tree().create_timer(0.6).timeout
	health.health = health.max_health
