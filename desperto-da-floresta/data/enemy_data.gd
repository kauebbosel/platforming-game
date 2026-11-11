# data/enemy_data.gd
class_name EnemyData
extends Resource
## Parâmetros de comportamento de um inimigo. Crie um .tres por tipo (Corpo-Seco, Mula...).
## Tempo, dano e knockback do golpe NÃO ficam aqui: vêm do AttackData que está no
## AttackComponent do inimigo (uma fonte só para cada informação).

@export_group("Vida")
@export var max_health: int = 30

@export_group("Movimento")
@export var move_speed: float = 35.0
## Desaceleração (px/s²) quando o inimigo para ou termina o recuo.
@export var friction: float = 600.0
@export var gravity: float = 750.0
## Quanto à frente do alvo ele mira (em segundos de movimento do alvo). 0 = vai direto onde
## o alvo está; maior que 0 = tenta interceptá-lo (Mula).
@export var chase_lead_time: float = 0.0
@export var max_fall_speed: float = 300.0

@export_group("Percepção")
## Distância em que o inimigo percebe o Valtair e começa a perseguir.
@export var detect_range: float = 160.0

@export_group("Ataque")
## Distância horizontal em que ele para de andar e tenta atacar.
@export var attack_range: float = 28.0
## Nome do estado que o Chase aciona ao chegar no alcance ("attack" = garra do Corpo-Seco,
## "charge" = investida da Mula). Tem de existir um nó com esse nome no StateMachine.
@export var attack_state: StringName = &"attack"
## Diferença de altura máxima para o golpe acertar (evita bater no ar embaixo de uma plataforma).
@export var attack_vertical_range: float = 24.0
## Pausa depois de um ataque, antes de poder atacar de novo.
@export var attack_cooldown: float = 1.2
## Chance (0 a 1) de o ataque ser o arranhão duplo em vez de uma garra só.
@export_range(0.0, 1.0) var double_scratch_chance: float = 0.35
## Intervalo entre o primeiro e o segundo golpe do arranhão duplo (tempo para esquivar).
@export var double_scratch_gap: float = 0.5

@export_group("Investida")
## Velocidade horizontal durante a fase ativa da investida (só o estado Charge usa).
@export var charge_speed: float = 0.0

@export_group("Reação ao dano")
@export var hurt_duration: float = 0.25
## Fração do knockback recebido que ele realmente sofre (0.5 = recua "levemente").
@export var knockback_scale: float = 0.5

@export_group("Morte")
## Tempo parado antes de sumir.
@export var death_linger: float = 0.6
