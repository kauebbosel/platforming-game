# ui/hud.gd
class_name Hud
extends CanvasLayer
## HUD do jogo com a arte final. Só escuta o EventBus:
##  - vida em vitórias-régias (cada uma vale `hp_per_pad` de vida: cheia, metade ou vazia). A
##    quantidade cresce com a vida máxima e quebra de linha a cada `pads_per_row`; logo abaixo,
##    o número exato "atual / máxima";
##  - pedras do bodoque (cheia ou vazia);
##  - contador de Folhas (ícone + número) no canto superior direito.
## Monta tudo por código e apaga os filhos antigos da cena (a barra e as pedras provisórias),
## então a cena do HUD pode ser só um CanvasLayer com este script.

const PAD_FULL: Texture2D = preload("res://assets/art/hud/usar-jogo/vida-cheia-alt.png")
const PAD_HALF: Texture2D = preload("res://assets/art/hud/usar-jogo/vida-metade-alt.png")
const PAD_EMPTY: Texture2D = preload("res://assets/art/hud/usar-jogo/vida-vazia-alt.png")
const STONE_FULL: Texture2D = preload("res://assets/art/hud/pedra_cheia.png")
const STONE_EMPTY: Texture2D = preload("res://assets/art/hud/pedra_vazia.png")
const LEAF_ICON: Texture2D = preload("res://assets/art/hud/usar-jogo/gold.png")

## Quanto de vida cada vitória-régia representa. Com 20, um golpe de 10 sempre muda o desenho
## (cheia -> metade -> vazia), e uma relíquia de +20 de vida acrescenta exatamente uma.
@export var hp_per_pad: int = 20
## Quantas vitórias-régias cabem numa linha antes de quebrar (cada uma ocupa 30 px).
@export var pads_per_row: int = 10
@export var margin: int = 6

var leaf_label: Label
var hp_label: Label

var _pad_row: HFlowContainer
var _stone_row: HBoxContainer
var _pads: Array[TextureRect] = []
var _stones: Array[TextureRect] = []
var _pad_states: Array[StringName] = []
var _stone_states: Array[StringName] = []


func _ready() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_ammo_changed.connect(_on_ammo_changed)
	EventBus.leaves_changed.connect(_on_leaves_changed)


## Estado de cada vitória-régia, da primeira à última: &"full", &"half" ou &"empty".
func pad_states() -> Array[StringName]:
	return _pad_states


## Estado de cada pedra: &"full" ou &"empty".
func stone_states() -> Array[StringName]:
	return _stone_states


func _build() -> void:
	var left: VBoxContainer = VBoxContainer.new()
	left.position = Vector2(margin, margin)
	left.add_theme_constant_override("separation", 3)
	# A largura fixa é o que faz as vitórias-régias quebrarem de linha quando a vida cresce.
	left.custom_minimum_size = Vector2(pads_per_row * 30, 0)
	add_child(left)
	_pad_row = HFlowContainer.new()
	_pad_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad_row.add_theme_constant_override("h_separation", 2)
	_pad_row.add_theme_constant_override("v_separation", 2)
	left.add_child(_pad_row)
	hp_label = _outlined_label("0 / 0")
	left.add_child(hp_label)
	_stone_row = HBoxContainer.new()
	_stone_row.add_theme_constant_override("separation", 3)
	left.add_child(_stone_row)

	var right: HBoxContainer = HBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	var icon: TextureRect = _icon(LEAF_ICON, Vector2(16, 16))
	right.add_child(icon)
	leaf_label = _outlined_label("0")
	leaf_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.add_child(leaf_label)
	add_child(right)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, margin)


## Texto branco com contorno escuro, legível sobre qualquer cenário.
func _outlined_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.16))
	return label


func _icon(texture: Texture2D, min_size: Vector2) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = min_size
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return rect


func _on_health_changed(current: int, maximum: int) -> void:
	hp_label.text = "%d / %d" % [current, maximum]
	var count: int = ceili(float(maximum) / hp_per_pad)
	while _pads.size() < count:
		var pad: TextureRect = _icon(PAD_EMPTY, Vector2(28, 24))
		_pad_row.add_child(pad)
		_pads.append(pad)
	while _pads.size() > count:
		_pads.pop_back().queue_free()
	_pad_states.clear()
	for i in count:
		var capacity: int = mini(hp_per_pad, maximum - i * hp_per_pad)
		var inside: int = clampi(current - i * hp_per_pad, 0, capacity)
		var state: StringName = &"empty"
		if inside > 0:
			state = &"full" if float(inside) > capacity * 0.5 else &"half"
		_pad_states.append(state)
		_pads[i].texture = PAD_FULL if state == &"full" else (PAD_HALF if state == &"half" else PAD_EMPTY)


func _on_ammo_changed(current: int, maximum: int) -> void:
	while _stones.size() < maximum:
		var stone: TextureRect = _icon(STONE_EMPTY, Vector2(11, 10))
		_stone_row.add_child(stone)
		_stones.append(stone)
	while _stones.size() > maximum:
		_stones.pop_back().queue_free()
	_stone_states.clear()
	for i in maximum:
		var full: bool = i < current
		_stone_states.append(&"full" if full else &"empty")
		_stones[i].texture = STONE_FULL if full else STONE_EMPTY


func _on_leaves_changed(total: int) -> void:
	leaf_label.text = str(total)
