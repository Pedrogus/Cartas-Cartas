class_name ClassData
extends Resource
## ClassData (Resource). Molde de uma classe: números de nível 1, dado de vida e cartas.
## Só dados. O HP que cresce por nível fica na run (GameManager/RunState), não aqui.

@export var id: Enums.Classe = Enums.Classe.GUERREIRO
@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var atributo_principal: Enums.Atributo = Enums.Atributo.FOR
## Faces do dado de vida (Guerreiro d10 = 10, Mago d6 = 6). Usado no descanso curto e no level up.
@export var dado_vida: int = 8
## Atributos, HP e CA no nível 1.
@export var stats: ActorStats
## Cartas da classe. Quantas entram no deck inicial vem de CardData.copias_iniciais.
@export var cartas: Array[CardData] = []


## Deck inicial: cada carta repetida copias_iniciais vezes (22 cartas por classe).
func montar_deck_inicial() -> Array[CardData]:
	var deck: Array[CardData] = []
	for carta in cartas:
		for i in carta.copias_iniciais:
			deck.append(carta)
	return deck
