# levels/rest_site.gd
class_name RestSite
extends Node2D
## Fogueira (nó Descanso): ponto pacífico com uma escolha única, curar ou recarregar o
## bodoque (GDD 8.4). Escolher aplica o efeito no Valtair, e o RunState acompanha por
## causa dos componentes, e sai direto para o mapa pelo EventBus.

## Fração da vida máxima que a fogueira cura.
@export_range(0.05, 1.0, 0.05) var heal_fraction: float = 0.5

@onready var _player: Player = $Player
@onready var _campfire: Area2D = $Campfire
@onready var _prompt: Label = $Overlay/Prompt
@onready var _menu: CanvasLayer = $Menu
@onready var _heal_button: Button = $Menu/Panel/Box/HealButton
@onready var _ammo_button: Button = $Menu/Panel/Box/AmmoButton

var _near_fire: bool = false
var _menu_open: bool = false
var _chosen: bool = false


func _ready() -> void:
	_menu.visible = false
	_prompt.visible = false
	_prompt.text = "[%s] Descansar" % InputHint.key_name(&"interact")
	_campfire.body_entered.connect(_on_campfire_body_entered)
	_campfire.body_exited.connect(_on_campfire_body_exited)
	_heal_button.pressed.connect(_on_heal_pressed)
	_ammo_button.pressed.connect(_on_reload_pressed)


func is_menu_open() -> bool:
	return _menu_open


func _unhandled_input(event: InputEvent) -> void:
	if _near_fire and not _menu_open and event.is_action_pressed(&"interact"):
		_open_menu()


func _open_menu() -> void:
	_menu_open = true
	_prompt.visible = false
	var health: HealthComponent = _player.health
	var ammo: AmmoComponent = _player.ammo
	if health.health >= health.max_health:
		_heal_button.text = "Curar  (vida cheia)"
	else:
		_heal_button.text = "Curar  +%d HP  (%d > %d)" % [_heal_amount(), health.health, mini(health.health + _heal_amount(), health.max_health)]
	if ammo.current >= ammo.max_ammo:
		_ammo_button.text = "Recarregar bodoque  (cheio)"
	else:
		_ammo_button.text = "Recarregar bodoque  (%d > %d)" % [ammo.current, ammo.max_ammo]
	_menu.visible = true
	# Pausa o jogo: senão o Valtair pularia com o mesmo botão que confirma o menu.
	get_tree().paused = true
	_heal_button.grab_focus()


func _heal_amount() -> int:
	return ceili(_player.health.max_health * heal_fraction)


func _on_heal_pressed() -> void:
	_choose(func() -> void: _player.health.heal(_heal_amount()))


func _on_reload_pressed() -> void:
	_choose(func() -> void: _player.ammo.refill())


func _choose(effect: Callable) -> void:
	if _chosen:
		return
	_chosen = true
	# O estado de pausa sobrevive à troca de cena, então precisa ser desligado aqui.
	get_tree().paused = false
	effect.call()
	EventBus.room_exit_requested.emit()


func _on_campfire_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_near_fire = true
		_prompt.visible = not _menu_open


func _on_campfire_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_near_fire = false
		_prompt.visible = false
