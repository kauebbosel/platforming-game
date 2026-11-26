# core/hit_stop.gd
class_name HitStop
extends RefCounted
## Congelada curtíssima quando um golpe do Valtair acerta, para dar peso ao impacto.
## Usa Engine.time_scale quase zero por alguns quadros e depois volta a 1. O tempo é contado
## em tempo REAL (o timer ignora o time_scale), então não dá para travar o jogo.
## A duração vem do AttackData.hitstop_frames do golpe (3 quadros = 0,05 s).
## Para desligar tudo: ENABLED = false.

const ENABLED: bool = true
## Quase parado, mas não zero (zero pararia até as animações que ainda queremos suaves).
const SLOW_SCALE: float = 0.02

static var _active: int = 0


static func trigger(tree: SceneTree, seconds: float) -> void:
	if not ENABLED or seconds <= 0.0 or tree == null:
		return
	_active += 1
	Engine.time_scale = SLOW_SCALE
	await tree.create_timer(seconds, true, false, true).timeout
	_active = maxi(0, _active - 1)
	if _active == 0:
		Engine.time_scale = 1.0
