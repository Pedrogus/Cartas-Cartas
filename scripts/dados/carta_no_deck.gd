class_name CartaNoDeck
extends RefCounted
## CartaNoDeck. Uma carta do deck da run: o molde (CardData) + o tier em que ela foi obtida.
## Deck inicial = tier 0. Carta nova (level up ou mercador) nasce no tier do nível atual.
## O molde (.tres) nunca é alterado: o tier vive aqui, na instância.

var carta: CardData
var tier: int = 0


func _init(p_carta: CardData = null, p_tier: int = 0) -> void:
	carta = p_carta
	tier = p_tier


## Tier a partir do nível do jogador: 0 a 9 (sobe a cada 2 níveis).
static func tier_do_nivel(nivel: int) -> int:
	return floori((nivel - 1) / 2.0)
