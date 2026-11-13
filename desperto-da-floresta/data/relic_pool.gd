# data/relic_pool.gd
class_name RelicPool
extends Resource
## A lista de relíquias que podem aparecer (loja, recompensas, baús).

@export var relics: Array[RelicData] = []


## Relíquias da lista que o jogador ainda não tem. `rarities` vazio = qualquer raridade.
func available(owned: Array, rarities: Array = []) -> Array[RelicData]:
	var owned_ids: Array[StringName] = []
	for r in owned:
		owned_ids.append((r as RelicData).id)
	var out: Array[RelicData] = []
	for relic in relics:
		if relic.id in owned_ids:
			continue
		if not rarities.is_empty() and not (relic.rarity in rarities):
			continue
		out.append(relic)
	return out


## Uma relíquia aleatória que o jogador ainda não tem, ou null se acabaram.
func pick_random(owned: Array, rarities: Array = []) -> RelicData:
	var options: Array[RelicData] = available(owned, rarities)
	if options.is_empty():
		return null
	return options[randi() % options.size()]
