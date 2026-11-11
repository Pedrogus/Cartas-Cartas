class_name AttackResolver
extends RefCounted
## AttackResolver (sem autoload). Funções estáticas: recebem números, devolvem ResultadoAtaque.
## Não lê GameManager nem emite sinais: quem aplica o dano e avisa o EventBus é o CombatManager.
## Acerto: d20 + bônus >= CA. Natural 20 = acerta e crítico (dobra os DADOS). Natural 1 = erra.


## Ataque do jogador com uma carta de dano por acerto (d20 vs CA).
## Cartas com salvaguarda (Bola de Fogo, Teia) NÃO passam por aqui: ver SavingThrowResolver (4d).
static func atacar_com_carta(carta: CardData, atacante: ActorStats, alvo: EnemyData, ca_alvo: int, mods: ModificadoresAtaque) -> ResultadoAtaque:
	var r := ResultadoAtaque.new()
	r.tipo_dano = carta.tipo_dano
	if not carta.causa_dano() or carta.exige_salvaguarda:
		return r

	if carta.acerto_automatico:
		r.acertou = true
		r.acerto_automatico = true
	else:
		var bonus := atacante.bonus_ataque(carta.atributo_usado) + mods.bonus_acerto - carta.penalidade_acerto
		if Enums.eh_fisico(carta.tipo_dano):
			bonus += _bonus_acerto_tier(mods.tier)
		r.d20 = _rolar_d20(mods.vantagem, mods.desvantagem)
		if mods.rerrolar_ate > 0 and r.d20 <= mods.rerrolar_ate:
			r.d20 = DiceRoller.d20()
			r.rerrolou = true
		r.total_acerto = r.d20 + bonus
		r.critico = r.d20 == 20
		r.acertou = r.critico or (r.d20 != 1 and r.total_acerto >= ca_alvo)

	if not r.acertou:
		return r

	var principal := rolar_dano(carta, atacante, mods, r.critico)
	r.dano_principal = principal
	var extra := _rolar_dano_extra(mods, r.critico)
	r.dano_bruto = principal + extra
	r.dano_final = floori(principal * alvo.multiplicador_dano(carta.tipo_dano)) \
		+ floori(extra * alvo.multiplicador_dano(mods.tipo_dano_extra))
	return r


## Rola só o dano da carta (sem fraqueza/resistência). Também usada pela 4d (Bola de Fogo).
static func rolar_dano(carta: CardData, atacante: ActorStats, mods: ModificadoresAtaque, critico: bool) -> int:
	var qtd := carta.qtd_dados
	if carta.nivel_magia > 0:
		qtd += floori(mods.tier / 2.0)  # espaço de magia maior: +1 dado a cada 2 tiers
	if critico:
		qtd *= 2                         # crítico dobra os dados, não o bônus fixo
	var total := DiceRoller.rolar(qtd, carta.faces_dado)
	total += carta.bonus_dano_fixo + mods.bonus_dano
	if carta.soma_atributo_no_dano:
		total += atacante.modificador(carta.atributo_usado)
	if Enums.eh_fisico(carta.tipo_dano):
		total += mods.tier               # físico: +1 de dano por tier
	return maxi(total, 0)


## Ataque de inimigo: d20 + bônus_ataque contra a CA atual do jogador.
static func atacar_com_inimigo(inimigo: EnemyData, ca_jogador: int, vantagem: bool = false, desvantagem: bool = false) -> ResultadoAtaque:
	return rolar_ataque_simples(inimigo.bonus_ataque, inimigo.qtd_dados, inimigo.faces_dado, 0,
		inimigo.tipo_dano, ca_jogador, vantagem, desvantagem)


## Ataque só com números. Serve ao ataque comum do inimigo e, na etapa 7, a ataques especiais
## (ex.: Explosão Sombria = bônus 6, 2d6 necrótico). O jogador não tem fraqueza/resistência.
static func rolar_ataque_simples(bonus_ataque: int, qtd_dados: int, faces: int, bonus_dano: int,
		tipo: Enums.TipoDano, ca_alvo: int, vantagem: bool = false, desvantagem: bool = false) -> ResultadoAtaque:
	var r := ResultadoAtaque.new()
	r.tipo_dano = tipo
	r.d20 = _rolar_d20(vantagem, desvantagem)
	r.total_acerto = r.d20 + bonus_ataque
	r.critico = r.d20 == 20
	r.acertou = r.critico or (r.d20 != 1 and r.total_acerto >= ca_alvo)
	if r.acertou:
		var qtd := qtd_dados * 2 if r.critico else qtd_dados
		r.dano_bruto = maxi(DiceRoller.rolar(qtd, faces) + bonus_dano, 0)
		r.dano_final = r.dano_bruto
	return r


## Tier do jogador a partir do nível: 0 a 9 (sobe a cada 2 níveis).
static func tier_do_nivel(nivel: int) -> int:
	return CartaNoDeck.tier_do_nivel(nivel)


# --- internas ---

## Acerto extra das cartas físicas: +floor((tier+1)/3), máximo +3.
static func _bonus_acerto_tier(tier: int) -> int:
	return mini(floori((tier + 1) / 3.0), 3)


static func _rolar_dano_extra(mods: ModificadoresAtaque, critico: bool) -> int:
	if mods.dados_extras <= 0:
		return 0
	var qtd := mods.dados_extras * 2 if critico else mods.dados_extras
	return DiceRoller.rolar(qtd, mods.faces_dado_extra)


## Vantagem e desvantagem juntas se anulam (regra do 5e).
static func _rolar_d20(vantagem: bool, desvantagem: bool) -> int:
	if vantagem and not desvantagem:
		return DiceRoller.d20_vantagem()
	if desvantagem and not vantagem:
		return DiceRoller.d20_desvantagem()
	return DiceRoller.d20()
