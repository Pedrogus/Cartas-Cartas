class_name ResultadoSalvaguarda
extends RefCounted
## ResultadoSalvaguarda (saída do SavingThrowResolver). Só guarda o que aconteceu.

var passou: bool = false          # true = a salvaguarda foi bem-sucedida (quem salva)
var d20: int = 0
var total: int = 0                # d20 + modificador do atributo
var cd: int = 0                   # dificuldade enfrentada
var vantagem: bool = false        # o d20 foi rolado com vantagem
var dano_bruto: int = 0           # dano rolado, antes de metade/resistência
var dano_final: int = 0           # depois de metade e fraqueza/resistência
var turnos_perdidos: int = 0      # Teia: turnos que o inimigo perde (0 se passou)


func resumo() -> String:
	var texto := "%s (d20 %d, total %d vs CD %d%s)" % [
		"PASSOU" if passou else "FALHOU", d20, total, cd, ", vantagem" if vantagem else ""]
	if dano_bruto > 0:
		texto += " | dano %d (bruto %d)" % [dano_final, dano_bruto]
	if turnos_perdidos > 0:
		texto += " | perde %d turnos" % turnos_perdidos
	return texto
