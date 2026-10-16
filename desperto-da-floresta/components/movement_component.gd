class_name MovementComponent
extends Node
## Movimento HORIZONTAL. O pai precisa ser um CharacterBody2D.
## Não chama move_and_slide(): quem manda é o Player.

enum Mode {
	INSTANT,      ## velocidade vai direto ao alvo. Seco, estilo Hollow Knight.
	ACCELERATED,  ## acelera e freia. Mais "peso", estilo Dead Cells.
}

@export var mode: Mode = Mode.ACCELERATED
@export var max_speed: float = 140.0
@export_group("Só no modo ACCELERATED")
@export var acceleration: float = 1100.0
@export var friction: float = 1500.0
## Multiplicador de aceleração/atrito no ar (1.0 = igual ao chão).
@export var air_control: float = 0.8

@onready var body: CharacterBody2D = get_parent() as CharacterBody2D


func update(delta: float, dir: float, speed_multiplier: float = 1.0) -> void:
	var target := dir * max_speed * speed_multiplier
	match mode:
		Mode.INSTANT:
			body.velocity.x = target
		Mode.ACCELERATED:
			var rate := acceleration if absf(dir) > 0.01 else friction
			if not body.is_on_floor():
				rate *= air_control
			body.velocity.x = move_toward(body.velocity.x, target, rate * delta)
