# levels/relic_draft.gd
class_name RelicDraft
extends RefCounted
## Escolha de relíquia numa sala de recompensa: em vez de um pedestal só, aparecem N lado a
## lado com relíquias DIFERENTES, e pegar uma faz as outras sumirem (o mesmo que a sala do
## Curupira já faz). Não tem arte nem UI próprias: usa o RelicPedestal, que mostra nome e
## descrição quando o Valtair chega perto.

const PEDESTAL_SCENE: PackedScene = preload("res://entities/pickups/relic_pedestal.tscn")


## Cria até `count` pedestais (menos, se faltarem relíquias que o jogador ainda não tem).
## `anchor` = onde o grupo fica, no chão; `spacing` = distância entre pedestais.
## `grow_left` = false: o grupo fica CENTRADO no `anchor`.
## `grow_left` = true: o primeiro fica no `anchor` e os outros à esquerda dele (para não
## invadir o que está à direita, como o baú do Parkour).
## Devolve os pedestais criados (vazio se não há relíquia para oferecer).
static func spawn(room: Node2D, pool: RelicPool, rarities: Array, count: int, anchor: Vector2, spacing: float = 56.0, grow_left: bool = false, arm_delay: float = 0.0) -> Array[RelicPedestal]:
	var pedestals: Array[RelicPedestal] = []
	if pool == null or count <= 0:
		return pedestals
	var options: Array[RelicData] = pool.available(RunState.relics, rarities)
	options.shuffle()
	var n: int = mini(count, options.size())
	for i in n:
		var pedestal: RelicPedestal = PEDESTAL_SCENE.instantiate() as RelicPedestal
		pedestal.relic = options[i]
		pedestal.arm_delay = arm_delay
		room.add_child(pedestal)
		var x: float = -float(i) * spacing if grow_left else (float(i) - float(n - 1) * 0.5) * spacing
		pedestal.global_position = anchor + Vector2(x, 0.0)
		pedestals.append(pedestal)
	for pedestal in pedestals:
		pedestal.taken.connect(func(_relic: RelicData) -> void: RelicDraft._discard_others(pedestals, pedestal))
	return pedestals


static func _discard_others(pedestals: Array[RelicPedestal], chosen: RelicPedestal) -> void:
	for other in pedestals:
		if other != chosen and is_instance_valid(other) and not other.is_queued_for_deletion():
			other.queue_free()
