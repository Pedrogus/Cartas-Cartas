extends Node

const CICLOS_MAX := 20
const FASES_POR_CICLO := 3
const NIVEL_MAX := 20

var run_ativa: bool = false
var classe: Enums.Classe = Enums.Classe.GUERREIRO
var nivel: int = 1
var ouro: int = 0
var ciclo_atual: int = 1
var fase_atual: int = 1
var turnos_contados: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)
	print("GameManager pronto")
	
	#nova_run(Enums.Classe.GUERREIRO)
	#var t := ActorStats.new()
	#t.forca = 16
	#t.nivel = 5
	#t.hp_max = 12
	#var c := t.criar_copia_combate(5)
	#c.receber_dano(20)
	#print(t.bonus_proficiencia(), " ", t.modificador(Enums.Atributo.FOR), " ", c.hp_atual, " ", t.hp_atual, " ", c.esta_morto())
	for pasta in ["guerreiro", "mago"]:
		var total := 0
		for arq in DirAccess.get_files_at("res://data/cartas/" + pasta):
			if arq.ends_with(".tres"):
				var c: CardData = load("res://data/cartas/%s/%s" % [pasta, arq])
				total += c.copias_iniciais
		print(pasta, ": ", total)
	print((load("res://data/cartas/mago/misseis_magicos.tres") as CardData).texto_dado())
	print((load("res://data/cartas/guerreiro/espada.tres") as CardData).texto_dado())



func nova_run(classe_escolhida: Enums.Classe) -> void:
	classe = classe_escolhida
	nivel = 1
	ouro = 0
	ciclo_atual = 1
	fase_atual = 1
	turnos_contados = 0
	run_ativa = true
	EventBus.nivel_alterado.emit(nivel)
	EventBus.ouro_alterado.emit(ouro)
	print("Run iniciada: %s, nível %d" % [Enums.Classe.keys()[classe], nivel])

func registrar_turno() -> void:
	turnos_contados += 1

func adicionar_ouro(quantidade: int) -> void:
	ouro += quantidade
	EventBus.ouro_alterado.emit(ouro)
	
func gastar_ouro(quantidade: int) -> bool:
	if quantidade > ouro:
		return false
	ouro -= quantidade
	EventBus.ouro_alterado.emit(ouro)
	return true


func subir_nivel() -> void:
	if nivel >= NIVEL_MAX:
		return
	nivel += 1
	EventBus.nivel_alterado.emit(nivel)

func avancar_fase() -> void:
	turnos_contados = 0
	fase_atual += 1
	if fase_atual > FASES_POR_CICLO:
		fase_atual = 1
		ciclo_atual += 1
		if ciclo_atual > CICLOS_MAX:
			run_ativa = false
			print("Run vencida!")   # um sinal run_vencida entra no EventBus quando houver a tela final
			return
		subir_nivel()
		
func _on_game_over(motivo: String) -> void:
	run_ativa = false
	print("Game Over: %s" % motivo)
