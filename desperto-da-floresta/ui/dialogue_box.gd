# ui/dialogue_box.gd
class_name DialogueBox
extends CanvasLayer
## Caixa de diálogo. Monta tudo por código (não precisa de cena).
## Uso, de qualquer script com acesso a um nó da cena atual:
##     await DialogueBox.play(self, Dialogues.INTRO)
## O jogo fica pausado enquanto a caixa está aberta e volta ao estado de antes ao fechar.
## Controles: [E] ou Enter avança (na primeira vez mostra a fala toda); Esc pula tudo.

signal finished

const CHARS_PER_SECOND: float = 45.0
## Ignora o input logo depois de abrir, senão o [E] que abriu o diálogo já avançaria a primeira fala.
const IGNORE_INPUT_MS: int = 200

var _lines: Array = []
var _index: int = 0
var _skippable: bool = true
var _was_paused: bool = false
var _opened_ms: int = 0
var _typing: bool = false
var _progress: float = 0.0
var _closed: bool = false

var _speaker: Label
var _text: Label
var _hint: Label


## Abre a caixa, espera o jogador terminar (ou pular) e fecha. Precisa de `await`.
static func play(host: Node, lines: Array, skippable: bool = true) -> void:
	if lines.is_empty():
		return
	var box := DialogueBox.new()
	host.add_child(box)
	box.start(lines, skippable)
	await box.finished
	if is_instance_valid(box):
		box.queue_free()


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func start(lines: Array, skippable: bool = true) -> void:
	_lines = lines
	_skippable = skippable
	_index = 0
	_opened_ms = Time.get_ticks_msec()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_hint.text = "[%s] Continuar" % InputHint.key_name(&"interact")
	if _skippable:
		_hint.text += "    [%s] Pular" % InputHint.key_name(&"pause")
	_show_line()


func _exit_tree() -> void:
	# Se a cena for trocada com a caixa aberta, devolve a pausa e libera quem está esperando.
	_close()


func _process(delta: float) -> void:
	if not _typing:
		return
	_progress += CHARS_PER_SECOND * delta
	_text.visible_characters = int(_progress)
	if _text.visible_characters >= _text.text.length():
		_finish_typing()


func _input(event: InputEvent) -> void:
	if _closed:
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _opened_ms < IGNORE_INPUT_MS:
		return
	if _skippable and event.is_action_pressed(&"pause"):
		_close()
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		_advance()


func _advance() -> void:
	if _typing:
		_finish_typing()
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()


func _show_line() -> void:
	var line: Array = _lines[_index]
	var who: String = line[0]
	_speaker.text = who
	_speaker.visible = who != ""
	_text.text = line[1]
	_text.visible_characters = 0
	_progress = 0.0
	_typing = true


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1


func _close() -> void:
	if _closed:
		return
	_closed = true
	_typing = false
	get_tree().paused = _was_paused
	finished.emit()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16.0
	panel.offset_right = -16.0
	panel.offset_top = -96.0
	panel.offset_bottom = -12.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.07, 0.96)
	style.border_color = Color(0.62, 0.40, 0.20)
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 10)
	_speaker.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	box.add_child(_speaker)

	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 10)
	_text.add_theme_color_override("font_color", Color(0.93, 0.95, 0.90))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 30)
	box.add_child(_text)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint)
