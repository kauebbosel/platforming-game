# core/run_state.gd
extends Node
## Tudo o que precisa sobreviver à troca de cena durante uma run (vida, munição, progresso
## no mapa). Registre como Autoload "RunState", SEM class_name, depois do EventBus.
## Só guarda dados: quem decide quando trocar de cena é o SceneManager.
## Fora de uma run (ex.: a test_arena aberta com F6) `run_active` é falso e todo o jogo
## se comporta como antes, sem ler nem gravar nada aqui.

var run_active: bool = false

## Estado atual do Valtair. -1 = ainda não definido (o Player usa os valores da cena).
var health: int = -1
var ammo: int = -1

## Folhas (a moeda). Vêm de inimigos e de salas limpas; a loja as gasta.
var leaves: int = 0

## Relíquias que o Valtair tem nesta run (aplicadas ao PlayerStats pelo Player).
var relics: Array[RelicData] = []

## Cópia de `health` e `ammo` no momento em que a sala atual começou.
## É o que volta quando o Valtair morre e a sala reinicia.
var entry_health: int = -1
var entry_ammo: int = -1
var entry_leaves: int = 0
var entry_relics: Array[RelicData] = []

## Progresso no mapa (formato do MapScreen.export_progress()). Vazio = origem.
var map_progress: Dictionary = {}

## Semente do sorteio do mapa desta run (ver MapLayout.generate). Com a mesma semente o mapa
## sai igual, então ela serve para reproduzir a run de um jogador.
var map_seed: int = 0

## Atributos que estão NO LIMITE agora (ver StatLimits). Recalculado a cada apply_relics(); o HUD,
## a loja, o pedestal e o menu de pausa leem esta lista.
var capped_stats: Array[StringName] = []

## Elite da sala em que o Valtair está: o SceneManager preenche ao escolher o nó do mapa e a
## CombatRoom lê ao nascer. -1 = sala comum. `elite_slot` diz qual dos inimigos da sala vira o
## elite (o índice é contado entre os pontos de nascimento).
var elite_affix: int = -1
var elite_slot: int = 0


func _ready() -> void:
	EventBus.leaves_gained.connect(add_leaves)


## Soma Folhas (ou tira, se negativo) e avisa o HUD. Conta mesmo fora de uma run, para
## dar para testar a coleta na test_arena.
func add_leaves(amount: int) -> void:
	leaves = maxi(0, leaves + amount)
	EventBus.leaves_changed.emit(leaves)


func has_relic(relic: RelicData) -> bool:
	for r in relics:
		if r.id == relic.id:
			return true
	return false


func add_relic(relic: RelicData) -> void:
	if not has_relic(relic):
		relics.append(relic)


## Remove uma relíquia da run (as que se consomem: Proteção da Caipora e Benção do Curupira).
func consume_relic(relic: RelicData) -> void:
	for i in relics.size():
		if relics[i].id == relic.id:
			relics.remove_at(i)
			return


## Aplica todas as relíquias da run a uma cópia do PlayerStats (o Player chama isto em
## refresh_stats()). Se algum atributo ACABOU de bater no limite, avisa pelo EventBus.
func apply_relics(stats: Object) -> void:
	var before: Array[StringName] = capped_stats
	capped_stats = _apply(stats, relics)
	var newly_capped: Array = []
	for stat in capped_stats:
		if not before.has(stat):
			newly_capped.append(stat)
	if not newly_capped.is_empty():
		EventBus.stat_limit_reached.emit(newly_capped)


## O cálculo em si (não mexe na run nem emite sinais; serve também para simular).
## Regras de empilhamento:
##  - bônus em porcentagem (MULTIPLY com valor > 1) de um MESMO atributo se SOMAM: três relíquias
##    de +50% dão x2,5 (1 + 0,5 + 0,5 + 0,5), e não x3,375;
##  - reduções (MULTIPLY com valor <= 1) continuam se multiplicando (0,85 x 0,9 = 0,765), que já
##    tem retorno decrescente e nunca chega a zero;
##  - somas (ADD) e o resto seguem como antes (StatModifier.apply);
##  - por fim os limites de StatLimits. Devolve os atributos que ficaram no limite.
func _apply(stats: Object, list: Array[RelicData]) -> Array[StringName]:
	var base: Dictionary = StatLimits.base_values(stats)
	var bonus: Dictionary = {}  # atributo -> soma de (valor - 1)
	for relic in list:
		for modifier in relic.modifiers:
			if modifier.op == StatModifier.Op.MULTIPLY and modifier.value > 1.0:
				bonus[modifier.stat] = float(bonus.get(modifier.stat, 0.0)) + (modifier.value - 1.0)
			else:
				modifier.apply(stats)
	for stat: StringName in bonus:
		if not (stat in stats):
			push_warning("RunState: o PlayerStats não tem o campo '%s'." % stat)
			continue
		var current: Variant = stats.get(stat)
		var result: float = float(current) * (1.0 + float(bonus[stat]))
		if typeof(current) == TYPE_INT:
			stats.set(stat, roundi(result))
		else:
			stats.set(stat, result)
	return StatLimits.apply(stats, base)


## Simula o que mudaria se o Valtair pegasse `relic` agora, sem tocar na run nem emitir sinais.
## `base_stats` é o PlayerStats de fábrica (o Player passa o dele: Player.preview_relic()).
## Devolve {"no_effect": [...], "reaches": [...]} com nomes de atributos DESTA relíquia:
##  - no_effect: já estão no limite e continuariam iguais (a relíquia não ajuda neles);
##  - reaches: passariam a bater no limite por causa dela (parte do bônus se perde).
func preview_relic(relic: RelicData, base_stats: PlayerStats) -> Dictionary:
	var current: PlayerStats = base_stats.duplicate() as PlayerStats
	_apply(current, relics)
	var with_relic: Array[RelicData] = []
	with_relic.assign(relics)
	with_relic.append(relic)
	var after: PlayerStats = base_stats.duplicate() as PlayerStats
	var hit: Array[StringName] = _apply(after, with_relic)
	var no_effect: Array[StringName] = []
	var reaches: Array[StringName] = []
	for modifier in relic.modifiers:
		var stat: StringName = modifier.stat
		if not hit.has(stat) or no_effect.has(stat) or reaches.has(stat):
			continue
		if is_equal_approx(float(after.get(stat)), float(current.get(stat))):
			no_effect.append(stat)
		else:
			reaches.append(stat)
	return {"no_effect": no_effect, "reaches": reaches}


func start_run() -> void:
	reset()
	run_active = true


func end_run() -> void:
	reset()


func reset() -> void:
	run_active = false
	health = -1
	ammo = -1
	entry_health = -1
	entry_ammo = -1
	leaves = 0
	entry_leaves = 0
	relics.clear()
	entry_relics.clear()
	capped_stats.clear()
	map_progress = {}
	map_seed = 0
	elite_affix = -1
	elite_slot = 0


func begin_room() -> void:
	entry_health = health
	entry_ammo = ammo
	entry_leaves = leaves
	entry_relics.assign(relics)


func restore_room_entry() -> void:
	health = entry_health
	ammo = entry_ammo
	leaves = entry_leaves
	relics.assign(entry_relics)
