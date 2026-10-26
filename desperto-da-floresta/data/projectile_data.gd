# data/definitions/projectile_data.gd
class_name ProjectileData
extends Resource
## Dados de um projétil reto. Crie um .tres por tipo (pedra do Valtair, bola de fogo da Cuca...).

@export var speed: float = 320.0
## Tempo máximo de vida em segundos (o projétil some mesmo sem acertar nada).
@export var lifetime: float = 1.2
@export var damage: int = 1
