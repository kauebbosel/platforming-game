# entities/enemies/boitata/boitata.gd
class_name Boitata
extends Node2D
## Boitatá, o chefe final (GDD 9.5): serpente de fogo, UMA fase, três ataques.
##   Sopro de fogo      - vai a um lado da arena, avisa e solta uma rajada reta (baixa ou alta).
##   Investida serpentina - recua, avisa, e avança rápido na posição onde o Valtair ESTAVA.
##   Incêndio da copa   - sobe, marca colunas no chão e deixa cair brasas só nelas.
## Entre os ataques voa em serpentina pela arena. Só a CABEÇA recebe dano. Ela fica baixa e
## parada (vulnerável) depois do Sopro e da Investida; o resto do tempo voa na altura que um pulo
## de plataforma alcança. O corpo é uma lista de segmentos que seguem o caminho da cabeça:
## `segment_count = 0` deixa só a cabeça (útil se o corpo virar um sprite inteiro).
## Tudo é montado por código com formas coloridas (provisórias). Todos os números são @export:
## ajuste no Inspetor da cena boitata.tscn. A origem do nó fica em (0, 0); as coordenadas das
## ações são do MUNDO (arena de 640x360, chão em y=310, plataformas em y=251).

signal died

@export_group("Vida e dano")
@export var max_health: int = 300
@export var damage_sopro: int = 20
@export var damage_investida: int = 25
@export var damage_brasas: int = 15
## Encostar na cabeça enquanto ela voa.
@export var damage_contato: int = 10

@export_group("Corpo")
@export var segment_count: int = 14
@export var segment_spacing: float = 9.0

@export_group("Ritmo geral")
@export var roam_time: float = 2.4
@export var roam_speed: float = 150.0
@export var attack_pause: float = 0.5
## Altura da cabeça enquanto voa (um pulo de plataforma alcança).
@export var roam_height: float = 165.0

@export_group("Sopro de fogo")
@export var sopro_windup: float = 1.1
@export var sopro_duration: float = 0.9
## Quanto tempo a cabeça fica parada (vulnerável) depois do sopro.
@export var sopro_rest: float = 0.9

@export_group("Investida serpentina")
@export var investida_windup: float = 0.95
@export var investida_speed: float = 340.0
@export var investida_rest: float = 1.0

@export_group("Incêndio da copa")
@export var incendio_windup: float = 1.2
@export var ember_columns: int = 10
@export var embers_per_wave: int = 4
@export var incendio_waves: int = 2
@export var ember_fall_speed: float = 320.0
## Aviso (marcas no chão) antes de cada brasa cair.
@export var ember_warning: float = 1.0
@export var wave_gap: float = 1.1

@export_group("Arena")
@export var arena_width: float = 640.0
@export var floor_y: float = 310.0
@export var platform_y: float = 251.0

enum State { PARKED, INTRO, ROAM, SOPRO_GO, SOPRO_WIND, SOPRO_FIRE, SOPRO_REST, INVEST_GO, INVEST_WIND, INVEST_DASH, INVEST_REST, FIRE_GO, FIRE_RAIN, DEAD }

const BEAM_HEIGHT: float = 28.0
const COLOR_HEAD: Color = Color(0.98, 0.5, 0.1)
const COLOR_TAIL: Color = Color(0.42, 0.08, 0.05)
const COLOR_HOT: Color = Color(1.0, 0.95, 0.5)

var health: HealthComponent
## Para a Escama do Boitatá: o dano deste chefe é de fogo (lido por HealthComponent._is_fire).
var data: EnemyData = EnemyData.new()

var state: State = State.PARKED
var _state_time: float = 0.0
var _last_attack: StringName = &""
var _roam_clock: float = 0.0
var _roam_origin_x: float = 320.0
var _contact_timer: float = 0.0
var _body_hit_left: float = 0.0
var _glow: float = 0.0

var _head: Node2D
var _head_polys: Array[Polygon2D] = []
var _head_hurtbox: Hurtbox
var _head_hitbox: Hitbox
var _segments: Array[Node2D] = []
var _segment_polys: Array[Polygon2D] = []
var _segment_hitboxes: Array[Hitbox] = []
var _trail: Array[Vector2] = []

var _beam: Hitbox
var _beam_shape: CollisionShape2D
var _beam_visual: Polygon2D
var _tele_line: Polygon2D
var _markers: Array[Polygon2D] = []

var _sopro_side: int = 1
var _sopro_low: bool = true
var _beam_from: float = 0.0
var _beam_to: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_left: float = 0.0
var _dash_target: Vector2 = Vector2.ZERO
var _dash_locked: bool = false
var _waves: Array = []
var _wave_index: int = 0
var _wave_clock: float = 0.0
var _marked_waves: Array[bool] = []
var _tween_dead: Tween


func _ready() -> void:
	data.deals_fire = true
	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = max_health
	add_child(health)
	health.died.connect(_on_died)
	_build()


## Coloca a cabeça (e o rastro do corpo) num ponto do mundo. Chamado pela sala.
func place(pos: Vector2) -> void:
	_head.global_position = pos
	_trail.clear()
	for i in 60:
		_trail.append(pos + Vector2(-float(i) * 3.0, 0.0))
	_place_segments()


## A luta começa: a cabeça desce até a altura de voo e os ataques começam.
func begin() -> void:
	if state == State.PARKED:
		_set_state(State.INTRO)


func is_dead() -> bool:
	return state == State.DEAD


func head_position() -> Vector2:
	return _head.global_position


## Para testes e ajuste fino: força um ataque agora. nome: &"sopro_baixo", &"sopro_alto",
## &"investida" ou &"incendio".
func force_attack(attack_name: StringName) -> void:
	_stop_attack_effects()
	match attack_name:
		&"sopro_baixo":
			_sopro_low = true
			_sopro_side = 1 if _head.global_position.x >= arena_width / 2.0 else -1
			_set_state(State.SOPRO_GO)
		&"sopro_alto":
			_sopro_low = false
			_sopro_side = 1 if _head.global_position.x >= arena_width / 2.0 else -1
			_set_state(State.SOPRO_GO)
		&"investida":
			_set_state(State.INVEST_GO)
		&"incendio":
			_set_state(State.FIRE_GO)


# --------------------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	_state_time += delta
	_record_trail()
	match state:
		State.PARKED:
			pass
		State.INTRO:
			if _move_head(Vector2(arena_width / 2.0, roam_height), 140.0, delta):
				_set_state(State.ROAM)
		State.ROAM:
			_roam(delta)
			if _state_time >= roam_time:
				_choose_attack()
		State.SOPRO_GO:
			if _move_head(Vector2(_sopro_edge_x(), _beam_y()), 420.0, delta):
				_set_state(State.SOPRO_WIND)
		State.SOPRO_WIND:
			_set_glow(minf(1.0, _state_time / sopro_windup))
			_tele_line.visible = int(_state_time * 10.0) % 2 == 0 or _state_time < 0.3
			if _state_time >= sopro_windup:
				_set_state(State.SOPRO_FIRE)
		State.SOPRO_FIRE:
			if _state_time >= sopro_duration:
				_set_state(State.SOPRO_REST)
		State.SOPRO_REST:
			if _state_time >= sopro_rest:
				_after_attack()
		State.INVEST_GO:
			if _move_head(_invest_start(), 420.0, delta):
				_set_state(State.INVEST_WIND)
		State.INVEST_WIND:
			_invest_windup(delta)
		State.INVEST_DASH:
			_invest_dash(delta)
		State.INVEST_REST:
			if _state_time >= investida_rest:
				_after_attack()
		State.FIRE_GO:
			if _move_head(Vector2(arena_width / 2.0, 62.0), 360.0, delta):
				_set_state(State.FIRE_RAIN)
		State.FIRE_RAIN:
			_fire_rain(delta)
		State.DEAD:
			pass
	_tick_contact(delta)
	_place_segments()


func _process(_delta: float) -> void:
	# Chamas das marcas piscando.
	var pulse: float = 0.55 + 0.35 * sin(Time.get_ticks_msec() / 70.0)
	for marker in _markers:
		if marker.visible:
			marker.modulate.a = pulse


# --------------------------------------------------------------------------- estados

func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.ROAM:
			_roam_clock = 0.0
			_roam_origin_x = _head.global_position.x
			_set_glow(0.0)
		State.SOPRO_WIND:
			_beam_from = _head.global_position.x
			_beam_to = 8.0 if _sopro_side > 0 else arena_width - 8.0
			_show_line(_beam_from, _beam_to, _beam_y())
			_face(-_sopro_side)
		State.SOPRO_FIRE:
			_tele_line.visible = false
			_set_glow(1.0)
			_fire_beam(true)
		State.SOPRO_REST:
			_fire_beam(false)
			_set_glow(0.0)
		State.INVEST_WIND:
			_dash_locked = false
			_tele_line.visible = true
		State.INVEST_DASH:
			_tele_line.visible = false
			_set_glow(1.0)
			_head_hitbox.damage = damage_investida
			_head_hitbox.activate()
			_body_hit_left = 99.0
			_set_body_hitboxes(true)
		State.INVEST_REST:
			_set_glow(0.0)
			_head_hitbox.damage = damage_contato
			_body_hit_left = 0.5
		State.FIRE_RAIN:
			_prepare_waves()
		State.DEAD:
			_enter_dead()


func _choose_attack() -> void:
	var options: Array[StringName] = [&"sopro", &"investida", &"incendio"]
	options.erase(_last_attack)
	var pick: StringName = options[randi() % options.size()]
	_last_attack = pick
	match pick:
		&"sopro":
			var low: bool = randf() < 0.5
			var side: int = 1 if randf() < 0.5 else -1
			if low == _sopro_low and side == _sopro_side:
				low = not low  # não repete a mesma rajada
			_sopro_low = low
			_sopro_side = side
			_set_state(State.SOPRO_GO)
		&"investida":
			_set_state(State.INVEST_GO)
		&"incendio":
			_set_state(State.FIRE_GO)


func _after_attack() -> void:
	_stop_attack_effects()
	_set_state(State.ROAM)
	_state_time = -attack_pause  # uma pausa curta antes do próximo ataque


func _roam(delta: float) -> void:
	_roam_clock += delta
	var amplitude: float = arena_width / 2.0 - 80.0
	var target: Vector2 = Vector2(
		arena_width / 2.0 + amplitude * sin(_roam_clock * 0.9),
		roam_height + 28.0 * sin(_roam_clock * 1.9))
	_move_head(target, roam_speed, delta)


# --------------------------------------------------------------------------- sopro

func _beam_y() -> float:
	return (floor_y - 14.0) if _sopro_low else (platform_y - 14.0)


## O lado em que a cabeça fica (_sopro_side = 1 → direita) e o sopro vai para o outro lado.
func _sopro_edge_x() -> float:
	return arena_width - 30.0 if _sopro_side > 0 else 30.0


func _show_line(from_x: float, to_x: float, y: float) -> void:
	var length: float = absf(to_x - from_x)
	_tele_line.global_position = Vector2((from_x + to_x) / 2.0, y)
	_tele_line.polygon = _rect_points(length, BEAM_HEIGHT)
	_tele_line.visible = true


func _fire_beam(on: bool) -> void:
	if on:
		var length: float = absf(_beam_to - _beam_from)
		_beam.global_position = Vector2((_beam_from + _beam_to) / 2.0, _beam_y())
		(_beam_shape.shape as RectangleShape2D).size = Vector2(length, BEAM_HEIGHT)
		_beam_visual.polygon = _rect_points(length, BEAM_HEIGHT)
		_beam_visual.visible = true
		_beam.damage = damage_sopro
		_beam.activate()
	else:
		_beam.deactivate()
		_beam_visual.visible = false


# --------------------------------------------------------------------------- investida

func _player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


## De onde ela recua para investir: do lado de cá do Valtair, no alto.
func _invest_start() -> Vector2:
	var player: Node2D = _player()
	var px: float = player.global_position.x if player != null else arena_width / 2.0
	var side: float = 1.0 if px < arena_width / 2.0 else -1.0
	return Vector2(clampf(px + side * 250.0, 40.0, arena_width - 40.0), 110.0)


func _invest_windup(delta: float) -> void:
	_set_glow(minf(1.0, _state_time / investida_windup))
	var player: Node2D = _player()
	# Acompanha o Valtair e TRAVA o alvo um pouco antes de investir (dá tempo de reagir).
	if player != null and _state_time < investida_windup - 0.25:
		_dash_target = Vector2(player.global_position.x, minf(player.global_position.y - 12.0, floor_y - 12.0))
	elif not _dash_locked:
		_dash_locked = true
	var to: Vector2 = _dash_target - _head.global_position
	if to.length() > 1.0:
		_face(signf(to.x))
		_show_line_between(_head.global_position, _dash_target)
	if _state_time >= investida_windup:
		_dash_dir = (_dash_target - _head.global_position).normalized()
		_dash_left = (_dash_target - _head.global_position).length() + 130.0
		_set_state(State.INVEST_DASH)


func _show_line_between(a: Vector2, b: Vector2) -> void:
	var length: float = a.distance_to(b)
	_tele_line.global_position = (a + b) / 2.0
	_tele_line.rotation = (b - a).angle()
	_tele_line.polygon = _rect_points(length, 8.0)
	_tele_line.visible = int(_state_time * 12.0) % 2 == 0 or _state_time < 0.3


func _invest_dash(delta: float) -> void:
	var step: float = minf(investida_speed * delta, _dash_left)
	var next: Vector2 = _head.global_position + _dash_dir * step
	next.y = minf(next.y, floor_y - 12.0)
	next.x = clampf(next.x, 16.0, arena_width - 16.0)
	var blocked: bool = next.is_equal_approx(_head.global_position) and step > 0.0
	_head.global_position = next
	_dash_left -= step
	if _dash_left <= 0.01 or blocked or next.x <= 16.0 or next.x >= arena_width - 16.0 or next.y >= floor_y - 12.0:
		_tele_line.rotation = 0.0
		_set_state(State.INVEST_REST)


# --------------------------------------------------------------------------- incêndio

func _prepare_waves() -> void:
	_waves.clear()
	_marked_waves.clear()
	for w in incendio_waves:
		_waves.append(_pick_columns())
		_marked_waves.append(false)
	_wave_index = 0
	_wave_clock = -incendio_windup


## Sorteia colunas sem 3 vizinhas seguidas, para sempre sobrar um vão seguro.
func _pick_columns() -> Array:
	var order: Array = range(ember_columns)
	order.shuffle()
	var chosen: Array = []
	for column in order:
		if chosen.size() >= embers_per_wave:
			break
		if chosen.has(column - 1) and chosen.has(column + 1):
			continue
		chosen.append(column)
	return chosen


func _column_x(column: int) -> float:
	return (float(column) + 0.5) * (arena_width / float(ember_columns))


func _fire_rain(delta: float) -> void:
	_wave_clock += delta
	_set_glow(minf(1.0, maxf(0.0, (_wave_clock + incendio_windup) / incendio_windup)))
	# Marcas aparecem `ember_warning` antes de cada onda; as brasas caem na hora marcada.
	for w in _waves.size():
		var drop_at: float = float(w) * wave_gap
		if not _marked_waves[w] and _wave_clock >= drop_at - ember_warning:
			_marked_waves[w] = true
			for column in _waves[w]:
				_add_marker(_column_x(column))
	if _wave_index < _waves.size() and _wave_clock >= float(_wave_index) * wave_gap:
		for column in _waves[_wave_index]:
			BoitataEmber.spawn(get_parent(), _column_x(column), -20.0, floor_y, ember_fall_speed, damage_brasas, self)
		_clear_markers()
		_wave_index += 1
	var landing: float = (floor_y + 20.0) / ember_fall_speed
	if _wave_index >= _waves.size() and _wave_clock >= float(_waves.size() - 1) * wave_gap + landing + 0.3:
		_after_attack()


func _add_marker(x: float) -> void:
	var marker: Polygon2D = Polygon2D.new()
	marker.color = Color(1.0, 0.35, 0.1, 0.8)
	marker.polygon = _rect_points(arena_width / float(ember_columns) - 6.0, 6.0)
	marker.z_index = 10
	add_child(marker)
	marker.global_position = Vector2(x, floor_y - 3.0)
	_markers.append(marker)


func _clear_markers() -> void:
	for marker in _markers:
		marker.queue_free()
	_markers.clear()


# --------------------------------------------------------------------------- comuns

func _stop_attack_effects() -> void:
	_fire_beam(false)
	_tele_line.visible = false
	_tele_line.rotation = 0.0
	_clear_markers()
	_set_body_hitboxes(false)
	_head_hitbox.damage = damage_contato
	_set_glow(0.0)


func _move_head(target: Vector2, speed: float, delta: float) -> bool:
	var to: Vector2 = target - _head.global_position
	var dist: float = to.length()
	if absf(to.x) > 6.0:
		_face(signf(to.x))
	if dist <= speed * delta:
		_head.global_position = target
		return true
	_head.global_position += to / dist * speed * delta
	return false


func _face(direction: float) -> void:
	if direction != 0.0:
		_head.scale.x = signf(direction)


func _tick_contact(delta: float) -> void:
	if state == State.DEAD:
		return
	# Encostar na cabeça machuca: a hitbox liga de novo a cada 0,8 s (a Hurtbox do Valtair
	# tem a própria invulnerabilidade).
	_contact_timer -= delta
	if _contact_timer <= 0.0 and state != State.INVEST_DASH:
		_contact_timer = 0.8
		_head_hitbox.damage = damage_contato
		_head_hitbox.activate()
	if _body_hit_left > 0.0 and state != State.INVEST_DASH:
		_body_hit_left -= delta
		if _body_hit_left <= 0.0:
			_set_body_hitboxes(false)


func _set_body_hitboxes(on: bool) -> void:
	for hitbox in _segment_hitboxes:
		hitbox.damage = int(damage_investida * 0.8)
		if on:
			hitbox.activate()
		else:
			hitbox.deactivate()


func _set_glow(amount: float) -> void:
	_glow = clampf(amount, 0.0, 1.0)
	for i in _head_polys.size():
		_head_polys[i].color = COLOR_HEAD.lerp(COLOR_HOT, _glow) if i == 0 else _head_polys[i].color
	for i in _segment_polys.size():
		var t: float = float(i) / maxf(1.0, float(_segment_polys.size() - 1))
		_segment_polys[i].color = COLOR_HEAD.lerp(COLOR_TAIL, t).lerp(COLOR_HOT, _glow * (1.0 - t * 0.5))


func _record_trail() -> void:
	var pos: Vector2 = _head.global_position
	if _trail.is_empty() or pos.distance_to(_trail[0]) >= 2.0:
		_trail.push_front(pos)
		if _trail.size() > 700:
			_trail.resize(700)


func _place_segments() -> void:
	if _segments.is_empty():
		return
	var placed: int = 0
	var accumulated: float = 0.0
	var previous: Vector2 = _head.global_position
	for point in _trail:
		var step: float = previous.distance_to(point)
		while placed < _segments.size() and accumulated + step >= segment_spacing * float(placed + 1):
			var t: float = (segment_spacing * float(placed + 1) - accumulated) / maxf(step, 0.001)
			_segments[placed].global_position = previous.lerp(point, t)
			placed += 1
		accumulated += step
		previous = point
		if placed >= _segments.size():
			return
	while placed < _segments.size():
		_segments[placed].global_position = previous
		placed += 1


# --------------------------------------------------------------------------- morte

func _on_died() -> void:
	if state != State.DEAD:
		_set_state(State.DEAD)


func _enter_dead() -> void:
	_stop_attack_effects()
	_head_hitbox.deactivate()
	_head_hurtbox.set_deferred("monitorable", false)
	_tele_line.visible = false
	died.emit()
	# O corpo explode da cabeça para a cauda, um segmento de cada vez, e some.
	DeathPuff.spawn(get_parent(), _head.global_position, 3.0)
	for i in _segments.size():
		var segment: Node2D = _segments[i]
		get_tree().create_timer(0.07 * float(i + 1)).timeout.connect(func() -> void:
			if is_instance_valid(segment) and is_instance_valid(self):
				DeathPuff.spawn(get_parent(), segment.global_position, 1.5)
				segment.visible = false
		)
	get_tree().create_timer(0.07 * float(_segments.size() + 2)).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_head.visible = false
	)
	get_tree().create_timer(0.07 * float(_segments.size() + 6)).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


# --------------------------------------------------------------------------- montagem

func _circle_points(radius: float, count: int = 10) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _rect_points(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-width / 2.0, -height / 2.0), Vector2(width / 2.0, -height / 2.0), Vector2(width / 2.0, height / 2.0), Vector2(-width / 2.0, height / 2.0)])


func _make_hitbox(radius: float, damage: int) -> Hitbox:
	var hitbox: Hitbox = Hitbox.new()
	hitbox.team = &"enemy"
	hitbox.damage = damage
	hitbox.source = self
	hitbox.knockback = Vector2(120.0, -90.0)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hitbox.add_child(shape)
	return hitbox


func _build() -> void:
	# --- corpo (atrás da cabeça)
	for i in segment_count:
		var t: float = float(i) / maxf(1.0, float(segment_count - 1))
		var segment: Node2D = Node2D.new()
		segment.z_index = 4 - i
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = _circle_points(lerpf(12.0, 5.0, t))
		poly.color = COLOR_HEAD.lerp(COLOR_TAIL, t)
		segment.add_child(poly)
		var hitbox: Hitbox = _make_hitbox(lerpf(10.0, 4.0, t), int(damage_investida * 0.8))
		segment.add_child(hitbox)
		add_child(segment)
		_segments.append(segment)
		_segment_polys.append(poly)
		_segment_hitboxes.append(hitbox)

	# --- cabeça
	_head = Node2D.new()
	_head.z_index = 6
	add_child(_head)
	var skull: Polygon2D = Polygon2D.new()
	skull.color = COLOR_HEAD
	skull.polygon = PackedVector2Array([Vector2(-16, -11), Vector2(8, -13), Vector2(22, -4), Vector2(22, 7), Vector2(8, 12), Vector2(-16, 11)])
	_head.add_child(skull)
	_head_polys.append(skull)
	var crest: Polygon2D = Polygon2D.new()
	crest.color = Color(1.0, 0.85, 0.3)
	crest.polygon = PackedVector2Array([Vector2(-12, -11), Vector2(-4, -22), Vector2(2, -12), Vector2(8, -20), Vector2(10, -12)])
	_head.add_child(crest)
	var eye: Polygon2D = Polygon2D.new()
	eye.color = Color(1.0, 1.0, 0.7)
	eye.polygon = PackedVector2Array([Vector2(6, -6), Vector2(14, -6), Vector2(14, -1), Vector2(6, -1)])
	_head.add_child(eye)
	var pupil: Polygon2D = Polygon2D.new()
	pupil.color = Color(0.15, 0.02, 0.02)
	pupil.polygon = PackedVector2Array([Vector2(11, -5), Vector2(14, -5), Vector2(14, -2), Vector2(11, -2)])
	_head.add_child(pupil)

	# --- Hurtbox: só a cabeça recebe dano
	_head_hurtbox = Hurtbox.new()
	_head_hurtbox.team = &"enemy"
	_head_hurtbox.health = health
	var hurt_shape: CollisionShape2D = CollisionShape2D.new()
	var hurt_circle: CircleShape2D = CircleShape2D.new()
	hurt_circle.radius = 16.0
	hurt_shape.shape = hurt_circle
	_head_hurtbox.add_child(hurt_shape)
	_head.add_child(_head_hurtbox)
	_head_hurtbox.hit_received.connect(_on_head_hit)

	# --- contato da cabeça
	_head_hitbox = _make_hitbox(14.0, damage_contato)
	_head.add_child(_head_hitbox)

	# --- rajada e aviso
	_beam = Hitbox.new()
	_beam.team = &"enemy"
	_beam.source = self
	_beam.damage = damage_sopro
	_beam.knockback = Vector2(0.0, -90.0)
	_beam_shape = CollisionShape2D.new()
	var beam_rect: RectangleShape2D = RectangleShape2D.new()
	beam_rect.size = Vector2(100.0, BEAM_HEIGHT)
	_beam_shape.shape = beam_rect
	_beam.add_child(_beam_shape)
	add_child(_beam)
	_beam_visual = Polygon2D.new()
	_beam_visual.color = Color(1.0, 0.55, 0.12, 0.9)
	_beam_visual.z_index = 12
	_beam_visual.visible = false
	_beam.add_child(_beam_visual)

	_tele_line = Polygon2D.new()
	_tele_line.color = Color(1.0, 0.25, 0.1, 0.35)
	_tele_line.z_index = 11
	_tele_line.visible = false
	add_child(_tele_line)


func _on_head_hit(_damage: int, _source: Node, _knockback: Vector2) -> void:
	# Piscada branca curta ao ser atingida (o chefe não é interrompido).
	if state == State.DEAD or _head_polys.is_empty():
		return
	_head.modulate = Color(1.0, 0.6, 0.6)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(_head):
			_head.modulate = Color.WHITE
	)
