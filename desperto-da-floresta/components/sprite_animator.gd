# components/sprite_animator.gd
class_name SpriteAnimator
extends Node
## Anima o Sprite2D de um inimigo com spritesheets, de acordo com o estado em que ele está
## (Idle, Chase, Attack...). Basta pôr este nó como filho do inimigo e escolher o `profile`.
## O que cada perfil usa (sheet, quadros, velocidade, deslocamento) está em PROFILES, no fim
## deste arquivo. Se uma textura não for encontrada, o inimigo continua com o sprite estático.
##
## Como cada estado escolhe a animação (`states` do perfil):
##   "nome": &"anim"                  -> sempre essa animação
##   { "moving": a, "still": b }      -> a se está se movendo na horizontal, senão b
##   { "air": a, "ground": b, "landed": c } -> a no ar, b no chão antes de saltar, c depois de pousar
## Estados que o perfil não cita usam a animação `default`.
## Uma animação com `phases` acompanha as fases do AttackComponent do inimigo (startup/active/
## recovery) em vez de rodar por tempo.
## `offset` mantém os pés e o centro do corpo onde o sprite estático estava: o X é espelhado
## junto com o flip_h do Sprite2D (o Godot não espelha o `offset`).

@export var profile: String = ""

## Velocidade horizontal (px/s) a partir da qual o inimigo conta como "se movendo".
const MOVE_THRESHOLD: float = 20.0
const ATTACK_PHASES: Array[String] = ["idle", "startup", "active", "recovery"]

var _enemy: EnemyBase
var _sprite: Sprite2D
var _data: Dictionary = {}
var _textures: Dictionary = {}
var _current: Dictionary = {}
var _current_id: StringName = &""
var _last_state: String = ""
var _time: float = 0.0
var _airborne: bool = false
var _phase: int = -1
var _phase_time: float = 0.0
var _ok: bool = false


func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	if _enemy == null or not PROFILES.has(profile):
		push_warning("SpriteAnimator: perfil '%s' inexistente." % profile)
		return
	# O @onready `sprite` do inimigo ainda não existe aqui (os filhos ficam prontos primeiro).
	_sprite = _enemy.get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		return
	_data = PROFILES[profile]
	var anims: Dictionary = _data["anims"]
	for anim_id in anims:
		var path: String = anims[anim_id]["tex"]
		if _textures.has(path):
			continue
		if not ResourceLoader.exists(path):
			push_warning("SpriteAnimator: textura não encontrada (%s). O inimigo fica com o sprite estático." % path)
			return
		_textures[path] = load(path)
	_ok = true


func _process(delta: float) -> void:
	if not _ok or not is_instance_valid(_enemy):
		return
	var machine: EnemyStateMachine = _enemy.state_machine
	if machine == null or machine.current_state == null:
		return
	var state: String = String(machine.current_state.name).to_lower()
	if state != _last_state:
		_last_state = state
		_airborne = false
	var wanted: StringName = _resolve(state)
	if wanted != _current_id:
		_play(wanted)
	_advance(delta)
	var shift: Vector2 = _current["offset"]
	_sprite.offset = Vector2(shift.x * (-1.0 if _sprite.flip_h else 1.0), shift.y)


func _resolve(state: String) -> StringName:
	var spec: Variant = _data["states"].get(state, _data["default"])
	if spec is Dictionary:
		var branch: Dictionary = spec
		if branch.has("air"):
			if not _enemy.is_on_floor():
				_airborne = true
				return branch["air"]
			return branch["landed"] if _airborne else branch["ground"]
		if branch.has("moving"):
			return branch["moving"] if absf(_enemy.velocity.x) > MOVE_THRESHOLD else branch["still"]
		return _data["default"]
	return StringName(spec)


func _play(anim_id: StringName) -> void:
	var anims: Dictionary = _data["anims"]
	if not anims.has(anim_id):
		anim_id = _data["default"]
	_current_id = anim_id
	_current = anims[anim_id]
	_time = 0.0
	_phase = -1
	_phase_time = 0.0
	_sprite.texture = _textures[_current["tex"]]
	_sprite.hframes = _current["hframes"]
	_sprite.vframes = _current.get("vframes", 1)
	_sprite.frame = (_current["frames"] as Array)[0]


func _advance(delta: float) -> void:
	if _current.has("phases") and _enemy.attack != null:
		var phase: int = int(_enemy.attack.state)
		if phase != _phase:
			_phase = phase
			_phase_time = 0.0
		_phase_time += delta
		var list: Array = _current["phases"].get(ATTACK_PHASES[phase], _current["frames"])
		var phase_index: int = mini(int(_phase_time * float(_current.get("phase_fps", 12.0))), list.size() - 1)
		_sprite.frame = list[phase_index]
		return
	var frames: Array = _current["frames"]
	_time += delta
	var index: int = int(_time * float(_current["fps"]))
	if _current["loop"]:
		index = index % frames.size()
	else:
		index = mini(index, frames.size() - 1)
	_sprite.frame = frames[index]



const PROFILES := {
	"cuca": {
		"default": &"fly",
		"states": {},
		"anims": {
			&"fly": {
				"tex": "res://assets/art/anim/cuca_move.png",
				"hframes": 8,
				"frames": [0, 1, 2, 3, 4, 5, 6, 7],
				"fps": 10.0,
				"loop": true,
				"offset": Vector2(0, 0),
			},
		},
	},
	"mula": {
		"default": &"idle",
		"states": {
			"chase": &"walk",
			"charge": { "moving": &"run", "still": &"idle" },
		},
		"anims": {
			&"idle": {
				"tex": "res://assets/art/anim/mula_walk.png",
				"hframes": 8,
				"frames": [0],
				"fps": 1.0,
				"loop": true,
				"offset": Vector2(0, -18),
			},
			&"walk": {
				"tex": "res://assets/art/anim/mula_walk.png",
				"hframes": 8,
				"frames": [0, 1, 2, 3, 4, 5, 6, 7],
				"fps": 12.0,
				"loop": true,
				"offset": Vector2(0, -18),
			},
			&"run": {
				"tex": "res://assets/art/anim/mula_walk.png",
				"hframes": 8,
				"frames": [0, 1, 2, 3, 4, 5, 6, 7],
				"fps": 18.0,
				"loop": true,
				"offset": Vector2(0, -18),
			},
		},
	},
	"mapinguari": {
		"default": &"idle",
		"states": { "chase": &"walk" },
		"anims": {
			&"idle": {
				"tex": "res://assets/art/anim/mapinguari_walk.png",
				"hframes": 7,
				"frames": [0],
				"fps": 1.0,
				"loop": true,
				"offset": Vector2(0, -20),
			},
			&"walk": {
				"tex": "res://assets/art/anim/mapinguari_walk.png",
				"hframes": 7,
				"frames": [0, 1, 2, 3, 4, 5, 6],
				"fps": 6.0,
				"loop": true,
				"offset": Vector2(0, -20),
			},
		},
	},
	"corpo_seco": {
		"default": &"idle",
		"states": { "chase": &"walk", "attack": &"attack", "hurt": &"hurt", "dead": &"death" },
		"anims": {
			&"idle": {
				"tex": "res://assets/art/anim/corpo_seco_actions.png",
				"hframes": 4,
				"frames": [0],
				"fps": 1.0,
				"loop": true,
				"offset": Vector2(-4, -20),
				"vframes": 4,
			},
			&"walk": {
				"tex": "res://assets/art/anim/corpo_seco_walk.png",
				"hframes": 4,
				"frames": [0, 1, 4, 5, 6, 7],
				"fps": 6.0,
				"loop": true,
				"offset": Vector2(-4, -20),
				"vframes": 2,
			},
			&"attack": {
				"tex": "res://assets/art/anim/corpo_seco_actions.png",
				"hframes": 4,
				"frames": [4, 5, 6, 8, 9],
				"fps": 12.0,
				"loop": true,
				"offset": Vector2(-4, -20),
				"vframes": 4,
				"phases": { "idle": [0], "startup": [4], "active": [5, 6], "recovery": [8, 9] },
				"phase_fps": 14.0,
			},
			&"hurt": {
				"tex": "res://assets/art/anim/corpo_seco_actions.png",
				"hframes": 4,
				"frames": [12],
				"fps": 1.0,
				"loop": true,
				"offset": Vector2(-4, -20),
				"vframes": 4,
			},
			&"death": {
				"tex": "res://assets/art/anim/corpo_seco_actions.png",
				"hframes": 4,
				"frames": [13, 14],
				"fps": 6.0,
				"loop": false,
				"offset": Vector2(-4, -20),
				"vframes": 4,
			},
		},
	},
	"curupira": {
		"default": &"idle",
		"states": {
			"idle": &"idle",
			"chase": &"walk",
			"charge": { "moving": &"dash", "still": &"windup" },
			"slam": { "air": &"jump", "ground": &"crouch", "landed": &"land" },
			"seeds": &"idle",
			"hurt": &"hurt",
			"dead": &"death",
		},
		"anims": {
			&"idle": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [0, 1, 2, 3],
				"fps": 5.0,
				"loop": true,
				"offset": Vector2(2, -14),
			},
			&"walk": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [6, 7, 8, 9, 10, 11, 12],
				"fps": 9.0,
				"loop": true,
				"offset": Vector2(2, -14),
			},
			&"windup": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [16],
				"fps": 1.0,
				"loop": true,
				"offset": Vector2(2, -14),
			},
			&"dash": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [16, 17, 18],
				"fps": 12.0,
				"loop": false,
				"offset": Vector2(2, -14),
			},
			&"crouch": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [22],
				"fps": 1.0,
				"loop": true,
				"offset": Vector2(2, -15),
			},
			&"jump": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [23, 24, 25],
				"fps": 8.0,
				"loop": false,
				"offset": Vector2(2, -15),
			},
			&"land": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [26],
				"fps": 1.0,
				"loop": true,
				"offset": Vector2(2, -15),
			},
			&"hurt": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [29],
				"fps": 1.0,
				"loop": true,
				"offset": Vector2(2, -14),
			},
			&"death": {
				"tex": "res://assets/art/anim/curupira_sheet.png",
				"hframes": 40,
				"frames": [34, 35, 36],
				"fps": 8.0,
				"loop": false,
				"offset": Vector2(2, -14),
			},
		},
	},
}
