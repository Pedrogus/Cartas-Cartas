class_name DeckManager
extends RefCounted
## DeckManager (sem autoload). Criado pelo CombatManager no início de CADA fase.
## Só MOVE cartas entre pilha, mão e descarte. Os limites do turno (3 jogadas, mulligans)
## ficam no CombatManager. Não há reembaralhar: o descarte só volta na próxima fase.

signal mao_alterada  # a interface se atualiza quando a mão ou a pilha mudam

const TAMANHO_MAO := 5

var pilha: Array[CartaNoDeck] = []
var mao: Array[CartaNoDeck] = []
var descarte: Array[CartaNoDeck] = []


## Começa uma fase: embaralha o deck inteiro na pilha e compra a mão inicial.
func iniciar_fase(deck: Array[CartaNoDeck]) -> void:
	pilha.assign(deck)
	mao.clear()
	descarte.clear()
	DiceRoller.embaralhar(pilha)
	comprar_ate_mao_cheia()


## Compra até qtd cartas (para se a pilha acabar). Retorna quantas comprou.
func comprar(qtd: int) -> int:
	var comprou := 0
	for i in qtd:
		if pilha.is_empty():
			break
		mao.append(pilha.pop_back())
		comprou += 1
	if comprou > 0:
		mao_alterada.emit()
	return comprou


## Cartas não jogadas ficam na mão; compra só o que falta para chegar a 5.
func comprar_ate_mao_cheia() -> int:
	return comprar(TAMANHO_MAO - mao.size())


## Joga a carta: sai da mão e vai para o descarte. Retorna false se ela não está na mão.
func jogar_carta(carta: CartaNoDeck) -> bool:
	var indice := mao.find(carta)
	if indice == -1:
		return false
	mao.remove_at(indice)
	descarte.append(carta)
	mao_alterada.emit()
	return true


## Mulligan: descarta a carta e compra outra da pilha. Retorna false se não puder
## (carta fora da mão ou pilha vazia).
func trocar_carta(carta: CartaNoDeck) -> bool:
	if pilha.is_empty() or not mao.has(carta):
		return false
	jogar_carta(carta)
	comprar(1)
	return true


## Game Over por falta de cartas: mão e pilha vazias (o descarte não conta).
func sem_cartas() -> bool:
	return mao.is_empty() and pilha.is_empty()


## Total de cartas em jogo (mão + pilha + descarte). Deve sempre ser o tamanho do deck.
func total_cartas() -> int:
	return pilha.size() + mao.size() + descarte.size()
