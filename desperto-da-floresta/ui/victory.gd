# ui/victory.gd
class_name Victory
extends Control
## Final de vitória (GDD 7 e 10 "Boss Final: Vitória e encerramento da run"). Primeiro toca o
## epílogo (Dialogues.EPILOGO, jogo pausado, pulável), depois mostra a tela de vitória com o
## resumo da run. [E] ou Enter volta ao menu, mas só depois de LOCK_SECONDS; sem apertar
## nada, volta sozinha depois de AUTO_RETURN_SECONDS.

const LOCK_SECONDS: float = 1.2
const AUTO_RETURN_SECONDS: float = 25.0
const FADE_SECONDS: float = 1.5

var _elapsed: float = 0.0
var _screen_ready: bool = false
var _done: bool = false
var _column: VBoxContainer
var _hint: Label


func _ready() -> void:
	_build()
	await DialogueBox.play(self, Dialogues.EPILOGO)
	_screen_ready = true
	create_tween().tween_property(_column, "modulate:a", 1.0, FADE_SECONDS)


func _process(delta: float) -> void:
	if not _screen_ready:
		return
	_elapsed += delta
	if _elapsed >= LOCK_SECONDS:
		_hint.visible = true
	if _elapsed >= AUTO_RETURN_SECONDS:
		_return_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not _screen_ready or _elapsed < LOCK_SECONDS:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact"):
		_return_to_menu()


func _return_to_menu() -> void:
	if _done:
		return
	_done = true
	SceneManager.go_to_main_menu()


func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.05, 0.11, 0.08)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 8)
	_column.modulate.a = 0.0
	center.add_child(_column)

	_column.add_child(_label("VITÓRIA", 28, Color(1.0, 0.85, 0.35)))
	_column.add_child(_label("O que permanece real é a transformação de Valtair.", 10, Color(0.85, 0.9, 0.8)))
	var summary: String = "Folhas: %d      Relíquias: %d" % [RunState.leaves, RunState.relics.size()]
	_column.add_child(_label(summary, 8, Color(0.65, 0.7, 0.6)))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	_column.add_child(spacer)
	_hint = _label("[%s] Voltar ao menu" % InputHint.key_name(&"interact"), 8, Color(0.95, 0.85, 0.5))
	_hint.visible = false
	_column.add_child(_hint)


func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.05))
	return label
