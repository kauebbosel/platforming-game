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
## Cor do projétil (para distinguir o tiro inimigo da pedra do Valtair).
@export var tint: Color = Color.WHITE
## Knockback para quem atira para a direita; o X é espelhado com a direção do tiro.
@export var knockback: Vector2 = Vector2(160.0, -80.0)
## Arte do projétil (opcional). Sem ela, vale o sprite padrão da cena (o ícone da Godot).
@export var texture: Texture2D
## Quadros da arte lado a lado (spritesheet em uma linha) e a velocidade da animação.
@export var hframes: int = 1
@export var fps: float = 10.0
## Escala do sprite e deslocamento (para centralizar uma arte que não está no meio da célula).
@export var sprite_scale: float = 1.0
@export var sprite_offset: Vector2 = Vector2.ZERO
