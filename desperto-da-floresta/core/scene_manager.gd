# core/scene_manager.gd
extends Node
## Troca de cenas do jogo. Registre como Autoload com o nome "SceneManager",
## DEPOIS do EventBus na lista, e SEM `class_name` (autoloads não podem ter).
## Por enquanto só trata a morte do Valtair; a integração mapa <-> sala (Dia 7)
## entra aqui depois.

## Troque pelo caminho do menu quando ele existir. Enquanto o arquivo não existir,
## a morte definitiva só avisa no Output e reinicia a sala.
const MAIN_MENU_PATH: String = "res://ui/main_menu.tscn"


func _ready() -> void:
	EventBus.player_death_finished.connect(_on_player_death_finished)


func restart_room() -> void:
	get_tree().reload_current_scene()


func go_to_main_menu() -> void:
	if ResourceLoader.exists(MAIN_MENU_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
	else:
		push_warning("SceneManager: o menu principal ainda não existe (%s). Reiniciando a sala no lugar." % MAIN_MENU_PATH)
		restart_room()


func _on_player_death_finished(permanent: bool) -> void:
	if permanent:
		go_to_main_menu()
	else:
		restart_room()
