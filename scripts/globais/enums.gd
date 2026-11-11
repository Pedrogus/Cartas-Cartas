class_name Enums
extends RefCounted
## Enums (sem autoload). Lista fixa de opções usadas no projeto todo.
## REGRA: valores novos entram SEMPRE no FINAL de cada enum, para não quebrar saves.
## Uso: Enums.Classe.MAGO, Enums.TipoDano.FOGO

enum Classe {
	GUERREIRO,
	MAGO,
}

enum TipoDano {
	# Físicos
	CORTANTE,
	PERFURANTE,
	CONTUNDENTE,
	# Mágicos
	FORCA,
	PSIQUICO,
	FOGO,
	GELO,
	ELETRICIDADE,
	SAGRADO,
	NECROTICO,
}


## Físico ou Mágico? (usado depois no cálculo de tier e de resistência)
static func eh_fisico(tipo: TipoDano) -> bool:
	return tipo == TipoDano.CORTANTE \
		or tipo == TipoDano.PERFURANTE \
		or tipo == TipoDano.CONTUNDENTE
