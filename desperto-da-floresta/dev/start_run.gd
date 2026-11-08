# dev/start_run.gd
extends Node
## Stand-in do menu principal: abra esta cena e aperte F6 para começar uma run nova
## (mapa -> sala -> mapa). Apague quando o menu principal existir.

func _ready() -> void:
	SceneManager.start_run.call_deferred()
