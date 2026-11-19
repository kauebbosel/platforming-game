# core/dialogues.gd
class_name Dialogues
extends RefCounted
## Todos os textos de diálogo do jogo, num lugar só (GDD 7.1 e 7.2).
## Cada fala é [quem fala, texto]. Quem fala vazio ("") = narração, sem nome na caixa.
## Para tocar um diálogo:  await DialogueBox.play(self, Dialogues.INTRO)

const VALTAIR := "Valtair"
const CURUPIRA := "Curupira"

## Poema do início de cada partida (GDD 7.1). Cada "página" tem dois versos.
const INTRO: Array = [
	["", "Valtair das lendas vivia a zombar,\nDizia que eram histórias para boi dormir e sonhar."],
	["", "Mas um dia, na floresta, perdeu seu caminho,\nE descobriu que ali não estava sozinho."],
	["", "Entre o sonho e a realidade, terá de caminhar,\nPois os segredos da mata começam a despertar."],
	["", "Se quiser encontrar o caminho de volta ao lar,\nÀs histórias que desprezou terá de escutar."],
]

## Antes da luta contra o Curupira (GDD 7.2.1).
const CURUPIRA_ANTES: Array = [
	[CURUPIRA, "Quem é você, forasteiro? O que faz tão longe de seu caminho?"],
	[VALTAIR, "Eu me perdi. Só quero sair desta floresta."],
	[CURUPIRA, "Você entra em um lugar que não compreende e espera simplesmente ir embora? A floresta não é apenas um caminho entre dois lugares."],
	[VALTAIR, "Não tenho tempo para essas histórias. Vai me deixar passar ou não?"],
	[CURUPIRA, "Vejo que ainda tem muito a aprender. Mostre-me do que é capaz."],
]

## Depois que o Valtair vence o Curupira (GDD 7.2.2).
const CURUPIRA_VITORIA: Array = [
	[CURUPIRA, "Nada mal, forasteiro. Você tem mais determinação do que imaginei."],
	[VALTAIR, "Então vai me mostrar como sair daqui?"],
	[CURUPIRA, "Ainda não. Você venceu uma batalha, mas não compreendeu o que está acontecendo nesta floresta."],
	[VALTAIR, "E o que exatamente eu preciso compreender?"],
	[CURUPIRA, "Que estas histórias que você tanto despreza são parte deste lugar. E agora você também faz parte delas."],
	[VALTAIR, "Então tudo aquilo que ouvi quando era criança... era verdade?"],
	[CURUPIRA, "Algumas histórias guardam mais verdade do que você imagina. Continue seu caminho. Ainda nos encontraremos novamente."],
	# TODO: aqui entra o diálogo do antigo Evento (as lendas e o aviso sobre o Boitatá).
]

## Depois que o Curupira vence o Valtair; em seguida vem o Game Over (GDD 7.2.3).
const CURUPIRA_DERROTA: Array = [
	[CURUPIRA, "Sua coragem é evidente, mas você ainda age sem pensar."],
	[VALTAIR, "Eu... só queria voltar para casa."],
	[CURUPIRA, "Então aprenda a respeitar aquilo que não conhece. A floresta não perdoa quem ignora seus perigos."],
	[CURUPIRA, "Sua jornada termina aqui, por enquanto."],
]
