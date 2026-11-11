# entities/projectiles/projectile.gd
class_name Projectile
extends Area2D
## Projétil reto genérico. Quem dispara chama setup() logo após adicioná-lo à cena.
## Some ao acertar uma Hurtbox, ao bater no cenário ou quando o tempo de vida acaba.
## Estrutura da cena: Projectile (Area2D, mask = camada do cenário) com os filhos
## Sprite2D e Hitbox (com CollisionShape2D, configurada como a Hitbox do Player).
## Obs.: acima de ~600 px/s um alvo muito fino pode ser atravessado entre dois frames.

@onready var hitbox: Hitbox = $Hitbox as Hitbox
@onready var sprite: Sprite2D = $Sprite2D

var _velocity: Vector2 = Vector2.ZERO
var _life: float = 1.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	hitbox.hit_landed.connect(func(_h: Hurtbox) -> void: queue_free())
	hitbox.activate()


## `direction` não precisa estar normalizado. Horizontal (y = 0) espelha o projétil; mirado
## (diagonal) gira o projétil inteiro. Nos dois casos o knockback da Hitbox acompanha o rumo.
func setup(data: ProjectileData, direction: Vector2, shooter: CharacterBody2D) -> void:
	var dir: Vector2 = direction.normalized()
	_velocity = dir * data.speed
	sprite.modulate = data.tint
	_life = data.lifetime
	hitbox.damage = data.damage
	hitbox.team = data.team
	hitbox.knockback = data.knockback
	hitbox.source = shooter  # a Hitbox usa isso para não acertar quem atirou
	if is_zero_approx(dir.y):
		scale.x = signf(dir.x)  # espelha o projétil inteiro (sprite, formas e knockback)
	else:
		rotation = dir.angle()


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(_body: Node2D) -> void:
	queue_free()
