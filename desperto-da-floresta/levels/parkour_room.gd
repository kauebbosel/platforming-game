# levels/parkour_room.gd
class_name ParkourRoom
extends Node2D
## Sala de Parkour (GDD 10.1): percurso de plataformas, cipós e espinhos, sem combate.
## A cada vez sorteia um dos `layouts` (Alcance o baú no fim). É a opção SEGURA do mapa: paga
## menos que o combate. Há um cronômetro (começa no primeiro movimento): ao abrir o baú saem
## Folhas (base + bônus por terminar rápido) e a escolha de 1 entre 2 relíquias comuns. Não dá
## pedras nem vida.
## Cair no vazio só custa TEMPO (pena no cronômetro) e devolve o Valtair ao último ponto seguro;
## os espinhos é que tiram vida (e também o devolvem ao ponto seguro).
## Como as outras salas, não conhece o mapa: avisa pelo EventBus (room_exit_requested).

signal cleared

## Os percursos possíveis (layout_*.tscn). Um é sorteado ao entrar.
@export var layouts: Array[PackedScene] = []
## Folhas garantidas ao abrir o baú, não importa o tempo. O Parkour paga menos que o combate
## (que dá 10 de bônus + as Folhas que os inimigos soltam).
@export var base_leaves: int = 5
## Folhas extras por terminar rápido: máximo com tempo <= `target_time` do percurso, zero com
## tempo >= `limit_time`, e proporcional entre os dois (metas no ParkourLayout).
@export var max_time_bonus: int = 10
## Escolha de relíquia do baú: quantas opções e de que raridade (as melhores ficam no combate).
@export var relic_choices: int = 2
@export var relic_rarities: Array[RelicData.Rarity] = [RelicData.Rarity.COMMON]
@export var relic_pool: RelicPool = preload("res://relics/relic_pool.tres")
## Distância entre os pedestais da escolha.
@export var relic_spacing: float = 56.0
## Dano de cair no vazio. 0 = cair só custa tempo (`fall_time_penalty`). Os espinhos têm o
## dano deles.
@export var fall_damage: int = 0
## Segundos somados ao cronômetro a cada queda no vazio.
@export var fall_time_penalty: float = 3.0
## Margem abaixo do percurso a partir da qual conta como "caiu".
@export var fall_margin: float = 80.0
## Quantos frames de posição guardar para escolher o ponto seguro (15 = ~0,25 s a 60 fps).
const HISTORY_FRAMES: int = 15
## Quanto o Valtair precisa se afastar do início para o cronômetro começar (px).
const START_MOVE_DISTANCE: float = 12.0

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
var _pedestals: Array[RelicPedestal] = []
var _start_pos: Vector2
var _time: float = 0.0
var _timer_started: bool = false
var _timer_label: Label


func _ready() -> void:
	assert(not layouts.is_empty(), "ParkourRoom precisa de pelo menos um layout no Inspetor!")
	var index: int = forced_layout if forced_layout >= 0 else randi() % layouts.size()
	layout = layouts[index].instantiate() as ParkourLayout
	_course.add_child(layout)
	_bounds = layout.bounds

	_player.global_position = layout.player_start()
	_safe_pos = _player.global_position
	_start_pos = _player.global_position
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
	_build_timer_label()
	_message.text = "Parkour: chegue ao baú, quanto mais rápido mais Folhas!\nCair só custa tempo; os espinhos tiram vida.\n[W]/[S] sobem e descem em cipós   [S] desce de plataformas"
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
	if not _chest_opened:
		if not _timer_started and _player.global_position.distance_to(_start_pos) > START_MOVE_DISTANCE:
			_timer_started = true
		if _timer_started:
			_time += delta
		_update_timer_label()
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
		if fall_damage > 0:
			_player.hurtbox.receive_hit(fall_damage, self, Vector2.ZERO)
		_time += fall_time_penalty
		_popup("+%d s" % roundi(fall_time_penalty), Color(1.0, 0.55, 0.45))
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
	_update_timer_label()
	_reward_ready_ms = Time.get_ticks_msec() + int(reward_arm_delay * 1000.0)

	var bonus: int = _time_bonus()
	var total: int = roundi((base_leaves + bonus) * _player.stats.leaf_bonus_mult)  # Amuleto de Madeira
	if total > 0:
		EventBus.leaves_gained.emit(total)
	print("[Parkour] %s: %.1f s (meta %.0f s, limite %.0f s) -> +%d Folhas" % [layout.name, _time, layout.target_time, layout.limit_time, total])

	_pedestals = RelicDraft.spawn(self, relic_pool, relic_rarities, relic_choices, layout.pedestal_spot(), relic_spacing, true, reward_arm_delay)

	var key: String = InputHint.key_name(&"interact")
	_message.text = "Tempo: %.1f s (meta %.0f s)\n+%d Folhas" % [_time, layout.target_time, total]
	if _pedestals.size() > 1:
		_message.text += "\nEscolha 1 de %d relíquias: [%s] sobre a que quiser" % [_pedestals.size(), key]
	elif _pedestals.size() == 1:
		_message.text += "\nPegue a relíquia: [%s] sobre ela" % key
	_message.text += "\n[%s] na porta para sair" % key
	_message.visible = true

	_exit.visible = true
	_exit.set_deferred("monitoring", true)
	cleared.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not (_chest_opened and _exit.visible and _player_at_exit and not _exit_requested):
		return
	if not event.is_action_pressed(&"interact"):
		return
	if Time.get_ticks_msec() < _reward_ready_ms:
		return
	# Sair sem pegar a relíquia perde a recompensa: pede para confirmar uma vez.
	if not _exit_warned and _has_pending_relic():
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


func _has_pending_relic() -> bool:
	for pedestal in _pedestals:
		if is_instance_valid(pedestal) and not pedestal.is_queued_for_deletion():
			return true
	return false


## Folhas extras pelo tempo: máximo até `target_time`, zero a partir de `limit_time`.
func _time_bonus() -> int:
	var span: float = maxf(layout.limit_time - layout.target_time, 1.0)
	var fraction: float = clampf((layout.limit_time - _time) / span, 0.0, 1.0)
	return roundi(max_time_bonus * fraction)


func _build_timer_label() -> void:
	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.offset_left = -100.0
	_timer_label.offset_right = 100.0
	_timer_label.offset_top = 10.0
	_timer_label.offset_bottom = 26.0
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 10)
	_timer_label.add_theme_constant_override("outline_size", 3)
	_timer_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	$Overlay.add_child(_timer_label)
	_update_timer_label()


## Verde = bônus máximo, amarelo = bônus diminuindo, vermelho = sem bônus de tempo.
func _update_timer_label() -> void:
	if _timer_label == null:
		return
	var color: Color = Color(0.65, 1.0, 0.65)
	if _time >= layout.limit_time:
		color = Color(1.0, 0.6, 0.55)
	elif _time > layout.target_time:
		color = Color(1.0, 0.9, 0.5)
	_timer_label.add_theme_color_override("font_color", color)
	_timer_label.text = "%.1f s   (meta %.0f s)" % [_time, layout.target_time]


## Texto que sobe e some perto do ponto de retorno (ex.: "+3 s" ao cair).
func _popup(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.16))
	label.z_index = 20
	add_child(label)
	label.global_position = _safe_pos + Vector2(-10.0, -44.0)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(label.queue_free)
