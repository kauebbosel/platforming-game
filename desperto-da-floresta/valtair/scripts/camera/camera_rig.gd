class_name CameraRig
extends Camera2D
## Câmera com dois modos + tremor de tela.
##  STATIC: parada no centro da arena (combates em arena fechada).
##  FOLLOW: segue o alvo suavemente, limitada pelo retângulo da arena.

enum Mode { STATIC, FOLLOW }

@export var mode: Mode = Mode.STATIC
@export var target: Node2D
## Retângulo da arena em coordenadas do mundo. Vira o limite da câmera.
@export var arena_rect: Rect2 = Rect2(0, 0, 640, 360)
@export var follow_speed: float = 8.0
@export var shake_decay: float = 30.0

var _shake: float = 0.0


func _ready() -> void:
	limit_left = int(arena_rect.position.x)
	limit_top = int(arena_rect.position.y)
	limit_right = int(arena_rect.end.x)
	limit_bottom = int(arena_rect.end.y)
	if mode == Mode.STATIC:
		global_position = arena_rect.get_center()
	elif target:
		global_position = target.global_position


func _process(delta: float) -> void:
	if mode == Mode.FOLLOW and target:
		var t := 1.0 - exp(-follow_speed * delta)  # suavização independente de FPS
		global_position = global_position.lerp(target.global_position, t)

	if _shake > 0.0:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = move_toward(_shake, 0.0, shake_decay * delta)
	else:
		offset = Vector2.ZERO


## Chame ao acertar um golpe forte, tomar dano, etc. (strength em pixels)
func shake(strength: float = 3.0) -> void:
	_shake = maxf(_shake, strength)
