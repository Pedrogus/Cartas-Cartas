class_name ArcanaData
extends Resource
## ArcanaData (Resource). Molde de um Arcano: relíquia passiva que o jogador equipa (máx. 5).
## Só dados. Quem aplica o efeito no combate é o CombatManager (via GameManager.arcanos).
## PLACEHOLDER: os 3 efeitos vêm da simulação v3. Nome, arte e efeitos finais dependem dos assets.

@export_group("Identidade")
@export var id: String = ""
@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var arte: Texture2D
## Preço no mercador (PO). Faixa atual: 7 a 10.
@export var preco: int = 7
## Arcano super raro (pendência do GDD: ainda sem regra própria).
@export var super_raro: bool = false

@export_group("Efeito")
@export var efeito: Enums.EfeitoArcano = Enums.EfeitoArcano.DANO_EXTRA
## DANO_EXTRA: dano somado. DANO_ELEMENTAL: quantidade de dados. BONUS_CA: CA somada.
@export var valor: int = 1
## Só DANO_ELEMENTAL: faces do dado extra e o tipo dele (fraqueza/resistência valem).
@export var faces_dado: int = 6
@export var tipo_dano_extra: Enums.TipoDano = Enums.TipoDano.FOGO


## Texto curto do efeito para a interface: "+2 de dano", "+1d6 de Fogo", "+1 de CA".
func texto_efeito() -> String:
	match efeito:
		Enums.EfeitoArcano.DANO_EXTRA:
			return "+%d de dano em todo acerto" % valor
		Enums.EfeitoArcano.DANO_ELEMENTAL:
			return "+%dd%d de %s em todo acerto" % [valor, faces_dado,
				Enums.TipoDano.keys()[tipo_dano_extra].capitalize()]
		Enums.EfeitoArcano.BONUS_CA:
			return "+%d de CA" % valor
	return ""
