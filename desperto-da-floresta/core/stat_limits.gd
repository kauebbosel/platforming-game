# core/stat_limits.gd
class_name StatLimits
extends RefCounted
## Tetos e pisos dos atributos que as relíquias alteram, e o nome de cada um para a interface.
## Os limites são RELATIVOS ao valor de fábrica do atributo (o do player_stats.tres):
## 1.6 = no máximo +60% sobre o valor base; 0.5 = no mínimo metade do valor base. Assim eles
## continuam valendo se você mudar o valor base, e funcionam até no jump_velocity (que é negativo).
## Vector2(piso, teto). Use -INF / INF para "sem limite" daquele lado.
## Atributo que não aparece aqui não tem limite. Ajuste os números à vontade.

const LIMITS: Dictionary = {
	&"attack_speed_mult": Vector2(-INF, 2.0),
	&"melee_damage_mult": Vector2(-INF, 3.0),
	&"ranged_damage_mult": Vector2(-INF, 3.0),
	&"projectile_speed_mult": Vector2(-INF, 3.0),
	&"move_speed": Vector2(-INF, 2.0),
	&"jump_velocity": Vector2(-INF, 1.25),  # a altura do pulo não pode passar do que o parkour aguenta
	&"dash_cooldown": Vector2(0.4, INF),
	&"damage_taken_mult": Vector2(0.7, INF),
	&"fire_damage_taken_mult": Vector2(0.5, INF),
	&"low_health_damage_mult": Vector2(-INF, 2.0),
	&"air_damage_mult": Vector2(-INF, 2.0),
	&"post_dash_damage_mult": Vector2(-INF, 2.5),
	&"leaf_bonus_mult": Vector2(-INF, 2.0),
}

const LABELS: Dictionary = {
	&"attack_speed_mult": "Vel. de ataque",
	&"melee_damage_mult": "Dano corpo a corpo",
	&"ranged_damage_mult": "Dano à distância",
	&"projectile_speed_mult": "Vel. dos projéteis",
	&"move_speed": "Vel. de movimento",
	&"jump_velocity": "Altura do pulo",
	&"dash_cooldown": "Recarga do dash",
	&"damage_taken_mult": "Resistência a dano",
	&"fire_damage_taken_mult": "Resist. ao fogo",
	&"low_health_damage_mult": "Dano com vida baixa",
	&"air_damage_mult": "Dano no ar",
	&"post_dash_damage_mult": "Dano pós-dash",
	&"leaf_bonus_mult": "Bônus de Folhas",
}

## Teto do multiplicador TOTAL de um golpe ou tiro (permanente × condicionais).
## Rede de segurança contra dano infinito; alto para não interferir no balanceamento normal.
const MAX_HIT_DAMAGE_MULT: float = 10.0

static func label(stat: StringName) -> String:
	return String(LABELS.get(stat, stat))


## Guarda o valor de fábrica de cada atributo com limite. Chame ANTES de aplicar as relíquias.
static func base_values(stats: Object) -> Dictionary:
	var out: Dictionary = {}
	for stat: StringName in LIMITS:
		if stat in stats:
			out[stat] = float(stats.get(stat))
	return out


## Aplica os limites em `stats` (já com as relíquias) e devolve quais atributos estão NO limite
## (bateram nele ou chegaram exatamente nele).
static func apply(stats: Object, base: Dictionary) -> Array[StringName]:
	var hit: Array[StringName] = []
	for stat: StringName in LIMITS:
		var base_value: float = float(base.get(stat, 0.0))
		if is_zero_approx(base_value):
			continue  # sem valor base não existe "proporção" (ex.: bônus de vida, que é soma)
		var limit: Vector2 = LIMITS[stat]
		var ratio: float = float(stats.get(stat)) / base_value
		if ratio >= limit.y or ratio <= limit.x:
			hit.append(stat)
			stats.set(stat, base_value * clampf(ratio, limit.x, limit.y))
	return hit


## Texto do aviso "antes de pegar" (pedestal e loja) a partir de RunState.preview_relic().
## Vazio se a relíquia não esbarra em nenhum limite.
static func preview_text(preview: Dictionary) -> String:
	var lines: Array[String] = []
	for stat: StringName in (preview.get("no_effect", []) as Array):
		lines.append("%s: já no limite" % label(stat))
	for stat: StringName in (preview.get("reaches", []) as Array):
		lines.append("%s: atinge o limite" % label(stat))
	return "\n".join(lines)


## Aviso grave (a relíquia não ajuda em algo) ou só informativo (parte do bônus se perde)?
static func preview_is_severe(preview: Dictionary) -> bool:
	return not (preview.get("no_effect", []) as Array).is_empty()
