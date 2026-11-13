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

enum Atributo {
	FOR,
	DES,
	CON,
	INT,
	SAB,
	CAR,
}

enum TipoCarta {
	ATAQUE,     # causa dano (rolagem de acerto ou salvaguarda)
	DEFESA,     # dá bônus de CA ou protege
	UTILIDADE,  # compra carta, controle do inimigo, etc.
}

## O que a carta FAZ além (ou no lugar) do dano.
## O CombatManager (etapa 6) lê este enum com um match.
enum Efeito {
	NENHUM,
	BONUS_CA,                # +valor de CA por duracao_turnos
	BONUS_ACERTO,            # +valor no ataque por duracao_turnos
	BONUS_DANO,              # +valor de dano por duracao_turnos
	COMPRAR_CARTAS,          # compra valor cartas
	INIMIGO_PERDE_TURNOS,    # Teia: inimigo perde valor turnos (se falhar na salvaguarda)
	BONUS_ACERTO_PROXIMA,    # Grito de Guerra: +valor no d20 da próxima carta de ataque
	COMPRAR_SE_DADO_PAR,     # Toque Chocante: compra valor carta(s) se o dado de dano for par
	MULLIGAN_EXTRA,          # Foco Mental: troca até valor cartas sem gastar o limite
	BONUS_CA_E_REROLAR,      # Escudo Arcano: +valor CA e rerrola d20 de 1 ou 2
	CURAR_DADO,              # Segundo Fôlego: cura 1d(valor) + nível + tier
	RECUPERAR_DESCARTE,      # Recuperação Arcana: devolve ⌈nível ÷ valor⌉ cartas do descarte à pilha
	ACAO_EXTRA,              # Surto de Ação: +valor ação(ões) neste turno
	AUMENTO_ATRIBUTO,        # Poções: +valor no atributo_usado por duracao_turnos
}

## Quem a carta afeta. UNICO: um inimigo (o alvo atual). TODOS: todos os inimigos.
## DIVIDIDO: os dardos/partes da carta são divididos entre os inimigos. JOGADOR: só o jogador.
## REGRA: valores novos entram SEMPRE no FINAL.
enum AlvoCarta {
	UNICO,
	TODOS,
	DIVIDIDO,
	JOGADOR,
}

## De onde a carta vem: das cartas de classe, de itens (poções) ou de relíquias mágicas.
enum CategoriaCarta {
	CLASSE,
	ITEM,
	RELIQUIA,
}

## Que tipo de ação a carta gasta no turno.
## ACAO: ataques, magias de ataque e Teia. ACAO_BONUS: suporte (escudos, Grito, Foco).
enum TipoAcao {
	ACAO,
	ACAO_BONUS,
}

## Tipo de criatura do inimigo (usado depois por cartas/Arcanos que dão bônus contra um tipo).
## REGRA: valores novos entram SEMPRE no FINAL.
enum TipoCriatura {
	HUMANOIDE,
	MONSTRUOSIDADE,
	INFERNAL,
	FERRICO,
	FERA,
	CONSTRUCTO,
	MORTO_VIVO,
}

## Físico ou Mágico? (usado depois no cálculo de tier e de resistência)
static func eh_fisico(tipo: TipoDano) -> bool:
	return tipo == TipoDano.CORTANTE \
		or tipo == TipoDano.PERFURANTE \
		or tipo == TipoDano.CONTUNDENTE
