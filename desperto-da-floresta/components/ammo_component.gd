# components/ammo_component.gd
class_name AmmoComponent
extends Node
## Munição contada (pedras). Só guarda e controla a quantidade; quem atira e quem mostra
## na tela (HUD) apenas conversam com este componente.
## Quando existir o RunState, SÓ este arquivo muda para ler/gravar a munição lá,
## para ela persistir entre salas. Quem usa o componente não precisa mudar.

## Emitido sempre que a quantidade muda (o HUD escuta este sinal).
signal changed(current: int, maximum: int)
## Emitido ao tentar gastar sem ter munição (bom lugar para um som de "vazio").
signal depleted

@export var max_ammo: int = 6

var current: int = 0


func _ready() -> void:
	current = max_ammo


func has(amount: int = 1) -> bool:
	return current >= amount


## Gasta munição. Retorna false (e emite `depleted`) se não houver o suficiente.
func consume(amount: int = 1) -> bool:
	if current < amount:
		depleted.emit()
		return false
	current -= amount
	changed.emit(current, max_ammo)
	return true


## Recarrega. Sem argumento, enche tudo (use na fogueira e na loja).
func refill(amount: int = -1) -> void:
	var target: int = max_ammo if amount < 0 else mini(current + amount, max_ammo)
	if target == current:
		return
	current = target
	changed.emit(current, max_ammo)


## Para relíquias que aumentam a capacidade no futuro.
func set_max(value: int, refill_to_full: bool = false) -> void:
	max_ammo = maxi(value, 0)
	current = max_ammo if refill_to_full else mini(current, max_ammo)
	changed.emit(current, max_ammo)
