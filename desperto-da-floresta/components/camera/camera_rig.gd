class_name CameraRig
extends Camera2D
## Câmera com dois modos.
##  STATIC: parada no centro da arena (combates em arena fechada).
##  FOLLOW: segue o alvo suavemente, limitada pelo retângulo da arena.

enum Mode { STATIC, FOLLOW }

@export var mode: Mode = Mode.STATIC
@export var target: Node2D
## Retângulo da arena em coordenadas do mundo. Vira o limite da câmera.
@export var arena_rect: Rect2 = Rect2(0, 0, 640, 360)
@export var follow_speed: float = 8.0


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
