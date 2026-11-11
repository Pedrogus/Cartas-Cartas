extends Node

const CICLOS_MAX := 20
const FASES_POR_CICLO := 3
const NIVEL_MAX := 20
const DECK_MIN := 22
const DECK_MAX := 30
const ACOES_MAX := 4
## Classe -> molde. Para criar uma classe nova: enum em Enums + .tres + uma linha aqui.
const CLASSES := {
	Enums.Classe.GUERREIRO: preload("res://data/classes/guerreiro.tres"),
	Enums.Classe.MAGO: preload("res://data/classes/mago.tres"),
}

var run_ativa: bool = false
var classe: Enums.Classe = Enums.Classe.GUERREIRO
var nivel: int = 1
var ouro: int = 0
var ciclo_atual: int = 1
var fase_atual: int = 1
var turnos_contados: int = 0
## Deck da run (22 a 30 cartas). Cada fase embaralha uma cópia dele no DeckManager.
var deck_da_run: Array[CartaNoDeck] = []
## Ficha do jogador na run. O HP carrega de uma fase para a outra (não volta ao máximo).
var stats_jogador: ActorStats


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)
	print("GameManager pronto")
	# TesteDeck.rodar()  # teste manual da etapa 5 (descomente para rodar)
	# TesteDeck.rodar_acoes()  # teste manual das ações (descomente para rodar)




func nova_run(classe_escolhida: Enums.Classe) -> void:
	classe = classe_escolhida
	nivel = 1
	ouro = 0
	ciclo_atual = 1
	fase_atual = 1
	turnos_contados = 0
	montar_deck_inicial()
	stats_jogador = dados_da_classe().stats.criar_copia_combate(nivel)
	run_ativa = true
	EventBus.nivel_alterado.emit(nivel)
	EventBus.ouro_alterado.emit(ouro)
	print("Run iniciada: %s, nível %d" % [Enums.Classe.keys()[classe], nivel])

func registrar_turno() -> void:
	turnos_contados += 1

func adicionar_ouro(quantidade: int) -> void:
	ouro += quantidade
	EventBus.ouro_alterado.emit(ouro)
	
func gastar_ouro(quantidade: int) -> bool:
	if quantidade > ouro:
		return false
	ouro -= quantidade
	EventBus.ouro_alterado.emit(ouro)
	return true


func subir_nivel() -> void:
	if nivel >= NIVEL_MAX:
		return
	nivel += 1
	# TODO etapa 7: HP ganho por nível (dado de vida + CON)
	if stats_jogador != null:
		stats_jogador.nivel = nivel  # a proficiência acompanha o nível
	EventBus.nivel_alterado.emit(nivel)

func avancar_fase() -> void:
	turnos_contados = 0
	fase_atual += 1
	if fase_atual > FASES_POR_CICLO:
		fase_atual = 1
		ciclo_atual += 1
		if ciclo_atual > CICLOS_MAX:
			run_ativa = false
			print("Run vencida!")   # um sinal run_vencida entra no EventBus quando houver a tela final
			return
		subir_nivel()
		
func _on_game_over(motivo: String) -> void:
	run_ativa = false
	print("Game Over: %s" % motivo)


## Molde (ClassData) da classe escolhida na run.
func dados_da_classe() -> ClassData:
	return CLASSES[classe]


## Deck inicial da classe: todas as cartas no tier 0.
func montar_deck_inicial() -> void:
	deck_da_run.clear()
	for carta in dados_da_classe().montar_deck_inicial():
		deck_da_run.append(CartaNoDeck.new(carta, 0))


## Carta nova (level up ou mercador): nasce no tier do nível atual.
## Retorna false se o deck já está cheio (use substituir_carta).
func adicionar_carta(carta: CardData) -> bool:
	if deck_da_run.size() >= DECK_MAX:
		return false
	deck_da_run.append(CartaNoDeck.new(carta, CartaNoDeck.tier_do_nivel(nivel)))
	return true


## Deck cheio: a carta nova toma o lugar de uma existente (índice em deck_da_run).
func substituir_carta(indice: int, nova: CardData) -> bool:
	if indice < 0 or indice >= deck_da_run.size():
		return false
	deck_da_run[indice] = CartaNoDeck.new(nova, CartaNoDeck.tier_do_nivel(nivel))
	return true


## Ações por turno (ataques, magias de ataque, Teia): 1 no início, +1 nos níveis 5, 10 e 15
## (máximo 4). A ação bônus (suporte) é fixa em 1 por turno.
func acoes_por_turno() -> int:
	return mini(ACOES_MAX, 1 + floori(nivel / 5.0))
