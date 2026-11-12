class_name CombatManager
extends Node
## CombatManager. Conduz UMA fase de combate: turnos, cartas, inimigo, vitória e derrota.
## Não conhece a interface: ela escuta os sinais abaixo e chama jogar_carta / trocar_carta /
## terminar_turno. As contas vêm do AttackResolver e do SavingThrowResolver; as cartas, do DeckManager.
## Fluxo (GDD v3.1): o jogador sempre age primeiro; ações por turno (1 + 1 nos níveis 5, 10 e 15,
## máx. 4) para ataques e Teia, mais 1 ação bônus para suporte; mulligan 1 por turno e
## 5 por fase; Game Over quando mão e pilha esvaziam com o inimigo vivo.

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
var inimigo: EnemyData
var inimigo_stats: ActorStats
var deck: DeckManager
var deck_inimigo: DeckManager          # o inimigo joga cartas como o jogador (GDD v3.2)

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
var bonus_acerto_proxima: int = 0      # Grito de Guerra
var rerrolar_ate: int = 0              # Escudo Arcano: rerrola d20 de 1 ou 2 (uma vez)
var turnos_inimigo_perdidos: int = 0   # Teia do jogador no inimigo
var turnos_jogador_perdidos: int = 0   # Teia do inimigo no jogador
var inimigo_bonus_ca: Array[Dictionary] = []   # [{valor, restante}] escudos do inimigo
var inimigo_bonus_acerto_proxima: int = 0
var inimigo_rerrolar_ate: int = 0
var ouro_ganho: int = 0


## Começa a fase contra o inimigo dado. O jogador vem do GameManager (HP persiste entre fases).
func iniciar(p_inimigo: EnemyData) -> void:
	jogador = GameManager.stats_jogador
	inimigo = p_inimigo
	inimigo_stats = inimigo.stats.criar_copia_combate(inimigo.stats.nivel)
	deck_inimigo = DeckManager.new()
	deck_inimigo.iniciar_fase(inimigo.montar_deck_com_tier())
	deck = DeckManager.new()
	deck.iniciar_fase(GameManager.deck_da_run)
	mulligans_fase = MULLIGANS_POR_FASE
	_log("%s aparece! (HP %d, CA %d)" % [inimigo.nome, inimigo_stats.hp_max, inimigo_stats.ca])
	EventBus.hp_alterado.emit(jogador, jogador.hp_atual, jogador.hp_max)
	EventBus.hp_alterado.emit(inimigo_stats, inimigo_stats.hp_atual, inimigo_stats.hp_max)
	_iniciar_turno_jogador()


## CA do jogador agora: base + bônus temporários das cartas.
func ca_jogador() -> int:
	var total := jogador.ca
	for b in bonus_ca:
		total += b["valor"]
	return total


## CA do inimigo agora: base + bônus temporários das cartas dele.
func ca_inimigo() -> int:
	var total := inimigo_stats.ca
	for b in inimigo_bonus_ca:
		total += b["valor"]
	return total


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
	if carta.exige_salvaguarda or not carta.causa_dano():
		_log(LogCombate.usou(NOME_JOGADOR, carta))  # ataque com d20 já se anuncia na linha da rolagem
	EventBus.carta_jogada.emit(carta, inimigo)
	if carta.exige_salvaguarda:
		_usar_salvaguarda(cn)
	elif carta.causa_dano():
		_usar_ataque(cn)
	_aplicar_efeito(cn)
	if inimigo_stats.esta_morto():
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


## Encerra o turno do jogador: o inimigo age e começa o turno seguinte.
## Se o jogador estiver preso (Teia do inimigo), o inimigo age de novo.
func terminar_turno() -> void:
	if encerrado or not turno_do_jogador:
		return
	turno_do_jogador = false
	_passar_duracao_inimigo()   # o escudo do inimigo vale até o fim do turno do jogador
	_rodar_turno_inimigo()
	if not encerrado:
		_passar_duracao_bonus()
	while not encerrado and turnos_jogador_perdidos > 0:
		turnos_jogador_perdidos -= 1
		turno += 1
		GameManager.registrar_turno()
		_log("--- Turno %d ---" % turno)
		_log("Você está preso e perde o turno!")
		_passar_duracao_inimigo()
		_rodar_turno_inimigo()
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


func _rodar_turno_inimigo() -> void:
	if turnos_inimigo_perdidos > 0:
		turnos_inimigo_perdidos -= 1
		_log("%s está preso e perde o turno!" % inimigo.nome)
		return
	_turno_inimigo()


## Turno do inimigo = turno do jogador: compra até 5, usa ação bônus (suporte) e depois a ação
## (ataque). Sem mulligan. IA simples: ver _escolher_carta_bonus e _escolher_carta_acao.
func _turno_inimigo() -> void:
	inimigo_bonus_acerto_proxima = 0
	inimigo_rerrolar_ate = 0
	_inimigo_comprar(DeckManager.TAMANHO_MAO - deck_inimigo.mao.size())
	for i in inimigo.acoes_bonus_por_turno:
		var cn := _escolher_carta_bonus()
		if cn == null:
			break
		_inimigo_jogar(cn)
		if encerrado:
			return
	for i in inimigo.acoes_por_turno:
		var cn := _escolher_carta_acao()
		if cn == null:
			break
		_inimigo_jogar(cn)
		if encerrado:
			return


## Ação bônus: cura se o HP está em 50% ou menos; buff de acerto se tem ataque na mão;
## escudo se não há um ativo; compra carta. Retorna null se nada vale a pena.
func _escolher_carta_bonus() -> CartaNoDeck:
	var hp_baixo := inimigo_stats.hp_atual * 2 <= inimigo_stats.hp_max
	var tem_ataque := false
	for cn in deck_inimigo.mao:
		if cn.carta.tipo_acao == Enums.TipoAcao.ACAO and cn.carta.causa_dano():
			tem_ataque = true
	var melhor: CartaNoDeck = null
	var melhor_pontos := 0
	for cn in deck_inimigo.mao:
		var c := cn.carta
		if c.tipo_acao != Enums.TipoAcao.ACAO_BONUS:
			continue
		var pontos := 0
		match c.efeito:
			Enums.Efeito.CURAR_DADO:
				if inimigo_stats.hp_atual < inimigo_stats.hp_max:
					pontos = 10 if hp_baixo else 3
			Enums.Efeito.BONUS_ACERTO_PROXIMA:
				if tem_ataque and inimigo_bonus_acerto_proxima == 0:
					pontos = 6
			Enums.Efeito.BONUS_CA, Enums.Efeito.BONUS_CA_E_REROLAR:
				if inimigo_bonus_ca.is_empty():
					pontos = 7 if hp_baixo else 5
			Enums.Efeito.COMPRAR_CARTAS:
				pontos = 3
		if pontos > melhor_pontos:
			melhor_pontos = pontos
			melhor = cn
	return melhor


## Ação: o ataque com maior dano médio; sem ataque, Teia (se o jogador ainda não está preso).
func _escolher_carta_acao() -> CartaNoDeck:
	var melhor: CartaNoDeck = null
	var melhor_media := -1.0
	var teia: CartaNoDeck = null
	for cn in deck_inimigo.mao:
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


func _inimigo_jogar(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	deck_inimigo.jogar_carta(cn)
	if carta.exige_salvaguarda:
		_log(LogCombate.usou(inimigo.nome, carta))
		_inimigo_salvaguarda(cn)
	elif carta.causa_dano():
		_inimigo_ataque(cn)
	else:
		_log(LogCombate.usou(inimigo.nome, carta))
	_inimigo_efeito(cn)
	combate_atualizado.emit()


func _mods_inimigo(cn: CartaNoDeck) -> ModificadoresAtaque:
	var m := ModificadoresAtaque.new()
	m.tier = cn.tier
	m.bonus_acerto = inimigo_bonus_acerto_proxima
	m.rerrolar_ate = inimigo_rerrolar_ate
	return m


func _inimigo_ataque(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var r := AttackResolver.atacar_com_carta(carta, inimigo_stats, null, ca_jogador(), _mods_inimigo(cn))
	if not carta.acerto_automatico:
		inimigo_bonus_acerto_proxima = 0
	if r.rerrolou:
		inimigo_rerrolar_ate = 0
	_log(LogCombate.ataque(inimigo.nome, carta, r))
	if not r.acertou:
		return
	_log(LogCombate.dano_ataque(r))
	_causar_dano_no_jogador(r.dano_final, carta.tipo_dano, r.critico)
	if carta.efeito == Enums.Efeito.COMPRAR_SE_DADO_PAR and r.dano_principal % 2 == 0 and not encerrado:
		_inimigo_comprar(carta.valor)


func _inimigo_salvaguarda(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var r := SavingThrowResolver.salvaguarda_do_jogador_contra_carta(carta, inimigo_stats, jogador, _mods_inimigo(cn))
	_log(LogCombate.salvaguarda(NOME_JOGADOR, carta.atributo_salvaguarda, r))
	if r.dano_bruto > 0:
		_log(LogCombate.dano_salvaguarda(r, carta.tipo_dano))
	if r.dano_final > 0:
		_causar_dano_no_jogador(r.dano_final, carta.tipo_dano, false)
	if r.turnos_perdidos > 0 and not encerrado:
		turnos_jogador_perdidos += r.turnos_perdidos
		_log("Você perderá %d turno(s)!" % r.turnos_perdidos)


## Efeitos do inimigo que não são dano (o dano e a Teia já foram tratados acima).
func _inimigo_efeito(cn: CartaNoDeck) -> void:
	if encerrado:
		return
	var carta := cn.carta
	match carta.efeito:
		Enums.Efeito.BONUS_CA, Enums.Efeito.BONUS_CA_E_REROLAR:
			var ca_extra := carta.valor + floori(cn.tier / 3.0)
			inimigo_bonus_ca.append({"valor": ca_extra, "restante": carta.duracao_turnos})
			_log("%s ganha +%d de CA por %d turno(s)." % [inimigo.nome, ca_extra, carta.duracao_turnos])
			if carta.efeito == Enums.Efeito.BONUS_CA_E_REROLAR:
				inimigo_rerrolar_ate = 2
		Enums.Efeito.BONUS_ACERTO_PROXIMA:
			inimigo_bonus_acerto_proxima += carta.valor + floori(cn.tier / 4.0)
			_log("%s ganha +%d no d20 do próximo ataque." % [inimigo.nome, inimigo_bonus_acerto_proxima])
		Enums.Efeito.COMPRAR_CARTAS:
			_inimigo_comprar(carta.valor)
		Enums.Efeito.CURAR_DADO:
			var dado := DiceRoller.rolar(1, carta.valor)
			var cura := dado + inimigo_stats.nivel + cn.tier
			var antes := inimigo_stats.hp_atual
			inimigo_stats.curar(cura)
			_log("%s se cura: d%d (%d) + nível %d + tier %d (HP %d → %d)." % [inimigo.nome, carta.valor,
				dado, inimigo_stats.nivel, cn.tier, antes, inimigo_stats.hp_atual])
			EventBus.hp_alterado.emit(inimigo_stats, inimigo_stats.hp_atual, inimigo_stats.hp_max)
		Enums.Efeito.RECUPERAR_DESCARTE:
			var qtd := ceili(inimigo_stats.nivel / float(carta.valor))
			deck_inimigo.recuperar_do_descarte(qtd, cn)


## Compra para o inimigo. Se a pilha acabar, o descarte é embaralhado de volta (o inimigo
## nunca fica sem cartas; esvaziar o baralho dele não é atalho para vencer).
func _inimigo_comprar(qtd: int) -> void:
	if qtd <= 0:
		return
	var faltam := qtd - deck_inimigo.comprar(qtd)
	if faltam > 0 and not deck_inimigo.descarte.is_empty():
		deck_inimigo.reciclar_descarte()
		_log("%s embaralha o descarte de volta ao baralho." % inimigo.nome)
		deck_inimigo.comprar(faltam)


func _causar_dano_no_jogador(valor: int, tipo: Enums.TipoDano, critico: bool) -> void:
	jogador.receber_dano(valor)
	EventBus.dano_causado.emit(jogador, valor, tipo, critico)
	EventBus.hp_alterado.emit(jogador, jogador.hp_atual, jogador.hp_max)
	if jogador.esta_morto():
		_derrota("hp_zero")


func _passar_duracao_inimigo() -> void:
	for i in range(inimigo_bonus_ca.size() - 1, -1, -1):
		inimigo_bonus_ca[i]["restante"] -= 1
		if inimigo_bonus_ca[i]["restante"] <= 0:
			inimigo_bonus_ca.remove_at(i)


func _passar_duracao_bonus() -> void:
	for i in range(bonus_ca.size() - 1, -1, -1):
		bonus_ca[i]["restante"] -= 1
		if bonus_ca[i]["restante"] <= 0:
			bonus_ca.remove_at(i)


# --- cartas ---

func _montar_mods(cn: CartaNoDeck) -> ModificadoresAtaque:
	var m := ModificadoresAtaque.new()
	m.tier = cn.tier
	m.bonus_acerto = bonus_acerto_proxima
	m.rerrolar_ate = rerrolar_ate
	return m


func _usar_ataque(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var r := AttackResolver.atacar_com_carta(carta, jogador, inimigo, ca_inimigo(), _montar_mods(cn))
	if not carta.acerto_automatico:
		bonus_acerto_proxima = 0  # o Grito de Guerra vale para um ataque só
	if r.rerrolou:
		rerrolar_ate = 0          # o Escudo Arcano rerrola uma vez
	_log(LogCombate.ataque(NOME_JOGADOR, carta, r))
	if not r.acertou:
		return
	_log(LogCombate.dano_ataque(r))
	_causar_dano_no_inimigo(r.dano_final, carta.tipo_dano, r.critico)
	if carta.efeito == Enums.Efeito.COMPRAR_SE_DADO_PAR and r.dano_principal % 2 == 0:
		var comprou := deck.comprar(carta.valor)
		if comprou > 0:
			_log("Dado par! Você compra %d carta(s)." % comprou)


func _usar_salvaguarda(cn: CartaNoDeck) -> void:
	var carta := cn.carta
	var r := SavingThrowResolver.salvaguarda_do_inimigo(carta, jogador, inimigo, _montar_mods(cn))
	_log(LogCombate.salvaguarda(inimigo.nome, carta.atributo_salvaguarda, r))
	if r.dano_bruto > 0:
		_log(LogCombate.dano_salvaguarda(r, carta.tipo_dano))
	if r.dano_final > 0:
		_causar_dano_no_inimigo(r.dano_final, carta.tipo_dano, false)
	if r.turnos_perdidos > 0:
		turnos_inimigo_perdidos += r.turnos_perdidos
		_log("%s perderá %d turno(s)!" % [inimigo.nome, r.turnos_perdidos])


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
			var acerto_extra := carta.valor + floori(cn.tier / 4.0)  # Grito: +1 a cada 4 tiers
			bonus_acerto_proxima += acerto_extra
			_log("+%d no d20 da próxima carta de ataque." % acerto_extra)
		Enums.Efeito.MULLIGAN_EXTRA:
			mulligans_extras += carta.valor
			_log("Você pode trocar até %d carta(s) sem gastar o limite." % carta.valor)
		Enums.Efeito.COMPRAR_CARTAS:
			deck.comprar(carta.valor)
		Enums.Efeito.CURAR_DADO:
			var dado := DiceRoller.rolar(1, carta.valor)
			var cura := dado + GameManager.nivel + cn.tier  # 1d(valor) + nível + tier
			var antes := jogador.hp_atual
			jogador.curar(cura)
			_log("Você se cura: d%d (%d) + nível %d + tier %d = %d (HP %d → %d)." % [carta.valor,
				dado, GameManager.nivel, cn.tier, cura, antes, jogador.hp_atual])
			EventBus.hp_alterado.emit(jogador, jogador.hp_atual, jogador.hp_max)
		Enums.Efeito.RECUPERAR_DESCARTE:
			var qtd := ceili(GameManager.nivel / float(carta.valor))  # metade do nível, para cima
			var voltou := deck.recuperar_do_descarte(qtd, cn)
			_log("Recuperação Arcana: %d carta(s) voltam à pilha, embaralhada." % voltou)
		_:
			pass


func _causar_dano_no_inimigo(valor: int, tipo: Enums.TipoDano, critico: bool) -> void:
	inimigo_stats.receber_dano(valor)
	EventBus.dano_causado.emit(inimigo_stats, valor, tipo, critico)
	EventBus.hp_alterado.emit(inimigo_stats, inimigo_stats.hp_atual, inimigo_stats.hp_max)


# --- fim do combate ---

func _vitoria() -> void:
	encerrado = true
	turno_do_jogador = false
	ouro_ganho = OURO_BASE_FASE + floori(jogador.hp_atual / 10.0) \
		+ maxi(BONUS_TURNOS_BASE - GameManager.turnos_contados, 0)
	GameManager.adicionar_ouro(ouro_ganho)
	_log("%s foi derrotado! +%d PO." % [inimigo.nome, ouro_ganho])
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
