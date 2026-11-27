# entities/pickups/relic_pedestal.gd
class_name RelicPedestal
extends Area2D
## Uma relíquia exposta sobre um pedestal (recompensa de sala). Perto dela aparecem o nome e
## a descrição; `interact` entrega a relíquia ao Valtair. Defina `relic` ANTES de adicionar
## à cena. Não conhece o mapa nem a sala: só entrega a relíquia (Player.grant_relic).

signal taken(relic: RelicData)

const FRAMES: Dictionary = {
	RelicData.Rarity.COMMON: preload("res://assets/art/hud/usar-jogo/moldura-comum.png"),
	RelicData.Rarity.UNCOMMON: preload("res://assets/art/hud/usar-jogo/moldura-incomum.png"),
	RelicData.Rarity.RARE: preload("res://assets/art/hud/usar-jogo/moldura-rara.png"),
}

var relic: RelicData
## Segundos, depois de aparecer, em que o pedestal ainda NÃO aceita o `interact` (fica meio
## apagado). Evita pegar a relíquia sem querer, por exemplo ao pular um diálogo apertando [E].
## 0 = aceita na hora (padrão).
var arm_delay: float = 0.0

var _arm_left: float = 0.0
var _player: Player
var _near: bool = false
var _taken: bool = false
## Só UM pedestal por vez fica "em foco": o mais próximo do Valtair entre os que ele toca.
## É o único que mostra nome/descrição e aceita o `interact` (evita pegar duas relíquias
## ao ficar entre dois pedestais).
var _focused: bool = false
var _name_label: Label
var _desc_label: Label
## Aviso de limite de atributos (acima do nome): "Dano à distância: já no limite" etc.
var _warn_label: Label


func _ready() -> void:
	assert(relic != null, "RelicPedestal precisa de uma relíquia (defina `relic` antes de adicionar à cena).")
	add_to_group(&"relic_pedestals")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visuals()
	_arm_left = arm_delay
	if _arm_left > 0.0:
		modulate.a = 0.5


func _process(delta: float) -> void:
	if _arm_left > 0.0:
		_arm_left -= delta
		if _arm_left <= 0.0:
			modulate.a = 1.0
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _focused and not _taken and _arm_left <= 0.0 and event.is_action_pressed(&"interact"):
		# Marca o input como tratado: nenhum outro pedestal (nem baú) reage a este mesmo [E].
		get_viewport().set_input_as_handled()
		_take()


func _take() -> void:
	if _taken:
		return
	_taken = true
	if _player != null:
		_player.grant_relic(relic)
	_show_popup()
	taken.emit(relic)
	queue_free()


func _build_visuals() -> void:
	var base: Polygon2D = Polygon2D.new()
	base.color = Color(0.35, 0.28, 0.2)
	base.polygon = PackedVector2Array([Vector2(-11, 0), Vector2(11, 0), Vector2(8, -9), Vector2(-8, -9)])
	add_child(base)

	# A moldura e o ícone flutuam um pouco, para chamar atenção.
	var floating: Node2D = Node2D.new()
	floating.position = Vector2(0, -24)
	add_child(floating)
	var frame: Sprite2D = Sprite2D.new()
	frame.texture = FRAMES[relic.rarity]
	floating.add_child(frame)
	if relic.icon != null:
		var icon: Sprite2D = Sprite2D.new()
		icon.texture = relic.icon
		floating.add_child(icon)
	var tween: Tween = floating.create_tween().set_loops()
	tween.tween_property(floating, "position:y", -26.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(floating, "position:y", -22.0, 0.8).set_trans(Tween.TRANS_SINE)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(48, 44)
	shape.shape = rect
	shape.position = Vector2(0, -20)
	add_child(shape)

	_name_label = _label("[%s] %s" % [InputHint.key_name(&"interact"), relic.display_name], -66.0)
	_desc_label = _label(relic.description, -56.0)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.visible = false
	_desc_label.visible = false
	_warn_label = _label("", -76.0)
	_warn_label.visible = false


func _label(text: String, y: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(160, 0)
	label.position = Vector2(-80, y)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.16))
	label.z_index = 20
	add_child(label)
	return label


func _show_popup() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var label: Label = Label.new()
	label.text = relic.display_name
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.16))
	label.z_index = 20
	parent.add_child(label)
	label.global_position = global_position + Vector2(-30, -50)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(label.queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player = body as Player
		_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_near = false


## Atualiza qual pedestal está em foco e mostra/esconde os textos de acordo.
func _update_focus() -> void:
	var focused: bool = _near and not _taken and _is_closest_to_player()
	if focused == _focused:
		return
	_focused = focused
	_name_label.visible = focused
	_desc_label.visible = focused
	if focused:
		_update_limit_warning()
	else:
		_warn_label.visible = false


## Este é o pedestal mais próximo do Valtair entre os que ele está tocando agora?
## Empate: ganha o de menor id, para o resultado ser sempre o mesmo.
func _is_closest_to_player() -> bool:
	if _player == null:
		return false
	var my_distance: float = global_position.distance_to(_player.global_position)
	for node: Node in get_tree().get_nodes_in_group(&"relic_pedestals"):
		var other: RelicPedestal = node as RelicPedestal
		if other == null or other == self or not other._near or other._taken:
			continue
		var other_distance: float = other.global_position.distance_to(_player.global_position)
		if other_distance < my_distance:
			return false
		if is_equal_approx(other_distance, my_distance) and other.get_instance_id() < get_instance_id():
			return false
	return true


## Se a relíquia esbarra no limite de algum atributo, avisa ANTES de o jogador pegar:
## vermelho = não ajuda em algo (já está no limite); amarelo = parte do bônus se perde.
func _update_limit_warning() -> void:
	var preview: Dictionary = _player.preview_relic(relic) if _player != null else {}
	var text: String = StatLimits.preview_text(preview)
	_warn_label.visible = text != ""
	if text == "":
		return
	_warn_label.text = text
	_warn_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if StatLimits.preview_is_severe(preview) else Color(1.0, 0.85, 0.4))
	# As linhas crescem para cima, para não cobrir o nome.
	_warn_label.position.y = -68.0 - _warn_label.get_line_count() * _warn_label.get_line_height()
