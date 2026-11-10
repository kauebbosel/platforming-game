# core/input_hint.gd
class_name InputHint
extends RefCounted
## Nome legível da tecla de uma ação, para textos como "[E] Descansar".
## Se o jogador remapear a ação, o texto acompanha.

static func key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.as_text_physical_keycode()
	return str(action)
