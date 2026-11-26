# ui/damage_number.gd
class_name DamageNumber
extends Label
## Número de dano que sobe e some sobre o inimigo atingido. Branco = dano normal; laranja com "!"
## = golpe POTENCIALIZADO por relíquia (Dente de Piranha, Garras do Gavião, Pena Encantada...).
## Uso: DamageNumber.spawn(parent, posição_global, dano, potencializado)

const RISE: float = 16.0
const DURATION: float = 0.7


static func spawn(parent: Node, at: Vector2, amount: int, empowered: bool) -> void:
	var label: DamageNumber = DamageNumber.new()
	label.text = "%d%s" % [amount, "!" if empowered else ""]
	label.z_index = 50
	label.add_theme_font_size_override("font_size", 8 if not empowered else 10)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.15) if empowered else Color(1.0, 1.0, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.global_position = at + Vector2(randf_range(-6.0, 6.0) - 6.0, 0.0)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - RISE, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION)
	tween.chain().tween_callback(label.queue_free)
