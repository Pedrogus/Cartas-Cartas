class_name MerchantManager
extends RefCounted
## MerchantManager (sem autoload). Criado pela tela do mercador a cada visita.
## Monta as ofertas e faz as compras. Ouro, deck e Arcanos vivem no GameManager;
## aqui só tem a vitrine da visita atual.
## Mercador comum (GDD v3): 3 ofertas, com 10% de chance de UMA delas ser um Arcano.
## O Mercador do Chefe (6 ofertas, 2 Arcanos sempre) entra na próxima etapa.

const OFERTAS_COMUM := 3
const CHANCE_ARCANO_COMUM := 0.10
## Refresh: 1 PO no primeiro, +1 PO a cada refresh na mesma visita (1, 2, 3...). Sem limite.
const CUSTO_REFRESH_BASE := 1


## Uma oferta da vitrine: carta OU Arcano.
class Oferta:
	extends RefCounted
	var carta: CardData = null
	var arcano: ArcanaData = null
	var preco: int = 0
	var vendida: bool = false

	func nome() -> String:
		return carta.nome if carta != null else arcano.nome

	func eh_arcano() -> bool:
		return arcano != null


var ofertas: Array[Oferta] = []
## Refreshes nesta visita. Zera sozinho: cada visita cria um MerchantManager novo.
var refreshes_feitos: int = 0

var _pool_cartas: Array[CardData] = []
var _pool_arcanos: Array[ArcanaData] = []


func gerar_oferta_comum(pool_cartas: Array[CardData] = [], pool_arcanos: Array[ArcanaData] = []) -> void:
	_pool_cartas = pool_cartas if not pool_cartas.is_empty() else GameManager.pool_de_cartas()
	_pool_arcanos = pool_arcanos if not pool_arcanos.is_empty() else GameManager.pool_de_arcanos()
	ofertas.clear()
	var slot_arcano := -1
	if DiceRoller.chance(CHANCE_ARCANO_COMUM):
		slot_arcano = DiceRoller.indice(OFERTAS_COMUM)
	for i in OFERTAS_COMUM:
		var o := _sortear_oferta(i == slot_arcano)
		if o != null:
			ofertas.append(o)


## Sorteia 1 oferta. Se pedir Arcano e não houver nenhum livre, cai para carta.
func _sortear_oferta(quer_arcano: bool) -> Oferta:
	var o := Oferta.new()
	if quer_arcano:
		o.arcano = _sortear_arcano()
	if o.arcano == null:
		o.carta = _sortear_carta()
		if o.carta == null:
			return null   # pool vazio
	o.preco = preco_final(o.arcano.preco if o.eh_arcano() else o.carta.preco)
	return o


func _sortear_carta() -> CardData:
	var candidatas: Array[CardData] = []
	for c in _pool_cartas:
		if not _na_vitrine(c):
			candidatas.append(c)
	if candidatas.is_empty():
		return null
	return candidatas[DiceRoller.indice(candidatas.size())]


func _sortear_arcano() -> ArcanaData:
	var candidatos: Array[ArcanaData] = []
	for a in _pool_arcanos:
		if not GameManager.arcanos.has(a) and not _na_vitrine(a):
			candidatos.append(a)
	if candidatos.is_empty():
		return null
	return candidatos[DiceRoller.indice(candidatos.size())]


## true se a carta/Arcano já está exposto (vendido ou não).
func _na_vitrine(r: Resource) -> bool:
	for o in ofertas:
		if o.carta == r or o.arcano == r:
			return true
	return false


## Preço depois do Carisma. A fórmula de CAR ainda está pendente no GDD: por enquanto
## devolve o preço base. Quando for decidida, muda só aqui.
func preco_final(preco_base: int) -> int:
	return preco_base


## Motivo pelo qual a oferta não pode ser comprada agora ("" = pode comprar).
func motivo_bloqueio(indice: int) -> String:
	if indice < 0 or indice >= ofertas.size():
		return "Oferta inválida."
	var o := ofertas[indice]
	if o.vendida:
		return "Já foi comprada."
	if o.preco > GameManager.ouro:
		return "Ouro insuficiente (%d/%d PO)." % [GameManager.ouro, o.preco]
	if o.eh_arcano() and GameManager.arcanos.size() >= GameManager.ARCANOS_MAX:
		return "Você já tem %d Arcanos equipados." % GameManager.ARCANOS_MAX
	if not o.eh_arcano() and GameManager.deck_da_run.size() >= GameManager.DECK_MAX:
		return "Deck cheio (%d cartas)." % GameManager.DECK_MAX   # substituição: próxima etapa
	return ""


## Compra a oferta: gasta o ouro e põe a carta no deck (no tier do nível atual) ou equipa o
## Arcano. Retorna "" se deu certo, ou o motivo se não deu.
func comprar(indice: int) -> String:
	var motivo := motivo_bloqueio(indice)
	if motivo != "":
		return motivo
	var o := ofertas[indice]
	GameManager.gastar_ouro(o.preco)
	if o.eh_arcano():
		GameManager.adicionar_arcano(o.arcano)
	else:
		GameManager.adicionar_carta(o.carta)
	o.vendida = true
	return ""


## Preço do próximo refresh: 1, 2, 3... (cresce a cada refresh da visita).
func custo_refresh() -> int:
	return CUSTO_REFRESH_BASE + refreshes_feitos


## Índices das ofertas ainda não vendidas (as únicas que o refresh troca).
func _indices_livres() -> Array[int]:
	var livres: Array[int] = []
	for i in ofertas.size():
		if not ofertas[i].vendida:
			livres.append(i)
	return livres


## Motivo pelo qual o refresh não pode ser feito agora ("" = pode).
func motivo_bloqueio_refresh() -> String:
	if _indices_livres().is_empty():
		return "Nada para atualizar."
	if custo_refresh() > GameManager.ouro:
		return "Ouro insuficiente (%d/%d PO)." % [GameManager.ouro, custo_refresh()]
	return ""


## Refresh: cobra custo_refresh() e troca só as ofertas não vendidas (10% de chance de uma
## delas virar Arcano). As vendidas ficam como estão. Retorna "" se deu certo, ou o motivo.
func refrescar() -> String:
	var motivo := motivo_bloqueio_refresh()
	if motivo != "":
		return motivo
	GameManager.gastar_ouro(custo_refresh())
	refreshes_feitos += 1
	var livres := _indices_livres()
	var slot_arcano := -1
	if DiceRoller.chance(CHANCE_ARCANO_COMUM):
		slot_arcano = livres[DiceRoller.indice(livres.size())]
	for i in livres:
		var nova := _sortear_oferta(i == slot_arcano)
		if nova != null:
			ofertas[i] = nova
	return ""
