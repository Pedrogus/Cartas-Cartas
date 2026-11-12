class_name EnemyData
extends Resource
## EnemyData (Resource). Molde de um inimigo (valores base do ciclo 1).
## Não há mais ataque comum: o inimigo só ataca com as cartas do deck dele (regras do jogador).
## Só dados. O HP que escala por ciclo entra na etapa 7; o combate usa stats.criar_copia_combate().

@export_group("Identidade")
@export var id: String = ""
@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var arte: Texture2D
@export var tipo_criatura: Enums.TipoCriatura = Enums.TipoCriatura.HUMANOIDE
@export var eh_chefe: bool = false  # chefe faz salvaguarda com vantagem (Teia)

@export_group("Números")
@export var stats: ActorStats       # hp_max, CA, DES (esquiva) e INT (CD das magias)
@export var turnos_alvo: int = 3    # terminar dentro disso dá bônus de ouro

@export_group("Deck e ações (o inimigo joga como o jogador)")
## Deck de uma classe (ex.: guerreiro.tres). Vazio = usa só as cartas_proprias.
@export var classe_do_deck: ClassData
## Cartas exclusivas do inimigo (ex.: Mordida). Quantas entram vem de CardData.copias_iniciais.
@export var cartas_proprias: Array[CardData] = []
## Igual ao jogador no nível 1: 1 ação e 1 ação bônus por turno (sem mulligan).
@export var acoes_por_turno: int = 1
@export var acoes_bonus_por_turno: int = 1

@export_group("Defesas")
@export var fraquezas: Array[Enums.TipoDano] = []      # dano x2
@export var resistencias: Array[Enums.TipoDano] = []   # dano ÷2 (arredonda para baixo)
@export var imunidades: Array[Enums.TipoDano] = []     # dano 0

@export_group("Habilidades")
@export_multiline var habilidades: String = ""  # texto por enquanto; vira lógica na etapa 7


## Todo inimigo tem um deck de 22 cartas (GDD v3.2). Sem reembaralhar no combate do jogador,
## mas o inimigo recicla o descarte quando a pilha acaba (regra do CombatManager).
const TAMANHO_DECK := 22


## Monta o deck do inimigo: cartas da classe (se houver) + cartas próprias, repetidas por
## copias_iniciais. Mesma lógica de ClassData.montar_deck_inicial().
func montar_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	if classe_do_deck != null:
		deck.append_array(classe_do_deck.montar_deck_inicial())
	for carta in cartas_proprias:
		for i in carta.copias_iniciais:
			deck.append(carta)
	return deck


## Deck pronto para o DeckManager: cada carta com o tier do nível do inimigo (stats.nivel).
func montar_deck_com_tier() -> Array[CartaNoDeck]:
	var tier := CartaNoDeck.tier_do_nivel(stats.nivel) if stats != null else 0
	var deck: Array[CartaNoDeck] = []
	for carta in montar_deck():
		deck.append(CartaNoDeck.new(carta, tier))
	return deck


## O deck tem de ter pelo menos 22 cartas.
func deck_valido() -> bool:
	return montar_deck().size() >= TAMANHO_DECK


## Multiplicador de dano do GDD: imune 0, fraqueza 2, resistência 0.5, normal 1.
func multiplicador_dano(tipo: Enums.TipoDano) -> float:
	if tipo in imunidades:
		return 0.0
	if tipo in fraquezas:
		return 2.0
	if tipo in resistencias:
		return 0.5
	return 1.0
