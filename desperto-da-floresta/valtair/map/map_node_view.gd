class_name MapNodeView
extends Control
## Um nó do mapa na tela: desenha o ícone, o anel de estado e recebe o clique.

signal chosen(view: MapNodeView)

enum State {
	LOCKED,     ## ainda inalcançável (escurecido)
	AVAILABLE,  ## pode ser escolhido agora (anel dourado pulsando)
	VISITED,    ## já passou por aqui
	CURRENT,    ## onde o Valtair está
}

var id: String = ""
var kind: int = 0
var icon: Texture2D
var icon_diameter: float = 22.0
var static_mode: bool = false  ## true = só desenho (usado na legenda), sem clique/estado

var state: State = State.LOCKED:
	set(value):
		state = value
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (state == State.AVAILABLE and not static_mode) else Control.CURSOR_ARROW
		queue_redraw()

var _hover: bool = false
var _t: float = 0.0


func setup(p_id: String, p_kind: int, p_icon: Texture2D, diameter: float, pixel_art: bool, p_static: bool = false) -> void:
	id = p_id
	kind = p_kind
	icon = p_icon
	icon_diameter = diameter
	static_mode = p_static
	size = Vector2.ONE * (diameter + 12.0)
	custom_minimum_size = size
	pivot_offset = size * 0.5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE if static_mode else Control.MOUSE_FILTER_STOP
	if not static_mode:
		mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
		mouse_exited.connect(func() -> void: _hover = false; queue_redraw())
	queue_redraw()


func _process(delta: float) -> void:
	if state == State.AVAILABLE and not static_mode:
		_t += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if static_mode or state != State.AVAILABLE:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(self)
		accept_event()


func _draw() -> void:
	var c := size * 0.5
	var r := icon_diameter * 0.5

	if not static_mode:
		match state:
			State.AVAILABLE:
				var pulse := 0.5 + 0.5 * sin(_t * 4.0)
				if _hover:
					draw_circle(c, r + 4.0, Color(1, 1, 1, 0.15))
				draw_arc(c, r + 3.0 + pulse * 1.5, 0.0, TAU, 32, Color(1.0, 0.88, 0.45, 0.55 + 0.45 * pulse), 1.5, true)
			State.CURRENT:
				draw_arc(c, r + 3.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 1.0), 2.0, true)
			State.VISITED:
				draw_arc(c, r + 2.0, 0.0, TAU, 32, Color(0.55, 0.9, 0.6, 0.8), 1.0, true)

	# Fundo escuro atrás do ícone: garante leitura sobre qualquer imagem de fundo.
	draw_circle(c, r + 1.0, Color(0.04, 0.07, 0.05, 0.85))

	var tint := Color.WHITE
	if not static_mode:
		match state:
			State.LOCKED: tint = Color(0.45, 0.45, 0.45, 1.0)
			State.VISITED: tint = Color(0.6, 0.75, 0.6, 1.0)

	if icon != null:
		# Encaixa a imagem dentro do círculo mantendo a proporção.
		var ts := icon.get_size()
		var k := minf(icon_diameter / ts.x, icon_diameter / ts.y)
		var sz := ts * k
		draw_texture_rect(icon, Rect2(c - sz * 0.5, sz), false, tint)
	else:
		draw_circle(c, r, MapTheme.fallback_color(kind) * tint)
		var f := ThemeDB.fallback_font
		var letter := MapTheme.fallback_letter(kind)
		var fs := int(icon_diameter * 0.5)
		draw_string(f, Vector2(0.0, c.y + fs * 0.35), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1, 1, 1, tint.a))
