# levels/shop_clearing.gd
class_name ShopClearing
extends Node2D
## Clareira da Caipora (nó Mercadora, GDD 11.3): lugar seguro onde se gasta Folhas em cura,
## pedras e relíquias. Perto da Caipora, `interact` abre o menu de compra; perto da porta,
## `interact` sai para o mapa (pelo EventBus). Não conhece o mapa: o SceneManager decide.
##
## Enquanto o menu está aberto o Valtair fica desligado (process_mode), em vez de pausar o
## jogo inteiro: assim `ui_cancel` ainda fecha o menu e nenhuma pausa vaza para outra cena.

## De onde saem as relíquias à venda (as que o jogador ainda não tem).
@export var relic_pool: RelicPool
## Quantas relíquias ficam à venda nesta visita.
@export var relic_slots: int = 3
@export var heal_price: int = 30
## Fração da vida máxima que a cura devolve.
@export_range(0.05, 1.0, 0.05) var heal_fraction: float = 0.4
@export var ammo_price: int = 20

enum Kind { HEAL, AMMO, RELIC }

@onready var _player: Player = $Player
@onready var _caipora: Area2D = $Caipora
@onready var _exit: Area2D = $ExitDoor
@onready var _prompt: Label = $Overlay/Prompt
@onready var _menu: CanvasLayer = $Menu
@onready var _balance: Label = $Menu/Panel/Box/Balance
@onready var _rows: VBoxContainer = $Menu/Panel/Box/Rows
@onready var _description: Label = $Menu/Panel/Box/Description
@onready var _close_button: Button = $Menu/Panel/Box/CloseButton

var _offers: Array[Dictionary] = []
var _near_caipora: bool = false
var _near_exit: bool = false
var _menu_open: bool = false
var _leaving: bool = false


func _ready() -> void:
	_menu.visible = false
	_prompt.visible = false
	_roll_offers()
	_caipora.body_entered.connect(func(b: Node2D) -> void: _on_area_body(b, true, true))
	_caipora.body_exited.connect(func(b: Node2D) -> void: _on_area_body(b, true, false))
	_exit.body_entered.connect(func(b: Node2D) -> void: _on_area_body(b, false, true))
	_exit.body_exited.connect(func(b: Node2D) -> void: _on_area_body(b, false, false))
	_close_button.pressed.connect(_close_menu)
	_close_button.focus_entered.connect(func() -> void: _description.text = "")


func is_menu_open() -> bool:
	return _menu_open


## Os itens à venda nesta visita (cada um é um Dictionary: kind, name, description, price, relic).
func offers() -> Array[Dictionary]:
	return _offers


func _roll_offers() -> void:
	_offers.clear()
	_offers.append({"kind": Kind.HEAL, "name": "Cura", "price": heal_price, "relic": null})
	_offers.append({"kind": Kind.AMMO, "name": "Recarregar bodoque", "price": ammo_price, "relic": null})
	if relic_pool != null:
		var taken: Array = RunState.relics.duplicate()
		for i in relic_slots:
			var relic: RelicData = relic_pool.pick_random(taken)
			if relic == null:
				break
			taken.append(relic)
			_offers.append({"kind": Kind.RELIC, "name": relic.display_name, "description": relic.description, "price": relic.price(), "relic": relic})


## Texto de por que o item não pode ser comprado agora ("" = pode).
func blocked_reason(offer: Dictionary) -> String:
	match offer["kind"]:
		Kind.HEAL:
			if _player.health.health >= _player.health.max_health:
				return "vida cheia"
		Kind.AMMO:
			if _player.ammo.current >= _player.ammo.max_ammo:
				return "cheio"
		Kind.RELIC:
			if RunState.has_relic(offer["relic"]):
				return "comprada"
	if RunState.leaves < int(offer["price"]):
		return "Folhas insuficientes"
	return ""


func buy(offer: Dictionary) -> bool:
	if blocked_reason(offer) != "":
		return false
	RunState.add_leaves(-int(offer["price"]))
	match offer["kind"]:
		Kind.HEAL:
			_player.health.heal(_heal_amount())
		Kind.AMMO:
			_player.ammo.refill()
		Kind.RELIC:
			var old_max: int = _player.health.max_health
			RunState.add_relic(offer["relic"])
			_player.refresh_stats()
			# Vida máxima nova também vem cheia: quem ganha +20 de vida ganha +20 agora.
			var gained: int = _player.health.max_health - old_max
			if gained > 0:
				_player.health.heal(gained)
	return true


func _heal_amount() -> int:
	return ceili(_player.health.max_health * heal_fraction)


func _unhandled_input(event: InputEvent) -> void:
	if _menu_open:
		if event.is_action_pressed(&"ui_cancel"):
			_close_menu()
			get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"interact"):
		return
	if _near_caipora:
		_open_menu()
	elif _near_exit and not _leaving:
		_leaving = true
		EventBus.room_exit_requested.emit()


func _open_menu() -> void:
	_menu_open = true
	_prompt.visible = false
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_menu.visible = true
	_rebuild_rows(0)


func _close_menu() -> void:
	_menu_open = false
	_menu.visible = false
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_update_prompt()


func _rebuild_rows(focus_index: int) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_balance.text = "Folhas: %d" % RunState.leaves
	_description.text = ""
	var first_enabled: Button = null
	var focus_button: Button = null
	for i in _offers.size():
		var offer: Dictionary = _offers[i]
		var reason: String = blocked_reason(offer)
		var button: Button = Button.new()
		button.add_theme_font_size_override("font_size", 10)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s   (%d)" % [offer["name"], offer["price"]]
		if reason != "":
			button.text += "   " + reason
			button.disabled = true
		else:
			button.pressed.connect(_on_offer_pressed.bind(i))
			if first_enabled == null:
				first_enabled = button
		button.focus_entered.connect(_show_description.bind(i))
		button.mouse_entered.connect(_show_description.bind(i))
		_rows.add_child(button)
		if i == focus_index and not button.disabled:
			focus_button = button
	var target: Button = focus_button if focus_button != null else first_enabled
	if target != null:
		target.grab_focus.call_deferred()
	else:
		_close_button.grab_focus.call_deferred()


func _show_description(index: int) -> void:
	var offer: Dictionary = _offers[index]
	match offer["kind"]:
		Kind.HEAL:
			_description.text = "Recupera %d de vida." % _heal_amount()
		Kind.AMMO:
			_description.text = "Enche as pedras do bodoque."
		Kind.RELIC:
			_description.text = String(offer["description"])


func _on_offer_pressed(index: int) -> void:
	if buy(_offers[index]):
		_rebuild_rows(index)


func _on_area_body(body: Node2D, is_caipora: bool, entered: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	if is_caipora:
		_near_caipora = entered
	else:
		_near_exit = entered
	_update_prompt()


func _update_prompt() -> void:
	var key: String = InputHint.key_name(&"interact")
	if _menu_open:
		_prompt.visible = false
	elif _near_caipora:
		_prompt.text = "[%s] Falar com a Caipora" % key
		_prompt.visible = true
	elif _near_exit:
		_prompt.text = "[%s] Seguir viagem" % key
		_prompt.visible = true
	else:
		_prompt.visible = false
