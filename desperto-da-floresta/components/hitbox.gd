class_name Hitbox
extends Area2D
## Área que CAUSA dano. Fica desligada até alguém chamar activate().
## Cada Hurtbox só é atingida uma vez por ativação.

signal hit_landed(hurtbox: Hurtbox)

@export var team: StringName = &"player"
@export var damage: int = 1
## Knockback para quem olha para a direita. O X é espelhado automaticamente
## se o Hitbox (ou um pai dele) estiver com scale.x negativo.
@export var knockback: Vector2 = Vector2(160.0, -80.0)

var source: Node
var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	monitoring = false
	monitorable = false  # ninguém precisa detectar o Hitbox


func activate() -> void:
	_already_hit.clear()
	monitoring = true


func deactivate() -> void:
	monitoring = false


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		var target := area as Hurtbox
		if target == null or target.team == team or target in _already_hit:
			continue
		_already_hit.append(target)
		var dir := signf(global_transform.x.x)
		var kb := Vector2(knockback.x * dir, knockback.y)
		target.receive_hit(damage, source if source else self, kb)
		hit_landed.emit(target)
