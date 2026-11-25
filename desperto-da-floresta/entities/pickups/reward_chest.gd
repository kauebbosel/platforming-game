# entities/pickups/reward_chest.gd
class_name RewardChest
extends Area2D
## Baú do fim do Parkour (GDD 10.1: "Baú com Folhas, munição e Relíquia"). Perto dele, [E] abre
## uma vez e avisa `opened`; quem monta a sala (ParkourRoom) decide o que sai dele.
## A ORIGEM é o centro da base.

signal opened

var _near: bool = false
var _opened: bool = false
var _lid: Polygon2D
var _hint: Label


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(36, 28)
	shape.shape = rect
	shape.position = Vector2(0, -14)
	add_child(shape)

	var body: Polygon2D = Polygon2D.new()
	body.color = Color(0.5, 0.3, 0.15)
	body.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(14, -12), Vector2(-14, -12)])
	add_child(body)
	_lid = Polygon2D.new()
	_lid.color = Color(0.65, 0.4, 0.2)
	_lid.polygon = PackedVector2Array([Vector2(-15, -12), Vector2(15, -12), Vector2(15, -18), Vector2(-15, -18)])
	add_child(_lid)
	var lock: Polygon2D = Polygon2D.new()
	lock.color = Color(0.95, 0.8, 0.3)
	lock.polygon = PackedVector2Array([Vector2(-2, -10), Vector2(2, -10), Vector2(2, -15), Vector2(-2, -15)])
	add_child(lock)

	_hint = Label.new()
	_hint.text = "[%s] Abrir" % InputHint.key_name(&"interact")
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_constant_override("outline_size", 2)
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	_hint.position = Vector2(-24, -34)
	_hint.visible = false
	add_child(_hint)


func is_opened() -> bool:
	return _opened


func _unhandled_input(event: InputEvent) -> void:
	if _near and not _opened and event.is_action_pressed(&"interact"):
		_opened = true
		_hint.visible = false
		_lid.polygon = PackedVector2Array([Vector2(-15, -12), Vector2(15, -12), Vector2(15, -26), Vector2(-15, -26)])
		_lid.color = Color(0.4, 0.25, 0.12)
		opened.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_near = true
		_hint.visible = not _opened


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_near = false
		_hint.visible = false
