# core/scene_manager.gd
extends Node
## Troca de cenas do jogo: mapa <-> salas, morte e reinício. Registre como Autoload
## "SceneManager", DEPOIS do EventBus e do RunState, e SEM `class_name`.
## O mapa e as salas não se conhecem: só avisam (sinais/EventBus) e este arquivo decide.

const MAP_SCENE: String = "res://map/map_screen.tscn"
const COMBAT_ROOM_SCENE: String = "res://levels/combat_room.tscn"
const REST_SITE_SCENE: String = "res://levels/rest_site.tscn"
## Troque pelo caminho do menu quando ele existir. Enquanto o arquivo não existir,
## a morte definitiva só avisa no Output e começa uma run nova.
const MAIN_MENU_PATH: String = "res://ui/main_menu.tscn"

var _map: MapScreen


func _ready() -> void:
	EventBus.player_death_finished.connect(_on_player_death_finished)
	EventBus.room_exit_requested.connect(go_to_map)


## Começa uma run nova no início do mapa.
func start_run() -> void:
	RunState.start_run()
	go_to_map()


func go_to_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)
	await get_tree().scene_changed
	_map = get_tree().current_scene as MapScreen
	if _map == null:
		push_warning("SceneManager: a cena do mapa não é um MapScreen (%s)." % MAP_SCENE)
		return
	if not RunState.map_progress.is_empty():
		_map.import_progress(RunState.map_progress)
	_map.node_chosen.connect(_on_map_node_chosen)


func enter_room(scene_path: String) -> void:
	RunState.begin_room()
	get_tree().change_scene_to_file(scene_path)


## Reinicia a sala atual. Dentro de uma run, o Valtair volta com a vida e as pedras
## que tinha ao entrar nela (não dá para "farmar" munição morrendo).
func restart_room() -> void:
	if RunState.run_active:
		RunState.restore_room_entry()
	get_tree().reload_current_scene()


func go_to_main_menu() -> void:
	var was_in_run: bool = RunState.run_active
	RunState.end_run()
	if ResourceLoader.exists(MAIN_MENU_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
	elif was_in_run:
		push_warning("SceneManager: o menu principal ainda não existe (%s). Começando uma run nova no lugar." % MAIN_MENU_PATH)
		start_run()
	else:
		push_warning("SceneManager: o menu principal ainda não existe (%s). Reiniciando a sala no lugar." % MAIN_MENU_PATH)
		restart_room()


func _on_map_node_chosen(id: String, kind: int) -> void:
	RunState.map_progress = _map.export_progress()
	match kind:
		MapLayout.Kind.COMBATE:
			enter_room(COMBAT_ROOM_SCENE)
		MapLayout.Kind.DESCANSO:
			enter_room(REST_SITE_SCENE)
		_:
			push_warning("SceneManager: o nó '%s' (%s) ainda não tem sala. Siga para o próximo nó." % [id, MapLayout.KIND_NAMES[kind]])


func _on_player_death_finished(permanent: bool) -> void:
	if permanent:
		go_to_main_menu()
	else:
		restart_room()
