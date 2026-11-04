# core/event_bus.gd
extends Node
## Barramento global de eventos.
## Registre como Autoload com o nome "EventBus" e SEM `class_name` (senão dá conflito de nome).
## Só entram aqui eventos que mais de um sistema precisa ouvir; cada sinal novo
## é adicionado quando passa a ser usado, não antes.
## Convenção de nome: quem emitiu + o que aconteceu, no passado (player_health_changed).

@warning_ignore("unused_signal")
signal player_health_changed(current: int, maximum: int)
@warning_ignore("unused_signal")
signal player_ammo_changed(current: int, maximum: int)
@warning_ignore("unused_signal")
signal player_died
