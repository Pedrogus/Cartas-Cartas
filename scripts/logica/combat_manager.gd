class_name CombatManager
extends Node
## CombatManager. Conduz UMA fase de combate: turnos, cartas, inimigos, vitória e derrota.
## Não conhece a interface: ela escuta os sinais abaixo e chama jogar_carta / trocar_carta /
## selecionar_alvo / terminar_turno. As contas vêm do AttackResolver e do SavingThrowResolver;
## as cartas, do DeckManager.
## Fluxo (GDD v3.2): o jogador sempre age primeiro; depois cada inimigo vivo age, do maior para o
## menor DES (empate: da esquerda para a direita). Ações por turno (1 + 1 nos níveis 5, 10 e 15,
## máx. 4) para ataques e Teia, mais 1 ação bônus para suporte; mulligan 1 por turno e 5 por
## fase; Game Over quando mão e pilha esvaziam com inimigos vivos. Vence quando TODOS morrem.
## Alvo da carta (CardData.alvo): ÚNICO = o inimigo selecionado; TODOS = todos os vivos (dano
## rolado uma vez, d20/salvaguarda de cada um); DIVIDIDO = dardos distribuídos a partir do alvo
## selecionado; JOGADOR = não escolhe inimigo.

signal combate_atualizado                          # a interface redesenha tudo
signal log_adicionado(texto: String)               # linha para o log de combate
signal combate_finalizado(venceu: bool, motivo: String)

const NOME_JOGADOR := "Jogador"   # nome do jogador nas linhas do log
const BONUS_POR_TURNO := 1   # ações bônus (suporte) por turno
const MULLIGANS_POR_TURNO := 1
const MULLIGANS_POR_FASE := 5
const OURO_BASE_FASE := 2
const BONUS_TURNOS_BASE := 5   # bônus de ouro = 5 menos os turnos usados (mínimo 0)

var jogador: ActorStats
var inimigos: Array[InimigoEmCombate] = []   # todos da fase; os mortos ficam na lista (esmaecidos)
var alvo_atual: InimigoEmCombate = null      # alvo das cartas de alvo ÚNICO
var deck: DeckManager

var turno: int = 0
var turno_do_jogador: bool = false
var encerrado: bool = false
var acoes_max: int = 1                 # ações do turno (GameManager.acoes_por_turno)
var acoes_restantes: int = 0
var bonus_restantes: int = 0
var mulligans_turno: int = 0
var mulligans_fase: int = 0
var mulligans_extras: int = 0          # Foco Mental: trocas que não gastam o limite
var bonus_ca: Array[Dictionary] = []   # [{valor, restante}] bônus temporários de CA
var bonus_acerto_proxima: int = 0      # Mente Tática
var rerrolar_ate: int = 0              # Escudo Arcano: rerrola d20 de 1 ou 2 (uma vez)
var turnos_jogador_perdidos: int = 0   # Teia do inimigo no jogador
var bonus_atributo_temp: Array[Dictionary] = []   # poções: [{atributo, valor, restante}]
var ouro_ganho: int = 0


## Começa a fase contra os inimigos dados. O jogador vem do GameManager (HP persiste entre fases).
## Inimigos de mesmo nome ganham número no log: "Rato Mutante 1", "Rato Mutante 2".
func iniciar(p_inimigos: Array[EnemyData]) -> void:
	jogador = GameManager.stats_jogador
	jogador.bonus_atributos.clear()   # poções de um combate anterior não passam para este
	bonus_atributo_temp.clear()
	inimigos.clear()
	var contagem := {}
	for d in p_inimigos:
		contagem[d.nome] = int(contagem.get(d.nome, 0)) + 1
	var usados := {}
	for d in p_inimigos:
		var nome := d.nome
		if contagem[d.nome] > 1:
			usados[d.nome] = int(usados.get(d.nome, 0)) + 1
			nome += " %d" % usados[d.nome]
		inimigos.append(InimigoEmCombate.criar(d, nome))
	alvo_atual = inimigos[0] if not inimigos.is_empty() else null
	deck = DeckManager.new()
	deck.iniciar_fase(GameManager.deck_da_run)
	mulligans_fase = MULLIGANS_POR_FASE
	for e in inimigos:
		_log("%s aparece! (HP %d, CA %d)" % [e.nome, e.stats.hp_max, e.stats.ca])
		EventBus.hp_alterado.emit(e.stats, e.stats.hp_atual, e.stats.hp_max)
	EventBus.hp_alterado.emit(jogador, jogador.hp_atual, jogador.hp_max)
	_iniciar_turno_jogador()


## CA do jogador agora: base + bônus temporários das cartas.
func ca_jogador() -> int:
	var total := jogador.ca
	for b in bonus_ca:
		total += b["valor"]
	return total


## Inimigos vivos, da esquerda para a direita.
func vivos() -> Array[InimigoEmCombate]:
	var lista: Array[InimigoEmCombate] = []
	for e in inimigos:
		if e.vivo():
			lista.append(e)
	return lista


## Escolhe o alvo das cartas de alvo ÚNICO (clique no inimigo). Só vale para inimigo vivo.
func selecionar_alvo(indice: int) -> bool:
	if encerrado or indice < 0 or indice >= inimigos.size() or not inimigos[indice].vivo():
		return false
	alvo_atual = inimigos[indice]
	combate_atualizado.emit()
	return true


## Ordem de ação dos inimigos vivos: maior DES primeiro; empate = da esquerda para a direita.
func ordem_de_iniciativa() -> Array[InimigoEmCombate]:
	var indices: Array[int] = []
	for i in inimigos.size():
		if inimigos[i].vivo():
			indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var da := inimigos[a].iniciativa()
		var db := inimigos[b].iniciativa()
		if da != db:
			return da > db
		return a < b)
	var ordem: Array[InimigoEmCombate] = []
	for i in indices:
		ordem.append(inimigos[i])
	return ordem


## Joga uma carta da mão. Retorna false se não puder (e explica no log).
func jogar_carta(cn: CartaNoDeck) -> bool:
	if encerrado or not turno_do_jogador or not deck.mao.has(cn):
		return false
	var carta := cn.carta
	if carta.tipo_acao == Enums.TipoAcao.ACAO_BONUS:
		if bonus_restantes <= 0:
			_log("Você já usou sua ação bônus neste turno.")
			return false
		bonus_restantes -= 1
	else:
		if acoes_restantes <= 0:
			_log("Você já usou as %d ação(ões) deste turno." % acoes_max)
			return false
		acoes_restantes -= 1
	deck.jogar_carta(cn)
	EventBus.carta_jogada.emit(carta, alvo_atual.data if alvo_atual != null else null)
	if carta.exige_salvaguarda:
		_log(LogCombate.usou(NOME_JOGADOR, carta))
		_usar_salvaguarda(cn)
	elif carta.causa_dano():
		if carta.alvo == Enums.AlvoCarta.DIVIDIDO:
			_usar_dardos(cn)
		else:
			_usar_ataque(cn)
	else:
		_log(LogCombate.usou(NOME_JOGADOR, carta))
	_aplicar_efeito(cn)
	if vivos().is_empty():
		_vitoria()
	elif deck.sem_cartas():
		_derrota("sem_cartas")
	combate_atualizado.emit()
	return true


## Mulligan: descarta a carta e compra outra. Gasta 1 troca do turno e 1 da fase,
## exceto as trocas extras do Foco Mental.
func trocar_carta(cn: CartaNoDeck) -> bool:
	if encerrado or not turno_do_jogador or not deck.mao.has(cn):
		return false
	var extra := mulligans_extras > 0
	if not extra and mulligans_turno <= 0:
		_log("Você já trocou uma carta neste turno.")
		return false
	if not extra and mulligans_fase <= 0:
		_log("Acabaram as trocas desta fase.")
		return false
	if not deck.trocar_carta(cn):
		_log("Não há cartas na pilha para trocar.")
		return false
	if extra:
		mulligans_extras -= 1
	else:
		mulligans_turno -= 1
		mulligans_fase -= 1
	_log("Você troca %s por uma carta nova." % cn.carta.nome)
	combate_atualizado.emit()
	return true


## Encerra o turno do jogador: os inimigos agem e começa o turno seguinte.
## Se o jogador estiver preso (Teia do inimigo), os inimigos agem de novo.
func terminar_turno() -> void:
	if encerrado or not turno_do_jogador:
		return
	turno_do_jogador = false
	_passar_duracao_inimigos()   # o escudo do inimigo vale até o fim do turno do jogador
	_rodar_turno_dos_inimigos()
	if not encerrado:
		_passar_duracao_bonus()
	while not encerrado and turnos_jogador_perdidos > 0:
		turnos_jogador_perdidos -= 1
		turno += 1
		GameManager.registrar_turno()
		_log("--- Turno %d ---" % turno)
		_log("Você está preso e perde o turno!")
		_passar_duracao_inimigos()
		_rodar_turno_dos_inimigos()
		if not encerrado:
			_passar_duracao_bonus()
	if encerrado:
		combate_atualizado.emit()
		return
	_iniciar_turno_jogador()


# --- turnos ---

func _iniciar_turno_jogador() -> void:
	turno += 1
	GameManager.registrar_turno()
	turno_do_jogador = true
	acoes_max = GameManager.acoes_por_turno()
	acoes_restantes = acoes_max
	bonus_restantes = BONUS_POR_TURNO
	mulligans_turno = MULLIGANS_POR_TURNO
	mulligans_extras = 0
	bonus_acerto_proxima = 0
	rerrolar_ate = 0
	if turno > 1:
		deck.comprar_ate_mao_cheia()  # cartas não jogadas ficam; compra só o que falta
	EventBus.turno_iniciado.emit(turno, "jogador")
	_log("--- Turno %d ---" % turno)
	if deck.sem_cartas():
		_derrota("sem_cartas")
	combate_atualizado.emit()


func _rodar_turno_dos_inimigos() -> void:
	for e in ordem_de_iniciativa():
		if encerrado:
			return
		if not e.vivo():
			continue
		if e.turnos_perdidos > 0:
			e.turnos_perdidos -= 1
			_log("%s está preso e perde o turno!" % e.nome)
			continue
		_turno_inimigo(e)


## Turno do inimigo = turno do jogador: compra até 5, usa ação bônus (suporte) e depois a ação
## (ataque). Sem mulligan. IA simples: ver _escolher_carta_bonus e _escolher_carta_acao.
func _turno_inimigo(e: InimigoEmCombate) -> void:
	e.bonus_acerto_proxima = 0
	e.rerrolar_ate = 0
	_inimigo_comprar(e, DeckManager.TAMANHO_MAO - e.deck.mao.size())
	for i in e.data.acoes_bonus_por_turno:
		var cn := _escolher_carta_bonus(e)
		if cn == null:
			break
		_inimigo_jogar(e, cn)
		if encerrado:
			return
	e.acoes_restantes = e.data.acoes_por_turno
	while e.acoes_restantes > 0:
		var cn := _escolher_carta_acao(e)
		if cn == null:
			break
		e.acoes_restantes -= 1
		_inimigo_jogar(e, cn)
		if encerrado:
			return


## Ação bônus: cura se o HP está em 50% ou menos; buff de acerto se tem ataque na mão;
## escudo se não há um ativo; compra carta. Retorna null se nada vale a pena.
func _escolher_carta_bonus(e: InimigoEmCombate) -> CartaNoDeck:
	var hp_baixo := e.stats.hp_atual * 2 <= e.stats.hp_max
	var tem_ataque := false
	for cn in e.deck.mao:
		if cn.carta.tipo_acao == Enums.TipoAcao.ACAO and cn.carta.causa_dano():
			tem_ataque = true
	var melhor: CartaNoDeck = null
	var melhor_pontos := 0
	for cn in e.deck.mao:
		var c := cn.carta
		if c.tipo_acao != Enums.TipoAcao.ACAO_BONUS:
			continue
		var pontos := 0
		match c.efeito:
			Enums.Efeito.CURAR_DADO:
				if e.stats.hp_atual < e.stats.hp_max:
					pontos = 10 if hp_baixo else 3
			Enums.Efeito.BONUS_ACERTO_PROXIMA:
				if tem_ataque and e.bonus_acerto_proxima == 0:
					pontos = 6
			Enums.Efeito.BONUS_CA, Enums.Efeito.BONUS_CA_E_REROLAR:
				if e.bonus_ca.is_empty():
					pontos = 7 if hp_baixo else 5
			Enums.Efeito.COMPRAR_CARTAS:
				pontos = 3
			Enums.Efeito.ACAO_EXTRA:
				if tem_ataque:
					pontos = 8
		if pontos > melhor_pontos:
			melhor_pontos = pontos
			melhor = cn
	return melhor


## Ação: o ataque com maior dano médio; sem ataque, Teia (se o jogador ainda não está preso).
func _escolher_carta_acao(e: InimigoEmCombate) -> CartaNoDeck:
	var melhor: CartaNoDeck = null
	var melhor_media := -1.0
	var teia: CartaNoDeck = null
	for cn in e.deck.mao:
		var c := cn.carta
		if c.tipo_acao != Enums.TipoAcao.ACAO:
			continue
		if c.causa_dano():
			var media := c.qtd_dados * (c.faces_dado + 1) / 2.0 + c.bonus_dano_fixo
			if media > melhor_media:
				melhor_media = media
				melhor = cn
		elif c.efeito == Enums.Efeito.INIMIGO_PERDE_TURNOS and turnos_jogador_perdidos == 0:
			teia = cn
	return melhor if melhor != null else teia


func _inimigo_jogar(e: InimigoEmCombate, cn: CartaNoDeck) -> void:
	var carta := cn.carta
	e.deck.jogar_carta(cn)
	if carta.exige_salvaguarda:
		_log(LogCombate.usou(e.nome, carta))
		_inimigo_salvaguarda(e, cn)
	elif carta.causa_dano():
		_inimigo_ataque(e, cn)
	else:
		_log(LogCombate.usou(e.nome, carta))
	_inimigo_efeito(e, cn)
	combate_atualizado.emit()


func _mods_inimigo(e: InimigoEmCombate, cn: CartaNoDeck) -> ModificadoresAtaque:
	var m := ModificadoresAtaque.new()
	m.tier = cn.tier
	m.bonus_acerto = e.bonus_acerto_proxima
	m.rerrolar_ate = e.rerrolar_ate
	return m


func _inimigo_ataque(e: InimigoEmCombate, cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var r := AttackResolver.atacar_com_carta(carta, e.stats, null, ca_jogador(), _mods_inimigo(e, cn))
	if not carta.acerto_automatico:
		e.bonus_acerto_proxima = 0
	if r.rerrolou:
		e.rerrolar_ate = 0
	_log(LogCombate.ataque(e.nome, carta, r))
	if not r.acertou:
		return
	_log(LogCombate.dano_ataque(r))
	_causar_dano_no_jogador(r.dano_final, carta.tipo_dano, r.critico)
	if carta.efeito == Enums.Efeito.COMPRAR_SE_DADO_PAR and r.dano_principal % 2 == 0 and not encerrado:
		_inimigo_comprar(e, carta.valor)


func _inimigo_salvaguarda(e: InimigoEmCombate, cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var r := SavingThrowResolver.salvaguarda_do_jogador_contra_carta(carta, e.stats, jogador, _mods_inimigo(e, cn))
	_log(LogCombate.salvaguarda(NOME_JOGADOR, carta.atributo_salvaguarda, r))
	if r.dano_bruto > 0:
		_log(LogCombate.dano_salvaguarda(r, carta.tipo_dano))
	if r.dano_final > 0:
		_causar_dano_no_jogador(r.dano_final, carta.tipo_dano, false)
	if r.turnos_perdidos > 0 and not encerrado:
		turnos_jogador_perdidos += r.turnos_perdidos
		_log("Você perderá %d turno(s)!" % r.turnos_perdidos)


## Efeitos do inimigo que não são dano (o dano e a Teia já foram tratados acima).
func _inimigo_efeito(e: InimigoEmCombate, cn: CartaNoDeck) -> void:
	if encerrado:
		return
	var carta := cn.carta
	match carta.efeito:
		Enums.Efeito.BONUS_CA, Enums.Efeito.BONUS_CA_E_REROLAR:
			var ca_extra := carta.valor + floori(cn.tier / 3.0)
			e.bonus_ca.append({"valor": ca_extra, "restante": carta.duracao_turnos})
			_log("%s ganha +%d de CA por %d turno(s)." % [e.nome, ca_extra, carta.duracao_turnos])
			if carta.efeito == Enums.Efeito.BONUS_CA_E_REROLAR:
				e.rerrolar_ate = 2
		Enums.Efeito.BONUS_ACERTO_PROXIMA:
			var acerto := carta.valor + floori(cn.tier / 4.0) + DiceRoller.rolar(carta.qtd_dados, carta.faces_dado)
			e.bonus_acerto_proxima += acerto
			_log("%s ganha +%d no d20 do próximo ataque." % [e.nome, acerto])
		Enums.Efeito.ACAO_EXTRA:
			e.acoes_restantes += carta.valor
			_log("%s ganha %d ação extra." % [e.nome, carta.valor])
		Enums.Efeito.COMPRAR_CARTAS:
			_inimigo_comprar(e, carta.valor)
		Enums.Efeito.CURAR_DADO:
			var dado := DiceRoller.rolar(carta.qtd_dados, carta.faces_dado)
			var extra := carta.bonus_dano_fixo
			if carta.categoria != Enums.CategoriaCarta.ITEM:
				extra += e.stats.nivel + cn.tier   # habilidade de classe: soma nível e tier
			var cura := dado + extra
			var antes := e.stats.hp_atual
			e.stats.curar(cura)
			_log("%s se cura: %dd%d (%d) + %d = %d (HP %d → %d)." % [e.nome, carta.qtd_dados, carta.faces_dado,
				dado, extra, cura, antes, e.stats.hp_atual])
			EventBus.hp_alterado.emit(e.stats, e.stats.hp_atual, e.stats.hp_max)
		Enums.Efeito.RECUPERAR_DESCARTE:
			var qtd := ceili(e.stats.nivel / float(carta.valor))
			e.deck.recuperar_do_descarte(qtd, cn)


## Compra para o inimigo. Se a pilha acabar, o descarte é embaralhado de volta (o inimigo
## nunca fica sem cartas; esvaziar o baralho dele não é atalho para vencer).
func _inimigo_comprar(e: InimigoEmCombate, qtd: int) -> void:
	if qtd <= 0:
		return
	var faltam := qtd - e.deck.comprar(qtd)
	if faltam > 0 and not e.deck.descarte.is_empty():
		e.deck.reciclar_descarte()
		_log("%s embaralha o descarte de volta ao baralho." % e.nome)
		e.deck.comprar(faltam)


func _causar_dano_no_jogador(valor: int, tipo: Enums.TipoDano, critico: bool) -> void:
	jogador.receber_dano(valor)
	EventBus.dano_causado.emit(jogador, valor, tipo, critico)
	EventBus.hp_alterado.emit(jogador, jogador.hp_atual, jogador.hp_max)
	if jogador.esta_morto():
		_derrota("hp_zero")


func _passar_duracao_inimigos() -> void:
	for e in inimigos:
		e.passar_duracao()


func _passar_duracao_bonus() -> void:
	for i in range(bonus_ca.size() - 1, -1, -1):
		bonus_ca[i]["restante"] -= 1
		if bonus_ca[i]["restante"] <= 0:
			bonus_ca.remove_at(i)
	for i in range(bonus_atributo_temp.size() - 1, -1, -1):
		bonus_atributo_temp[i]["restante"] -= 1
		if bonus_atributo_temp[i]["restante"] <= 0:
			var b: Dictionary = bonus_atributo_temp[i]
			jogador.bonus_atributos[b["atributo"]] = int(jogador.bonus_atributos.get(b["atributo"], 0)) - int(b["valor"])
			_log("O efeito da poção de %s acabou." % Enums.Atributo.keys()[b["atributo"]])
			bonus_atributo_temp.remove_at(i)


# --- cartas ---

func _montar_mods(cn: CartaNoDeck) -> ModificadoresAtaque:
	var m := ModificadoresAtaque.new()
	m.tier = cn.tier
	m.bonus_acerto = bonus_acerto_proxima
	m.rerrolar_ate = rerrolar_ate
	return m


## Inimigos atingidos pela carta: ÚNICO e DIVIDIDO = o alvo selecionado; TODOS = todos os vivos;
## JOGADOR = nenhum (a carta é sobre o próprio jogador).
func _alvos_da_carta(carta: CardData) -> Array[InimigoEmCombate]:
	var lista: Array[InimigoEmCombate] = []
	match carta.alvo:
		Enums.AlvoCarta.TODOS:
			lista = vivos()
		Enums.AlvoCarta.JOGADOR:
			pass
		_:
			if alvo_atual != null and alvo_atual.vivo():
				lista.append(alvo_atual)
	return lista


## Cartas em área rolam o dano UMA vez para todos os alvos (-1 = cada alvo rola o seu).
func _dano_comum(cn: CartaNoDeck, alvos: Array[InimigoEmCombate]) -> int:
	if alvos.size() > 1 and cn.carta.causa_dano():
		return AttackResolver.rolar_dano(cn.carta, jogador, _montar_mods(cn), false)
	return -1


func _usar_ataque(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var alvos := _alvos_da_carta(carta)
	var dano_rolado := _dano_comum(cn, alvos)
	var comprou_par := false
	for alvo in alvos:
		var m := _montar_mods(cn)
		m.dano_rolado = dano_rolado
		var r := AttackResolver.atacar_com_carta(carta, jogador, alvo.data, alvo.ca(), m)
		if r.rerrolou:
			rerrolar_ate = 0          # o Escudo Arcano rerrola uma vez
		_log(LogCombate.ataque(NOME_JOGADOR, carta, r, alvo.nome))
		if not r.acertou:
			continue
		_log(LogCombate.dano_ataque(r))
		_causar_dano_no_inimigo(alvo, r.dano_final, carta.tipo_dano, r.critico)
		if carta.efeito == Enums.Efeito.COMPRAR_SE_DADO_PAR and r.dano_principal % 2 == 0 and not comprou_par:
			comprou_par = true
			var comprou := deck.comprar(carta.valor)
			if comprou > 0:
				_log("Dado par! Você compra %d carta(s)." % comprou)
	if not carta.acerto_automatico:
		bonus_acerto_proxima = 0  # a Mente Tática vale para uma carta de ataque só


## Carta DIVIDIDA (Mísseis Mágicos): os dados viram dardos de acerto automático. O primeiro vai
## no alvo selecionado e os outros passam pelos inimigos vivos, em ordem, voltando ao começo.
## Cada dardo respeita fraqueza/resistência e causa no mínimo 1 (exceto contra imunidade).
func _usar_dardos(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var m := _montar_mods(cn)
	var qtd := AttackResolver.qtd_dardos(carta, m)
	var inicio := maxi(vivos().find(alvo_atual), 0)
	_log("%s -> Utilizou %s -> %d dardo(s), acerto automático" % [NOME_JOGADOR, carta.id.to_upper(), qtd])
	for i in qtd:
		var vivos_agora := vivos()
		if vivos_agora.is_empty():
			break
		var alvo := vivos_agora[(inicio + i) % vivos_agora.size()]
		var bruto := AttackResolver.dano_dardo(carta, jogador, m)
		var mult := alvo.data.multiplicador_dano(carta.tipo_dano)
		var final := floori(bruto * mult)
		if final < 1 and bruto > 0 and mult > 0.0:
			final = 1
		_log("      Dardo %d → %s: %d %s%s" % [i + 1, alvo.nome, bruto, _nome_tipo(carta.tipo_dano),
			(" → %d (fraqueza/resistência)" % final) if final != bruto else ""])
		_causar_dano_no_inimigo(alvo, final, carta.tipo_dano, false)


func _usar_salvaguarda(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var alvos := _alvos_da_carta(carta)
	var dano_rolado := _dano_comum(cn, alvos)
	for alvo in alvos:
		var m := _montar_mods(cn)
		m.dano_rolado = dano_rolado
		var r := SavingThrowResolver.salvaguarda_do_inimigo(carta, jogador, alvo.data, m)
		_log(LogCombate.salvaguarda(alvo.nome, carta.atributo_salvaguarda, r))
		if r.dano_bruto > 0:
			_log(LogCombate.dano_salvaguarda(r, carta.tipo_dano))
		if r.dano_final > 0:
			_causar_dano_no_inimigo(alvo, r.dano_final, carta.tipo_dano, false)
		if r.turnos_perdidos > 0:
			alvo.turnos_perdidos += r.turnos_perdidos
			_log("%s perderá %d turno(s)!" % [alvo.nome, r.turnos_perdidos])


static func _nome_tipo(tipo: Enums.TipoDano) -> String:
	return Enums.TipoDano.keys()[tipo].capitalize()


## Efeitos que não são dano (o dano e a Teia já foram tratados acima).
func _aplicar_efeito(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	match carta.efeito:
		Enums.Efeito.BONUS_CA, Enums.Efeito.BONUS_CA_E_REROLAR:
			var ca_extra := carta.valor + floori(cn.tier / 3.0)  # escudos: +1 CA a cada 3 tiers
			bonus_ca.append({"valor": ca_extra, "restante": carta.duracao_turnos})
			_log("+%d de CA por %d turno(s)." % [ca_extra, carta.duracao_turnos])
			if carta.efeito == Enums.Efeito.BONUS_CA_E_REROLAR:
				rerrolar_ate = 2
				_log("Seu próximo d20 de 1 ou 2 será rerrolado.")
		Enums.Efeito.BONUS_ACERTO_PROXIMA:
			var dado_acerto := DiceRoller.rolar(carta.qtd_dados, carta.faces_dado)   # Mente Tática: 1d10
			var acerto_extra := carta.valor + floori(cn.tier / 4.0) + dado_acerto
			bonus_acerto_proxima += acerto_extra
			_log("+%d no d20 da próxima carta de ataque." % acerto_extra)
		Enums.Efeito.MULLIGAN_EXTRA:
			mulligans_extras += carta.valor
			_log("Você pode trocar até %d carta(s) sem gastar o limite." % carta.valor)
		Enums.Efeito.COMPRAR_CARTAS:
			deck.comprar(carta.valor)
		Enums.Efeito.CURAR_DADO:
			var dado := DiceRoller.rolar(carta.qtd_dados, carta.faces_dado)
			var extra := carta.bonus_dano_fixo
			if carta.categoria != Enums.CategoriaCarta.ITEM:
				extra += GameManager.nivel + cn.tier   # habilidade de classe: soma nível e tier
			var cura := dado + extra
			var antes := jogador.hp_atual
			jogador.curar(cura)
			_log("Você se cura: %dd%d (%d) + %d = %d (HP %d → %d)." % [carta.qtd_dados, carta.faces_dado,
				dado, extra, cura, antes, jogador.hp_atual])
			EventBus.hp_alterado.emit(jogador, jogador.hp_atual, jogador.hp_max)
		Enums.Efeito.RECUPERAR_DESCARTE:
			var qtd := ceili(GameManager.nivel / float(carta.valor))  # metade do nível, para cima
			var voltou := deck.recuperar_do_descarte(qtd, cn)
			_log("Recuperação Arcana: %d carta(s) voltam à pilha, embaralhada." % voltou)
		Enums.Efeito.ACAO_EXTRA:
			acoes_restantes += carta.valor
			acoes_max += carta.valor
			_log("Você ganha %d ação extra neste turno." % carta.valor)
		Enums.Efeito.AUMENTO_ATRIBUTO:
			var atributo := carta.atributo_usado
			jogador.bonus_atributos[atributo] = int(jogador.bonus_atributos.get(atributo, 0)) + carta.valor
			bonus_atributo_temp.append({"atributo": atributo, "valor": carta.valor, "restante": carta.duracao_turnos})
			_log("+%d de %s por %d turno(s)." % [carta.valor, Enums.Atributo.keys()[atributo], carta.duracao_turnos])
		Enums.Efeito.INIMIGO_PERDE_TURNOS:
			if not carta.exige_salvaguarda:   # sem salvaguarda (Parar o Tempo): vale direto
				for alvo in _alvos_da_carta(carta):
					alvo.turnos_perdidos += carta.valor
					_log("%s perderá %d turno(s)!" % [alvo.nome, carta.valor])
		_:
			pass


func _causar_dano_no_inimigo(alvo: InimigoEmCombate, valor: int, tipo: Enums.TipoDano, critico: bool) -> void:
	alvo.stats.receber_dano(valor)
	EventBus.dano_causado.emit(alvo.stats, valor, tipo, critico)
	EventBus.hp_alterado.emit(alvo.stats, alvo.stats.hp_atual, alvo.stats.hp_max)
	if alvo.stats.esta_morto():
		_log("%s foi derrotado!" % alvo.nome)
		if alvo == alvo_atual:
			var proximos := vivos()
			alvo_atual = proximos[0] if not proximos.is_empty() else alvo   # o alvo passa ao próximo vivo


# --- fim do combate ---

func _vitoria() -> void:
	encerrado = true
	turno_do_jogador = false
	ouro_ganho = OURO_BASE_FASE + floori(jogador.hp_atual / 10.0) \
		+ maxi(BONUS_TURNOS_BASE - GameManager.turnos_contados, 0)
	GameManager.adicionar_ouro(ouro_ganho)
	_log("Todos os inimigos foram derrotados! +%d PO." % ouro_ganho)
	EventBus.combate_terminado.emit(true, GameManager.turnos_contados)
	combate_finalizado.emit(true, "")


func _derrota(motivo: String) -> void:
	encerrado = true
	turno_do_jogador = false
	_log("Você foi derrotado. (%s)" % motivo)
	EventBus.game_over.emit(motivo)
	EventBus.combate_terminado.emit(false, GameManager.turnos_contados)
	combate_finalizado.emit(false, motivo)


func _log(texto: String) -> void:
	log_adicionado.emit(texto)
