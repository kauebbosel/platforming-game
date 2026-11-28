# levels/boitata_room.gd
class_name BoitataRoom
extends Node2D
## Sala do Boitatá, o chefe final (GDD 9.5 e 11.2 "Floresta em Chamas"). A arena é a mesma do
## Curupira (640x360, chão em y=310, duas plataformas); aqui o cenário é de floresta queimando.
## Fluxo: o chefe desce do alto, a luta acontece, e quando ele morre a sala avisa que acabou
## (EventBus.room_exit_requested). Como o nó do mapa é o chefe final, o SceneManager leva à vitória.
## Liga `player.in_boitata_fight`, que é o que faz a Benção do Curupira valer.

signal cleared

@export var boss_scene: PackedScene
@export var boss_name: String = "Boitatá"
## Pausa entre a sala aparecer e o chefe começar a descer.
@export var start_delay: float = 1.0
## Tempo entre o último golpe e a saída (a animação de morte do corpo dura uns 1,5 s).
@export var victory_delay: float = 3.2

@onready var _spawn: Marker2D = $BossSpawn
@onready var _player: Player = $Player

var _boss: Boitata
var _bar: BossBar
var _done: bool = false
var _flames: Array[Polygon2D] = []


func _ready() -> void:
	assert(boss_scene != null, "BoitataRoom precisa de uma Boss Scene no Inspetor!")
	_player.in_boitata_fight = true  # Benção do Curupira vale só aqui
	_build_decor()
	_boss = boss_scene.instantiate() as Boitata
	add_child(_boss)
	_boss.place(_spawn.position)
	_boss.died.connect(_on_boss_died)
	_bar = BossBar.new()
	add_child(_bar)
	_bar.setup(boss_name, _boss.health)
	get_tree().create_timer(start_delay).timeout.connect(func() -> void:
		if is_instance_valid(_boss):
			_boss.begin()
	)


func boss() -> Boitata:
	return _boss


func _on_boss_died() -> void:
	if _done:
		return
	_done = true
	if _bar != null:
		_bar.queue_free()
		_bar = null
	await get_tree().create_timer(victory_delay).timeout
	cleared.emit()
	EventBus.room_exit_requested.emit()


func _process(_delta: float) -> void:
	# Chamas do cenário tremulando.
	var t: float = Time.get_ticks_msec() / 1000.0
	for i in _flames.size():
		_flames[i].scale.y = 0.85 + 0.25 * sin(t * 7.0 + float(i) * 1.7)


## Cenário: troncos queimando ao fundo e brasas subindo (tudo provisório, formas simples).
func _build_decor() -> void:
	var trunk_xs: Array[float] = [40.0, 130.0, 245.0, 330.0, 420.0, 520.0, 600.0]
	for i in trunk_xs.size():
		var x: float = trunk_xs[i]
		var height: float = 150.0 + 40.0 * float((i * 37) % 3)
		var trunk: Polygon2D = Polygon2D.new()
		trunk.color = Color(0.1, 0.05, 0.04)
		trunk.z_index = -8
		trunk.polygon = PackedVector2Array([Vector2(x - 9, 310), Vector2(x + 9, 310), Vector2(x + 6, 310 - height), Vector2(x - 6, 310 - height)])
		add_child(trunk)
		var flame: Polygon2D = Polygon2D.new()
		flame.color = Color(0.95, 0.4, 0.08, 0.85)
		flame.z_index = -7
		flame.position = Vector2(x, 310 - height)
		flame.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(-8, -16), Vector2(-3, -9), Vector2(2, -30), Vector2(8, -12), Vector2(14, 0)])
		add_child(flame)
		_flames.append(flame)
	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.position = Vector2(320, 340)
	embers.amount = 40
	embers.lifetime = 4.0
	embers.preprocess = 4.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(320, 4)
	embers.direction = Vector2(0, -1)
	embers.spread = 20.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 25.0
	embers.initial_velocity_max = 55.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.0
	embers.z_index = -6
	var fade: Gradient = Gradient.new()
	fade.colors = PackedColorArray([Color(1.0, 0.7, 0.2, 0.9), Color(1.0, 0.3, 0.05, 0.0)])
	embers.color_ramp = fade
	add_child(embers)
