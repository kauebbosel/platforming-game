# ui/game_over.gd
class_name GameOver
extends Control
## Tela de Game Over (GDD 5.1): aparece quando o Valtair morre dentro de uma run (morte
## definitiva) e volta ao menu principal. Mostra um resumo da run. [E] ou Enter volta ao menu,
## mas só depois de LOCK_SECONDS (quem estava apertando [E] na hora da morte não pula a tela);
## se ninguém apertar nada, volta sozinha depois de AUTO_RETURN_SECONDS.

const LOCK_SECONDS: float = 1.2
const AUTO_RETURN_SECONDS: float = 12.0
const FADE_SECONDS: float = 1.0

var _elapsed: float = 0.0
var _done: bool = false
var _hint: Label


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LOCK_SECONDS:
		_hint.visible = true
	if _elapsed >= AUTO_RETURN_SECONDS:
		_return_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _elapsed < LOCK_SECONDS:
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
	background.color = Color(0.03, 0.02, 0.03)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.modulate.a = 0.0
	center.add_child(column)

	column.add_child(_label("GAME OVER", 28, Color(0.85, 0.2, 0.25)))
	column.add_child(_label("A floresta não perdoa quem ignora seus perigos.", 10, Color(0.85, 0.82, 0.75)))
	var summary: String = "Folhas: %d      Relíquias: %d" % [RunState.leaves, RunState.relics.size()]
	column.add_child(_label(summary, 8, Color(0.65, 0.62, 0.55)))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	column.add_child(spacer)
	_hint = _label("[%s] Voltar ao menu" % InputHint.key_name(&"interact"), 8, Color(0.95, 0.85, 0.5))
	_hint.visible = false
	column.add_child(_hint)

	create_tween().tween_property(column, "modulate:a", 1.0, FADE_SECONDS)


func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05))
	return label
