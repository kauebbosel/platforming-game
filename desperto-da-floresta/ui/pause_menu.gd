# ui/pause_menu.gd
class_name PauseMenu
extends CanvasLayer
## Menu de pausa com inventário (GDD 6, figura 7), montado sobre o guia do artista
## (pausado-menu.png). Esc abre (quem abre é o SceneManager) e fecha.
## A tela é um painel de 480x270 (assets/art/hud/pausado-painel.png, o guia sem os elementos
## que o jogo desenha) e, em cima dele, os COMPONENTES: grade de relíquias 8x3 com molduras
## por raridade, caixa de descrição, vitórias-régias e pedras (as mesmas do HUD), Folhas e três
## botões com um cursor. Navegação: W/A/S/D ou setas; [E] ou Enter confirma; o mouse também.
## Pausa o jogo enquanto está aberto e devolve o estado anterior ao fechar.
## Todas as posições vêm do guia (pixel a pixel) e estão nas constantes abaixo.

signal closed

const ART: String = "res://assets/art/hud/usar-jogo/"
const COLUMNS: int = 8
const ROWS: int = 3
const SLOT: int = 24
const PANEL_ART: String = "res://assets/art/hud/pausado-painel.png"
## Origem (canto da imagem de 24x24) do primeiro slot; as molduras têm 2 px de folga.
const GRID_POS: Vector2 = Vector2(73, 91)
const DESC_POS: Vector2 = Vector2(270, 90)
const DESC_SIZE: Vector2 = Vector2(138, 74)
const DESC_TEXT_POS: Vector2 = Vector2(8, 7)
const BUTTON_SIZE: Vector2 = Vector2(92, 21)
## Os botões do guia ficam a 4 px um do outro; aqui há 12 px entre eles para o cursor caber.
const BUTTON_X: float = 90.0
const BUTTON_PITCH: float = 104.0
const BUTTON_Y: float = 209.0
const PADS_POS: Vector2 = Vector2(73, 167)
const PAD_PITCH: float = 28.0
const PADS_MAX_WIDTH: float = 224.0
const STONES_POS: Vector2 = Vector2(78, 192)
const STONE_PITCH: float = 14.0
const LEAF_ICON_POS: Vector2 = Vector2(354, 173)
const LEAF_TEXT_RIGHT: float = 400.0
const LEAF_TEXT_Y: float = 173.0
## Ignora o input logo ao abrir.
const INPUT_LOCK_MS: int = 150

const RARITY_NAMES: Dictionary = {
	RelicData.Rarity.COMMON: "Comum",
	RelicData.Rarity.UNCOMMON: "Incomum",
	RelicData.Rarity.RARE: "Rara",
}
const RARITY_COLORS: Dictionary = {
	RelicData.Rarity.COMMON: Color(0.88, 0.78, 0.55),
	RelicData.Rarity.UNCOMMON: Color(0.5, 0.7, 1.0),
	RelicData.Rarity.RARE: Color(0.8, 0.6, 1.0),
}
const FRAME_FILES: Dictionary = {
	RelicData.Rarity.COMMON: "moldura-comum.png",
	RelicData.Rarity.UNCOMMON: "moldura-incomum.png",
	RelicData.Rarity.RARE: "moldura-rara.png",
}

enum Area { GRID, BUTTONS }


## Botão de tamanho FIXO (o Button do Godot cresce com o texto e o tema). Desenha o fundo
## (arte ou visual simples), o texto centralizado e responde ao mouse. Emite `pressed` e `hovered`.
class PauseButton extends Control:
	signal pressed
	signal hovered

	var text: String = "":
		set(value):
			text = value
			if _label != null:
				_label.text = value
	var _background: Panel
	var _label: Label

	func _init(button_size: Vector2) -> void:
		custom_minimum_size = button_size
		size = button_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		_background = Panel.new()
		_background.size = button_size
		_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_background)
		_label = Label.new()
		_label.size = button_size
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.clip_text = true
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_size_override("font_size", 8)
		add_child(_label)
		mouse_entered.connect(func() -> void: hovered.emit())

	func set_style(style: StyleBox) -> void:
		_background.add_theme_stylebox_override("panel", style)

	func set_text_color(color: Color) -> void:
		_label.add_theme_color_override("font_color", color)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit()
			accept_event()

var _area: Area = Area.GRID
var _grid_index: int = 0
var _button_index: int = 0
var _confirming: bool = false
var _was_paused: bool = false
var _closed: bool = false
var _opened_ms: int = 0
var _relics: Array[RelicData] = []

var _slot_frames: Array[Panel] = []
var _slot_icons: Array[TextureRect] = []
var _slot_empties: Array[Panel] = []
var _select_frame: Panel
var _buttons: Array[PauseButton] = []
var _button_cursor: TextureRect
var _desc_name: Label
var _desc_text: Label
## Linha de baixo da caixa de descrição: "MÁX: ..." quando a relíquia mexe num atributo no limite.
var _desc_limit: Label
var _stats_layer: Control
var _stat_leaves: Label


## Abre o menu (ou devolve o que já estiver aberto). `host` é um nó da cena atual.
static func open(host: Node) -> PauseMenu:
	var existing: Array[Node] = host.get_tree().get_nodes_in_group(&"pause_menu")
	if not existing.is_empty():
		return existing[0] as PauseMenu
	var menu: PauseMenu = PauseMenu.new()
	host.add_child(menu)
	return menu


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"pause_menu")
	_opened_ms = Time.get_ticks_msec()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_relics = RunState.relics.duplicate()
	_build()
	_refresh()


func _exit_tree() -> void:
	_close()


func _input(event: InputEvent) -> void:
	if _closed:
		return
	# O mouse fica para os botões e as relíquias (GUI); consumir tudo impedia os cliques.
	if event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _opened_ms < INPUT_LOCK_MS:
		return
	if event.is_action_pressed(&"pause"):
		_close()
	elif _pressed(event, &"move_left", &"ui_left"):
		_move(-1, 0)
	elif _pressed(event, &"move_right", &"ui_right"):
		_move(1, 0)
	elif _pressed(event, &"move_up", &"ui_up"):
		_move(0, -1)
	elif _pressed(event, &"move_down", &"ui_down"):
		_move(0, 1)
	elif _pressed(event, &"interact", &"ui_accept"):
		_activate()


func _pressed(event: InputEvent, action: StringName, fallback: StringName) -> bool:
	return event.is_action_pressed(action) or event.is_action_pressed(fallback)


func _move(dx: int, dy: int) -> void:
	_confirming = false
	if _area == Area.GRID:
		var col: int = _grid_index % COLUMNS
		var row: int = floori(float(_grid_index) / COLUMNS)
		if dy > 0 and row == ROWS - 1:
			_area = Area.BUTTONS
			_button_index = clampi(floori(float(col) * _buttons.size() / COLUMNS), 0, _buttons.size() - 1)
		else:
			col = clampi(col + dx, 0, COLUMNS - 1)
			row = clampi(row + dy, 0, ROWS - 1)
			_grid_index = row * COLUMNS + col
	else:
		if dy < 0:
			_area = Area.GRID
			var col: int = clampi(floori((_button_index + 0.5) * COLUMNS / _buttons.size()), 0, COLUMNS - 1)
			_grid_index = (ROWS - 1) * COLUMNS + col
		elif dx != 0:
			_button_index = posmod(_button_index + dx, _buttons.size())
	_refresh()


func _activate() -> void:
	if _area != Area.BUTTONS:
		return
	match _button_index:
		0:
			_close()
		1:
			# Abandonar a run perde tudo: pede para confirmar uma vez.
			if not _confirming:
				_confirming = true
				_refresh()
			else:
				_close()
				SceneManager.go_to_main_menu()
		2:
			get_tree().quit()


func _close() -> void:
	if _closed:
		return
	_closed = true
	get_tree().paused = _was_paused
	closed.emit()
	if is_inside_tree():
		queue_free()


func _refresh() -> void:
	# Grade: moldura por raridade, ícone e seleção. Slot vazio = caixa escura, como no guia.
	for i in _slot_frames.size():
		var relic: RelicData = _relics[i] if i < _relics.size() else null
		_slot_icons[i].texture = relic.icon if relic != null else null
		_slot_frames[i].add_theme_stylebox_override("panel", _frame_style(relic.rarity) if relic != null else StyleBoxEmpty.new())
		_slot_empties[i].visible = relic == null
	_select_frame.visible = _area == Area.GRID
	_select_frame.position = _slot_position(_grid_index)

	# Descrição da relíquia escolhida.
	var chosen: RelicData = null
	if _area == Area.GRID and _grid_index < _relics.size():
		chosen = _relics[_grid_index]
	_desc_limit.text = ""
	if chosen != null:
		_desc_name.text = chosen.display_name
		_desc_name.add_theme_color_override("font_color", RARITY_COLORS[chosen.rarity])
		_desc_text.text = "[%s]  %s" % [RARITY_NAMES[chosen.rarity], chosen.description]
		# Atributos desta relíquia que já estão no limite.
		var capped_names: Array[String] = []
		for modifier in chosen.modifiers:
			var capped_label: String = StatLimits.label(modifier.stat)
			if RunState.capped_stats.has(modifier.stat) and not capped_names.has(capped_label):
				capped_names.append(capped_label)
		if not capped_names.is_empty():
			_desc_limit.text = "MÁX: " + ", ".join(capped_names)
	elif not RunState.capped_stats.is_empty():
		# Nada selecionado: resumo dos atributos que estão no limite.
		var all_names: Array[String] = []
		for stat in RunState.capped_stats:
			all_names.append(StatLimits.label(stat))
		_desc_name.text = "No limite"
		_desc_name.add_theme_color_override("font_color", Color8(255, 182, 46))
		_desc_text.text = ", ".join(all_names)
	else:
		_desc_name.text = ""
		_desc_text.text = ""

	# Botões.
	for i in _buttons.size():
		var selected: bool = _area == Area.BUTTONS and i == _button_index
		_buttons[i].set_style(_button_style(selected))
		_buttons[i].set_text_color(Color(1.0, 0.95, 0.75) if selected else Color(0.8, 0.75, 0.65))
	_buttons[1].text = "Confirmar?" if _confirming else "Menu principal"
	_button_cursor.visible = _area == Area.BUTTONS
	if _area == Area.BUTTONS:
		_button_cursor.position = _buttons[_button_index].position + Vector2(-12.0, (BUTTON_SIZE.y - _button_cursor.size.y) / 2.0)

	_refresh_stats()


## Vitórias-régias e pedras com as mesmas regras e a mesma arte do HUD; Folhas à direita.
func _refresh_stats() -> void:
	for child in _stats_layer.get_children():
		child.queue_free()
	var current_hp: int = 100
	var max_hp: int = 100
	var current_ammo: int = 6
	var max_ammo: int = 6
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player != null:
		current_hp = player.health.health
		max_hp = player.health.max_health
		current_ammo = player.ammo.current
		max_ammo = player.ammo.max_ammo
	else:
		# No mapa não há Valtair: usa o que a run guardou (-1 = ainda não guardou = cheio).
		if RunState.health >= 0:
			current_hp = RunState.health
		if RunState.ammo >= 0:
			current_ammo = RunState.ammo

	var hp_per_pad: int = 20
	var hud: Node = get_tree().current_scene.get_node_or_null("Hud") if get_tree().current_scene != null else null
	if hud is Hud:
		hp_per_pad = (hud as Hud).hp_per_pad
	var count: int = ceili(float(max_hp) / hp_per_pad)
	var pitch: float = minf(PAD_PITCH, PADS_MAX_WIDTH / maxf(1.0, float(count)))
	for i in count:
		var capacity: int = mini(hp_per_pad, max_hp - i * hp_per_pad)
		var inside: int = clampi(current_hp - i * hp_per_pad, 0, capacity)
		var texture: Texture2D = Hud.PAD_EMPTY
		if inside > 0:
			texture = Hud.PAD_FULL if float(inside) > capacity * 0.5 else Hud.PAD_HALF
		_add_rect(texture, PADS_POS + Vector2(i * pitch, 0.0), Vector2(28, 24))
	for i in max_ammo:
		_add_rect(Hud.STONE_FULL if i < current_ammo else Hud.STONE_EMPTY, STONES_POS + Vector2(i * STONE_PITCH, 0.0), Vector2(11, 10))
	_stat_leaves.text = str(RunState.leaves)


func _add_rect(texture: Texture2D, pos: Vector2, rect_size: Vector2) -> void:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.position = pos
	rect.size = rect_size
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_layer.add_child(rect)


func _slot_position(index: int) -> Vector2:
	var col: int = index % COLUMNS
	var row: int = floori(float(index) / COLUMNS)
	return GRID_POS + Vector2(col * SLOT, row * SLOT)


func _tex(file: String) -> Texture2D:
	var path: String = ART + file
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _frame_style(rarity: int) -> StyleBox:
	var texture: Texture2D = _tex(FRAME_FILES[rarity])
	if texture != null:
		var textured: StyleBoxTexture = StyleBoxTexture.new()
		textured.texture = texture
		return textured
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = Color(0.12, 0.09, 0.08)
	flat.border_color = RARITY_COLORS[rarity]
	flat.set_border_width_all(2)
	return flat


func _button_style(selected: bool) -> StyleBox:
	var texture: Texture2D = _tex("botao-selecionado.png" if selected else "botao.png")
	if texture != null:
		var textured: StyleBoxTexture = StyleBoxTexture.new()
		textured.texture = texture
		return textured
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = Color(0.62, 0.40, 0.20) if selected else Color(0.30, 0.20, 0.14)
	flat.border_color = Color(0.1, 0.06, 0.05)
	flat.set_border_width_all(1)
	return flat


func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build() -> void:
	var root: Control = Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	# Painel do artista (com o título "Pausado" já desenhado). Sem o arquivo, um painel simples.
	var panel_texture: Texture2D = load(PANEL_ART) as Texture2D if ResourceLoader.exists(PANEL_ART) else null
	if panel_texture != null:
		var panel_image: TextureRect = TextureRect.new()
		panel_image.texture = panel_texture
		panel_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(panel_image)
	else:
		var panel: Panel = Panel.new()
		panel.position = Vector2(60, 30)
		panel.size = Vector2(360, 210)
		var panel_style: StyleBoxFlat = StyleBoxFlat.new()
		panel_style.bg_color = Color8(35, 26, 31)
		panel_style.border_color = Color8(90, 63, 51)
		panel_style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", panel_style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(panel)
		var title: Label = _label("Pausado", 10, Color8(242, 233, 207))
		title.position = Vector2(60, 40)
		title.size = Vector2(360, 14)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(title)

	# Grade de relíquias.
	for i in COLUMNS * ROWS:
		var frame: Panel = Panel.new()
		frame.position = _slot_position(i)
		frame.size = Vector2(SLOT, SLOT)
		frame.mouse_filter = Control.MOUSE_FILTER_STOP
		frame.mouse_entered.connect(_on_slot_hover.bind(i))
		root.add_child(frame)
		var empty_box: Panel = Panel.new()
		empty_box.position = Vector2(2, 2)
		empty_box.size = Vector2(SLOT - 4, SLOT - 4)
		empty_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var empty_style: StyleBoxFlat = StyleBoxFlat.new()
		empty_style.bg_color = Color8(8, 12, 18)
		empty_style.border_color = Color8(58, 42, 44)
		empty_style.set_border_width_all(1)
		empty_box.add_theme_stylebox_override("panel", empty_style)
		frame.add_child(empty_box)
		var icon: TextureRect = TextureRect.new()
		icon.position = Vector2(4, 4)
		icon.size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# O quadro amarelo de seleção é opaco e fica por cima do slot: o ícone precisa ser
		# desenhado na frente dele (z_index maior), senão a relíquia selecionada "some".
		icon.z_index = 1
		frame.add_child(icon)
		_slot_frames.append(frame)
		_slot_icons.append(icon)
		_slot_empties.append(empty_box)

	_select_frame = Panel.new()
	_select_frame.size = Vector2(SLOT, SLOT)
	_select_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var select_texture: Texture2D = _tex("moldura-selecionada.png")
	if select_texture != null:
		var textured: StyleBoxTexture = StyleBoxTexture.new()
		textured.texture = select_texture
		_select_frame.add_theme_stylebox_override("panel", textured)
	else:
		var outline: StyleBoxFlat = StyleBoxFlat.new()
		outline.bg_color = Color(0, 0, 0, 0)
		outline.border_color = Color8(255, 182, 46)
		outline.set_border_width_all(2)
		_select_frame.add_theme_stylebox_override("panel", outline)
	root.add_child(_select_frame)

	# Descrição.
	var desc: Panel = Panel.new()
	desc.position = DESC_POS
	desc.size = DESC_SIZE
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var desc_texture: Texture2D = _tex("descri-item.png")
	if desc_texture != null:
		var desc_style: StyleBoxTexture = StyleBoxTexture.new()
		desc_style.texture = desc_texture
		desc.add_theme_stylebox_override("panel", desc_style)
	else:
		var desc_flat: StyleBoxFlat = StyleBoxFlat.new()
		desc_flat.bg_color = Color8(8, 12, 18)
		desc_flat.border_color = Color8(58, 42, 44)
		desc_flat.set_border_width_all(3)
		desc.add_theme_stylebox_override("panel", desc_flat)
	root.add_child(desc)
	_desc_name = _label("", 8, Color.WHITE)
	_desc_name.position = DESC_TEXT_POS
	_desc_name.size = Vector2(DESC_SIZE.x - DESC_TEXT_POS.x * 2.0, 10)
	desc.add_child(_desc_name)
	_desc_text = _label("", 8, Color8(200, 187, 151))
	_desc_text.position = DESC_TEXT_POS + Vector2(0, 12)
	_desc_text.size = Vector2(DESC_SIZE.x - DESC_TEXT_POS.x * 2.0, DESC_SIZE.y - DESC_TEXT_POS.y - 16.0)
	_desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_child(_desc_text)
	_desc_limit = _label("", 8, Color8(255, 182, 46))
	_desc_limit.position = Vector2(DESC_TEXT_POS.x, DESC_SIZE.y - 14.0)
	_desc_limit.size = Vector2(DESC_SIZE.x - DESC_TEXT_POS.x * 2.0, 10)
	desc.add_child(_desc_limit)

	# Vida e pedras (refeitas a cada _refresh) e Folhas.
	_stats_layer = Control.new()
	_stats_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stats_layer)
	var leaf_icon: TextureRect = TextureRect.new()
	leaf_icon.texture = Hud.LEAF_ICON
	leaf_icon.position = LEAF_ICON_POS
	leaf_icon.size = Vector2(16, 16)
	leaf_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(leaf_icon)
	_stat_leaves = _label("", 12, Color8(242, 233, 207))
	_stat_leaves.position = Vector2(LEAF_TEXT_RIGHT - 34.0, LEAF_TEXT_Y)
	_stat_leaves.size = Vector2(34, 16)
	_stat_leaves.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_stat_leaves)

	# Botões e cursor.
	var labels: Array[String] = ["Continuar", "Menu principal"]
	if not OS.has_feature("web"):
		labels.append("Sair")
	var start_x: float = BUTTON_X
	if labels.size() < 3:
		start_x += BUTTON_PITCH / 2.0 * (3 - labels.size())  # centraliza com 2 botões
	for i in labels.size():
		var button: PauseButton = PauseButton.new(BUTTON_SIZE)
		button.text = labels[i]
		button.position = Vector2(start_x + i * BUTTON_PITCH, BUTTON_Y)
		button.hovered.connect(_on_button_hover.bind(i))
		button.pressed.connect(_on_button_pressed.bind(i))
		root.add_child(button)
		_buttons.append(button)

	_button_cursor = TextureRect.new()
	_button_cursor.texture = _tex("cursor.png")
	_button_cursor.size = Vector2(8, 16)
	_button_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_button_cursor)


func _on_slot_hover(index: int) -> void:
	_area = Area.GRID
	_grid_index = index
	_confirming = false
	_refresh()


func _on_button_hover(index: int) -> void:
	_area = Area.BUTTONS
	_button_index = index
	_refresh()


func _on_button_pressed(index: int) -> void:
	_area = Area.BUTTONS
	_button_index = index
	_activate()

