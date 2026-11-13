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
	_conferir("deck do Guerreiro tem 23", _deck_da_classe(Enums.Classe.GUERREIRO) == 23)

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


## Teste manual dos múltiplos alvos (GDD v3.2). Chame TesteDeck.rodar_multi() no _ready.
static func rodar_multi() -> void:
	_ok = 0
	_total = 0
	DiceRoller.definir_semente(11)
	var rato: EnemyData = load("res://data/inimigos/rato_esgoto.tres")
	var esqueleto: EnemyData = load("res://data/inimigos/esqueleto_guardiao.tres")
	GameManager.nova_run(Enums.Classe.GUERREIRO)

	var par: Array[EnemyData] = [rato, rato]
	var cm := CombatManager.new()
	var linhas: Array[String] = []
	cm.log_adicionado.connect(func(t: String) -> void: linhas.append(t))
	cm.iniciar(par)
	_conferir("2 inimigos, nomes numerados", cm.inimigos.size() == 2 and cm.inimigos[0].nome.ends_with(" 1") and cm.inimigos[1].nome.ends_with(" 2"))
	_conferir("rato tem 9 de HP e CA 10", cm.inimigos[0].stats.hp_max == 9 and cm.inimigos[0].ca() == 10)
	_conferir("alvo inicial = primeiro", cm.alvo_atual == cm.inimigos[0])
	_conferir("selecionar_alvo(1) funciona", cm.selecionar_alvo(1) and cm.alvo_atual == cm.inimigos[1])
	_conferir("selecionar_alvo(5) recusa", not cm.selecionar_alvo(5))

	# TODOS (Orbe de Fogo): 1 linha de ataque por inimigo, 1 ação gasta
	cm.acoes_restantes = 5
	var orbe: CardData = load("res://data/cartas/mago/orbe_fogo.tres")
	var cn_orbe := CartaNoDeck.new(orbe, 0)
	cm.deck.mao.append(cn_orbe)
	linhas.clear()
	cm.jogar_carta(cn_orbe)
	var n_orbe := 0
	for l in linhas:
		if l.contains("Utilizou ORBE_FOGO"):
			n_orbe += 1
	print("\n".join(linhas))
	_conferir("TODOS: uma linha de ataque por inimigo", n_orbe == 2)
	_conferir("TODOS: gasta 1 ação só", cm.acoes_restantes == 4)

	# DIVIDIDO (Mísseis): 2 dardos de acerto automático, cada um causa pelo menos 1
	var cm2 := CombatManager.new()
	cm2.iniciar(par)
	cm2.acoes_restantes = 5
	var hp_antes := 0
	for e in cm2.inimigos:
		hp_antes += e.stats.hp_atual
	var misseis: CardData = load("res://data/cartas/mago/misseis_magicos.tres")
	var cn_m := CartaNoDeck.new(misseis, 0)
	cm2.deck.mao.append(cn_m)
	cm2.jogar_carta(cn_m)
	var hp_depois := 0
	for e in cm2.inimigos:
		hp_depois += e.stats.hp_atual
	var perdido := hp_antes - hp_depois
	_conferir("DIVIDIDO: 2 dardos causam entre 2 e 8 no total (%d)" % perdido, perdido >= 2 and perdido <= 8)
	_conferir("DIVIDIDO: o segundo dardo cai no outro inimigo",
		cm2.inimigos[0].stats.hp_atual < 9 and cm2.inimigos[1].stats.hp_atual < 9)

	# ordem de iniciativa: DES maior age primeiro
	var misto: Array[EnemyData] = [esqueleto, rato]
	var cm3 := CombatManager.new()
	cm3.iniciar(misto)
	var ordem := cm3.ordem_de_iniciativa()
	_conferir("iniciativa: Rato (DES 14) antes do Morto-vivo", ordem[0].data == rato and ordem[1].data == esqueleto)

	# morte do alvo passa a seleção para o próximo vivo
	cm3.alvo_atual = cm3.inimigos[0]
	cm3.inimigos[0].stats.hp_atual = 1
	cm3._causar_dano_no_inimigo(cm3.inimigos[0], 5, Enums.TipoDano.FOGO, false)
	_conferir("alvo morto: seleção vai para o próximo vivo", cm3.alvo_atual == cm3.inimigos[1] and not cm3.inimigos[0].vivo())
	_conferir("não seleciona inimigo morto", not cm3.selecionar_alvo(0))
	print("Multi: %d/%d verificacoes OK" % [_ok, _total])
	for c in [cm, cm2, cm3]:
		c.free()


## Teste manual das cartas novas e efeitos (planilha v2). Chame TesteDeck.rodar_cartas() no _ready.
static func rodar_cartas() -> void:
	_ok = 0
	_total = 0
	var mente: CardData = load("res://data/cartas/guerreiro/mente_tatica.tres")
	var folego: CardData = load("res://data/cartas/guerreiro/segundo_folego.tres")
	var surto: CardData = load("res://data/cartas/guerreiro/surto_acao.tres")
	var orbe: CardData = load("res://data/cartas/mago/orbe_fogo.tres")
	var misseis: CardData = load("res://data/cartas/mago/misseis_magicos.tres")
	var teia: CardData = load("res://data/cartas/mago/teia.tres")
	var explosao: CardData = load("res://data/cartas/mago/explosao_psiquica.tres")
	var parar: CardData = load("res://data/cartas/mago/parar_tempo.tres")
	_conferir("Mente Tatica: bonus de acerto por dado, nao e ataque", mente.efeito == Enums.Efeito.BONUS_ACERTO_PROXIMA and mente.qtd_dados == 1 and not mente.causa_dano())
	_conferir("Segundo Folego cura por dado, nao e ataque", folego.efeito == Enums.Efeito.CURAR_DADO and folego.qtd_dados == 1 and not folego.causa_dano())
	_conferir("Surto de Acao: acao bonus, ACAO_EXTRA, alvo jogador", surto.efeito == Enums.Efeito.ACAO_EXTRA and surto.tipo_acao == Enums.TipoAcao.ACAO_BONUS and surto.alvo == Enums.AlvoCarta.JOGADOR)
	_conferir("Orbe de Fogo atinge TODOS", orbe.alvo == Enums.AlvoCarta.TODOS)
	_conferir("Misseis Magicos DIVIDIDO", misseis.alvo == Enums.AlvoCarta.DIVIDIDO)
	_conferir("Teia atinge UNICO", teia.alvo == Enums.AlvoCarta.UNICO)
	_conferir("Parar o Tempo: nivel 9, todos, 0 copias", parar.nivel_magia == 9 and parar.alvo == Enums.AlvoCarta.TODOS and parar.copias_iniciais == 0)
	var pocoes := ["cura", "forca", "destreza", "constituicao", "inteligencia", "sabedoria", "carisma"]
	for nome in pocoes:
		var c: CardData = load("res://data/cartas/itens/pocao_%s.tres" % nome)
		_conferir("pocao_%s e item, bonus, jogador" % nome, c.categoria == Enums.CategoriaCarta.ITEM and c.tipo_acao == Enums.TipoAcao.ACAO_BONUS and c.alvo == Enums.AlvoCarta.JOGADOR)
	var st := ActorStats.new()
	st.forca = 10
	_conferir("FOR 10 = +0", st.modificador(Enums.Atributo.FOR) == 0)
	st.bonus_atributos[Enums.Atributo.FOR] = 2
	_conferir("bonus temporario +2 em FOR = FOR 12 (+1)", st.valor_atributo(Enums.Atributo.FOR) == 12 and st.modificador(Enums.Atributo.FOR) == 1)
	# Explosao Psiquica: salvaguarda de INT com metade do dano; ninguem toma 0 de dano
	var mago := ActorStats.new()
	mago.inteligencia = 17
	var alvo := ActorStats.new()
	var sempre_ao_menos_1 := true
	var passou_alguma_vez := false
	for i in 300:
		var r := SavingThrowResolver.salvaguarda_do_jogador_contra_carta(explosao, mago, alvo, ModificadoresAtaque.new())
		if r.passou:
			passou_alguma_vez = true
		if r.dano_final < 1:
			sempre_ao_menos_1 = false
	_conferir("Explosao Psiquica: passou na salvaguarda toma metade (>= 1)", passou_alguma_vez and sempre_ao_menos_1)
	print("Cartas: %d/%d verificacoes OK" % [_ok, _total])


## Teste manual da economia de ações (GDD v3.1). Chame TesteDeck.rodar_acoes() no _ready.
static func rodar_acoes() -> void:
	_ok = 0
	_total = 0
	var por_nivel := {1: 1, 4: 1, 5: 2, 9: 2, 10: 3, 14: 3, 15: 4, 20: 4}
	for nivel in por_nivel:
		GameManager.nivel = nivel
		_conferir("nivel %d = %d acao(oes)" % [nivel, por_nivel[nivel]], GameManager.acoes_por_turno() == por_nivel[nivel])
	GameManager.nivel = 1
	var bonus := ["guerreiro/escudo_madeira", "guerreiro/mente_tatica", "guerreiro/surto_acao", "mago/armadura_arcana",
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
