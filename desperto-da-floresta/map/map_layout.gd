class_name MapLayout
extends RefCounted
## O MAPA. A ESTRUTURA (posições e caminhos) é fixa; os TIPOS dos nós são sorteados a cada
## run a partir de uma semente (seed), seguindo regras. Mesma semente = mesmo mapa, então dá
## para reproduzir a run de qualquer jogador.
##
## Quem lê o mapa (MapScreen etc.) continua usando MapLayout.NODES / EDGES / START como antes.
## NODES agora é uma variável estática: começa igual ao mapa fixo antigo (TEMPLATE_NODES) e
## passa a ser o mapa sorteado quando generate(seed) é chamado (o SceneManager faz isso).
##
## pos = (x, y) normalizados de 0 a 1 dentro da área do mapa
##       (x: 0 = esquerda, 1 = direita | y: 0 = topo, 1 = base).
## O mapa é lido de baixo (início) para cima (Boitatá), como no GDD.
## GDD-3: 11 etapas (camadas L0 a L10), sem Evento. Curupira na camada do meio (L5) e
## Boitatá no topo (L10). As duas Mercadoras ficam em L4 e L9, cada uma ao lado de uma Fogueira.

## MINIBOSS (elite) e EVENTO continuam no enum para o MapTheme e o resto do código compilarem.
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


# ====================================================================== SORTEIO
## 0 = semente aleatória a cada run. Qualquer outro número força essa semente
## (para testar um mapa específico ou reproduzir a run de alguém).
const DEBUG_FORCED_SEED: int = 0


## Camadas em que combate/parkour são sorteados: {camada: [mín. de parkour, máx. de parkour]}.
## O resto da camada vira combate. A camada 0 tem sempre exatamente 1 parkour, para o
## jogador ver os dois tipos de sala logo na primeira escolha.
const PARKOUR_PER_LAYER := {
	0: [1, 1],
	1: [1, 2],
	2: [1, 1],
	3: [0, 1],
	6: [1, 1],
	7: [1, 2],
	8: [1, 1],
}

## Camadas de preparo para um chefe (Mercadora e Descanso). Cada uma tem 50% de chance de
## trocar de lado.
const SHOP_REST_LAYERS: Array[int] = [4, 9]

## Elites (Kind.MINIBOSS). A sala de elite ainda não existe: deixe false até criá-la, senão o
## nó apareceria no mapa sem sala. Ao ligar, ELITE_COUNT camadas de ELITE_LAYERS ganham 1 elite.
const ELITES_ENABLED: bool = false
const ELITE_LAYERS: Array[int] = [3, 6, 7, 8]
const ELITE_COUNT: int = 3

## Deslocamento aleatório (em coordenadas normalizadas) das posições, só para o mapa não
## parecer idêntico. Chefes não se mexem.
const POS_JITTER := Vector2(0.02, 0.008)

## Tentativas de sorteio até achar um mapa que passe nas regras de _is_valid().
const MAX_ATTEMPTS: int = 64

## O mapa-base: posições e tipos "de fábrica". Os tipos das camadas sorteadas são
## sobrescritos por generate(); as demais (Mercadora/Descanso/chefes) vêm daqui.
const TEMPLATE_NODES := {
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

## Mapa em uso. Antes de generate() ser chamado é uma cópia do mapa-base (o mapa fixo antigo).
## (Maiúsculas de propósito: mantém `MapLayout.NODES` funcionando em quem já o usa.)
static var NODES: Dictionary = TEMPLATE_NODES.duplicate(true)

static var _generated_seed: int = -1


## Sorteia o mapa desta run. Chamar de novo com a mesma semente não faz nada (e dá o mesmo
## resultado de qualquer jeito: o sorteio só depende da semente).
static func generate(seed_value: int) -> void:
	if seed_value == _generated_seed:
		return
	var rng := RandomNumberGenerator.new()
	var nodes: Dictionary = {}
	var valid: bool = false
	for attempt in MAX_ATTEMPTS:
		rng.seed = seed_value * 1000003 + attempt
		nodes = _roll(rng)
		if _is_valid(nodes):
			valid = true
			break
	if not valid:
		push_warning("MapLayout: nenhum sorteio passou nas regras em %d tentativas (semente %d). Usando o último." % [MAX_ATTEMPTS, seed_value])
	NODES = nodes
	_generated_seed = seed_value


## "L10_A" -> 10
static func layer_of(id: String) -> int:
	return id.substr(1, id.find("_") - 1).to_int()


static func _ids_by_layer() -> Dictionary:
	var out: Dictionary = {}
	for id: String in TEMPLATE_NODES:
		var layer: int = layer_of(id)
		if not out.has(layer):
			out[layer] = []
		(out[layer] as Array).append(id)
	return out


## Embaralha com o NOSSO gerador (Array.shuffle() usaria o aleatório global e quebraria a semente).
static func _shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var a: Array = items.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


static func _roll(rng: RandomNumberGenerator) -> Dictionary:
	var nodes: Dictionary = TEMPLATE_NODES.duplicate(true)
	var by_layer: Dictionary = _ids_by_layer()

	# 1) Combate x Parkour nas camadas sorteadas.
	for layer: int in PARKOUR_PER_LAYER:
		var ids: Array = _shuffled(by_layer[layer], rng)
		var limits: Array = PARKOUR_PER_LAYER[layer]
		var parkour_count: int = mini(rng.randi_range(limits[0], limits[1]), ids.size() - 1)
		for i in ids.size():
			nodes[ids[i]]["kind"] = Kind.PARKOUR if i < parkour_count else Kind.COMBATE

	# 2) Elites (desligados até a sala de elite existir).
	if ELITES_ENABLED:
		var layers: Array = _shuffled(ELITE_LAYERS, rng)
		for i in mini(ELITE_COUNT, layers.size()):
			for id: String in _shuffled(by_layer[layers[i]], rng):
				if nodes[id]["kind"] == Kind.COMBATE:
					nodes[id]["kind"] = Kind.MINIBOSS
					break

	# 3) Mercadora e Descanso: às vezes trocam de lado.
	for layer in SHOP_REST_LAYERS:
		if rng.randf() < 0.5:
			var a: String = "L%d_A" % layer
			var b: String = "L%d_B" % layer
			var tmp: int = nodes[a]["kind"]
			nodes[a]["kind"] = nodes[b]["kind"]
			nodes[b]["kind"] = tmp

	# 4) Pequeno desvio nas posições (menos os chefes).
	for id: String in nodes:
		var kind: int = nodes[id]["kind"]
		if kind == Kind.MID_BOSS or kind == Kind.BOSS:
			continue
		var pos: Vector2 = nodes[id]["pos"]
		pos.x += rng.randf_range(-POS_JITTER.x, POS_JITTER.x)
		pos.y += rng.randf_range(-POS_JITTER.y, POS_JITTER.y)
		nodes[id]["pos"] = pos
	return nodes


## Regras que o sorteio precisa respeitar:
##  - nenhum caminho tem 3 Parkours seguidos;
##  - nenhum caminho tem 2 Elites seguidos.
static func _is_valid(nodes: Dictionary) -> bool:
	var children: Dictionary = {}
	for e: Array in EDGES:
		if not children.has(e[0]):
			children[e[0]] = []
		(children[e[0]] as Array).append(e[1])
	for e: Array in EDGES:
		var from_kind: int = nodes[e[0]]["kind"]
		var to_kind: int = nodes[e[1]]["kind"]
		if from_kind == Kind.MINIBOSS and to_kind == Kind.MINIBOSS:
			return false
		if from_kind == Kind.PARKOUR and to_kind == Kind.PARKOUR:
			var kids: Array = children.get(e[1], [])
			for c: String in kids:
				if nodes[c]["kind"] == Kind.PARKOUR:
					return false
	return true
