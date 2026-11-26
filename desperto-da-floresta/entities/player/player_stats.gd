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

@export_group("Modificadores (relíquias)")
## Estes números começam neutros; as relíquias da run os alteram (ver StatModifier).
@export var max_health_bonus: int = 0
@export var damage_taken_mult: float = 1.0
@export var melee_damage_mult: float = 1.0
@export var ranged_damage_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var projectile_speed_mult: float = 1.0

## Mortes que a Benção do Curupira impede na luta contra o Boitatá (a relíquia é consumida).
@export var boitata_death_save: int = 0

@export_group("Relíquias de comportamento")
## Multiplica as Folhas de bônus ao concluir um combate (Amuleto de Madeira).
@export var leaf_bonus_mult: float = 1.0
## Dano do PRIMEIRO golpe corpo a corpo logo depois de um dash (Pena Encantada).
@export var post_dash_damage_mult: float = 1.0
## Dano dos golpes corpo a corpo dados no ar (Garras do Gavião).
@export var air_damage_mult: float = 1.0
## Dano (golpe e bodoque) quando a vida está baixa (Dente de Piranha).
@export var low_health_damage_mult: float = 1.0
## "Vida baixa" = vida atual até esta fração da vida máxima (0.35 = 35%). Ajuste aqui.
@export_range(0.05, 1.0, 0.05) var low_health_threshold: float = 0.35
## Vida recuperada ao concluir um combate (Flor da Vitória-Régia).
@export var heal_on_clear: int = 0
## Dano devolvido a quem machuca o Valtair (Espinhos da Floresta).
@export var thorns_damage: int = 0
## Multiplica o dano de FOGO recebido (Escama do Boitatá). Quem causa fogo: EnemyData.deals_fire.
@export var fire_damage_taken_mult: float = 1.0
## Depois de um dash, a velocidade vai a este múltiplo por `post_dash_speed_time` s (Coração da Mula).
@export var post_dash_speed_mult: float = 1.0
@export var post_dash_speed_time: float = 0.0
## Vida recuperada ao derrotar um inimigo (Maldição do Mapinguari). Não sofre a redução de curas.
@export var heal_on_kill: int = 0
## Multiplica TODAS as curas (loja, fogueira, Flor da Vitória-Régia). Maldição do Mapinguari reduz.
@export var healing_mult: float = 1.0
## Mortes que a Proteção da Caipora impede em qualquer luta (a relíquia é consumida).
@export var death_saves: int = 0
## Fração da vida máxima com que o Valtair volta quando uma relíquia o salva da morte.
@export var death_save_heal_fraction: float = 0.5
