class_name MapScreen
extends Control
## Tela do mapa de nós. Lê o layout de MapLayout e as imagens de MapTheme.
##
## Interação (útil para a apresentação):
##   clique num nó dourado = avança | R = reinicia | L = legenda | H = dicas | P = salva PNG
##
## Para ligar ao jogo de verdade depois, conecte o sinal `node_chosen(id, kind)`.

signal node_chosen(id: String, kind: int)
signal route_finished  ## o jogador escolheu um nó sem saída (o Boitatá)

@export var map_theme: MapTheme
## Retângulo (normalizado 0..1 na tela) onde a árvore é desenhada.
## O espaço à esquerda fica livre para a legenda.
@export var map_area: Rect2 = Rect2(0.30, 0.06, 0.66, 0.88)
@export var show_legend: bool = true:
	set(value):
		show_legend = value
		if _legend:
			_legend.visible = value
@export var show_hints: bool = true:
	set(value):
		show_hints = value
		if _hints:
			_hints.visible = value

var _views: Dictionary = {}        # id -> MapNodeView
var _children_of: Dictionary = {}  # id -> Array[String]
var _walked: Dictionary = {}       # "de>para" -> true (caminho já percorrido)
var _current_id: String = ""       # "" = ainda na origem
var _lines: Control
var _marker: Control
var _legend: Control
var _hints: Label
var _marker_base: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	if map_theme == null:
		map_theme = MapTheme.new()  # tema vazio: tudo vira bolinha colorida

	_build_background()
	_lines = Control.new()
	_lines.name = "Lines"
	_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	add_child(_lines)

	_build_graph()
	_build_views()
	_build_marker()
	_build_legend()
	_build_hints()

	resized.connect(_layout)
	reset()


func reset() -> void:
	_current_id = ""
	_walked.clear()
	for id: String in _views:
		(_views[id] as MapNodeView).state = MapNodeView.State.LOCKED
	for id: String in MapLayout.START:
		(_views[id] as MapNodeView).state = MapNodeView.State.AVAILABLE
	_layout()


func current_id() -> String:
	return _current_id


func available_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _views:
		if (_views[id] as MapNodeView).state == MapNodeView.State.AVAILABLE:
			out.append(id)
	return out


func choose(id: String) -> void:
	## Escolhe um nó por código (igual a clicar nele).
	if _views.has(id):
		_on_view_chosen(_views[id])


func save_screenshot(path: String = "user://mapa.png") -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Screenshot salvo em: ", ProjectSettings.globalize_path(path))


func _process(delta: float) -> void:
	_t += delta
	if _marker:
		_marker.position = _marker_base + Vector2(0.0, sin(_t * 3.0) * 1.5)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R: reset()
		KEY_L: show_legend = not show_legend
		KEY_H: show_hints = not show_hints
		KEY_P: save_screenshot()


# ---------------------------------------------------------------- construção

func _build_background() -> void:
	var solid := ColorRect.new()
	solid.name = "BackgroundColor"
	solid.color = map_theme.background_color
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(solid)
	if map_theme.background != null:
		var tex := TextureRect.new()
		tex.name = "Background"
		tex.texture = map_theme.background
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # cobre a tela sem distorcer
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if map_theme.pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tex)


func _build_graph() -> void:
	for id: String in MapLayout.NODES:
		_children_of[id] = [] as Array[String]
	for e: Array in MapLayout.EDGES:
		(_children_of[e[0]] as Array[String]).append(e[1])


func _build_views() -> void:
	for id: String in MapLayout.NODES:
		var data: Dictionary = MapLayout.NODES[id]
		var kind: int = data["kind"]
		var diameter := map_theme.icon_size * float(MapLayout.KIND_SCALE.get(kind, 1.0))
		var v := MapNodeView.new()
		v.name = id
		v.setup(id, kind, map_theme.icon_for(kind), diameter, map_theme.pixel_art)
		v.chosen.connect(_on_view_chosen)
		add_child(v)
		_views[id] = v


func _build_marker() -> void:
	_marker = Control.new()
	_marker.name = "PlayerMarker"
	_marker.size = map_theme.player_marker_size
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if map_theme.pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_marker.draw.connect(func() -> void:
		if map_theme.player_marker != null:
			_marker.draw_texture_rect(map_theme.player_marker, Rect2(Vector2.ZERO, _marker.size), false)
		else:
			_marker.draw_rect(Rect2(Vector2.ZERO, _marker.size), Color(0.2, 0.55, 0.9))
	)
	add_child(_marker)


func _build_legend() -> void:
	var panel := PanelContainer.new()
	panel.name = "Legend"
	panel.position = Vector2(10, 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.04, 0.72)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var title := Label.new()
	title.text = "LEGENDA"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	box.add_child(title)

	for kind: int in MapLayout.KIND_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_view := MapNodeView.new()
		icon_view.setup("legend_%d" % kind, kind, map_theme.icon_for(kind), 16.0, map_theme.pixel_art, true)
		row.add_child(icon_view)
		var label := Label.new()
		label.text = MapLayout.KIND_NAMES[kind]
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.9))
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		box.add_child(row)

	panel.visible = show_legend
	_legend = panel
	add_child(panel)


func _build_hints() -> void:
	_hints = Label.new()
	_hints.name = "Hints"
	_hints.text = "Clique num nó dourado  |  R reinicia  |  L legenda  |  H esconde dicas  |  P salva PNG"
	_hints.add_theme_font_size_override("font_size", 8)
	_hints.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hints.position = Vector2(10, -14)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.visible = show_hints
	add_child(_hints)


# ---------------------------------------------------------------- layout

func _to_screen(p: Vector2) -> Vector2:
	var area_pos := map_area.position * size
	var area_size := map_area.size * size
	return area_pos + p * area_size


func _center_of(id: String) -> Vector2:
	var v: MapNodeView = _views[id]
	return v.position + v.size * 0.5


func _layout() -> void:
	for id: String in _views:
		var v: MapNodeView = _views[id]
		var p: Vector2 = MapLayout.NODES[id]["pos"]
		v.position = _to_screen(p) - v.size * 0.5
	_place_marker()
	if _lines:
		_lines.queue_redraw()


func _place_marker() -> void:
	if _marker == null:
		return
	var ms := _marker.size
	if _current_id == "":
		_marker_base = _to_screen(MapLayout.ORIGIN) - Vector2(ms.x * 0.5, ms.y)
	else:
		# Fica ao lado esquerdo do nó atual, para não cobrir os caminhos à frente.
		var v: MapNodeView = _views[_current_id]
		var c := _center_of(_current_id)
		_marker_base = Vector2(c.x - v.icon_diameter * 0.5 - ms.x - 3.0, c.y - ms.y * 0.6)
	_marker.position = _marker_base


# ---------------------------------------------------------------- linhas

func _draw_lines() -> void:
	var origin := _to_screen(MapLayout.ORIGIN)
	for id: String in MapLayout.START:
		_draw_edge("", id, origin, _center_of(id))
	for e: Array in MapLayout.EDGES:
		_draw_edge(e[0], e[1], _center_of(e[0]), _center_of(e[1]))


func _draw_edge(from_id: String, to_id: String, a: Vector2, b: Vector2) -> void:
	var th := map_theme
	if _walked.has(from_id + ">" + to_id):
		_lines.draw_line(a, b, th.line_color_walked, th.line_width + 0.5, true)
	elif _current_id == from_id and (_views[to_id] as MapNodeView).state == MapNodeView.State.AVAILABLE:
		_lines.draw_dashed_line(a, b, th.line_color_available, th.line_width + 0.5, 4.0, true, true)
	else:
		_lines.draw_dashed_line(a, b, th.line_color, th.line_width, 3.0, true, true)


# ---------------------------------------------------------------- lógica de escolha

func _on_view_chosen(view: MapNodeView) -> void:
	if view.state != MapNodeView.State.AVAILABLE:
		return

	# Os outros nós disponíveis ficam bloqueados: não dá para voltar atrás.
	for id: String in _views:
		var other: MapNodeView = _views[id]
		if other.state == MapNodeView.State.AVAILABLE:
			other.state = MapNodeView.State.LOCKED
	if _current_id != "":
		(_views[_current_id] as MapNodeView).state = MapNodeView.State.VISITED

	_walked[_current_id + ">" + view.id] = true
	_current_id = view.id
	view.state = MapNodeView.State.CURRENT

	var next: Array[String] = _children_of[view.id]
	for child in next:
		(_views[child] as MapNodeView).state = MapNodeView.State.AVAILABLE

	_place_marker()
	_lines.queue_redraw()
	node_chosen.emit(view.id, view.kind)
	if next.is_empty():
		route_finished.emit()
