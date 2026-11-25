# levels/parkour_room.gd
class_name ParkourRoom
extends Node2D
## Sala de Parkour (GDD 10.1): percurso de plataformas, cipós e espinhos, sem combate.
## A cada vez sorteia um dos `layouts` (Alcance o baú no fim). Ao abrir o baú: Folhas, pedras
## para o bodoque e UMA relíquia comum/incomum num pedestal; a porta libera a saída.
## Cair no vazio ou encostar nos espinhos tira vida e devolve o Valtair ao último ponto seguro.
## Como as outras salas, não conhece o mapa: avisa pelo EventBus (room_exit_requested).

signal cleared

const PEDESTAL_SCENE: PackedScene = preload("res://entities/pickups/relic_pedestal.tscn")

## Os percursos possíveis (layout_*.tscn). Um é sorteado ao entrar.
@export var layouts: Array[PackedScene] = []
## Folhas do baú (GDD 12.1: 30 por sala de Parkour).
@export var clear_bonus_leaves: int = 30
## Pedras de bodoque do baú.
@export var ammo_reward: int = 3
@export var relic_pool: RelicPool = preload("res://relics/relic_pool.tres")
## Dano de cair no vazio (os espinhos têm o dano deles).
@export var fall_damage: int = 15
## Margem abaixo do percurso a partir da qual conta como "caiu".
@export var fall_margin: float = 80.0
## Quantos frames de posição guardar para escolher o ponto seguro (15 = ~0,25 s a 60 fps).
const HISTORY_FRAMES: int = 15

## Segundos, depois de abrir o baú, em que pedestal e porta ainda não aceitam o [E]
## (evita pegar/sair sem querer).
@export var reward_arm_delay: float = 1.0
## Para testes: força um percurso (0, 1, 2...). -1 = sorteia.
@export var forced_layout: int = -1

@onready var _course: Node2D = $Course
@onready var _chest: RewardChest = $Chest
@onready var _exit: Area2D = $ExitDoor
@onready var _player: Player = $Player
@onready var _camera: Camera2D = $CameraRig
@onready var _message: Label = $Overlay/Message

var layout: ParkourLayout
var _bounds: Rect2
var _safe_pos: Vector2
var _grounded_time: float = 0.0
## Posições dos últimos frames. O "ponto seguro" é a mais antiga (~0,25 s atrás), que fica um
## pouco antes da borda da plataforma, e não exatamente na borda.
var _history: Array[Vector2] = []
var _chest_opened: bool = false
var _player_at_exit: bool = false
var _exit_requested: bool = false
var _exit_warned: bool = false
var _reward_ready_ms: int = 0
var _pedestal: RelicPedestal


func _ready() -> void:
	assert(not layouts.is_empty(), "ParkourRoom precisa de pelo menos um layout no Inspetor!")
	var index: int = forced_layout if forced_layout >= 0 else randi() % layouts.size()
	layout = layouts[index].instantiate() as ParkourLayout
	_course.add_child(layout)
	_bounds = layout.bounds

	_player.global_position = layout.player_start()
	_safe_pos = _player.global_position
	_chest.global_position = layout.chest_spot()
	_exit.global_position = layout.exit_spot() + Vector2(0.0, -22.0)
	_exit.visible = false
	_exit.monitoring = false
	_exit.body_entered.connect(_on_exit_body_entered)
	_exit.body_exited.connect(_on_exit_body_exited)
	_chest.opened.connect(_on_chest_opened)

	for hazard in get_tree().get_nodes_in_group(&"hazards"):
		if _course.is_ancestor_of(hazard) and hazard.has_signal(&"player_touched"):
			hazard.player_touched.connect(_on_hazard_touched)

	_setup_camera()
	_message.text = "Parkour: chegue ao baú!\n[W]/[S] sobem e descem em cipós   [S] desce de plataformas"
	_message.visible = true
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if not _chest_opened:
			_message.visible = false
	)


func _setup_camera() -> void:
	_camera.set("arena_rect", _bounds)
	_camera.limit_left = int(_bounds.position.x)
	_camera.limit_top = int(_bounds.position.y)
	_camera.limit_right = int(_bounds.end.x)
	_camera.limit_bottom = int(_bounds.end.y)
	_camera.global_position = _player.global_position
	_camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	if _player.is_dead():
		return
	# Guarda o último ponto onde o Valtair ficou firme no chão, longe de espinhos.
	_history.append(_player.global_position)
	if _history.size() > HISTORY_FRAMES:
		_history.pop_front()
	if _player.is_on_floor():
		_grounded_time += delta
		if _grounded_time >= 0.3 and _history.size() >= HISTORY_FRAMES and not _near_hazard(_history[0]):
			_safe_pos = _history[0]
	else:
		_grounded_time = 0.0
	if _player.global_position.y > _bounds.end.y + fall_margin:
		_player.hurtbox.receive_hit(fall_damage, self, Vector2.ZERO)
		_respawn()


func _near_hazard(point: Vector2) -> bool:
	for hazard in get_tree().get_nodes_in_group(&"hazards"):
		if hazard is Spikes and _course.is_ancestor_of(hazard) and hazard.is_near(point):
			return true
	return false


func _on_hazard_touched(_body: Node2D) -> void:
	_respawn()


## Devolve o Valtair ao último ponto seguro, parado e fora de qualquer cipó.
func _respawn() -> void:
	if _player.is_dead():
		return
	_player.global_position = _safe_pos
	_player.velocity = Vector2.ZERO
	_player.nearby_vine = null
	_player.state_machine.transition_to("idle")
	_grounded_time = 0.0
	_history.clear()


func _on_chest_opened() -> void:
	_chest_opened = true
	_reward_ready_ms = Time.get_ticks_msec() + int(reward_arm_delay * 1000.0)
	if clear_bonus_leaves > 0:
		EventBus.leaves_gained.emit(clear_bonus_leaves)
	if ammo_reward > 0:
		_player.ammo.refill(ammo_reward)
	_spawn_relic()

	var key: String = InputHint.key_name(&"interact")
	_message.text = "+%d Folhas   +%d pedras" % [clear_bonus_leaves, ammo_reward]
	if _pedestal != null:
		_message.text += "\nPegue a relíquia: [%s] sobre ela" % key
	_message.text += "\n[%s] na porta para sair" % key
	_message.visible = true

	_exit.visible = true
	_exit.set_deferred("monitoring", true)
	cleared.emit()


func _spawn_relic() -> void:
	if relic_pool == null:
		return
	var relic: RelicData = relic_pool.pick_random(RunState.relics, [RelicData.Rarity.COMMON, RelicData.Rarity.UNCOMMON])
	if relic == null:
		return
	_pedestal = PEDESTAL_SCENE.instantiate() as RelicPedestal
	_pedestal.relic = relic
	_pedestal.arm_delay = reward_arm_delay
	add_child(_pedestal)
	_pedestal.global_position = layout.pedestal_spot()


func _unhandled_input(event: InputEvent) -> void:
	if not (_chest_opened and _exit.visible and _player_at_exit and not _exit_requested):
		return
	if not event.is_action_pressed(&"interact"):
		return
	if Time.get_ticks_msec() < _reward_ready_ms:
		return
	# Sair sem pegar a relíquia perde a recompensa: pede para confirmar uma vez.
	if not _exit_warned and _pedestal != null and is_instance_valid(_pedestal) and not _pedestal.is_queued_for_deletion():
		_exit_warned = true
		_message.text = "Você ainda não pegou a relíquia!\n[%s] de novo na porta para sair assim mesmo" % InputHint.key_name(&"interact")
		return
	_exit_requested = true
	EventBus.room_exit_requested.emit()


func _on_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = true


func _on_exit_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_at_exit = false
