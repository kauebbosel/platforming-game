# entities/enemies/enemy_affix.gd
class_name EnemyAffix
extends RefCounted
## Afixos dos inimigos ELITE. Um elite é um inimigo comum reforçado (mais vida, mais Folhas)
## com UM afixo que muda o jeito de lutar. Sem arte nova: só números do EnemyData, uma cor
## sobre o sprite e o nome do afixo em texto acima do inimigo.
##
## Uso (a CombatRoom faz isso, DEPOIS de o inimigo entrar na árvore):
##     EnemyAffix.apply(enemy, id)
##
## Cada elite usa uma CÓPIA do EnemyData (o .tres é compartilhado: mexer nele direto mudaria
## TODOS os inimigos daquele tipo). Os estados leem os números de `enemy.data` a cada uso, por
## isso mudar a cópia no meio da luta (fúria) também funciona.
## A cor vai no `modulate` do nó RAIZ do inimigo, que os estados não usam (eles mexem só no do
## Sprite), então não atrapalha o brilho de dano nem a indicação de ataque. Por isso as cores
## são claras: multiplicadas pela indicação de ataque, ainda dá para ler o golpe se preparando.
## Quem pode ser elite: EnemyData.can_be_elite.

enum Id { VELOZ, FRENETICO, BLINDADO, FURIOSO }

## Vida e Folhas que TODO elite ganha, qualquer que seja o afixo.
const HEALTH_MULT: float = 2.0
const LEAVES_MULT: float = 2.0

## Fúria do Furioso: entra quando a vida cai até esta fração da máxima.
const ENRAGE_AT: float = 0.5
const ENRAGE_TINT: Color = Color(1.0, 0.4, 0.35)

const INFO := {
	Id.VELOZ: {
		"name": "Veloz",
		"tint": Color(0.55, 1.0, 0.9),
		"desc": "Anda e investe bem mais rápido.",
	},
	Id.FRENETICO: {
		"name": "Frenético",
		"tint": Color(1.0, 0.65, 0.85),
		"desc": "Ataca com muito mais frequência.",
	},
	Id.BLINDADO: {
		"name": "Blindado",
		"tint": Color(0.7, 0.72, 0.85),
		"desc": "Muito mais vida e não recua ao apanhar.",
	},
	Id.FURIOSO: {
		"name": "Furioso",
		"tint": Color(1.0, 0.78, 0.55),
		"desc": "Com metade da vida, entra em fúria.",
	},
}


static func all_ids() -> Array:
	return INFO.keys()


static func is_valid(id: int) -> bool:
	return INFO.has(id)


static func name_of(id: int) -> String:
	return String(INFO[id]["name"]) if INFO.has(id) else ""


static func description_of(id: int) -> String:
	return String(INFO[id]["desc"]) if INFO.has(id) else ""


static func tint_of(id: int) -> Color:
	return INFO[id]["tint"] if INFO.has(id) else Color.WHITE


## Transforma o inimigo (já na árvore) em elite com o afixo `id`.
static func apply(enemy: EnemyBase, id: int) -> void:
	if not is_valid(id) or enemy.data == null:
		return
	var data: EnemyData = enemy.data.duplicate() as EnemyData
	data.max_health = roundi(data.max_health * HEALTH_MULT)
	data.leaves_min = roundi(data.leaves_min * LEAVES_MULT)
	data.leaves_max = roundi(data.leaves_max * LEAVES_MULT)
	match id:
		Id.VELOZ:
			data.move_speed *= 1.5
			data.charge_speed *= 1.3
			data.fly_acceleration *= 1.4
			data.attack_cooldown *= 0.85
		Id.FRENETICO:
			data.attack_cooldown *= 0.5
			data.shoot_windup = maxf(data.shoot_windup * 0.75, 0.35)
			data.shoot_recover *= 0.6
			data.double_scratch_chance = minf(data.double_scratch_chance + 0.3, 1.0)
			data.hurt_duration *= 0.6
		Id.BLINDADO:
			data.max_health = roundi(data.max_health * 1.4)
			data.hurt_interrupts = false  # os golpes só o fazem piscar: sem stunlock
			data.move_speed *= 0.85
		Id.FURIOSO:
			pass  # a fúria vem durante a luta (ver _check_enrage)
	enemy.data = data
	# O _ready do inimigo já copiou a vida do EnemyData antigo para o Health: refaz com a nova.
	enemy.health.max_health = data.max_health
	enemy.health.reset()
	enemy.modulate = tint_of(id)
	_add_label(enemy, id)


## Nome flutuante acima da cabeça (texto branco: a cor do afixo vem do `modulate` do inimigo).
static func _add_label(enemy: EnemyBase, id: int) -> void:
	var label: Label = Label.new()
	label.name = "AffixLabel"
	label.text = name_of(id).to_upper()
	label.custom_minimum_size = Vector2(80.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	var top: float = enemy.sprite.position.y + enemy.sprite.get_rect().position.y * absf(enemy.sprite.scale.y)
	label.position = Vector2(-40.0, top - 14.0)
	enemy.add_child(label)
	enemy.health.died.connect(label.hide)
	if id == Id.FURIOSO:
		enemy.health.damaged.connect(func(_amount: int, _source: Node) -> void: EnemyAffix._check_enrage(enemy, label))


static func _check_enrage(enemy: EnemyBase, label: Label) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead() or enemy.has_meta(&"enraged"):
		return
	if enemy.health.health > enemy.health.max_health * ENRAGE_AT:
		return
	enemy.set_meta(&"enraged", true)
	var data: EnemyData = enemy.data  # a cópia deste elite
	data.move_speed *= 1.4
	data.charge_speed *= 1.25
	data.fly_acceleration *= 1.3
	data.attack_cooldown *= 0.6
	data.shoot_windup = maxf(data.shoot_windup * 0.8, 0.35)
	data.shoot_recover *= 0.7
	enemy.modulate = ENRAGE_TINT
	if is_instance_valid(label):
		label.text = "FÚRIA!"
