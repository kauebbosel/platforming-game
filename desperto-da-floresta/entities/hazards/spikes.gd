# entities/hazards/spikes.gd
class_name Spikes
extends Area2D
## Faixa de espinhos (GDD 10.1, nó Parkour). A ORIGEM é o centro da BASE; os espinhos apontam
## para cima. Encostar causa `damage` e avisa `player_touched`; quem monta a sala (ParkourRoom)
## então devolve o Valtair ao último ponto seguro, para ele não ficar preso nos espinhos.

signal player_touched(player: Node2D)

@export var width: float = 40.0
@export var damage: int = 15

const HEIGHT: float = 8.0
const TOOTH: float = 8.0


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	add_to_group(&"hazards")
	body_entered.connect(_on_body_entered)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(width, HEIGHT)
	shape.shape = rect
	shape.position = Vector2(0.0, -HEIGHT / 2.0)
	add_child(shape)

	var x: float = -width / 2.0
	while x < width / 2.0:
		var tooth: Polygon2D = Polygon2D.new()
		tooth.color = Color(0.75, 0.72, 0.7)
		var right: float = minf(x + TOOTH, width / 2.0)
		tooth.polygon = PackedVector2Array([Vector2(x, 0), Vector2((x + right) / 2.0, -HEIGHT), Vector2(right, 0)])
		add_child(tooth)
		x += TOOTH


## O ponto (global) está em cima ou muito perto destes espinhos? (para não salvar o "ponto seguro" ali)
func is_near(point: Vector2, margin: float = 24.0) -> bool:
	return absf(point.x - global_position.x) <= width / 2.0 + margin and absf(point.y - global_position.y) <= 40.0


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	var hurtbox: Hurtbox = body.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox != null:
		hurtbox.receive_hit(damage, self, Vector2.ZERO)
	player_touched.emit(body)
