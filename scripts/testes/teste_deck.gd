class_name TesteDeck
extends RefCounted
## TESTE temporário da etapa 5 (DeckManager + deck da run). Chamado do _ready do GameManager.
## Imprime [OK] ou [FALHOU] por verificação. Pode ser apagado depois de validar.

static var _ok: int = 0
static var _total: int = 0


static func rodar() -> void:
	_ok = 0
	_total = 0
	DiceRoller.definir_semente(5)

	# --- deck da run (Mago) ---
	GameManager.nova_run(Enums.Classe.MAGO)
	var deck := GameManager.deck_da_run
	_conferir("deck do Mago tem 22 cartas", deck.size() == 22)
	var tudo_tier0 := true
	for c in deck:
		if c.tier != 0:
			tudo_tier0 = false
	_conferir("deck inicial inteiro no tier 0", tudo_tier0)

	# --- DeckManager ---
	var dm := DeckManager.new()
	dm.iniciar_fase(deck)
	_conferir("inicio: mao 5 / pilha 17 / descarte 0", dm.mao.size() == 5 and dm.pilha.size() == 17 and dm.descarte.size() == 0)

	for i in 3:
		dm.jogar_carta(dm.mao[0])
	_conferir("jogar 3: mao 2 / descarte 3", dm.mao.size() == 2 and dm.descarte.size() == 3)

	dm.comprar_ate_mao_cheia()
	_conferir("completar mao: mao 5 / pilha 14", dm.mao.size() == 5 and dm.pilha.size() == 14)

	_conferir("mulligan funciona", dm.trocar_carta(dm.mao[0]))
	_conferir("apos mulligan: mao 5 / pilha 13 / descarte 4", dm.mao.size() == 5 and dm.pilha.size() == 13 and dm.descarte.size() == 4)
	_conferir("nenhuma carta perdida ou duplicada (22)", dm.total_cartas() == 22)

	dm.comprar(99)
	_conferir("comprar tudo: pilha vazia, mao 18", dm.pilha.is_empty() and dm.mao.size() == 18)
	_conferir("mulligan com pilha vazia e recusado", not dm.trocar_carta(dm.mao[0]))
	_conferir("com cartas na mao, sem_cartas() e falso", not dm.sem_cartas())
	while not dm.mao.is_empty():
		dm.jogar_carta(dm.mao[0])
	_conferir("mao e pilha vazias: sem_cartas() verdadeiro", dm.sem_cartas())
	_conferir("descarte com as 22 cartas", dm.descarte.size() == 22 and dm.total_cartas() == 22)

	# --- mesma semente, mesmo embaralhamento ---
	DiceRoller.definir_semente(9)
	var a := DeckManager.new()
	a.iniciar_fase(deck)
	DiceRoller.definir_semente(9)
	var b := DeckManager.new()
	b.iniciar_fase(deck)
	var iguais := true
	for i in 5:
		if a.mao[i].carta.id != b.mao[i].carta.id:
			iguais = false
	_conferir("mesma semente = mesma mao inicial", iguais)

	# --- tier e limite do deck ---
	var espada: CardData = load("res://data/cartas/guerreiro/espada.tres")
	GameManager.nivel = 5
	GameManager.adicionar_carta(espada)
	_conferir("carta nova no nivel 5 nasce no tier 2", GameManager.deck_da_run[22].tier == 2)
	for i in 7:
		GameManager.adicionar_carta(espada)
	_conferir("deck chega a 30", GameManager.deck_da_run.size() == 30)
	_conferir("31a carta recusada com deck cheio", not GameManager.adicionar_carta(espada))
	_conferir("substituir carta mantem 30", GameManager.substituir_carta(0, espada) and GameManager.deck_da_run.size() == 30)
	_conferir("deck do Guerreiro tem 22", _deck_da_classe(Enums.Classe.GUERREIRO) == 22)

	GameManager.nova_run(Enums.Classe.GUERREIRO)  # volta o estado da run
	DiceRoller.aleatorizar()  # o teste fixou a semente; volta ao sorteio de verdade
	print("Etapa 5: %d/%d verificacoes OK" % [_ok, _total])


static func _deck_da_classe(classe: Enums.Classe) -> int:
	GameManager.nova_run(classe)
	return GameManager.deck_da_run.size()


static func _conferir(nome: String, condicao: bool) -> void:
	_total += 1
	if condicao:
		_ok += 1
	print("[%s] %s" % ["OK" if condicao else "FALHOU", nome])


## Teste manual do deck dos inimigos (GDD v3.2). Chame TesteDeck.rodar_inimigos() no _ready.
static func rodar_inimigos() -> void:
	_ok = 0
	_total = 0
	var rato: EnemyData = load("res://data/inimigos/rato_esgoto.tres")
	var esq: EnemyData = load("res://data/inimigos/esqueleto_guardiao.tres")
	var cult: EnemyData = load("res://data/inimigos/cultista_sombras.tres")
	for e in [rato, esq, cult]:
		_conferir("%s tem deck valido (>= 22)" % e.nome, e.deck_valido())
		_conferir("%s: 1 acao e 1 acao bonus" % e.nome, e.acoes_por_turno == 1 and e.acoes_bonus_por_turno == 1)
	var deck_rato := rato.montar_deck()
	var so_mordida := true
	for c in deck_rato:
		if c.id != "mordida":
			so_mordida = false
	_conferir("Rato: 22 cartas, todas Mordida", deck_rato.size() == 22 and so_mordida)
	_conferir("Esqueleto usa o deck do Guerreiro", esq.montar_deck().size() == GameManager.CLASSES[Enums.Classe.GUERREIRO].montar_deck_inicial().size())
	_conferir("Cultista usa o deck do Mago", cult.montar_deck().size() == GameManager.CLASSES[Enums.Classe.MAGO].montar_deck_inicial().size())
	var com_tier := rato.montar_deck_com_tier()
	_conferir("deck com tier tem o mesmo tamanho", com_tier.size() == deck_rato.size())
	_conferir("tier do inimigo nivel 1 = 0", com_tier[0].tier == 0)
	print("Inimigos: %d/%d verificacoes OK" % [_ok, _total])


## Teste manual do formato do log (GDD v3.2). Chame TesteDeck.rodar_log() no _ready.
static func rodar_log() -> void:
	_ok = 0
	_total = 0
	var espada: CardData = load("res://data/cartas/guerreiro/espada.tres")
	var r := ResultadoAtaque.new()
	r.acertou = true
	r.d20 = 12
	r.total_acerto = 17
	r.bonus_proficiencia = 2
	r.bonus_atributo = 3
	r.ca_alvo = 10
	var linha := LogCombate.ataque("Jogador", espada, r)
	print(linha)
	_conferir("ataque: Jogador -> Utilizou ESPADA", linha.begins_with("Jogador -> Utilizou ESPADA -> Tirou 12 (17 no total) (1d20 + 2 + 3)"))
	_conferir("ataque: ACERTOU (CA 10)", linha.contains("ACERTOU") and linha.ends_with("(CA 10)"))
	r.d20 = 20
	r.critico = true
	r.total_acerto = 25
	linha = LogCombate.ataque("Jogador", espada, r)
	print(linha)
	_conferir("critico: Tirou 20 CRÍTICO (25 no total)", linha.contains("Tirou 20 CRÍTICO (25 no total)"))
	var s := ResultadoSalvaguarda.new()
	s.passou = true
	s.d20 = 12
	s.modificador = 5
	s.total = 17
	s.cd = 10
	linha = LogCombate.salvaguarda("Jogador", Enums.Atributo.FOR, s)
	print(linha)
	_conferir("salvaguarda: Fez Salvaguarda de Força", linha.contains("Fez Salvaguarda de Força -> Tirou 12 (17 no total) (1d20 + 5)"))
	_conferir("salvaguarda: ND 10", linha.ends_with("(ND 10)"))
	print("Log: %d/%d verificacoes OK" % [_ok, _total])


## Teste manual da economia de ações (GDD v3.1). Chame TesteDeck.rodar_acoes() no _ready.
static func rodar_acoes() -> void:
	_ok = 0
	_total = 0
	var por_nivel := {1: 1, 4: 1, 5: 2, 9: 2, 10: 3, 14: 3, 15: 4, 20: 4}
	for nivel in por_nivel:
		GameManager.nivel = nivel
		_conferir("nivel %d = %d acao(oes)" % [nivel, por_nivel[nivel]], GameManager.acoes_por_turno() == por_nivel[nivel])
	GameManager.nivel = 1
	var bonus := ["guerreiro/escudo_madeira", "guerreiro/grito_guerra", "mago/armadura_arcana",
		"mago/escudo_arcano", "mago/foco_mental", "guerreiro/segundo_folego", "mago/recuperacao_arcana"]
	var acao := ["guerreiro/espada", "guerreiro/golpe_pesado", "guerreiro/investida", "mago/misseis_magicos",
		"mago/orbe_fogo", "mago/raio_gelo", "mago/toque_chocante", "mago/explosao_psiquica", "mago/teia"]
	for caminho in bonus:
		var c: CardData = load("res://data/cartas/%s.tres" % caminho)
		_conferir("%s usa acao bonus" % caminho, c.tipo_acao == Enums.TipoAcao.ACAO_BONUS)
	for caminho in acao:
		var c: CardData = load("res://data/cartas/%s.tres" % caminho)
		_conferir("%s usa acao" % caminho, c.tipo_acao == Enums.TipoAcao.ACAO)
	print("Acoes: %d/%d verificacoes OK" % [_ok, _total])
