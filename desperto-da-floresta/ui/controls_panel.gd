# ui/controls_panel.gd
class_name ControlsPanel
extends Control
## Tela de CONTROLES do menu principal: uma tabela "tecla -> o que faz", montada por código.
## As teclas vêm do Input Map (se o jogador/projeto remapear, a tela acompanha); `fallback`
## vale quando a ação não existe. Também oferece legend(), um resumo curto para o rodapé do menu.
## Arte usada se existir (senão cai num visual simples): painel (descri-item) e moldura das
## teclas (moldura-comum). Se existir `controles.png` em hud/usar-jogo/, ela é mostrada NO LUGAR
## da tabela (é só soltar o arquivo lá). Fecha com Esc, Enter, [E] ou o botão Voltar.

signal closed

const CONTROLS_ART: String = "res://assets/art/hud/usar-jogo/controles.png"
const PANEL_ART: String = "res://assets/art/hud/usar-jogo/descri-item.png"
const KEY_ART: String = "res://assets/art/hud/usar-jogo/moldura-comum.png"
const BUTTON_ART: String = "res://assets/art/hud/usar-jogo/botao-selecionado.png"
## Ignora o input logo ao abrir (evita que o [E] que abriu a tela já a feche).
const INPUT_LOCK_MS: int = 250

## Como o Godot chama algumas teclas -> como aparece na tela.
const KEY_NAMES := { "Space": "Espaço", "Escape": "Esc" }

## label = o que a tecla faz; short = versão curta do rodapé; actions = ações cujas teclas
## aparecem (uma tecla por ação); fallback = teclas de reserva, na mesma ordem.
const ROWS: Array[Dictionary] = [
	{ "label": "Mover", "short": "mover", "actions": [&"move_left", &"move_right"], "fallback": ["A", "D"] },
	{ "label": "Pular", "short": "pular", "actions": [&"jump"], "fallback": ["Espaço"] },
	{ "label": "Atacar (corpo a corpo)", "short": "atacar", "actions": [&"attack"], "fallback": ["J"] },
	{ "label": "Disparar o bodoque", "short": "bodoque", "actions": [&"ranged_attack"], "fallback": ["K"] },
	{ "label": "Esquivar", "short": "esquivar", "actions": [&"dodge"], "fallback": ["Shift"] },
	{ "label": "Interagir (portas, baús, loja)", "short": "interagir", "actions": [&"interact"], "fallback": ["E"] },
	{ "label": "Subir/descer cipós e plataformas", "actions": [&"move_up", &"move_down"], "fallback": ["W", "S"] },
	{ "label": "Pausar e ver as relíquias", "actions": [&"pause"], "fallback": ["Esc"] },
]

var _opened_ms: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


## Mostra a tela (remonta a tabela, para refletir teclas remapeadas).
func open() -> void:
	_rebuild()
	show()
	_opened_ms = Time.get_ticks_msec()


func _close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Enquanto aberta, engole o input: o menu por trás não deve reagir.
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _opened_ms < INPUT_LOCK_MS:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"ui_accept") \
			or event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause"):
		_close()


# --------------------------------------------------------------------------- dados
## Nomes das teclas de uma linha (uma por ação).
static func keys_of(row: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var actions: Array = row["actions"]
	var fallback: Array = row["fallback"]
	for i in actions.size():
		var text: String = ""
		var action: StringName = actions[i]
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				var key: InputEventKey = event as InputEventKey
				if key != null:
					text = key.as_text_physical_keycode()
					break
		if text.is_empty():
			text = String(fallback[i])
		result.append(String(KEY_NAMES.get(text, text)))
	return result


## Resumo curto em duas linhas, para o rodapé do menu: "A/D mover · Espaço pular · ...".
static func legend() -> String:
	var parts: Array[String] = []
	for row in ROWS:
		if row.has("short"):
			parts.append("%s %s" % ["/".join(keys_of(row)), row["short"]])
	var half: int = ceili(parts.size() / 2.0)
	return "  ·  ".join(parts.slice(0, half)) + "\n" + "  ·  ".join(parts.slice(half))


# --------------------------------------------------------------------------- visual
func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	column.add_child(_label("Controles", 14, Color(1.0, 0.88, 0.45), HORIZONTAL_ALIGNMENT_CENTER))
	if ResourceLoader.exists(CONTROLS_ART):
		var art: TextureRect = TextureRect.new()
		art.texture = load(CONTROLS_ART)
		art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		column.add_child(art)
	else:
		column.add_child(_table())

	column.add_child(_label("[%s] ou Esc para voltar" % InputHint.key_name(&"interact"), 8, Color(0.65, 0.62, 0.55), HORIZONTAL_ALIGNMENT_CENTER))
	var back: Button = Button.new()
	back.text = "Voltar"
	back.custom_minimum_size = Vector2(92, 21)
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 10)
	back.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	var style: StyleBox = _button_style()
	for state in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(state, style)
	back.pressed.connect(_close)
	column.add_child(back)


func _table() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 5)
	for row in ROWS:
		var caps: HBoxContainer = HBoxContainer.new()
		caps.custom_minimum_size = Vector2(66, 0)
		caps.add_theme_constant_override("separation", 3)
		caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for text in keys_of(row):
			caps.add_child(_keycap(text))
		grid.add_child(caps)
		var description: Label = _label(row["label"], 9, Color(0.92, 0.9, 0.82), HORIZONTAL_ALIGNMENT_LEFT)
		description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(description)
	return grid


func _keycap(text: String) -> PanelContainer:
	var cap: PanelContainer = PanelContainer.new()
	cap.add_theme_stylebox_override("panel", _key_style())
	cap.add_child(_label(text, 9, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	return cap


func _label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.1))
	return label


func _panel_style() -> StyleBox:
	if ResourceLoader.exists(PANEL_ART):
		return _textured(PANEL_ART, 5, 14, 12)
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = Color(0.13, 0.10, 0.12)
	flat.border_color = Color(0.40, 0.26, 0.16)
	flat.set_border_width_all(2)
	flat.set_content_margin_all(12)
	return flat


func _key_style() -> StyleBox:
	if ResourceLoader.exists(KEY_ART):
		return _textured(KEY_ART, 5, 5, 2)
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = Color(0.17, 0.13, 0.14)
	flat.border_color = Color(0.78, 0.72, 0.58)
	flat.set_border_width_all(1)
	flat.content_margin_left = 5.0
	flat.content_margin_right = 5.0
	flat.content_margin_top = 1.0
	flat.content_margin_bottom = 1.0
	return flat


func _button_style() -> StyleBox:
	if ResourceLoader.exists(BUTTON_ART):
		var textured: StyleBoxTexture = StyleBoxTexture.new()
		textured.texture = load(BUTTON_ART)
		return textured
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = Color(0.62, 0.40, 0.20)
	flat.border_color = Color(0.1, 0.06, 0.05)
	flat.set_border_width_all(1)
	return flat


## Moldura de 9 fatias: `edge` = largura da borda que não estica; `pad_x`/`pad_y` = respiro interno.
func _textured(path: String, edge: float, pad_x: float, pad_y: float) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = edge
	style.texture_margin_right = edge
	style.texture_margin_top = edge
	style.texture_margin_bottom = edge
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style
