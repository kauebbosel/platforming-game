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

@onready var _spawns: Node = $Spawns
@onready var _exit: Area2D = $ExitDoor
@onready var _message: Label = $Overlay/Message

var _alive: int = 0
var _is_cleared: bool = false
var _player_at_exit: bool = false
var _exit_requested: bool = false


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
	var bonus: int = clear_bonus_leaves
	if player != null:
		bonus = roundi(clear_bonus_leaves * player.stats.leaf_bonus_mult)  # Amuleto de Madeira
		player.on_room_cleared()  # Flor da Vitória-Régia
	if bonus > 0:
		EventBus.leaves_gained.emit(bonus)
		_message.text = "Sala limpa!  +%d Folhas  [%s] na porta para sair" % [bonus, key]
	else:
		_message.text = "Sala limpa!  [%s] na porta para sair" % key
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
	return RelicDraft.spawn(self, relic_pool, reward_rarities, reward_choices, anchor, reward_spacing).size()


func _attract_leaves() -> void:
	get_tree().call_group(&"leaf_pickups", &"attract")


func _on_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = true


func _on_exit_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = false
