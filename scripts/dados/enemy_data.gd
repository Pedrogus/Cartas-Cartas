class_name EnemyData
extends Resource
## EnemyData (Resource). Molde de um inimigo (valores base do ciclo 1).
## Só dados. O HP que escala por ciclo entra na etapa 7; o combate usa stats.criar_copia_combate().

@export_group("Identidade")
@export var id: String = ""
@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var arte: Texture2D
@export var tipo_criatura: Enums.TipoCriatura = Enums.TipoCriatura.HUMANOIDE
@export var eh_chefe: bool = false  # chefe faz salvaguarda com vantagem (Teia)

@export_group("Números")
@export var stats: ActorStats       # hp_max, CA, DES (esquiva) e INT (CD das magias)
@export var turnos_alvo: int = 3    # terminar dentro disso dá bônus de ouro

@export_group("Ataque comum")
@export var bonus_ataque: int = 0   # somado ao d20 (já inclui proficiência)
@export var qtd_dados: int = 1
@export var faces_dado: int = 4
@export var tipo_dano: Enums.TipoDano = Enums.TipoDano.CORTANTE

@export_group("Defesas")
@export var fraquezas: Array[Enums.TipoDano] = []      # dano x2
@export var resistencias: Array[Enums.TipoDano] = []   # dano ÷2 (arredonda para baixo)
@export var imunidades: Array[Enums.TipoDano] = []     # dano 0

@export_group("Habilidades")
@export_multiline var habilidades: String = ""  # texto por enquanto; vira lógica na etapa 7


## Multiplicador de dano do GDD: imune 0, fraqueza 2, resistência 0.5, normal 1.
func multiplicador_dano(tipo: Enums.TipoDano) -> float:
	if tipo in imunidades:
		return 0.0
	if tipo in fraquezas:
		return 2.0
	if tipo in resistencias:
		return 0.5
	return 1.0
