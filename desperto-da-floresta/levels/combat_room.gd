# levels/combat_room.gd
class_name CombatRoom
extends Node2D
## Sala de combate: nasce com um inimigo em cada Marker2D de "Spawns" e, quando todos
## morrem, libera a porta de saída. Não conhece o mapa nem o RunState: só avisa pelo
## EventBus (room_exit_requested) e o SceneManager decide para onde ir.

signal cleared

## O inimigo que nasce em cada ponto (ex.: corpo_seco.tscn).
@export var enemy_scene: PackedScene

@onready var _spawns: Node = $Spawns
@onready var _exit: Area2D = $ExitDoor
@onready var _message: Label = $Overlay/Message

var _alive: int = 0
var _is_cleared: bool = false
var _player_at_exit: bool = false
var _exit_requested: bool = false


func _ready() -> void:
	assert(enemy_scene != null, "CombatRoom precisa de um enemy_scene atribuído no Inspetor!")
	_exit.visible = false
	_exit.monitoring = false
	_exit.body_entered.connect(_on_exit_body_entered)
	_exit.body_exited.connect(_on_exit_body_exited)
	_message.visible = false

	for marker in _spawns.get_children():
		if marker is Marker2D:
			_spawn_enemy((marker as Marker2D).position)
	if _alive == 0:
		_clear()


func alive_enemies() -> int:
	return _alive


func is_cleared() -> bool:
	return _is_cleared


func _spawn_enemy(at: Vector2) -> void:
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
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
	_message.text = "Sala limpa!  [%s] na porta para sair" % _interact_key_name()
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


func _interact_key_name() -> String:
	for event in InputMap.action_get_events(&"interact"):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.as_text_physical_keycode()
	return "interagir"
