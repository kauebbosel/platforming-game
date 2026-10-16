# data/player/PlayerStats.gd
class_name PlayerStats
extends Resource
## Recurso de dados que centraliza todos os atributos e parâmetros de movimentação do Player.
## Mudar os valores neste recurso altera o feeling do jogo sem tocar em nenhuma linha de código.

@export_group("Movimentação Horizontal")
@export var move_speed: float = 120.0

@export_group("Pulo e Gravidade")
@export var jump_velocity: float = -260.0
@export var gravity: float = 750.0
@export var max_fall_speed: float = 300.0
@export var jump_cut_multiplier: float = 0.5

@export_group("Assistências de Jogabilidade (Game Feel)")
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.10

@export_group("Atributos de Combate")
@export var max_health: int = 5
