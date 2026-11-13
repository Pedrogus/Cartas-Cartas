class_name AttackResolver
extends RefCounted
## AttackResolver (sem autoload). Funções estáticas: recebem números, devolvem ResultadoAtaque.
## Não lê GameManager nem emite sinais: quem aplica o dano e avisa o EventBus é o CombatManager.
## Acerto: d20 + bônus >= CA. Natural 20 = acerta e crítico (dobra os DADOS). Natural 1 = erra.


## Ataque do jogador com uma carta de dano por acerto (d20 vs CA).
## Cartas com salvaguarda (Bola de Fogo, Teia) NÃO passam por aqui: ver SavingThrowResolver (4d).
## 'alvo' é o EnemyData quando o jogador ataca (fraqueza/resistência). Quando o INIMIGO ataca
## o jogador, passe null: o jogador não tem fraqueza nem resistência.
static func atacar_com_carta(carta: CardData, atacante: ActorStats, alvo: EnemyData, ca_alvo: int, mods: ModificadoresAtaque) -> ResultadoAtaque:
	var r := ResultadoAtaque.new()
	r.tipo_dano = carta.tipo_dano
	r.ca_alvo = ca_alvo
	if not carta.causa_dano() or carta.exige_salvaguarda:
		return r

	if carta.acerto_automatico:
		r.acertou = true
		r.acerto_automatico = true
	else:
		r.bonus_proficiencia = atacante.bonus_proficiencia()
		r.bonus_atributo = atacante.modificador(carta.atributo_usado)
		r.bonus_extra = mods.bonus_acerto - carta.penalidade_acerto
		if Enums.eh_fisico(carta.tipo_dano):
			r.bonus_extra += _bonus_acerto_tier(mods.tier)
		var bonus := r.bonus_proficiencia + r.bonus_atributo + r.bonus_extra
		r.vantagem = mods.vantagem and not mods.desvantagem
		r.d20 = _rolar_d20(mods.vantagem, mods.desvantagem)
		if mods.rerrolar_ate > 0 and r.d20 <= mods.rerrolar_ate:
			r.d20 = DiceRoller.d20()
			r.rerrolou = true
		r.total_acerto = r.d20 + bonus
		r.critico = r.d20 == 20
		r.acertou = r.critico or (r.d20 != 1 and r.total_acerto >= ca_alvo)

	if not r.acertou:
		return r

	# Carta em área: o dano é rolado uma vez para todos (mods.dano_rolado); o crítico rola o seu.
	var principal := mods.dano_rolado if (mods.dano_rolado >= 0 and not r.critico) else rolar_dano(carta, atacante, mods, r.critico)
	r.dano_principal = principal
	var extra := _rolar_dano_extra(mods, r.critico)
	r.dano_bruto = principal + extra
	r.formula_dano = formula_dano(carta, atacante, mods, r.critico)
	var mult_principal := alvo.multiplicador_dano(carta.tipo_dano) if alvo != null else 1.0
	var mult_extra := alvo.multiplicador_dano(mods.tipo_dano_extra) if alvo != null else 1.0
	r.dano_final = floori(principal * mult_principal) + floori(extra * mult_extra)
	# Quem toma dano de um acerto toma no mínimo 1 (só a imunidade, multiplicador 0, zera).
	if r.dano_final < 1 and r.dano_bruto > 0 and (mult_principal > 0.0 or (extra > 0 and mult_extra > 0.0)):
		r.dano_final = 1
	return r


## Rola só o dano da carta (sem fraqueza/resistência). Também usada pela 4d (Bola de Fogo).
static func rolar_dano(carta: CardData, atacante: ActorStats, mods: ModificadoresAtaque, critico: bool) -> int:
	var total := DiceRoller.rolar(_qtd_dados(carta, mods, critico), carta.faces_dado)
	total += _bonus_fixo_dano(carta, atacante, mods)
	return maxi(total, 0)


## Texto da conta do dano para o log: "1d6 + 3", "2d4", "4d4 - 1" (crítico dobra os dados).
static func formula_dano(carta: CardData, atacante: ActorStats, mods: ModificadoresAtaque, critico: bool) -> String:
	var texto := "%dd%d" % [_qtd_dados(carta, mods, critico), carta.faces_dado]
	var fixo := _bonus_fixo_dano(carta, atacante, mods)
	if fixo > 0:
		texto += " + %d" % fixo
	elif fixo < 0:
		texto += " - %d" % absi(fixo)
	return texto


## Quantidade de dardos de uma carta DIVIDIDA (Mísseis Mágicos): os dados da carta viram dardos.
static func qtd_dardos(carta: CardData, mods: ModificadoresAtaque) -> int:
	return _qtd_dados(carta, mods, false)


## Dano de UM dardo: 1 dado da carta + bônus fixo. Acerto automático.
static func dano_dardo(carta: CardData, atacante: ActorStats, mods: ModificadoresAtaque) -> int:
	return maxi(DiceRoller.rolar(1, carta.faces_dado) + _bonus_fixo_dano(carta, atacante, mods), 0)


## Tier do jogador a partir do nível: 0 a 9 (sobe a cada 2 níveis).
static func tier_do_nivel(nivel: int) -> int:
	return CartaNoDeck.tier_do_nivel(nivel)


# --- internas ---

static func _qtd_dados(carta: CardData, mods: ModificadoresAtaque, critico: bool) -> int:
	var qtd := carta.qtd_dados
	if carta.nivel_magia > 0:
		qtd += floori(mods.tier / 2.0)  # espaço de magia maior: +1 dado a cada 2 tiers
	if critico:
		qtd *= 2                         # crítico dobra os dados, não o bônus fixo
	return qtd


static func _bonus_fixo_dano(carta: CardData, atacante: ActorStats, mods: ModificadoresAtaque) -> int:
	var fixo := carta.bonus_dano_fixo + mods.bonus_dano
	if carta.soma_atributo_no_dano:
		fixo += atacante.modificador(carta.atributo_usado)
	if Enums.eh_fisico(carta.tipo_dano):
		fixo += mods.tier                # físico: +1 de dano por tier
	return fixo


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
