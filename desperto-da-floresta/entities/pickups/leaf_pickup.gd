# entities/pickups/leaf_pickup.gd
class_name LeafPickup
extends CharacterBody2D
## Folha (a moeda) solta por um inimigo: salta, cai no chão e é coletada quando o Valtair
## chega perto. Depois de `collect_delay` ela é puxada por quem estiver a `magnet_radius`,
## e a sala pode chamar attract() para puxar todas (ex.: ao limpar a sala).
## Não conhece o RunState: só avisa pelo EventBus (leaves_gained).

@export var value: int = 1
## Tempo antes de poder ser coletada (deixa ver a Folha saltar).
@export var collect_delay: float = 0.3
@export var magnet_radius: float = 40.0
@export var magnet_speed: float = 220.0
@export var gravity: float = 600.0
@export var ground_friction: float = 400.0

@onready var _area: Area2D = $PickupArea

var _age: float = 0.0
var _attracted: bool = false
var _collected: bool = false


func _ready() -> void:
	add_to_group(&"leaf_pickups")


## Dá o impulso inicial do salto (quem solta a Folha chama isto).
func pop(impulse: Vector2) -> void:
	velocity = impulse


## Passa a ir direto até o Valtair, de qualquer distância.
func attract() -> void:
	_attracted = true


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_age += delta
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	var can_collect: bool = _age >= collect_delay and player != null

	if can_collect:
		var goal: Vector2 = player.global_position + Vector2(0.0, -10.0)
		if _attracted or global_position.distance_to(goal) <= magnet_radius:
			global_position = global_position.move_toward(goal, magnet_speed * delta)
			if global_position.distance_to(goal) < 6.0:
				_collect()
			return
		for body in _area.get_overlapping_bodies():
			if body.is_in_group(&"player"):
				_collect()
				return

	# Caindo: gravidade, e atrito quando para no chão.
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	move_and_slide()


func _collect() -> void:
	if _collected:
		return
	_collected = true
	EventBus.leaves_gained.emit(value)
	_show_popup()
	queue_free()


func _show_popup() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var label: Label = Label.new()
	label.text = "+%d" % value
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5))
	label.z_index = 10
	parent.add_child(label)
	label.global_position = global_position + Vector2(-6.0, -18.0)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)
