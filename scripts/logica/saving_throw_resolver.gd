class_name SavingThrowResolver
extends RefCounted
## SavingThrowResolver (sem autoload). Funções estáticas, sem estado.
## Regras do GDD v3: sem crítico nem erro automático (nat 20/1 não valem em salvaguarda).
## Passou quando d20 + modificador >= CD.

const CD_BASE := 8


## O JOGADOR usa uma carta que exige salvaguarda do inimigo (Teia, Bola de Fogo).
## CD = 8 + proficiência + modificador do atributo da carta. O inimigo rola d20 + modificador
## do atributo_salvaguarda (DES). Chefe rola com vantagem em efeitos de controle (Teia).
static func salvaguarda_do_inimigo(carta: CardData, atacante: ActorStats, alvo: EnemyData, mods: ModificadoresAtaque) -> ResultadoSalvaguarda:
	var r := ResultadoSalvaguarda.new()
	r.cd = CD_BASE + atacante.bonus_ataque(carta.atributo_usado)
	r.vantagem = alvo.eh_chefe and carta.efeito == Enums.Efeito.INIMIGO_PERDE_TURNOS
	r.d20 = DiceRoller.d20_vantagem() if r.vantagem else DiceRoller.d20()
	r.total = r.d20 + alvo.stats.modificador(carta.atributo_salvaguarda)
	r.passou = r.total >= r.cd

	if carta.causa_dano():
		r.dano_bruto = AttackResolver.rolar_dano(carta, atacante, mods, false)
		var base := r.dano_bruto
		if r.passou:
			base = floori(r.dano_bruto / 2.0) if carta.dano_metade_na_salvaguarda else 0
		r.dano_final = floori(base * alvo.multiplicador_dano(carta.tipo_dano))

	if carta.efeito == Enums.Efeito.INIMIGO_PERDE_TURNOS and not r.passou:
		r.turnos_perdidos = carta.valor
	return r


## O INIMIGO exige salvaguarda do jogador. Só d20 + atributo (sem proficiência), como no GDD.
static func salvaguarda_do_jogador(jogador: ActorStats, atributo: Enums.Atributo, cd: int) -> ResultadoSalvaguarda:
	var r := ResultadoSalvaguarda.new()
	r.cd = cd
	r.d20 = DiceRoller.d20()
	r.total = r.d20 + jogador.modificador(atributo)
	r.passou = r.total >= cd
	return r


## CD das habilidades do inimigo: 8 + proficiência + INT (vem do ActorStats).
static func cd_do_inimigo(inimigo: EnemyData) -> int:
	return inimigo.stats.cd_magia()
