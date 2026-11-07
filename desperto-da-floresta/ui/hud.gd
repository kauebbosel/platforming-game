# ui/hud.gd
class_name Hud
extends CanvasLayer
## HUD do jogo. Só escuta o EventBus; nunca referencia o Player diretamente.
## Assim ele funciona em qualquer sala, não importa de onde o Player veio.
##
## Funciona de dois jeitos: se a cena tiver nós únicos chamados HealthBar e AmmoRow
## (veja hud.tscn), usa esses nós e dá para estilizá-los no editor. Se não tiver,
## monta a interface sozinho. Assim um simples CanvasLayer com este script já basta.

## Texturas opcionais para as pedras. Sem elas, o HUD desenha quadradinhos de placeholder.
@export var stone_full: Texture2D
@export var stone_empty: Texture2D

const PLACEHOLDER_SIZE: Vector2 = Vector2(6.0, 6.0)
const COLOR_FULL: Color = Color(0.85, 0.8, 0.7)
const COLOR_EMPTY: Color = Color(0.25, 0.25, 0.25)

var health_bar: ProgressBar
var ammo_row: HBoxContainer


func _ready() -> void:
	health_bar = get_node_or_null("%HealthBar") as ProgressBar
	ammo_row = get_node_or_null("%AmmoRow") as HBoxContainer
	if health_bar == null or ammo_row == null:
		_build_ui()

	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_ammo_changed.connect(_on_ammo_changed)


## Monta a interface por código (usado quando a cena não traz os nós prontos).
func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(80.0, 8.0)
	health_bar.show_percentage = false
	vbox.add_child(health_bar)

	ammo_row = HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 2)
	vbox.add_child(ammo_row)


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_ammo_changed(current: int, maximum: int) -> void:
	# Ajusta a quantidade de ícones só se a capacidade mudou (ex.: relíquia no futuro).
	while ammo_row.get_child_count() > maximum:
		var extra: Node = ammo_row.get_child(ammo_row.get_child_count() - 1)
		ammo_row.remove_child(extra)
		extra.queue_free()
	while ammo_row.get_child_count() < maximum:
		ammo_row.add_child(_make_icon())
	for i in maximum:
		_set_icon_filled(ammo_row.get_child(i) as Control, i < current)


func _make_icon() -> Control:
	if stone_full != null:
		var texture_rect: TextureRect = TextureRect.new()
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
		return texture_rect
	var color_rect: ColorRect = ColorRect.new()
	color_rect.custom_minimum_size = PLACEHOLDER_SIZE
	return color_rect


func _set_icon_filled(icon: Control, filled: bool) -> void:
	if icon is TextureRect:
		(icon as TextureRect).texture = stone_full if filled else stone_empty
	elif icon is ColorRect:
		(icon as ColorRect).color = COLOR_FULL if filled else COLOR_EMPTY
