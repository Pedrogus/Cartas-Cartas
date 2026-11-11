class_name ResultadoAtaque
extends RefCounted
## ResultadoAtaque (saída do AttackResolver). Só guarda o que aconteceu.
## Quem usa: CombatManager (aplica o dano) e a interface (mostra a rolagem).

var acertou: bool = false
var critico: bool = false
var acerto_automatico: bool = false   # Mísseis: sem d20, sem crítico
var d20: int = 0                      # valor natural rolado
var total_acerto: int = 0             # d20 + bônus (comparado com a CA)
var dano_principal: int = 0           # dano da carta antes de fraqueza/resistência, sem o dado extra
var rerrolou: bool = false            # o d20 foi rerrolado (Escudo Arcano)
var dano_bruto: int = 0               # antes de fraqueza/resistência
var dano_final: int = 0               # depois de fraqueza/resistência (mínimo 0)
var tipo_dano: Enums.TipoDano = Enums.TipoDano.CORTANTE


## Texto curto para depuração e para o log de combate.
func resumo() -> String:
	if not acertou:
		return "ERROU (d20 %d, total %d)" % [d20, total_acerto]
	var origem := "automático" if acerto_automatico else "d20 %d, total %d" % [d20, total_acerto]
	var crit := " CRÍTICO" if critico else ""
	return "ACERTOU%s (%s) dano %d (bruto %d) %s" % [crit, origem, dano_final, dano_bruto, Enums.TipoDano.keys()[tipo_dano]]
