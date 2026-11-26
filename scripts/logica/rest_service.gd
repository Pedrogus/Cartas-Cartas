class_name RestService
extends RefCounted
## RestService (sem autoload). Descanso curto com dados de vida (GDD v3).
## Cada dado gasto rola o dado de vida da classe + modificador de CON (mínimo 1) e cura isso.
## O jogador tem 3 dados por ciclo (GameManager.dados_vida_restantes).


## Resultado de um descanso: ok, motivo (se falhou), dado rolado, CON, cura e HP antes/depois.
static func descanso_curto() -> Dictionary:
	var r := {"ok": false, "motivo": "", "dado": 0, "con": 0, "cura": 0, "antes": 0, "depois": 0}
	var jogador := GameManager.stats_jogador
	if jogador == null:
		r["motivo"] = "Nenhuma run ativa."
		return r
	if GameManager.dados_vida_restantes <= 0:
		r["motivo"] = "Sem dados de vida neste ciclo."
		return r
	if jogador.hp_atual >= jogador.hp_max:
		r["motivo"] = "HP já está cheio."
		return r
	var faces := GameManager.dados_da_classe().dado_vida
	r["dado"] = DiceRoller.rolar(1, faces)
	r["con"] = jogador.modificador(Enums.Atributo.CON)
	r["cura"] = maxi(r["dado"] + r["con"], 1)
	r["antes"] = jogador.hp_atual
	jogador.curar(r["cura"])
	r["depois"] = jogador.hp_atual
	GameManager.dados_vida_restantes -= 1
	EventBus.hp_alterado.emit(jogador, jogador.hp_atual, jogador.hp_max)
	r["ok"] = true
	return r
