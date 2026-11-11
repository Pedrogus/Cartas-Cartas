extends Node
## EventBus (autoload).
## Só declara sinais: nenhuma variável de estado, nenhuma regra de jogo.
## Quem faz algo emite o sinal; quem se importa escuta. Ninguém precisa conhecer o outro.
## Convenção: o nome descreve algo que JÁ aconteceu (hp_alterado, não alterar_hp).
# Os sinais são emitidos por OUTROS scripts, então o Godot avisaria "sinal não usado".
@warning_ignore_start("unused_signal")
# ---------------------------------------------------------------------------
# Combate
# ---------------------------------------------------------------------------
## Emitido pelo CombatManager no começo de cada turno.
## de_quem: "jogador" ou "inimigo". Escutam: HandUI, EnemyUI.
signal turno_iniciado(numero: int, de_quem: String)
## Emitido pelo CombatManager quando uma carta é jogada.
## Escutam: HandUI (anima a carta), DeckManager (manda para o descarte).
## Tipos de carta e alvo ficam livres até a etapa 3 (CardData e ActorStats).
signal carta_jogada(carta, alvo)
## Emitido pelo AttackResolver depois de calcular o dano (já com fraqueza/resistência).
## tipo_dano: "cortante", "fogo", "gelo" etc. Escutam: barras de HP, DiceRollerUI.
signal dano_causado(alvo, valor: int, tipo_dano: Enums.TipoDano, critico: bool)
## Escutam: as barras de HP do jogador e do inimigo.
signal hp_alterado(ator, hp_atual: int, hp_max: int)
## Emitido pelo CombatManager quando o inimigo chega a 0 de HP.
## Escutam: RewardCalculator, GameManager.
signal combate_terminado(venceu: bool, turnos_usados: int)
## Emitido pelo CombatManager. motivo: "hp_zero" ou "sem_cartas".
## Escutam: GameManager, tela de fim da run.
signal game_over(motivo: String)
# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
## Emitido pelo GameManager quando o ouro muda. Escuta: ShopUI.
signal ouro_alterado(ouro: int)
## Emitido pelo GameManager no level up. Escutam: telas de progressão.
signal nivel_alterado(nivel: int)
@warning_ignore_restore("unused_signal")
