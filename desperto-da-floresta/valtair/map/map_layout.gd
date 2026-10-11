class_name MapLayout
extends RefCounted
## O MAPA HARDCODED. Para mudar o mapa, edite só este arquivo.
##
## pos = (x, y) normalizados de 0 a 1 dentro da área do mapa
##       (x: 0 = esquerda, 1 = direita | y: 0 = topo, 1 = base).
## O mapa é lido de baixo (início) para cima (Boitatá), como no GDD.
## Os ids são livres; só precisam ser únicos.

enum Kind { COMBATE, PARKOUR, MINIBOSS, MERCADORA, DESCANSO, EVENTO, MID_BOSS, BOSS }

## Nomes que aparecem na legenda.
const KIND_NAMES := {
	Kind.COMBATE: "Combate",
	Kind.PARKOUR: "Parkour",
	Kind.MINIBOSS: "Miniboss",
	Kind.MERCADORA: "Mercadora",
	Kind.DESCANSO: "Descanso",
	Kind.EVENTO: "Evento",
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
	# --- Camada 0 (início) ---
	"L0_A": {"kind": Kind.COMBATE, "pos": Vector2(0.20, 0.90)},
	"L0_B": {"kind": Kind.COMBATE, "pos": Vector2(0.50, 0.90)},
	"L0_C": {"kind": Kind.PARKOUR, "pos": Vector2(0.80, 0.90)},
	# --- Camada 1 ---
	"L1_A": {"kind": Kind.EVENTO, "pos": Vector2(0.12, 0.79)},
	"L1_B": {"kind": Kind.COMBATE, "pos": Vector2(0.37, 0.79)},
	"L1_C": {"kind": Kind.COMBATE, "pos": Vector2(0.63, 0.79)},
	"L1_D": {"kind": Kind.PARKOUR, "pos": Vector2(0.88, 0.79)},
	# --- Camada 2 ---
	"L2_A": {"kind": Kind.COMBATE, "pos": Vector2(0.20, 0.68)},
	"L2_B": {"kind": Kind.MINIBOSS, "pos": Vector2(0.50, 0.68)},
	"L2_C": {"kind": Kind.EVENTO, "pos": Vector2(0.80, 0.68)},
	# --- Camada 3 (preparo para o Curupira) ---
	"L3_A": {"kind": Kind.MERCADORA, "pos": Vector2(0.33, 0.58)},
	"L3_B": {"kind": Kind.DESCANSO, "pos": Vector2(0.67, 0.58)},
	# --- Camada 4 (meio do mapa) ---
	"L4_A": {"kind": Kind.MID_BOSS, "pos": Vector2(0.50, 0.47)},
	# --- Camada 5 ---
	"L5_A": {"kind": Kind.COMBATE, "pos": Vector2(0.20, 0.36)},
	"L5_B": {"kind": Kind.PARKOUR, "pos": Vector2(0.50, 0.36)},
	"L5_C": {"kind": Kind.COMBATE, "pos": Vector2(0.80, 0.36)},
	# --- Camada 6 ---
	"L6_A": {"kind": Kind.EVENTO, "pos": Vector2(0.20, 0.26)},
	"L6_B": {"kind": Kind.MINIBOSS, "pos": Vector2(0.50, 0.26)},
	"L6_C": {"kind": Kind.COMBATE, "pos": Vector2(0.80, 0.26)},
	# --- Camada 7 (preparo para o Boitatá) ---
	"L7_A": {"kind": Kind.MERCADORA, "pos": Vector2(0.33, 0.15)},
	"L7_B": {"kind": Kind.DESCANSO, "pos": Vector2(0.67, 0.15)},
	# --- Camada 8 (chefe final) ---
	"L8_A": {"kind": Kind.BOSS, "pos": Vector2(0.50, 0.04)},
}

## Caminhos: [de, para]. Sempre da camada de baixo para a de cima.
const EDGES := [
	["L0_A", "L1_A"], ["L0_A", "L1_B"], ["L0_B", "L1_B"], ["L0_B", "L1_C"], ["L0_C", "L1_C"], ["L0_C", "L1_D"],
	["L1_A", "L2_A"], ["L1_B", "L2_A"], ["L1_B", "L2_B"], ["L1_C", "L2_B"], ["L1_C", "L2_C"], ["L1_D", "L2_C"],
	["L2_A", "L3_A"], ["L2_B", "L3_A"], ["L2_B", "L3_B"], ["L2_C", "L3_B"],
	["L3_A", "L4_A"], ["L3_B", "L4_A"],
	["L4_A", "L5_A"], ["L4_A", "L5_B"], ["L4_A", "L5_C"],
	["L5_A", "L6_A"], ["L5_A", "L6_B"], ["L5_B", "L6_B"], ["L5_C", "L6_B"], ["L5_C", "L6_C"],
	["L6_A", "L7_A"], ["L6_B", "L7_A"], ["L6_B", "L7_B"], ["L6_C", "L7_B"],
	["L7_A", "L8_A"], ["L7_B", "L8_A"],
]
