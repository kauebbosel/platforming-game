# data/relic_data.gd
class_name RelicData
extends Resource
## Uma relíquia: um nome, um texto e uma lista de modificadores do PlayerStats.
## Criar uma relíquia nova de atributo é só criar um .tres, sem escrever código.

enum Rarity { COMMON, UNCOMMON, RARE }

## Preço na Mercadora por raridade (GDD: economia).
const PRICE_BY_RARITY: Dictionary = {
	Rarity.COMMON: 80,
	Rarity.UNCOMMON: 100,
	Rarity.RARE: 120,
}

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var modifiers: Array[StatModifier] = []


func price() -> int:
	return PRICE_BY_RARITY[rarity]


func apply_to(stats: Object) -> void:
	for modifier in modifiers:
		modifier.apply(stats)
