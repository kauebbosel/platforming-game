# components/sheet_sprite.gd
class_name SheetSprite
extends Sprite2D
## Sprite2D que anima sozinho percorrendo os quadros do spritesheet (hframes x vframes).
## Para props como a fogueira. Configure hframes/vframes no Inspetor e `fps` aqui.

@export var fps: float = 10.0


func _process(delta: float) -> void:
	var total: int = hframes * vframes
	if total <= 1:
		return
	_time += delta
	frame = int(_time * fps) % total


var _time: float = randf()  # começa em um ponto aleatório: fogueiras vizinhas não piscam juntas
