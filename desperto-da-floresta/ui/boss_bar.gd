# ui/boss_bar.gd
class_name BossBar
extends CanvasLayer
## Barra de vida do chefe, centralizada embaixo (GDD 6). Só escuta o HealthComponent do chefe.
## Provisória: desenhada com retângulos. Quando for usar a arte (vida-boss.png, 242x12),
## troque os dois ColorRect por TextureRect.
## Uso: var bar := BossBar.new(); add_child(bar); bar.setup("Curupira", boss.health)

const BAR_WIDTH: float = 242.0
const BAR_HEIGHT: float = 12.0

var _fill: ColorRect
var _name_label: Label


func _ready() -> void:
	layer = 10
	_build()


func setup(boss_name: String, health: HealthComponent) -> void:
	_name_label.text = boss_name
	health.changed.connect(_on_health_changed)
	_on_health_changed(health.health, health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	var ratio: float = clampf(float(current) / maxf(1.0, float(maximum)), 0.0, 1.0)
	_fill.size.x = BAR_WIDTH * ratio


func _build() -> void:
	var frame: ColorRect = ColorRect.new()
	frame.color = Color(0.08, 0.05, 0.05)
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = -BAR_WIDTH / 2.0 - 2.0
	frame.offset_right = BAR_WIDTH / 2.0 + 2.0
	frame.offset_top = -BAR_HEIGHT - 12.0
	frame.offset_bottom = -10.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var back: ColorRect = ColorRect.new()
	back.color = Color(0.28, 0.08, 0.1)
	back.position = Vector2(2, 2)
	back.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back)

	_fill = ColorRect.new()
	_fill.color = Color(0.78, 0.16, 0.2)
	_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_fill)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.16))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.custom_minimum_size = Vector2(BAR_WIDTH, 0)
	_name_label.position = Vector2(2, -11)
	frame.add_child(_name_label)
