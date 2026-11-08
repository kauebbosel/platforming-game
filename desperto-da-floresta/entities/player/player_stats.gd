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

@export var fall_gravity_multiplier: float = 1.0

@export_group("Dash")
@export var dash_distance: float = 96.0
@export var dash_duration: float = 0.20
## Conta desde o início do dash (inclui a duração dele).
@export var dash_cooldown: float = 0.6
@export var max_air_dashes: int = 1
## 0 = dash reto, sem cair durante ele.
@export var dash_gravity_multiplier: float = 0.0

@export_group("Morte")
## Pausa entre morrer e reiniciar a sala (o Valtair fica parado, sem controle).
@export_range(0.0, 5.0, 0.1, "suffix:s") var death_pause_time: float = 1.0
