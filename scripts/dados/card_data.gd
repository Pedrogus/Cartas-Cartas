class_name CardData
extends Resource
## CardData (Resource). Molde de uma carta. Só dados: a lógica fica no CombatManager.

@export_group("Identidade")
@export var id: String = ""
@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var classe_origem: Enums.Classe = Enums.Classe.GUERREIRO
@export var tipo_carta: Enums.TipoCarta = Enums.TipoCarta.ATAQUE
## Gasta 1 ação (ataques, magias de ataque, Teia) ou 1 ação bônus (suporte) do turno.
@export var tipo_acao: Enums.TipoAcao = Enums.TipoAcao.ACAO
@export var alvo: Enums.AlvoCarta = Enums.AlvoCarta.UNICO
@export var categoria: Enums.CategoriaCarta = Enums.CategoriaCarta.CLASSE
@export var arte: Texture2D
@export var preco: int = 1
## Cópias no deck inicial da classe de origem (0 = só aparece por level up ou mercador).
@export var copias_iniciais: int = 0

@export_group("Ataque")
@export var tipo_dano: Enums.TipoDano = Enums.TipoDano.CORTANTE
@export var qtd_dados: int = 0
@export var faces_dado: int = 0
@export var bonus_dano_fixo: int = 0
@export var soma_atributo_no_dano: bool = false
@export var atributo_usado: Enums.Atributo = Enums.Atributo.FOR
@export var acerto_automatico: bool = false
## Valor positivo = penalidade (2 significa -2 no d20).
@export var penalidade_acerto: int = 0

@export_group("Magia")
@export var nivel_magia: int = 0
@export var exige_salvaguarda: bool = false
@export var atributo_salvaguarda: Enums.Atributo = Enums.Atributo.DES
@export var dano_metade_na_salvaguarda: bool = false

@export_group("Efeito")
@export var efeito: Enums.Efeito = Enums.Efeito.NENHUM
@export var valor: int = 0
@export var duracao_turnos: int = 0


## Só cartas de ATAQUE causam dano. Cartas de utilidade podem ter dados (cura, Mente Tática)
## sem serem ataque.
func causa_dano() -> bool:
	return tipo_carta == Enums.TipoCarta.ATAQUE and (qtd_dados > 0 or bonus_dano_fixo > 0)


## Texto do dado para a interface: "2d4", "1d4+2". Vazio se a carta não causa dano.
func texto_dado() -> String:
	if qtd_dados == 0:
		return ""
	var texto := "%dd%d" % [qtd_dados, faces_dado]
	if bonus_dano_fixo != 0:
		texto += "%+d" % bonus_dano_fixo
	return texto
