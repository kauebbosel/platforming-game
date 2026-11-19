# levels/boss_room.gd
class_name BossRoom
extends Node2D
## Sala do chefe do meio (Curupira, GDD 7.2 e 9.4). Fluxo:
##   1. Ao entrar: diálogo "antes do combate" (jogo pausado), depois o chefe luta.
##   2. Se o Valtair morre: diálogo "após a derrota" e segue o fluxo normal de morte.
##   3. Se o chefe morre: diálogo "após a vitória", +Folhas, a Benção do Curupira (sempre) e
##      3 relíquias para ESCOLHER UMA (ao pegar uma, as outras somem). A porta libera a saída.
## Como a CombatRoom, não conhece o mapa: avisa pelo EventBus (room_exit_requested).

signal cleared

const PEDESTAL_SCENE: PackedScene = preload("res://entities/pickups/relic_pedestal.tscn")
## Recompensa fixa de quem derrota o Curupira (GDD 12.4). Não está no RelicPool de propósito.
const BLESSING: RelicData = preload("res://relics/bencao_do_curupira.tres")

@export var boss_scene: PackedScene
@export var boss_name: String = "Curupira"
## Folhas de bônus ao derrotar o chefe (GDD 12.1: 50).
@export var clear_bonus_leaves: int = 50
@export var relic_pool: RelicPool = preload("res://relics/relic_pool.tres")
@export var choice_count: int = 3
## Onde fica o primeiro pedestal, relativo à porta; os outros seguem para a direita.
@export var choice_offset: Vector2 = Vector2(-190.0, 22.0)
@export var choice_spacing: float = 56.0
## Pausa entre o último golpe e o diálogo da vitória.
@export var victory_delay: float = 1.0
## Pausa antes de o chefe começar a atacar.
@export var boss_start_delay: float = 1.2

@onready var _spawn: Marker2D = $BossSpawn
@onready var _exit: Area2D = $ExitDoor
@onready var _message: Label = $Overlay/Message

var _boss: EnemyBase
var _bar: BossBar
var _is_cleared: bool = false
var _defeat_shown: bool = false
var _player_at_exit: bool = false
var _exit_requested: bool = false


func _ready() -> void:
	_exit.visible = false
	_exit.monitoring = false
	_exit.body_entered.connect(_on_exit_body_entered)
	_exit.body_exited.connect(_on_exit_body_exited)
	_message.visible = false
	EventBus.player_died.connect(_on_player_died)
	_spawn_boss()
	await DialogueBox.play(self, Dialogues.CURUPIRA_ANTES)


func is_cleared() -> bool:
	return _is_cleared


func boss() -> EnemyBase:
	return _boss


func _spawn_boss() -> void:
	assert(boss_scene != null, "BossRoom precisa de uma Boss Scene no Inspetor!")
	_boss = boss_scene.instantiate() as EnemyBase
	_boss.position = _spawn.position
	add_child(_boss)
	_boss.attack_cooldown_left = boss_start_delay
	_boss.health.died.connect(_on_boss_died)
	_bar = BossBar.new()
	add_child(_bar)
	_bar.setup(boss_name, _boss.health)


func _on_player_died() -> void:
	if _defeat_shown or _is_cleared:
		return
	_defeat_shown = true
	# O Valtair morreu: o diálogo toca com o jogo pausado e depois a morte segue o fluxo normal.
	await DialogueBox.play(self, Dialogues.CURUPIRA_DERROTA)


func _on_boss_died() -> void:
	if _is_cleared:
		return
	_is_cleared = true
	await get_tree().create_timer(victory_delay).timeout
	await DialogueBox.play(self, Dialogues.CURUPIRA_VITORIA)
	_give_rewards()


func _give_rewards() -> void:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.grant_relic(BLESSING)
	if clear_bonus_leaves > 0:
		EventBus.leaves_gained.emit(clear_bonus_leaves)
	var spawned: int = _spawn_relic_choices()
	if _bar != null:
		_bar.queue_free()
		_bar = null

	var key: String = InputHint.key_name(&"interact")
	_message.text = "Curupira derrotado!  +%d Folhas  e a Benção do Curupira" % clear_bonus_leaves
	if spawned > 0:
		_message.text += "\nEscolha UMA relíquia: [%s] sobre ela para pegar" % key
	_message.text += "\n[%s] na porta para sair" % key
	_message.visible = true

	_exit.visible = true
	_exit.set_deferred("monitoring", true)
	get_tree().create_timer(0.6).timeout.connect(_attract_leaves)
	cleared.emit()


## Cria os pedestais com relíquias que o Valtair ainda não tem. Ao pegar uma, as outras somem.
func _spawn_relic_choices() -> int:
	if relic_pool == null:
		return 0
	var options: Array[RelicData] = relic_pool.available(RunState.relics)
	options.shuffle()
	var count: int = mini(choice_count, options.size())
	var pedestals: Array[RelicPedestal] = []
	for i in count:
		var pedestal: RelicPedestal = PEDESTAL_SCENE.instantiate() as RelicPedestal
		pedestal.relic = options[i]
		add_child(pedestal)
		pedestal.global_position = _exit.global_position + choice_offset + Vector2(choice_spacing * i, 0.0)
		pedestals.append(pedestal)
	for pedestal in pedestals:
		pedestal.taken.connect(func(_relic: RelicData) -> void:
			for other in pedestals:
				if other != pedestal and is_instance_valid(other):
					other.queue_free()
		)
	return count


func _unhandled_input(event: InputEvent) -> void:
	if _is_cleared and _exit.visible and _player_at_exit and not _exit_requested and event.is_action_pressed(&"interact"):
		_exit_requested = true
		EventBus.room_exit_requested.emit()


func _attract_leaves() -> void:
	get_tree().call_group(&"leaf_pickups", &"attract")


func _on_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = true


func _on_exit_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = false
