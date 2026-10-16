class_name Player
extends CharacterBody2D
## Orquestrador do Valtair. Não tem lógica de movimento própria: só chama os
## componentes NA ORDEM CERTA e depois move_and_slide().
## (Os componentes não usam _physics_process para não depender da ordem da árvore.)

signal facing_changed(facing: int)

@onready var movement: MovementComponent = $Movement
@onready var jump: JumpComponent = $Jump
@onready var attack: AttackComponent = $Attack
@onready var health: HealthComponent = $Health
@onready var visual: Node2D = $Visual
@onready var slash_fx: CanvasItem = get_node_or_null("Attack/SlashFX")

var facing: int = 1


func _ready() -> void:
	InputSetup.ensure_actions()
	attack.active_started.connect(func() -> void: _set_slash(true))
	attack.active_ended.connect(func() -> void: _set_slash(false))
	_set_slash(false)


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis(&"move_left", &"move_right")

	# Vira para o lado do input, exceto no meio de um ataque.
	if dir != 0.0 and not attack.is_attacking():
		_set_facing(1 if dir > 0.0 else -1)

	attack.update(delta)
	movement.update(delta, dir, attack.movement_multiplier())
	jump.update(delta)
	move_and_slide()


func _set_facing(new_facing: int) -> void:
	if new_facing == facing:
		return
	facing = new_facing
	visual.scale.x = float(facing)
	attack.set_facing(facing)
	facing_changed.emit(facing)


func _set_slash(on: bool) -> void:
	if slash_fx:
		slash_fx.visible = on
