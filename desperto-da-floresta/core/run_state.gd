# core/run_state.gd
extends Node
## Tudo o que precisa sobreviver à troca de cena durante uma run (vida, munição, progresso
## no mapa). Registre como Autoload "RunState", SEM class_name, depois do EventBus.
## Só guarda dados: quem decide quando trocar de cena é o SceneManager.
## Fora de uma run (ex.: a test_arena aberta com F6) `run_active` é falso e todo o jogo
## se comporta como antes, sem ler nem gravar nada aqui.

var run_active: bool = false

## Estado atual do Valtair. -1 = ainda não definido (o Player usa os valores da cena).
var health: int = -1
var ammo: int = -1

## Cópia de `health` e `ammo` no momento em que a sala atual começou.
## É o que volta quando o Valtair morre e a sala reinicia.
var entry_health: int = -1
var entry_ammo: int = -1

## Progresso no mapa (formato do MapScreen.export_progress()). Vazio = origem.
var map_progress: Dictionary = {}


func start_run() -> void:
	reset()
	run_active = true


func end_run() -> void:
	reset()


func reset() -> void:
	run_active = false
	health = -1
	ammo = -1
	entry_health = -1
	entry_ammo = -1
	map_progress = {}


func begin_room() -> void:
	entry_health = health
	entry_ammo = ammo


func restore_room_entry() -> void:
	health = entry_health
	ammo = entry_ammo
