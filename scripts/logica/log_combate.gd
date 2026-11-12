class_name LogCombate
extends RefCounted
## LogCombate (sem autoload). Só monta as LINHAS do log de combate (texto com BBCode).
## Formato: "Jogador -> Utilizou ESPADA -> Tirou 12 (17 no total) (1d20 + 2 + 3) - ACERTOU (CA 10)".
## O nome da carta é o ID em maiúsculas. Não conhece o CombatManager nem a interface.

const COR_ACERTO := "#7CE38B"
const COR_ERRO := "#FF8080"
const NOMES_ATRIBUTO := {
	Enums.Atributo.FOR: "Força",
	Enums.Atributo.DES: "Destreza",
	Enums.Atributo.CON: "Constituição",
	Enums.Atributo.INT: "Inteligência",
	Enums.Atributo.SAB: "Sabedoria",
	Enums.Atributo.CAR: "Carisma",
}

## Carta sem rolagem (escudo, cura...) ou o início de uma carta com salvaguarda.
static func usou(ator: String, carta: CardData) -> String:
	return "%s -> Utilizou %s" % [ator, carta.id.to_upper()]


## Carta de ataque (d20 contra a CA). Sai em uma linha só.
static func ataque(ator: String, carta: CardData, r: ResultadoAtaque) -> String:
	var texto := usou(ator, carta)
	if r.acerto_automatico:
		return texto + " -> " + _resultado(true, "ACERTO AUTOMÁTICO", "")
	texto += " -> Tirou %d" % r.d20
	if r.critico:
		texto += " CRÍTICO"
	texto += " (%d no total) (%s)" % [r.total_acerto, _formula_d20(r)]
	if r.rerrolou:
		texto += " [rerrolado]"
	return texto + " - " + _resultado(r.acertou, "ACERTOU" if r.acertou else "ERROU", "CA %d" % r.ca_alvo)


## Linha do dano de um ataque que acertou.
static func dano_ataque(r: ResultadoAtaque) -> String:
	return _linha_dano(r.dano_principal, r.dano_final, r.tipo_dano, r.formula_dano)


## Salvaguarda feita por 'ator' (quem salva). ACERTOU = passou na salvaguarda.
static func salvaguarda(ator: String, atributo: Enums.Atributo, r: ResultadoSalvaguarda) -> String:
	var formula := "1d20 vantagem" if r.vantagem else "1d20"
	formula += _soma(r.modificador)
	var texto := "%s -> Fez Salvaguarda de %s -> Tirou %d (%d no total) (%s)" % [
		ator, NOMES_ATRIBUTO.get(atributo, "?"), r.d20, r.total, formula]
	return texto + " - " + _resultado(r.passou, "PASSOU" if r.passou else "FALHOU", "ND %d" % r.cd)


## Linha do dano de uma carta com salvaguarda.
static func dano_salvaguarda(r: ResultadoSalvaguarda, tipo: Enums.TipoDano) -> String:
	return _linha_dano(r.dano_bruto, r.dano_final, tipo, r.formula_dano)


# --- internas ---

static func _formula_d20(r: ResultadoAtaque) -> String:
	var texto := "1d20 vantagem" if r.vantagem else "1d20"
	texto += _soma(r.bonus_proficiencia) + _soma(r.bonus_atributo)
	if r.bonus_extra != 0:
		texto += _soma(r.bonus_extra)
	return texto


## " + 3" ou " - 1".
static func _soma(valor: int) -> String:
	return " + %d" % valor if valor >= 0 else " - %d" % absi(valor)


static func _resultado(bom: bool, palavra: String, extra: String) -> String:
	var cor := COR_ACERTO if bom else COR_ERRO
	var texto := "[color=%s]%s[/color]" % [cor, palavra]
	if extra != "":
		texto += " (%s)" % extra
	return texto


static func _linha_dano(bruto: int, final: int, tipo: Enums.TipoDano, formula: String) -> String:
	var texto := "      Dano: %d %s (%s)" % [bruto, Enums.TipoDano.keys()[tipo].capitalize(), formula]
	if final != bruto:
		texto += " → %d (fraqueza/resistência/metade)" % final
	return texto
