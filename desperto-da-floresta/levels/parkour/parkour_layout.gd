# levels/parkour/parkour_layout.gd
class_name ParkourLayout
extends Node2D
## Um percurso de Parkour (GDD 10.1). Cada layout_*.tscn é um destes: plataformas, cipós e
## espinhos, mais quatro marcadores que a ParkourRoom usa:
##   PlayerStart  = onde o Valtair começa (nos pés)
##   ChestSpot    = onde fica o baú no fim
##   PedestalSpot = onde aparece a relíquia do baú
##   ExitSpot     = onde fica a porta de saída
## Todos os marcadores ficam na altura da SUPERFÍCIE da plataforma. `bounds` é o tamanho do
## percurso (a câmera não passa disso). Dá para editar o percurso no editor normalmente.

@export var bounds: Rect2 = Rect2(0, 0, 1280, 480)
@export var layout_name: String = ""


func player_start() -> Vector2:
	return ($PlayerStart as Marker2D).global_position


func chest_spot() -> Vector2:
	return ($ChestSpot as Marker2D).global_position


func pedestal_spot() -> Vector2:
	return ($PedestalSpot as Marker2D).global_position


func exit_spot() -> Vector2:
	return ($ExitSpot as Marker2D).global_position
