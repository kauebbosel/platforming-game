# entities/enemies/boitata/boitata_ember.gd
class_name BoitataEmber
extends Node2D
## Brasa do "Incêndio da copa" (GDD 9.5.2). Cai reto até o chão, machuca quem estiver no caminho
## (inclusive em plataformas) e some numa pequena nuvem. A origem é o centro da brasa.

var speed: float = 320.0
var floor_y: float = 310.0

var _hitbox: Hitbox


static func spawn(parent: Node, x: float, top_y: float, floor_y: float, fall_speed: float, damage: int, source: Node) -> BoitataEmber:
	var ember: BoitataEmber = BoitataEmber.new()
	ember.speed = fall_speed
	ember.floor_y = floor_y
	parent.add_child(ember)
	ember.global_position = Vector2(x, top_y)
	ember._hitbox.damage = damage
	ember._hitbox.source = source
	ember._hitbox.activate()
	return ember


func _ready() -> void:
	z_index = 15
	var body: Polygon2D = Polygon2D.new()
	body.color = Color(1.0, 0.55, 0.12)
	body.polygon = PackedVector2Array([Vector2(0, -11), Vector2(8, 0), Vector2(0, 11), Vector2(-8, 0)])
	add_child(body)
	var core: Polygon2D = Polygon2D.new()
	core.color = Color(1.0, 0.9, 0.45)
	core.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
	add_child(core)
	_hitbox = Hitbox.new()
	_hitbox.team = &"enemy"
	_hitbox.knockback = Vector2(0.0, -110.0)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	_hitbox.add_child(shape)
	add_child(_hitbox)


func _physics_process(delta: float) -> void:
	global_position.y += speed * delta
	if global_position.y >= floor_y - 4.0:
		DeathPuff.spawn(get_parent(), Vector2(global_position.x, floor_y - 6.0), 0.8)
		queue_free()
