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
	_message.text = "Sala limpa!  [%s] na porta para sair" % InputHint.key_name(&"interact")
	_message.visible = true
	cleared.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _is_cleared and _player_at_exit and not _exit_requested and event.is_action_pressed(&"interact"):
		_exit_requested = true
		EventBus.room_exit_requested.emit()


func _on_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = true


func _on_exit_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = false
