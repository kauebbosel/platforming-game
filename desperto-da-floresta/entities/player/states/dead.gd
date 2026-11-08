# entities/player/states/dead.gd
extends PlayerState
## Morte do Valtair. Sem controle: este estado não lê nenhum input.
## Fica no lugar (cai com a gravidade se morreu no ar), espera `death_pause_time`
## (PlayerStats) e avisa o Player, que repassa ao EventBus. Quem decide o que fazer
## depois (reiniciar a sala, ir ao menu) é o SceneManager, não este estado.

var _time_left: float = 0.0
var _finished: bool = false


func enter() -> void:
	_finished = false
	_time_left = player.stats.death_pause_time
	player.velocity.x = 0.0
	# Placeholder visual até existir a animação de morte.
	player.sprite.modulate = Color(0.45, 0.45, 0.45)
	# O corpo deixa de ser alvo (inimigos e projéteis não o "acertam" mais).
	# Adiado porque a morte costuma acontecer dentro de um callback de física.
	player.hurtbox.set_deferred("monitorable", false)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()

	if _finished:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_finished = true
		player.death_sequence_finished.emit(player.permanent_death)
