# components/blink_component.gd
class_name BlinkComponent
extends Node
## Faz um nó visual piscar enquanto uma Hurtbox estiver invulnerável.
## Não lê input nem sabe quem é o dono: só escuta os sinais da Hurtbox.
## Para usar em outra entidade, aponte `hurtbox` e `target` no Inspetor.

## A Hurtbox cujos sinais disparam o pisca (ex.: a do Valtair).
@export var hurtbox: Hurtbox
## O que pisca. No Valtair, o nó "Visual" (o modulate vale para os filhos).
@export var target: CanvasItem
## Segundos em cada meia fase (visível -> apagado -> visível).
@export_range(0.02, 0.5, 0.01, "suffix:s") var blink_interval: float = 0.08
## Opacidade na fase "apagada" (1 = não pisca, 0 = some por completo).
@export_range(0.0, 1.0, 0.05) var low_alpha: float = 0.3

var _tween: Tween
var _base_alpha: float = 1.0


func _ready() -> void:
	assert(hurtbox != null, "BlinkComponent precisa de uma Hurtbox atribuída no Inspetor!")
	assert(target != null, "BlinkComponent precisa de um Target (nó visual) atribuído no Inspetor!")
	hurtbox.invulnerability_started.connect(_on_invulnerability_started)
	hurtbox.invulnerability_ended.connect(stop)


func _on_invulnerability_started(_duration: float) -> void:
	start()


## Pode ser chamado direto (ex.: um power-up que pisca por outro motivo) e para
## sozinho quando a Hurtbox avisar que acabou; para parar antes, chame stop().
func start() -> void:
	stop()
	_base_alpha = target.modulate.a
	_tween = create_tween().set_loops()  # sem número = repete até alguém chamar stop()
	_tween.tween_property(target, "modulate:a", low_alpha, blink_interval)
	_tween.tween_property(target, "modulate:a", _base_alpha, blink_interval)


func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_tween = null
		target.modulate.a = _base_alpha
