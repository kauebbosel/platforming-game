class_name MapLayout
extends RefCounted
## O MAPA HARDCODED. Para mudar o mapa, edite só este arquivo.
##
## pos = (x, y) normalizados de 0 a 1 dentro da área do mapa
##       (x: 0 = esquerda, 1 = direita | y: 0 = topo, 1 = base).
## O mapa é lido de baixo (início) para cima (Boitatá), como no GDD.
## Os ids são livres; só precisam ser únicos.
##
## GDD-3: 11 etapas (camadas L0 a L10), sem Evento e sem Miniboss.
## Curupira na camada do meio (L5) e Boitatá no topo (L10).
## As duas Mercadoras ficam em L4 e L9, cada uma ao lado de uma Fogueira.

## MINIBOSS e EVENTO continuam no enum só para o MapTheme e o resto do código
## compilarem sem mudanças; nenhum nó os usa e eles não aparecem na legenda.
enum Kind { COMBATE, PARKOUR, MINIBOSS, MERCADORA, DESCANSO, EVENTO, MID_BOSS, BOSS }

## Nomes que aparecem na legenda.
const KIND_NAMES := {
	Kind.COMBATE: "Combate",
	Kind.PARKOUR: "Parkour",
	Kind.MERCADORA: "Mercadora",
	Kind.DESCANSO: "Descanso",
	Kind.MID_BOSS: "Curupira",
	Kind.BOSS: "Boitatá",
}

## Tamanho relativo do ícone (padrão 1.0). Os chefes são maiores.
const KIND_SCALE := {
	Kind.MID_BOSS: 1.4,
	Kind.BOSS: 1.7,
}

## De onde o Valtair "sai" antes de escolher o primeiro nó.
const ORIGIN := Vector2(0.5, 1.0)

## Nós que já começam disponíveis para escolher.
const START := ["L0_A", "L0_B", "L0_C"]

const NODES := {
	# --- Etapa 1 (início) ---
	"L0_A": {"kind": Kind.COMBATE, "pos": Vector2(0.20, 0.92)},
	"L0_B": {"kind": Kind.COMBATE, "pos": Vector2(0.50, 0.92)},
	"L0_C": {"kind": Kind.PARKOUR, "pos": Vector2(0.80, 0.92)},
	# --- Etapa 2 ---
	"L1_A": {"kind": Kind.COMBATE, "pos": Vector2(0.12, 0.832)},
	"L1_B": {"kind": Kind.COMBATE, "pos": Vector2(0.37, 0.832)},
	"L1_C": {"kind": Kind.PARKOUR, "pos": Vector2(0.63, 0.832)},
	"L1_D": {"kind": Kind.COMBATE, "pos": Vector2(0.88, 0.832)},
	# --- Etapa 3 ---
	"L2_A": {"kind": Kind.COMBATE, "pos": Vector2(0.20, 0.744)},
	"L2_B": {"kind": Kind.PARKOUR, "pos": Vector2(0.50, 0.744)},
	"L2_C": {"kind": Kind.COMBATE, "pos": Vector2(0.80, 0.744)},
	# --- Etapa 4 ---
	"L3_A": {"kind": Kind.COMBATE, "pos": Vector2(0.20, 0.656)},
	"L3_B": {"kind": Kind.COMBATE, "pos": Vector2(0.50, 0.656)},
	"L3_C": {"kind": Kind.PARKOUR, "pos": Vector2(0.80, 0.656)},
	# --- Etapa 5 (preparo para o Curupira: escolher Mercadora OU Descanso) ---
	"L4_A": {"kind": Kind.MERCADORA, "pos": Vector2(0.33, 0.568)},
	"L4_B": {"kind": Kind.DESCANSO, "pos": Vector2(0.67, 0.568)},
	# --- Etapa 6 (meio do mapa) ---
	"L5_A": {"kind": Kind.MID_BOSS, "pos": Vector2(0.50, 0.48)},
	# --- Etapa 7 ---
	"L6_A": {"kind": Kind.COMBATE, "pos": Vector2(0.20, 0.392)},
	"L6_B": {"kind": Kind.PARKOUR, "pos": Vector2(0.50, 0.392)},
	"L6_C": {"kind": Kind.COMBATE, "pos": Vector2(0.80, 0.392)},
	# --- Etapa 8 ---
	"L7_A": {"kind": Kind.PARKOUR, "pos": Vector2(0.20, 0.304)},
	"L7_B": {"kind": Kind.COMBATE, "pos": Vector2(0.50, 0.304)},
	"L7_C": {"kind": Kind.COMBATE, "pos": Vector2(0.80, 0.304)},
	# --- Etapa 9 ---
	"L8_A": {"kind": Kind.COMBATE, "pos": Vector2(0.20, 0.216)},
	"L8_B": {"kind": Kind.COMBATE, "pos": Vector2(0.50, 0.216)},
	"L8_C": {"kind": Kind.PARKOUR, "pos": Vector2(0.80, 0.216)},
	# --- Etapa 10 (preparo para o Boitatá: escolher Mercadora OU Descanso) ---
	"L9_A": {"kind": Kind.MERCADORA, "pos": Vector2(0.33, 0.128)},
	"L9_B": {"kind": Kind.DESCANSO, "pos": Vector2(0.67, 0.128)},
	# --- Etapa 11 (chefe final) ---
	"L10_A": {"kind": Kind.BOSS, "pos": Vector2(0.50, 0.04)},
}

## Caminhos: [de, para]. Sempre da camada de baixo para a de cima.
const EDGES := [
	# Etapa 1 -> 2
	["L0_A", "L1_A"], ["L0_A", "L1_B"], ["L0_B", "L1_B"], ["L0_B", "L1_C"], ["L0_C", "L1_C"], ["L0_C", "L1_D"],
	# Etapa 2 -> 3
	["L1_A", "L2_A"], ["L1_B", "L2_A"], ["L1_B", "L2_B"], ["L1_C", "L2_B"], ["L1_C", "L2_C"], ["L1_D", "L2_C"],
	# Etapa 3 -> 4
	["L2_A", "L3_A"], ["L2_A", "L3_B"], ["L2_B", "L3_B"], ["L2_B", "L3_C"], ["L2_C", "L3_B"], ["L2_C", "L3_C"],
	# Etapa 4 -> 5
	["L3_A", "L4_A"], ["L3_B", "L4_A"], ["L3_B", "L4_B"], ["L3_C", "L4_B"],
	# Etapa 5 -> Curupira
	["L4_A", "L5_A"], ["L4_B", "L5_A"],
	# Curupira -> Etapa 7
	["L5_A", "L6_A"], ["L5_A", "L6_B"], ["L5_A", "L6_C"],
	# Etapa 7 -> 8
	["L6_A", "L7_A"], ["L6_A", "L7_B"], ["L6_B", "L7_B"], ["L6_B", "L7_C"], ["L6_C", "L7_B"], ["L6_C", "L7_C"],
	# Etapa 8 -> 9
	["L7_A", "L8_A"], ["L7_B", "L8_A"], ["L7_B", "L8_B"], ["L7_B", "L8_C"], ["L7_C", "L8_C"],
	# Etapa 9 -> 10
	["L8_A", "L9_A"], ["L8_B", "L9_A"], ["L8_B", "L9_B"], ["L8_C", "L9_B"],
	# Etapa 10 -> Boitatá
	["L9_A", "L10_A"], ["L9_B", "L10_A"],
]
