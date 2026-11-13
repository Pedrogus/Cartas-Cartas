class_name InimigoEmCombate
extends RefCounted
## InimigoEmCombate. Um inimigo VIVO na fase atual: o molde (EnemyData) + o estado do combate
## (HP, baralho, bônus temporários, turnos perdidos). Uma fase pode ter vários (GDD v3.2).
## O molde (.tres) nunca é alterado; os dois Ratos são duas instâncias do mesmo molde.

var data: EnemyData
var stats: ActorStats                  # cópia de combate: o HP muda aqui
var deck: DeckManager                  # baralho de 22 cartas, mão 5, sem mulligan
var nome: String = ""                  # nome no log e na tela ("Rato Mutante 1")
var bonus_ca: Array[Dictionary] = []   # [{valor, restante}] escudos
var bonus_acerto_proxima: int = 0
var rerrolar_ate: int = 0
var acoes_restantes: int = 0
var turnos_perdidos: int = 0           # Teia / Parar o Tempo do jogador


static func criar(p_data: EnemyData, p_nome: String) -> InimigoEmCombate:
	var e := InimigoEmCombate.new()
	e.data = p_data
	e.nome = p_nome
	e.stats = p_data.stats.criar_copia_combate(p_data.stats.nivel)
	e.deck = DeckManager.new()
	e.deck.iniciar_fase(p_data.montar_deck_com_tier())
	return e


func vivo() -> bool:
	return not stats.esta_morto()


## CA agora: base + escudos ativos.
func ca() -> int:
	var total := stats.ca
	for b in bonus_ca:
		total += b["valor"]
	return total


## Destreza decide a ordem entre os inimigos (maior age primeiro; empate: da esquerda para a direita).
func iniciativa() -> int:
	return data.stats.valor_atributo(Enums.Atributo.DES)


## Passa 1 turno dos escudos; os que acabaram saem.
func passar_duracao() -> void:
	for i in range(bonus_ca.size() - 1, -1, -1):
		bonus_ca[i]["restante"] -= 1
		if bonus_ca[i]["restante"] <= 0:
			bonus_ca.remove_at(i)
