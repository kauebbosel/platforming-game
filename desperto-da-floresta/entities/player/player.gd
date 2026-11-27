# entities/player/player.gd
class_name Player
extends CharacterBody2D
## Controlador principal do Player: estado compartilhado e utilidades usadas pelos estados.

## Emitido quando a pausa da morte acaba. `permanent` = true leva ao menu principal.
signal death_sequence_finished(permanent: bool)
## Uma relíquia (Proteção da Caipora ou Benção do Curupira) impediu a morte e foi consumida.
signal death_saved(relic: RelicData)

@export var stats: PlayerStats

## Estado de escalar cipós (criado por código em _ready se o nó "Climb" não existir na cena).
const CLIMB_STATE: Script = preload("res://entities/player/states/climb.gd")

@onready var state_machine: StateMachine = $StateMachine
@onready var sprite: Sprite2D = $Visual/Sprite2D
## Nós filhos diretos do Player (os nomes precisam ser exatamente estes).
@onready var attack: AttackComponent = $AttackComponent
@onready var health: HealthComponent = $Health
@onready var ammo: AmmoComponent = $AmmoComponent
@onready var ranged: RangedAttackComponent = $RangedAttackComponent
@onready var hurtbox: Hurtbox = $Hurtbox

var facing: int = 1  # 1 = direita, -1 = esquerda
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jump_buffered: bool = false
## Verdadeiro enquanto o corte de pulo ainda pode acontecer (subindo por causa de um pulo).
var jump_cut_available: bool = false
## Tempo restante até poder usar o dash de novo (conta desde o início do dash).
var dash_cooldown_left: float = 0.0
## Dashes no ar ainda disponíveis; recarrega ao tocar o chão.
var air_dashes_left: int = 0

## Se verdadeiro, a morte é definitiva (menu principal) em vez de reiniciar a sala.
## Por enquanto só o F4 liga isso; depois, o RunState decide.
var permanent_death: bool = false

## Cipó (Vine) em que o corpo está encostando agora; quem preenche é o próprio Vine.
## Luta final: a Benção do Curupira só vale enquanto isto for true (a sala do Boitatá liga).
var in_boitata_fight: bool = false

var nearby_vine: Node2D = null
## Tempo, depois de soltar um cipó, em que não dá para agarrar de novo.
var climb_regrab_left: float = 0.0

# Valores de fábrica; as relíquias são aplicadas sobre uma CÓPIA em refresh_stats().
## Janela, depois de um dash, em que o próximo golpe conta como "logo após o dash" (Pena Encantada).
const POST_DASH_DAMAGE_WINDOW: float = 1.5
## Invulnerabilidade logo depois de uma relíquia salvar o Valtair da morte.
const DEATH_SAVE_INVULNERABILITY: float = 1.5

## O último golpe (corpo a corpo ou tiro) saiu potencializado por uma relíquia? Os números de
## dano dos inimigos usam isto para destacar o acerto.
var last_hit_empowered: bool = false

var _prev_state_name: String = ""
var _post_dash_damage_left: float = 0.0
var _speed_boost_left: float = 0.0
## A velocidade de movimento "de fábrica + relíquias", sem o bônus temporário do dash.
var _relic_move_speed: float = 120.0

var _base_stats: PlayerStats
var _base_max_health: int = 100

var _was_on_floor: bool = false


func _ready() -> void:
	add_to_group(&"player")  # os inimigos encontram o alvo por este grupo
	assert(stats != null, "ERRO: O recurso PlayerStats.tres precisa ser atribuído no Inspetor do Player!")
	_base_stats = stats
	_base_max_health = health.max_health
	_ensure_climb_state()
	state_machine.init(self)
	_connect_hud_events()
	health.died.connect(_on_health_died)
	health.damaged.connect(_on_damaged)
	attack.dynamic_damage_mult = _melee_extra_mult
	ranged.dynamic_damage_mult = _ranged_extra_mult
	refresh_stats()
	if not RunState.run_active:
		health.reset()  # sem run: vida cheia (com a vida máxima das relíquias)
	_sync_with_run()


func _physics_process(delta: float) -> void:
	# Coyote time centralizado: começa quando o chão some sem ter sido um pulo (velocity.y >= 0).
	# Assim nenhum estado precisa lembrar de chamar start_coyote_timer().
	var on_floor: bool = is_on_floor()
	if _was_on_floor and not on_floor and velocity.y >= 0.0:
		start_coyote_timer()
	_was_on_floor = on_floor

	if coyote_timer > 0.0:
		coyote_timer -= delta

	if on_floor:
		air_dashes_left = stats.max_air_dashes
	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta

	# Morto: sem dash nem tiro. O estado Dead cuida do resto.
	if is_dead():
		return

	_track_dash_effects(delta)

	# Cipós e plataformas finas: [W]/[S] perto de um cipó escalam; [S] em cima de uma plataforma
	# fina desce por ela. Ambos antes dos estados, como o dash.
	if climb_regrab_left > 0.0:
		climb_regrab_left -= delta
	_try_start_climb()
	_try_drop_through()

	# Dash: transição global, vale em qualquer estado (inclusive durante o golpe, que é cancelado).
	# Roda antes dos estados, então a troca já vale neste mesmo frame.
	if Input.is_action_just_pressed("dodge") and can_dash():
		state_machine.transition_to("dash")

	# Ataque ranged: ação paralela, não trava o movimento. Bloqueado durante o golpe corpo a corpo.
	if Input.is_action_just_pressed("ranged_attack") and not attack.is_attacking():
		ranged.try_fire(facing)


## Garante o estado "Climb" na máquina de estados (assim não precisa mexer na cena do Player).
func _ensure_climb_state() -> void:
	if state_machine.get_node_or_null("Climb") != null:
		return
	var climb: Node = CLIMB_STATE.new()
	climb.name = "Climb"
	state_machine.add_child(climb)


func _try_start_climb() -> void:
	if nearby_vine == null or climb_regrab_left > 0.0:
		return
	var state_name: String = String(state_machine.current_state.name)
	if state_name not in ["Idle", "Run", "Jump", "Fall"]:
		return
	if Input.is_action_pressed(&"move_up") or Input.is_action_pressed(&"move_down"):
		state_machine.transition_to("climb")


## [S] parado ou andando em cima de uma plataforma fina (one-way): atravessa para baixo.
func _try_drop_through() -> void:
	if not Input.is_action_just_pressed(&"move_down") or not is_on_floor():
		return
	var state_name: String = String(state_machine.current_state.name)
	if state_name != "Idle" and state_name != "Run":
		return
	drop_through_floor(0.3)


## Se o chão sob o Valtair é uma plataforma fina (one-way), ignora ela por `duration` segundos,
## para ele atravessar. Devolve true se conseguiu. Chão sólido não é atravessado.
func drop_through_floor(duration: float) -> bool:
	var hit: KinematicCollision2D = move_and_collide(Vector2(0.0, 2.0), true)
	if hit == null:
		return false
	var platform: CollisionObject2D = hit.get_collider() as CollisionObject2D
	if platform == null:
		return false
	var owner_id: int = platform.shape_find_owner(hit.get_collider_shape_index())
	var shape_node: CollisionShape2D = platform.shape_owner_get_owner(owner_id) as CollisionShape2D
	if shape_node == null or not shape_node.one_way_collision:
		return false
	add_collision_exception_with(platform)
	velocity.y = maxf(velocity.y, 40.0)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(platform) and is_instance_valid(self):
			remove_collision_exception_with(platform)
	)
	return true


func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g: float = stats.gravity
	if velocity.y > 0.0:
		g *= stats.fall_gravity_multiplier
	velocity.y = move_toward(velocity.y, stats.max_fall_speed, g * delta)


## Dentro de uma run, a vida vem do RunState e toda mudança volta para ele.
## (A munição faz o mesmo no próprio AmmoComponent.) Fora de uma run, não faz nada.
func _sync_with_run() -> void:
	if not RunState.run_active:
		return
	if RunState.health >= 0:
		health.set_current(RunState.health)
	RunState.health = health.health
	health.changed.connect(func(current: int, _maximum: int) -> void: RunState.health = current)


## Recalcula os números do Valtair: PlayerStats de fábrica + relíquias da run.
## Chame de novo ao ganhar uma relíquia no meio da sala. (A vida atual não muda: quem dá a
## relíquia decide se cura junto.)
func refresh_stats() -> void:
	stats = _base_stats.duplicate() as PlayerStats
	RunState.apply_relics(stats)
	health.max_health = _base_max_health + stats.max_health_bonus
	health.damage_taken_mult = stats.damage_taken_mult
	health.fire_damage_taken_mult = stats.fire_damage_taken_mult
	_relic_move_speed = stats.move_speed
	attack.damage_multiplier = stats.melee_damage_mult
	attack.speed_multiplier = stats.attack_speed_mult
	ranged.damage_multiplier = stats.ranged_damage_mult
	ranged.speed_multiplier = stats.projectile_speed_mult
	health.changed.emit(health.health, health.max_health)


## Dá uma relíquia ao Valtair agora (recompensa de sala, loja...): guarda na run, recalcula os
## números e, se ela aumenta a vida máxima, a vida nova já vem cheia.
func grant_relic(relic: RelicData) -> void:
	var old_max: int = health.max_health
	RunState.add_relic(relic)
	refresh_stats()
	var gained: int = health.max_health - old_max
	if gained > 0:
		health.heal(gained)


## O que esta relíquia faria com os limites de atributos se o Valtair a pegasse agora
## (pedestal e loja usam para avisar antes). Ver RunState.preview_relic().
func preview_relic(relic: RelicData) -> Dictionary:
	return RunState.preview_relic(relic, _base_stats)


func is_dead() -> bool:
	return health.health <= 0


func _on_health_died() -> void:
	if _try_death_save():
		return
	state_machine.transition_to("dead")


## Proteção da Caipora (qualquer luta) ou Benção do Curupira (só na luta final): impede a morte,
## devolve parte da vida, dá uma invulnerabilidade curta e CONSOME a relíquia.
## Na luta final usa a Benção primeiro, para guardar a Proteção.
func _try_death_save() -> bool:
	var relic: RelicData = _find_death_save_relic()
	if relic == null:
		return false
	RunState.consume_relic(relic)
	refresh_stats()
	health.set_current(maxi(1, ceili(health.max_health * stats.death_save_heal_fraction)))
	hurtbox.grant_invulnerability(DEATH_SAVE_INVULNERABILITY)
	death_saved.emit(relic)
	_show_message("%s te protegeu!" % relic.display_name)
	return true


func _find_death_save_relic() -> RelicData:
	var general: RelicData = null
	var final_fight: RelicData = null
	for relic in RunState.relics:
		for modifier in relic.modifiers:
			if modifier.stat == &"boitata_death_save" and final_fight == null:
				final_fight = relic
			elif modifier.stat == &"death_saves" and general == null:
				general = relic
	if in_boitata_fight and final_fight != null:
		return final_fight
	return general


## Texto curto no alto da tela (some sozinho).
func _show_message(text: String) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 40
	var label: Label = Label.new()
	label.text = text
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -160.0
	label.offset_right = 160.0
	label.offset_top = 60.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	layer.add_child(label)
	add_child(layer)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	)


## Espinhos da Floresta: quem machuca o Valtair leva dano de volta (se tiver Health).
func _on_damaged(_amount: int, source: Node) -> void:
	if stats.thorns_damage <= 0 or source == null or source == self:
		return
	var target: HealthComponent = source.get_node_or_null("Health") as HealthComponent
	if target != null:
		last_hit_empowered = false
		target.take_damage(stats.thorns_damage, self)


## Dash: marca o fim dele (Pena Encantada e Coração da Mula) e aplica o bônus de velocidade.
func _track_dash_effects(delta: float) -> void:
	var current: String = String(state_machine.current_state.name)
	if _prev_state_name == "Dash" and current != "Dash":
		_post_dash_damage_left = POST_DASH_DAMAGE_WINDOW
		_speed_boost_left = stats.post_dash_speed_time
	_prev_state_name = current
	if _post_dash_damage_left > 0.0:
		_post_dash_damage_left -= delta
	if _speed_boost_left > 0.0:
		_speed_boost_left -= delta
	stats.move_speed = _relic_move_speed * (stats.post_dash_speed_mult if _speed_boost_left > 0.0 else 1.0)


## Multiplicador extra do golpe corpo a corpo, calculado no instante do golpe.
func _melee_extra_mult() -> float:
	var mult: float = _low_health_mult()
	if not is_on_floor():
		mult *= stats.air_damage_mult  # Garras do Gavião
	if _post_dash_damage_left > 0.0:
		mult *= stats.post_dash_damage_mult  # Pena Encantada: só o primeiro golpe
		_post_dash_damage_left = 0.0
	last_hit_empowered = not is_equal_approx(mult, 1.0)
	return mult


func _ranged_extra_mult() -> float:
	var mult: float = _low_health_mult()
	last_hit_empowered = not is_equal_approx(mult, 1.0)
	return mult


func _low_health_mult() -> float:
	if health.health <= health.max_health * stats.low_health_threshold:
		return stats.low_health_damage_mult  # Dente de Piranha
	return 1.0


## Cura com a eficácia das curas do Valtair (a Maldição do Mapinguari reduz).
func scale_heal(amount: int) -> int:
	return maxi(1, roundi(amount * stats.healing_mult)) if amount > 0 else 0


func heal(amount: int) -> void:
	health.heal(scale_heal(amount))


## Chamado pela sala de combate quando ela é concluída (Flor da Vitória-Régia).
func on_room_cleared() -> void:
	if stats.heal_on_clear > 0:
		heal(stats.heal_on_clear)


## Chamado por todo inimigo que morre (Maldição do Mapinguari). Não sofre a redução de curas.
func on_enemy_killed() -> void:
	if stats.heal_on_kill > 0 and not is_dead():
		health.heal(stats.heal_on_kill)


func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0.0


func can_dash() -> bool:
	return dash_cooldown_left <= 0.0 and (is_on_floor() or air_dashes_left > 0)


## Dá o impulso do pulo. Usado pelo estado Jump e pelo Attack (pular durante o golpe
## não cancela o golpe), para o pulo ter uma implementação só.
func start_jump() -> void:
	velocity.y = stats.jump_velocity
	jump_buffered = false
	coyote_timer = 0.0
	jump_cut_available = true


func start_coyote_timer() -> void:
	coyote_timer = stats.coyote_time


func handle_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = stats.jump_buffer
		jump_buffered = true
	elif jump_buffered:
		jump_buffer_timer -= delta
		if jump_buffer_timer <= 0.0:
			jump_buffered = false


## Altura variável do pulo. Chame em TODO estado em que o Valtair pode estar subindo
## (Jump, Attack, Fall), para soltar o botão cortar a subida mesmo atacando no ar.
func apply_jump_cut() -> void:
	if not jump_cut_available:
		return
	if velocity.y >= 0.0:
		jump_cut_available = false  # passou do ápice: não há mais o que cortar
	elif not Input.is_action_pressed("jump"):
		velocity.y *= stats.jump_cut_multiplier
		jump_cut_available = false


func update_facing_direction(input_x: float) -> void:
	if input_x == 0.0:
		return
	var new_facing: int = 1 if input_x > 0.0 else -1
	if new_facing == facing:
		return
	facing = new_facing
	sprite.flip_h = facing < 0
	attack.set_facing(facing)  # a hitbox acompanha o lado para onde o Valtair olha


## O Player é a ponte entre os seus componentes e o HUD: repassa os sinais ao EventBus.
## Os componentes são genéricos (servem também a inimigos), então não falam com o HUD.
func _connect_hud_events() -> void:
	health.changed.connect(EventBus.player_health_changed.emit)
	ammo.changed.connect(EventBus.player_ammo_changed.emit)
	health.died.connect(EventBus.player_died.emit)
	death_sequence_finished.connect(EventBus.player_death_finished.emit)
	# Valores iniciais, depois que todos os nós (inclusive o HUD) terminarem o _ready.
	_emit_hud_state.call_deferred()


func _emit_hud_state() -> void:
	EventBus.player_health_changed.emit(health.health, health.max_health)
	EventBus.player_ammo_changed.emit(ammo.current, ammo.max_ammo)
	EventBus.leaves_changed.emit(RunState.leaves)


# TEMPORÁRIO: testa o HUD sem inimigos. Apague quando o Corpo-Seco existir.
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1: hurtbox.receive_hit(10, self, Vector2.ZERO)
		KEY_F2: health.heal(10)
		KEY_F3: ammo.refill()
		KEY_F4:  # morte definitiva (iria ao menu principal)
			permanent_death = true
			health.take_damage(health.health)
		KEY_F6:  # relíquia aleatória (teste)
			var pool: RelicPool = load("res://relics/relic_pool.tres")
			var relic: RelicData = pool.pick_random(RunState.relics)
			if relic != null:
				RunState.add_relic(relic)
				refresh_stats()
				print("Relíquia: ", relic.display_name)
		KEY_F5:  # morte normal (reinicia a sala)
			health.take_damage(health.health)
