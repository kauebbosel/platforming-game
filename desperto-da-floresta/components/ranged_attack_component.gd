# components/ranged_attack_component.gd
class_name RangedAttackComponent
extends Node
## Dispara projétil reto. N�O lê input: quem é dono (o Player, ou a IA de um inimigo)
## chama try_fire(). O pai precisa ser um CharacterBody2D.
## O projétil é adicionado à cena onde o dono está, para não acompanhar o movimento dele.

signal fired

@export var projectile_scene: PackedScene
@export var projectile_data: ProjectileData
## Posição de saída em relação ao dono, para o lado direito (o x é espelhado com `facing`).
@export var muzzle_offset: Vector2 = Vector2(14.0, -10.0)
@export var cooldown: float = 0.35
@export var ammo_cost: int = 1
## Opcional. Sem AmmoComponent o disparo é ilimitado (útil para inimigos).
@export var ammo: AmmoComponent

@onready var body: CharacterBody2D = get_parent() as CharacterBody2D

var _cooldown_left: float = 0.0


func _ready() -> void:
	assert(projectile_scene != null, "RangedAttackComponent precisa de uma Projectile Scene no Inspetor!")
	assert(projectile_data != null, "RangedAttackComponent precisa de um Projectile Data no Inspetor!")


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


## facing: 1 = direita, -1 = esquerda. Retorna true se atirou.
func try_fire(facing: int) -> bool:
	return _fire(Vector2(facing, 0.0), facing)


## Tiro mirado: `direction` é o rumo do disparo (não precisa estar normalizado).
func try_fire_toward(direction: Vector2) -> bool:
	return _fire(direction, 1 if direction.x >= 0.0 else -1)


func _fire(direction: Vector2, side: int) -> bool:
	if _cooldown_left > 0.0:
		return false
	if ammo != null and not ammo.consume(ammo_cost):
		return false

	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	body.get_parent().add_child(projectile)
	projectile.global_position = body.global_position + Vector2(muzzle_offset.x * side, muzzle_offset.y)
	projectile.setup(projectile_data, direction, body)

	_cooldown_left = cooldown
	fired.emit()
	return true
