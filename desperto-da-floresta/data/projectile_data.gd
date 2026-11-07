# data/projectile_data.gd
class_name ProjectileData
extends Resource
## Dados de um projétil reto. Crie um .tres por tipo (pedra do Valtair, bola de fogo da Cuca...).

@export var speed: float = 320.0
## Tempo máximo de vida em segundos (o projétil some mesmo sem acertar nada).
@export var lifetime: float = 1.2
@export var damage: int = 1
## Quem o projétil NÃO atinge: só acerta Hurtboxes de outro time.
## O padrão é "player" (pedra do Valtair). Projéteis de inimigos precisam de &"enemy".
@export var team: StringName = &"player"
## Knockback para quem atira para a direita; o X é espelhado com a direção do tiro.
@export var knockback: Vector2 = Vector2(160.0, -80.0)
