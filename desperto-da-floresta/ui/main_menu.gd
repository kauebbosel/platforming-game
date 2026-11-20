# ui/main_menu.gd
class_name MainMenu
extends Control
## Menu principal. Monta tudo por código. Navegação: W/S ou setas, [E] ou Enter confirma,
## o mouse também funciona. "Jogar" começa uma run (SceneManager.start_run) e "Sair" fecha o jogo.
## Pode ser rodado direto com F6, ou ser a Main Scene do projeto.
## Arte usada se existir (senão cai num visual simples): botao, botao-selecionado e cursor.

const BUTTON_ART: String = "res://assets/art/hud/usar-jogo/botao.png"
const BUTTON_SELECTED_ART: String = "res://assets/art/hud/usar-jogo/botao-selecionado.png"
const CURSOR_ART: String = "res://assets/art/hud/usar-jogo/cursor.png"
## Ignora o input logo ao abrir (evita que o [E] da tela anterior ative um botão).
const INPUT_LOCK_MS: int = 300

var _buttons: Array[Button] = []
var _selected: int = 0
var _cursor: TextureRect
var _opened_ms: int = 0
var _busy: bool = false
var _style_normal: StyleBox
var _style_selected: StyleBox


func _ready() -> void:
	_opened_ms = Time.get_ticks_msec()
	_style_normal = _make_style(BUTTON_ART, Color(0.30, 0.20, 0.14))
	_style_selected = _make_style(BUTTON_SELECTED_ART, Color(0.62, 0.40, 0.20))
	_build()
	_select(0)
	# O cursor só pode ser posicionado depois que o layout calcula o tamanho dos botões.
	await get_tree().process_frame
	_place_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or Time.get_ticks_msec() - _opened_ms < INPUT_LOCK_MS:
		return
	if event.is_action_pressed(&"ui_up") or _is_key(event, KEY_W):
		_select(posmod(_selected - 1, _buttons.size()))
	elif event.is_action_pressed(&"ui_down") or _is_key(event, KEY_S):
		_select(posmod(_selected + 1, _buttons.size()))
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact"):
		_buttons[_selected].pressed.emit()


func _is_key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == keycode


func _on_play() -> void:
	if _busy:
		return
	_busy = true
	SceneManager.start_run()


func _on_quit() -> void:
	if _busy:
		return
	_busy = true
	get_tree().quit()


func _select(index: int) -> void:
	_selected = index
	for i in _buttons.size():
		var chosen: bool = i == _selected
		_buttons[i].add_theme_stylebox_override("normal", _style_selected if chosen else _style_normal)
		_buttons[i].add_theme_color_override("font_color", Color(1.0, 0.95, 0.75) if chosen else Color(0.8, 0.75, 0.65))
	_place_cursor()


func _place_cursor() -> void:
	if _cursor == null or _buttons.is_empty():
		return
	var button: Button = _buttons[_selected]
	_cursor.global_position = button.global_position + Vector2(-_cursor.size.x - 6.0, (button.size.y - _cursor.size.y) / 2.0)


func _make_style(path: String, fallback: Color) -> StyleBox:
	if ResourceLoader.exists(path):
		var textured: StyleBoxTexture = StyleBoxTexture.new()
		textured.texture = load(path)
		return textured
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = fallback
	flat.border_color = Color(0.1, 0.06, 0.05)
	flat.set_border_width_all(1)
	return flat


func _add_button(label: String, on_pressed: Callable, parent: Control) -> void:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(92, 21)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override("hover", _style_selected)
	button.add_theme_stylebox_override("pressed", _style_selected)
	var index: int = _buttons.size()
	button.mouse_entered.connect(func() -> void: _select(index))
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	_buttons.append(button)


func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.05, 0.10, 0.09)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)

	column.add_child(_label("Desperto na Floresta", 24, Color(0.78, 0.95, 0.45)))
	column.add_child(_label("entre o sonho e a realidade", 8, Color(0.65, 0.62, 0.55)))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	column.add_child(spacer)

	_add_button("Jogar", _on_play, column)
	if not OS.has_feature("web"):
		_add_button("Sair", _on_quit, column)

	if ResourceLoader.exists(CURSOR_ART):
		_cursor = TextureRect.new()
		_cursor.texture = load(CURSOR_ART)
		_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_cursor)


func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.1))
	return label
