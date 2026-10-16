class_name MapTheme
extends Resource
## TODAS as imagens e cores do mapa ficam aqui.
## Para trocar uma imagem: abra `default_map_theme.tres` e arraste o seu arquivo
## para o slot correspondente no Inspector. (Ou sobrescreva o arquivo em `art/`
## mantendo o mesmo nome.) Slot vazio = o mapa desenha uma bolinha colorida no lugar.

@export_group("Imagens")
@export var background: Texture2D
@export var player_marker: Texture2D

@export_subgroup("Ícones dos nós")
@export var icon_combate: Texture2D      ## Pegada
@export var icon_parkour: Texture2D      ## Cipó
@export var icon_miniboss: Texture2D     ## Caveira (Saci / Lobisomem)
@export var icon_mercadora: Texture2D    ## Caipora
@export var icon_descanso: Texture2D     ## Fogueira
@export var icon_evento: Texture2D       ## Interrogação
@export var icon_midboss: Texture2D      ## Rastro (Curupira)
@export var icon_boss: Texture2D         ## Fogo (Boitatá)

@export_group("Tamanhos")
## Diâmetro do ícone padrão, em pixels da resolução base do jogo.
@export var icon_size: float = 22.0
@export var player_marker_size: Vector2 = Vector2(14, 21)

@export_group("Estilo")
## Marque se as imagens são pixel art. Desmarque para imagens grandes/suaves
## (reduzir imagem grande com "nearest" fica serrilhado).
@export var pixel_art: bool = true
@export var background_color: Color = Color(0.05, 0.1, 0.08, 1)
@export var line_color: Color = Color(0.75, 0.85, 0.7, 0.28)
@export var line_color_available: Color = Color(1.0, 0.88, 0.45, 0.9)
@export var line_color_walked: Color = Color(0.55, 0.9, 0.6, 0.95)
@export var line_width: float = 1.5


func icon_for(kind: int) -> Texture2D:
	match kind:
		MapLayout.Kind.COMBATE: return icon_combate
		MapLayout.Kind.PARKOUR: return icon_parkour
		MapLayout.Kind.MINIBOSS: return icon_miniboss
		MapLayout.Kind.MERCADORA: return icon_mercadora
		MapLayout.Kind.DESCANSO: return icon_descanso
		MapLayout.Kind.EVENTO: return icon_evento
		MapLayout.Kind.MID_BOSS: return icon_midboss
		MapLayout.Kind.BOSS: return icon_boss
	return null


## Cor e letra usadas quando o slot da imagem está vazio.
static func fallback_color(kind: int) -> Color:
	match kind:
		MapLayout.Kind.COMBATE: return Color(0.69, 0.23, 0.18)
		MapLayout.Kind.PARKOUR: return Color(0.24, 0.51, 0.27)
		MapLayout.Kind.MINIBOSS: return Color(0.42, 0.27, 0.59)
		MapLayout.Kind.MERCADORA: return Color(0.77, 0.59, 0.16)
		MapLayout.Kind.DESCANSO: return Color(0.77, 0.43, 0.16)
		MapLayout.Kind.EVENTO: return Color(0.2, 0.39, 0.67)
		MapLayout.Kind.MID_BOSS: return Color(0.59, 0.27, 0.16)
		MapLayout.Kind.BOSS: return Color(0.75, 0.16, 0.12)
	return Color.GRAY


static func fallback_letter(kind: int) -> String:
	match kind:
		MapLayout.Kind.COMBATE: return "C"
		MapLayout.Kind.PARKOUR: return "P"
		MapLayout.Kind.MINIBOSS: return "M"
		MapLayout.Kind.MERCADORA: return "$"
		MapLayout.Kind.DESCANSO: return "D"
		MapLayout.Kind.EVENTO: return "?"
		MapLayout.Kind.MID_BOSS: return "CU"
		MapLayout.Kind.BOSS: return "B"
	return "?"
