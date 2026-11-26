# levels/combat_room.gd
class_name CombatRoom
extends Node2D
## Sala de combate: nasce com um inimigo em cada ponto de "Spawns" (EnemySpawn, que escolhe
## o tipo de inimigo; ou um Marker2D simples, que usa o padrão da sala) e, quando todos
## morrem, libera a porta de saída. Não conhece o mapa nem o RunState: só avisa pelo
## EventBus (room_exit_requested) e o SceneManager decide para onde ir.

signal cleared

## Inimigo padrão: nasce nos pontos que não escolhem o próprio (ex.: corpo_seco.tscn).
## Pode ficar vazio se todo ponto de nascimento for um EnemySpawn com inimigo definido.
@export var enemy_scene: PackedScene
## Folhas que a sala dá de bônus ao ser limpa (além das que os inimigos soltam).
@export var clear_bonus_leaves: int = 10
## Ao limpar a sala, aparecem `reward_choices` relíquias sobre pedestais perto da porta e o
## jogador leva UMA (as outras somem). As raras só na loja e no Curupira.
@export var give_relic_reward: bool = true
@export var reward_choices: int = 2
## Distância entre os pedestais da escolha.
@export var reward_spacing: float = 56.0
@export var relic_pool: RelicPool = preload("res://relics/relic_pool.tres")
@export var reward_rarities: Array[RelicData.Rarity] = [RelicData.Rarity.COMMON, RelicData.Rarity.UNCOMMON]
## Onde o CENTRO do grupo de pedestais fica, relativo à porta de saída.
@export var reward_offset: Vector2 = Vector2(-80.0, 22.0)
## Sala de Elite (nó "Elite" do mapa): UM dos inimigos nasce reforçado e com um afixo (ver
## EnemyAffix). A recompensa é maior e a escolha de relíquia vem de raridades melhores.
@export var elite_bonus_leaves: int = 25
@export var elite_choices: int = 2
@export var elite_rarities: Array[RelicData.Rarity] = [RelicData.Rarity.UNCOMMON, RelicData.Rarity.RARE]
## Quanto tempo o aviso do elite fica na tela ao entrar (s).
@export var elite_banner_time: float = 4.0

@onready var _spawns: Node = $Spawns
@onready var _exit: Area2D = $ExitDoor
@onready var _message: Label = $Overlay/Message

var _alive: int = 0
var _is_cleared: bool = false
var _player_at_exit: bool = false
var _exit_requested: bool = false
## Inimigos que nasceram (para escolher quem vira elite).
var _enemies: Array[EnemyBase] = []
## Afixo do elite desta sala (-1 = sala comum). O mapa decide, via RunState.
var _elite_affix: int = -1
var _elite_name: String = ""


func _ready() -> void:
	_exit.visible = false
	_exit.monitoring = false
	_exit.body_entered.connect(_on_exit_body_entered)
	_exit.body_exited.connect(_on_exit_body_exited)
	_message.visible = false

	for marker in _spawns.get_children():
		if marker is Marker2D:
			_spawn_at(marker as Marker2D)
	if _alive == 0:
		_clear()
	elif EnemyAffix.is_valid(RunState.elite_affix):
		_make_elite(RunState.elite_affix, RunState.elite_slot)  # sala de Elite


func alive_enemies() -> int:
	return _alive


func is_cleared() -> bool:
	return _is_cleared


## O ponto escolhe o inimigo (EnemySpawn); sem escolha, vale o padrão da sala.
func _spawn_at(marker: Marker2D) -> void:
	var scene: PackedScene = enemy_scene
	if marker is EnemySpawn and (marker as EnemySpawn).enemy_scene != null:
		scene = (marker as EnemySpawn).enemy_scene
	if scene == null:
		push_warning("CombatRoom: o ponto '%s' não tem inimigo (defina Enemy Scene nele ou na sala)." % marker.name)
		return
	_spawn_enemy(scene, to_local(marker.global_position))


func _spawn_enemy(scene: PackedScene, at: Vector2) -> void:
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	enemy.position = at
	add_child(enemy)
	_enemies.append(enemy)
	enemy.health.died.connect(_on_enemy_died)
	_alive += 1


func _on_enemy_died() -> void:
	_alive -= 1
	if _alive <= 0:
		_clear()


func _clear() -> void:
	_is_cleared = true
	_exit.visible = true
	_exit.set_deferred("monitoring", true)
	var key: String = InputHint.key_name(&"interact")
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var is_elite: bool = _elite_affix >= 0
	var base_bonus: int = elite_bonus_leaves if is_elite else clear_bonus_leaves
	var title: String = "Elite derrotado!" if is_elite else "Sala limpa!"
	var bonus: int = base_bonus
	if player != null:
		bonus = roundi(base_bonus * player.stats.leaf_bonus_mult)  # Amuleto de Madeira
		player.on_room_cleared()  # Flor da Vitória-Régia
	if bonus > 0:
		EventBus.leaves_gained.emit(bonus)
		_message.text = "%s  +%d Folhas  [%s] na porta para sair" % [title, bonus, key]
	else:
		_message.text = "%s  [%s] na porta para sair" % [title, key]
	# As Folhas que ficaram no chão vão até o Valtair (dá um instante para as últimas caírem).
	get_tree().create_timer(0.6).timeout.connect(_attract_leaves)
	var offered: int = _spawn_relic_reward()
	if offered > 1:
		_message.text += "\nEscolha 1 de %d relíquias: [%s] sobre a que quiser (as outras somem)" % [offered, key]
	elif offered == 1:
		_message.text += "\nUma relíquia apareceu: [%s] sobre ela para pegar" % key
	_message.visible = true
	cleared.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _is_cleared and _player_at_exit and not _exit_requested and event.is_action_pressed(&"interact"):
		_exit_requested = true
		EventBus.room_exit_requested.emit()


## Cria os pedestais da escolha (relíquias que o jogador ainda não tem). Retorna quantos criou.
func _spawn_relic_reward() -> int:
	if not give_relic_reward:
		return 0
	var anchor: Vector2 = _exit.global_position + reward_offset
	var is_elite: bool = _elite_affix >= 0
	var choices: int = elite_choices if is_elite else reward_choices
	var rarities: Array = elite_rarities if is_elite else reward_rarities
	return RelicDraft.spawn(self, relic_pool, rarities, choices, anchor, reward_spacing).size()


## Sala de Elite: entre os inimigos que nasceram, escolhe quem vira elite (só os que têm
## EnemyData.can_be_elite; se nenhum tiver, vale qualquer um) e aplica o afixo. O `slot` vem do
## mapa e desempata de forma reproduzível (mesma semente = mesmo elite).
func _make_elite(affix: int, slot: int) -> void:
	var eligible: Array[EnemyBase] = []
	for enemy in _enemies:
		if enemy.data != null and enemy.data.can_be_elite:
			eligible.append(enemy)
	if eligible.is_empty():
		eligible = _enemies.duplicate()
	if eligible.is_empty():
		return
	var elite: EnemyBase = eligible[slot % eligible.size()]
	EnemyAffix.apply(elite, affix)
	_elite_affix = affix
	_elite_name = elite.scene_file_path.get_file().get_basename().capitalize()  # "corpo_seco" -> "Corpo Seco"
	if _elite_name.is_empty():
		_elite_name = String(elite.name)
	_show_elite_banner()


## Aviso ao entrar numa sala de Elite: nome do inimigo + afixo e o que ele faz.
func _show_elite_banner() -> void:
	_message.text = "ELITE: %s %s\n%s" % [_elite_name, EnemyAffix.name_of(_elite_affix), EnemyAffix.description_of(_elite_affix)]
	_message.visible = true
	get_tree().create_timer(elite_banner_time).timeout.connect(_hide_elite_banner)


func _hide_elite_banner() -> void:
	if not _is_cleared:
		_message.visible = false


func _attract_leaves() -> void:
	get_tree().call_group(&"leaf_pickups", &"attract")


func _on_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = true


func _on_exit_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = false
