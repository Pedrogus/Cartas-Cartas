extends Node

const CICLOS_MAX := 20
const FASES_POR_CICLO := 3
const NIVEL_MAX := 20
const DECK_MIN := 22
const DECK_MAX := 30
const ACOES_MAX := 4
const ARCANOS_MAX := 5
## 3 dados de vida por ciclo (um por mercador). Voltam todos ao começar um ciclo novo
## (depois: ao entrar no Mercador do Chefe, GDD v3).
const DADOS_VIDA_POR_CICLO := 3
## Pastas que formam o pool do mercador (multiclasse + poções). Cartas de inimigo ficam fora.
const PASTAS_POOL_CARTAS := [
	"res://data/cartas/guerreiro",
	"res://data/cartas/mago",
	"res://data/cartas/itens",
]
const PASTA_ARCANOS := "res://data/arcanos"
## Classe -> molde. Para criar uma classe nova: enum em Enums + .tres + uma linha aqui.
const CLASSES := {
	Enums.Classe.GUERREIRO: preload("res://data/classes/guerreiro.tres"),
	Enums.Classe.MAGO: preload("res://data/classes/mago.tres"),
}

var run_ativa: bool = false
var classe: Enums.Classe = Enums.Classe.GUERREIRO
var nivel: int = 1
var ouro: int = 10
var ciclo_atual: int = 1
var fase_atual: int = 1
var turnos_contados: int = 0
## Deck da run (22 a 30 cartas). Cada fase embaralha uma cópia dele no DeckManager.
var deck_da_run: Array[CartaNoDeck] = []
## Ficha do jogador na run. O HP carrega de uma fase para a outra (não volta ao máximo).
var stats_jogador: ActorStats
## Arcanos equipados (máx. 5). O 6º fica bloqueado (pendência do GDD).
var arcanos: Array[ArcanaData] = []
## Dados de vida que ainda dá para gastar no descanso curto neste ciclo.
var dados_vida_restantes: int = DADOS_VIDA_POR_CICLO

var _pool_cartas: Array[CardData] = []
var _pool_arcanos: Array[ArcanaData] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)
	print("GameManager pronto")
	
func nova_run(classe_escolhida: Enums.Classe) -> void:
	classe = classe_escolhida
	nivel = 1
	ouro = 10
	ciclo_atual = 1
	fase_atual = 1
	turnos_contados = 0
	arcanos.clear()
	dados_vida_restantes = DADOS_VIDA_POR_CICLO
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
		dados_vida_restantes = DADOS_VIDA_POR_CICLO   # TODO: mover para o Mercador do Chefe
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


# ---------------------------------------------------------------------------
# Arcanos
# ---------------------------------------------------------------------------

## Equipa o Arcano. Retorna false se já há 5 equipados (o 6º fica bloqueado).
func adicionar_arcano(arcano: ArcanaData) -> bool:
	if arcanos.size() >= ARCANOS_MAX:
		return false
	arcanos.append(arcano)
	return true


## CA somada por todos os Arcanos de BONUS_CA equipados.
func bonus_ca_arcanos() -> int:
	var total := 0
	for a in arcanos:
		if a.efeito == Enums.EfeitoArcano.BONUS_CA:
			total += a.valor
	return total


# ---------------------------------------------------------------------------
# Pool do mercador (carregado uma vez, sob demanda)
# ---------------------------------------------------------------------------

## Todas as cartas que o mercador pode oferecer: das duas classes (multiclasse) e poções.
func pool_de_cartas() -> Array[CardData]:
	if _pool_cartas.is_empty():
		for pasta in PASTAS_POOL_CARTAS:
			for r in _carregar_pasta(pasta):
				if r is CardData:
					_pool_cartas.append(r)
	return _pool_cartas


## Todos os Arcanos que existem em data/arcanos.
func pool_de_arcanos() -> Array[ArcanaData]:
	if _pool_arcanos.is_empty():
		for r in _carregar_pasta(PASTA_ARCANOS):
			if r is ArcanaData:
				_pool_arcanos.append(r)
	return _pool_arcanos


## Carrega todos os .tres de uma pasta. No jogo exportado eles viram ".tres.remap":
## tirar o ".remap" e dar load() no caminho original funciona nos dois casos.
func _carregar_pasta(pasta: String) -> Array[Resource]:
	var lista: Array[Resource] = []
	var arquivos := DirAccess.get_files_at(pasta)
	arquivos.sort()   # ordem estável (mesma semente = mesma oferta)
	var vistos := {}
	for nome in arquivos:
		var arq := nome.trim_suffix(".remap")
		if arq.ends_with(".tres") and not vistos.has(arq):
			vistos[arq] = true
			var r := load(pasta.path_join(arq))
			if r != null:
				lista.append(r)
	return lista
