class_name ModificadoresAtaque
extends RefCounted
## ModificadoresAtaque (entrada do AttackResolver).
## O CombatManager preenche com o que está ativo na hora: tier da carta, Grito de Guerra,
## Arcanos, etc. Tudo começa zerado: um ataque sem bônus é só ModificadoresAtaque.new().

var tier: int = 0                 # tier da carta (deck inicial = 0)
var bonus_acerto: int = 0         # soma no d20 (Grito de Guerra, Arcanos, escala física)
var bonus_dano: int = 0           # soma no dano (Arcano +2, escala de tier)
var dados_extras: int = 0         # quantidade de dados extras (Arcano +1d6 elemental)
var faces_dado_extra: int = 6
var tipo_dano_extra: Enums.TipoDano = Enums.TipoDano.FOGO
var vantagem: bool = false        # d20 de ataque com vantagem
var desvantagem: bool = false     # d20 de ataque com desvantagem
var rerrolar_ate: int = 0         # rerrola o d20 se sair <= este valor (Escudo Arcano = 2; 0 = desligado)
