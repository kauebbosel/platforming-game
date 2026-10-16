class_name InputSetup
extends RefCounted
## Registra as ações de input se elas ainda não existirem no Input Map.
## Assim você não precisa configurar nada em Project Settings para testar.
## Se depois você criar as ações manualmente no Input Map, este script não sobrescreve nada.

static func ensure_actions() -> void:
	_ensure(&"move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_ensure(&"move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_ensure(&"jump", [_key(KEY_SPACE), _key(KEY_W), _key(KEY_UP), _joy_button(JOY_BUTTON_A)])
	_ensure(&"attack", [_key(KEY_J), _key(KEY_X), _mouse(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_X)])


static func _ensure(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.5)
	for e in events:
		InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(btn: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	return e


static func _joy_button(btn: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = btn
	return e


static func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
