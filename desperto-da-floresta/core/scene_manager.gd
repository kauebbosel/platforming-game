# core/scene_manager.gd
extends Node
## Troca de cenas do jogo: mapa <-> salas, morte e reinício. Registre como Autoload
## "SceneManager", DEPOIS do EventBus e do RunState, e SEM `class_name`.
## O mapa e as salas não se conhecem: só avisam (sinais/EventBus) e este arquivo decide.

const MAP_SCENE: String = "res://map/map_screen.tscn"
const COMBAT_ROOM_SCENE: String = "res://levels/combat_room.tscn"
const REST_SITE_SCENE: String = "res://levels/rest_site.tscn"
const SHOP_SCENE: String = "res://levels/shop_clearing.tscn"
const CURUPIRA_ROOM_SCENE: String = "res://levels/curupira_room.tscn"
const PARKOUR_ROOM_SCENE: String = "res://levels/parkour_room.tscn"
## Troque pelo caminho do menu quando ele existir. Enquanto o arquivo não existir,
## a morte definitiva só avisa no Output e começa uma run nova.
const MAIN_MENU_PATH: String = "res://ui/main_menu.tscn"
const GAME_OVER_SCENE: String = "res://ui/game_over.tscn"
const VICTORY_SCENE: String = "res://ui/victory.tscn"
## Sala do Boitatá (ainda não existe). Quando criar, é só colocar o caminho certo aqui.
const BOSS_ROOM_SCENE: String = "res://levels/boitata_room.tscn"

var _map: MapScreen
## Tipo do nó do mapa em que o Valtair está agora (-1 = nenhum). Serve para saber se a sala
## que acabou de ser concluída era o chefe final.
var _current_kind: int = -1


func _ready() -> void:
	InputSetup.apply_controls()  # pulo só no Espaço; W/S sobem e descem (GDD seção 4)
	EventBus.player_death_finished.connect(_on_player_death_finished)
	EventBus.room_exit_requested.connect(_on_room_exit_requested)


## Começa uma run nova no início do mapa.
func start_run() -> void:
	_current_kind = -1
	RunState.start_run()
	await go_to_map()
	# Introdução de cada partida (GDD 7.1): poema pulável por cima do mapa.
	if _map != null:
		await DialogueBox.play(_map, Dialogues.INTRO)


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


## Final da run: epílogo e tela de vitória, depois o menu principal.
func go_to_victory() -> void:
	if ResourceLoader.exists(VICTORY_SCENE):
		get_tree().change_scene_to_file(VICTORY_SCENE)
	else:
		push_warning("SceneManager: a tela de vitória não existe (%s). Indo direto ao menu." % VICTORY_SCENE)
		go_to_main_menu()


## Morte dentro de uma run é definitiva (GDD 10): Game Over e, depois, o menu principal.
func go_to_game_over() -> void:
	if ResourceLoader.exists(GAME_OVER_SCENE):
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
	else:
		push_warning("SceneManager: a tela de Game Over não existe (%s). Indo direto ao menu." % GAME_OVER_SCENE)
		go_to_main_menu()


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


## Uma sala pediu para sair. Se era o chefe final, a run termina em vitória; senão volta ao mapa.
func _on_room_exit_requested() -> void:
	if _current_kind == MapLayout.Kind.BOSS:
		go_to_victory()
	else:
		go_to_map()


func _on_map_node_chosen(id: String, kind: int) -> void:
	_current_kind = kind
	RunState.map_progress = _map.export_progress()
	match kind:
		MapLayout.Kind.COMBATE:
			enter_room(COMBAT_ROOM_SCENE)
		MapLayout.Kind.DESCANSO:
			enter_room(REST_SITE_SCENE)
		MapLayout.Kind.MERCADORA:
			enter_room(SHOP_SCENE)
		MapLayout.Kind.PARKOUR:
			enter_room(PARKOUR_ROOM_SCENE)
		MapLayout.Kind.MID_BOSS:
			enter_room(CURUPIRA_ROOM_SCENE)
		MapLayout.Kind.BOSS:
			if ResourceLoader.exists(BOSS_ROOM_SCENE):
				enter_room(BOSS_ROOM_SCENE)
			elif OS.is_debug_build():
				push_warning("SceneManager: a sala do Boitatá ainda não existe (%s). Indo direto à vitória (só em build de debug)." % BOSS_ROOM_SCENE)
				go_to_victory()
			else:
				push_warning("SceneManager: a sala do Boitatá ainda não existe (%s)." % BOSS_ROOM_SCENE)
		_:
			push_warning("SceneManager: o nó '%s' (%s) ainda não tem sala. Siga para o próximo nó." % [id, MapLayout.KIND_NAMES[kind]])


func _on_player_death_finished(permanent: bool) -> void:
	# Dentro de uma run a morte é sempre definitiva. Fora dela (ex.: test_arena) a sala reinicia.
	if permanent or RunState.run_active:
		go_to_game_over()
	else:
		restart_room()
