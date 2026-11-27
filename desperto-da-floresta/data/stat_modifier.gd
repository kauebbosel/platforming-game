# data/stat_modifier.gd
class_name StatModifier
extends Resource
## Uma alteração num número do PlayerStats: soma (ADD) ou multiplica (MULTIPLY).
## `stat` é o nome exato do campo no PlayerStats (ex.: &"move_speed").

enum Op { ADD, MULTIPLY }

@export var stat: StringName
@export var op: Op = Op.MULTIPLY
@export var value: float = 1.0


func apply(stats: Object) -> void:
	if not (stat in stats):
		push_warning("StatModifier: o PlayerStats não tem o campo '%s'." % stat)
		return
	var current: Variant = stats.get(stat)
	var base: float = float(current)
	var result: float = (base + value) if op == Op.ADD else (base * value)
	# Campos inteiros (ex.: bônus de vida) continuam inteiros.
	if typeof(current) == TYPE_INT:
		stats.set(stat, roundi(result))
	else:
		stats.set(stat, result)
