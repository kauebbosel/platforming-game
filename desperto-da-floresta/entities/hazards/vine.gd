# entities/hazards/vine.gd
class_name Vine
extends Area2D
## Cipó (GDD 10.1, nó Parkour). Perto dele, [W] ou [S] fazem o Valtair agarrar e subir/descer
## (estado Climb do Player); [Espaço] solta com um pulo.
## A ORIGEM do nó é o TOPO do cipó, na altura da superfície da plataforma onde ele termina:
## ao chegar lá em cima o Valtair sobe para a plataforma. `length` é o comprimento até embaixo.
## A área de agarrar vai um pouco acima do topo, para dar para descer do cipó a partir da
## plataforma ([S] em cima dele).

@export var length: float = 120.0

const WIDTH: float = 14.0
const REACH_ABOVE: float = 14.0


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2  # o corpo do Valtair
	add_to_group(&"vines")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(WIDTH, length + REACH_ABOVE)
	shape.shape = rect
	shape.position = Vector2(0.0, (length - REACH_ABOVE) / 2.0)
	add_child(shape)

	var rope: Line2D = Line2D.new()
	rope.width = 2.0
	rope.default_color = Color(0.25, 0.55, 0.2)
	rope.points = PackedVector2Array([Vector2(0, -REACH_ABOVE), Vector2(0, length)])
	rope.z_index = -1
	add_child(rope)
	var y: float = 10.0
	var side: float = 1.0
	while y < length:
		var leaf: Polygon2D = Polygon2D.new()
		leaf.color = Color(0.35, 0.7, 0.25)
		leaf.polygon = PackedVector2Array([Vector2(0, y), Vector2(5.0 * side, y - 2.0), Vector2(0, y + 3.0)])
		leaf.z_index = -1
		add_child(leaf)
		side = -side
		y += 16.0


## Altura (global) da superfície onde o cipó termina em cima.
func get_top_y() -> float:
	return global_position.y


## Altura (global) do pé do cipó.
func get_bottom_y() -> float:
	return global_position.y + length


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		body.nearby_vine = self


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player") and body.nearby_vine == self:
		body.nearby_vine = null
