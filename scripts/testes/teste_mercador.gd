class_name TesteMercador
extends RefCounted
## TESTE manual da etapa do mercador (MerchantManager, RestService, Arcanos, preços).
## Para rodar: chame TesteMercador.rodar() no _ready do GameManager (e tire depois).
## Imprime [OK] ou [FALHOU] por verificação.

static var _ok: int = 0
static var _total: int = 0


static func rodar() -> void:
	_ok = 0
	_total = 0
	DiceRoller.definir_semente(7)

	# --- pools e preços ---
	var pool := GameManager.pool_de_cartas()
	_conferir("pool tem cartas das duas classes e poções", _tem_classe(pool, Enums.Classe.GUERREIRO)
		and _tem_classe(pool, Enums.Classe.MAGO) and _tem_item(pool))
	_conferir("pool não tem carta de inimigo (Mordida)", not _tem_id(pool, "mordida"))
	var espada: CardData = load("res://data/cartas/guerreiro/espada.tres")
	var pocao: CardData = load("res://data/cartas/itens/pocao_cura.tres")
	_conferir("carta comum custa 3 PO", espada.preco == 3)
	_conferir("poção custa 5 PO", pocao.preco == 5)
	var arcanos := GameManager.pool_de_arcanos()
	_conferir("3 Arcanos placeholder carregados", arcanos.size() == 3)
	var preco_ok := true
	for a in arcanos:
		if a.preco < 7 or a.preco > 10 or a.arte == null:
			preco_ok = false
	_conferir("Arcanos custam de 7 a 10 PO e têm arte", preco_ok)

	# --- vitrine ---
	GameManager.nova_run(Enums.Classe.GUERREIRO)
	var mm := MerchantManager.new()
	mm.gerar_oferta_comum()
	_conferir("vitrine comum tem 3 ofertas", mm.ofertas.size() == 3)
	var arcanos_vistos := 0
	for i in 500:
		mm.gerar_oferta_comum()
		for o in mm.ofertas:
			if o.eh_arcano():
				arcanos_vistos += 1
	_conferir("Arcano aparece em ~10%% das vitrines (%d/500)" % arcanos_vistos,
		arcanos_vistos > 25 and arcanos_vistos < 80)

	# --- compra de carta ---
	mm.ofertas.clear()
	var o := MerchantManager.Oferta.new()
	o.carta = espada
	o.preco = 3
	mm.ofertas.append(o)
	var tamanho := GameManager.deck_da_run.size()
	GameManager.ouro = 2
	_conferir("sem ouro: compra bloqueada", mm.comprar(0) != "" and GameManager.deck_da_run.size() == tamanho)
	GameManager.ouro = 5
	_conferir("com ouro: compra ok", mm.comprar(0) == "")
	_conferir("ouro desceu para 2", GameManager.ouro == 2)
	_conferir("deck ganhou 1 carta", GameManager.deck_da_run.size() == tamanho + 1)
	_conferir("não compra duas vezes", mm.comprar(0) != "")

	# --- deck cheio ---
	while GameManager.deck_da_run.size() < GameManager.DECK_MAX:
		GameManager.adicionar_carta(espada)
	o.vendida = false
	GameManager.ouro = 10
	_conferir("deck cheio (30): compra bloqueada", mm.comprar(0) != "" and GameManager.ouro == 10)

	# --- Arcanos ---
	GameManager.nova_run(Enums.Classe.GUERREIRO)
	var imperador: ArcanaData = load("res://data/arcanos/imperador.tres")
	var forca: ArcanaData = load("res://data/arcanos/forca.tres")
	var sol: ArcanaData = load("res://data/arcanos/sol.tres")
	GameManager.adicionar_arcano(imperador)
	_conferir("Imperador dá +1 de CA", GameManager.bonus_ca_arcanos() == 1)
	var cm := CombatManager.new()
	cm.jogador = GameManager.stats_jogador
	_conferir("CA no combate soma o Arcano (15 + 1)", cm.ca_jogador() == GameManager.stats_jogador.ca + 1)
	GameManager.adicionar_arcano(forca)
	GameManager.adicionar_arcano(sol)
	var m := ModificadoresAtaque.new()
	cm._aplicar_arcanos(m)
	_conferir("Força: +2 de dano nos mods", m.bonus_dano == 2)
	_conferir("Sol: +1d6 de Fogo nos mods", m.dados_extras == 1 and m.faces_dado_extra == 6
		and m.tipo_dano_extra == Enums.TipoDano.FOGO)
	cm.free()
	for i in 2:
		GameManager.adicionar_arcano(forca)
	_conferir("5 Arcanos equipados", GameManager.arcanos.size() == 5)
	_conferir("6º Arcano bloqueado", not GameManager.adicionar_arcano(forca))
	var mm2 := MerchantManager.new()
	mm2.gerar_oferta_comum([espada], [sol])
	var oa := MerchantManager.Oferta.new()
	oa.arcano = imperador
	oa.preco = 8
	mm2.ofertas = [oa]
	GameManager.ouro = 20
	_conferir("mercador bloqueia Arcano com 5 equipados", mm2.comprar(0) != "" and GameManager.ouro == 20)

	# --- descanso curto ---
	GameManager.nova_run(Enums.Classe.GUERREIRO)
	var jog := GameManager.stats_jogador
	var r := RestService.descanso_curto()
	_conferir("HP cheio: descanso bloqueado e não gasta dado", not r["ok"] and GameManager.dados_vida_restantes == 3)
	jog.hp_atual = 1
	r = RestService.descanso_curto()
	_conferir("descanso cura d10 + CON (%d)" % r["cura"], r["ok"] and r["cura"] == r["dado"] + 2
		and jog.hp_atual == mini(1 + r["cura"], jog.hp_max))
	_conferir("gastou 1 dado de vida (sobram 2)", GameManager.dados_vida_restantes == 2)
	jog.hp_atual = 1
	RestService.descanso_curto()
	jog.hp_atual = 1
	RestService.descanso_curto()
	jog.hp_atual = 1
	r = RestService.descanso_curto()
	_conferir("sem dados de vida: descanso bloqueado", not r["ok"] and jog.hp_atual == 1)
	for i in 3:
		GameManager.avancar_fase()
	_conferir("ciclo novo devolve os 3 dados de vida", GameManager.dados_vida_restantes == 3)

	_rodar_refresh()

	DiceRoller.aleatorizar()
	GameManager.nova_run(Enums.Classe.GUERREIRO)
	print("Mercador: %d/%d verificacoes OK" % [_ok, _total])


## Refresh: custo 1, 2, 3; vendidas não mudam; bloqueios não gastam ouro; visita nova zera.
static func _rodar_refresh() -> void:
	# --- custo crescente ---
	GameManager.nova_run(Enums.Classe.GUERREIRO)
	var mr := MerchantManager.new()
	mr.gerar_oferta_comum()
	GameManager.ouro = 10
	var custos: Array[int] = []
	for i in 3:
		custos.append(mr.custo_refresh())
		mr.refrescar()
	_conferir("refresh custa 1, 2, 3 (%s)" % str(custos), custos == [1, 2, 3])
	_conferir("ouro 10 - 6 = 4", GameManager.ouro == 4)
	_conferir("contador de refreshes = 3", mr.refreshes_feitos == 3)

	# --- espaço vendido não muda, livre muda ---
	var vista := MerchantManager.new()
	vista.gerar_oferta_comum()
	GameManager.ouro = 50
	vista.comprar(0)
	var vendida := vista.ofertas[0]
	var livre_antes := vista.ofertas[1]
	_conferir("refresh com espaço vendido passa", vista.refrescar() == "")
	_conferir("vendida continua o mesmo objeto", is_same(vista.ofertas[0], vendida) and vista.ofertas[0].vendida)
	_conferir("livre foi trocada", not is_same(vista.ofertas[1], livre_antes))
	_conferir("livre não repete a carta anterior", vista.ofertas[1].nome() != livre_antes.nome())

	# --- tudo vendido: bloqueado, sem gastar ---
	vista.comprar(1)
	vista.comprar(2)
	var ouro_antes := GameManager.ouro
	_conferir("tudo vendido: refresh bloqueado", vista.refrescar() != "")
	_conferir("tudo vendido: não gastou ouro", GameManager.ouro == ouro_antes)

	# --- sem ouro: bloqueado, vitrine igual ---
	var pobre := MerchantManager.new()
	pobre.gerar_oferta_comum()
	GameManager.ouro = 0
	var antes := pobre.ofertas.duplicate()
	_conferir("sem ouro: refresh bloqueado", pobre.refrescar() != "")
	var igual := true
	for i in antes.size():
		if not is_same(antes[i], pobre.ofertas[i]):
			igual = false
	_conferir("sem ouro: vitrine continua igual", igual)

	# --- visita nova zera o custo ---
	_conferir("mercador novo volta a custar 1", MerchantManager.new().custo_refresh() == 1)


static func _tem_classe(pool: Array[CardData], classe: Enums.Classe) -> bool:
	for c in pool:
		if c.categoria == Enums.CategoriaCarta.CLASSE and c.classe_origem == classe:
			return true
	return false


static func _tem_item(pool: Array[CardData]) -> bool:
	for c in pool:
		if c.categoria == Enums.CategoriaCarta.ITEM:
			return true
	return false


static func _tem_id(pool: Array[CardData], id: String) -> bool:
	for c in pool:
		if c.id == id:
			return true
	return false


static func _conferir(nome: String, condicao: bool) -> void:
	_total += 1
	if condicao:
		_ok += 1
	print("[%s] %s" % ["OK" if condicao else "FALHOU", nome])
