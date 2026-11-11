class_name ActorStats
extends Resource
## ActorStats (Resource). Números de uma criatura: atributos, HP, CA e nível.
## O .tres é o MOLDE: nunca altere o HP nele. No combate use criar_copia_combate().
## Não emite sinais: quem avisa o EventBus (hp_alterado) é o CombatManager.

@export_group("Atributos")
@export var forca: int = 10
@export var destreza: int = 10
@export var constituicao: int = 10
@export var inteligencia: int = 10
@export var sabedoria: int = 10
@export var carisma: int = 10

@export_group("Combate")
@export var hp_max: int = 10
@export var ca: int = 10
@export var nivel: int = 1

## HP em jogo. Não é exportado: só existe na cópia de combate.
var hp_atual: int = 0


## Valor bruto do atributo (ex.: 16).
func valor_atributo(atributo: Enums.Atributo) -> int:
	match atributo:
		Enums.Atributo.FOR: return forca
		Enums.Atributo.DES: return destreza
		Enums.Atributo.CON: return constituicao
		Enums.Atributo.INT: return inteligencia
		Enums.Atributo.SAB: return sabedoria
		Enums.Atributo.CAR: return carisma
	return 10


## Modificador D&D: (valor - 10) / 2, arredondado para baixo. 16 -> +3, 8 -> -1.
func modificador(atributo: Enums.Atributo) -> int:
	return floori((valor_atributo(atributo) - 10) / 2.0)


## Proficiência por faixa de nível: 1-4 = +2, 5-8 = +3, 9-12 = +4, 13-16 = +5, 17-20 = +6.
func bonus_proficiencia() -> int:
	return 2 + floori((nivel - 1) / 4.0)


## Bônus do d20 de ataque: proficiência + modificador do atributo da carta.
func bonus_ataque(atributo: Enums.Atributo) -> int:
	return bonus_proficiencia() + modificador(atributo)


## CD da salvaguarda do inimigo: 8 + proficiência + INT.
func cd_magia() -> int:
	return 8 + bonus_proficiencia() + modificador(Enums.Atributo.INT)


func receber_dano(valor: int) -> void:
	hp_atual = maxi(hp_atual - valor, 0)


func curar(valor: int) -> void:
	hp_atual = mini(hp_atual + valor, hp_max)


func esta_morto() -> bool:
	return hp_atual <= 0


## Cópia para usar no combate: HP cheio e nível atual. O molde (.tres) fica intacto.
func criar_copia_combate(nivel_atual: int) -> ActorStats:
	var copia: ActorStats = duplicate()
	copia.nivel = nivel_atual
	copia.hp_atual = copia.hp_max
	return copia
