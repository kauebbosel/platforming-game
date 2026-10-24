# data/definitions/attack_data.gd
class_name AttackData
extends Resource
## Dados de um ataque. Crie um .tres por golpe (Novo Recurso > AttackData).

enum DamageType { PHYSICAL, FIRE }

@export var id: StringName
@export_group("Dano")
@export var damage: int = 1
@export var damage_type: DamageType = DamageType.PHYSICAL
## x positivo empurra para longe do atacante (a direção é aplicada em runtime)
@export var knockback: Vector2 = Vector2(180, -80)
@export var hitstun: float = 0.2
@export var hitstop_frames: int = 3
@export_group("Tempo (em frames de física)")
@export var startup_frames: int = 4
@export var active_frames: int = 4
@export var recovery_frames: int = 8
@export_group("Visual")
@export var vfx: SpriteFrames


func startup_time() -> float:
	return startup_frames / float(Engine.physics_ticks_per_second)


func active_time() -> float:
	return active_frames / float(Engine.physics_ticks_per_second)


func recovery_time() -> float:
	return recovery_frames / float(Engine.physics_ticks_per_second)
