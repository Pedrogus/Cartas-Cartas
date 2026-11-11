extends Control
## Interface MÍNIMA do combate (protótipo). Monta os nós por código, escuta o CombatManager
## e só chama jogar_carta / trocar_carta / terminar_turno. Não tem regra de jogo aqui.
## Layout (1280x720): inimigo no topo, jogador e pilha nas laterais, log no centro, mão embaixo.

const INIMIGOS_CICLO_1: Array[String] = [
	"res://data/inimigos/rato_esgoto.tres",
	"res://data/inimigos/esqueleto_guardiao.tres",
	"res://data/inimigos/cultista_sombras.tres",
]

var _cm: CombatManager

var _lbl_fase: Label
var _lbl_inimigo_nome: Label
var _barra_inimigo: ProgressBar
var _lbl_inimigo_info: Label
var _lbl_jogador_nome: Label
var _barra_jogador: ProgressBar
var _lbl_jogador_info: Label
var _lbl_pilha: Label
var _log: RichTextLabel
var _mao: HBoxContainer
var _modo_troca: CheckButton
var _btn_fim_turno: Button

var _overlay: Control
var _overlay_titulo: Label
var _overlay_texto: Label
var _overlay_botoes: VBoxContainer


func _ready() -> void:
	_construir()
	_mostrar_selecao_classe()


# ---------------------------------------------------------------- construção da tela

func _construir() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.09, 0.09, 0.13)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margem.add_theme_constant_override(lado, 14)
	add_child(margem)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 8)
	margem.add_child(raiz)

	# topo: inimigo + fase
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 12)
	raiz.add_child(topo)
	var caixa_inimigo := VBoxContainer.new()
	_lbl_inimigo_nome = _novo_label(24)
	_barra_inimigo = _nova_barra(Color(0.8, 0.2, 0.2))
	_lbl_inimigo_info = _novo_label(15)
	caixa_inimigo.add_child(_lbl_inimigo_nome)
	caixa_inimigo.add_child(_barra_inimigo)
	caixa_inimigo.add_child(_lbl_inimigo_info)
	caixa_inimigo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_painel(caixa_inimigo, true))
	_lbl_fase = _novo_label(16)
	_lbl_fase.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	topo.add_child(_painel(_lbl_fase))

	# meio: jogador | log | pilha
	var meio := HBoxContainer.new()
	meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meio.add_theme_constant_override("separation", 12)
	raiz.add_child(meio)

	var caixa_jogador := VBoxContainer.new()
	_lbl_jogador_nome = _novo_label(20)
	_barra_jogador = _nova_barra(Color(0.2, 0.7, 0.3))
	_lbl_jogador_info = _novo_label(15)
	caixa_jogador.add_child(_lbl_jogador_nome)
	caixa_jogador.add_child(_barra_jogador)
	caixa_jogador.add_child(_lbl_jogador_info)
	var painel_jogador := _painel(caixa_jogador)
	painel_jogador.custom_minimum_size = Vector2(260, 0)
	meio.add_child(painel_jogador)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 15)
	meio.add_child(_painel(_log, true))

	_lbl_pilha = _novo_label(16)
	var painel_pilha := _painel(_lbl_pilha)
	painel_pilha.custom_minimum_size = Vector2(150, 0)
	meio.add_child(painel_pilha)

	# mão
	_mao = HBoxContainer.new()
	_mao.alignment = BoxContainer.ALIGNMENT_CENTER
	_mao.custom_minimum_size = Vector2(0, 230)
	_mao.add_theme_constant_override("separation", 10)
	raiz.add_child(_mao)

	# rodapé
	var rodape := HBoxContainer.new()
	rodape.alignment = BoxContainer.ALIGNMENT_END
	rodape.add_theme_constant_override("separation", 16)
	raiz.add_child(rodape)
	_modo_troca = CheckButton.new()
	_modo_troca.text = "Modo troca (mulligan)"
	rodape.add_child(_modo_troca)
	_btn_fim_turno = Button.new()
	_btn_fim_turno.text = "Terminar turno"
	_btn_fim_turno.custom_minimum_size = Vector2(180, 40)
	_btn_fim_turno.pressed.connect(_ao_terminar_turno)
	rodape.add_child(_btn_fim_turno)

	_construir_overlay()


func _construir_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.75)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(centro)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 12)
	caixa.custom_minimum_size = Vector2(420, 0)
	_overlay_titulo = _novo_label(32)
	_overlay_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_texto = _novo_label(18)
	_overlay_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_botoes = VBoxContainer.new()
	_overlay_botoes.add_theme_constant_override("separation", 8)
	caixa.add_child(_overlay_titulo)
	caixa.add_child(_overlay_texto)
	caixa.add_child(_overlay_botoes)
	centro.add_child(_painel(caixa))
	_overlay.hide()


func _novo_label(tamanho: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tamanho)
	return l


func _nova_barra(cor: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 22)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	b.add_theme_stylebox_override("fill", estilo)
	return b


func _painel(filho: Control, expandir: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(filho)
	if expandir:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


# ---------------------------------------------------------------- fluxo (run e fases)

func _mostrar_selecao_classe() -> void:
	var opcoes: Array[Dictionary] = []
	for c in GameManager.CLASSES:
		var dados: ClassData = GameManager.CLASSES[c]
		opcoes.append({
			"texto": "%s  (HP %d, CA %d)" % [dados.nome, dados.stats.hp_max, dados.stats.ca],
			"acao": _ao_escolher_classe.bind(c),
		})
	_mostrar_overlay("Cartas & Cartas", "Escolha sua classe", opcoes)


func _ao_escolher_classe(classe: Enums.Classe) -> void:
	GameManager.nova_run(classe)
	_iniciar_fase()


func _iniciar_fase() -> void:
	_overlay.hide()
	if _cm != null:
		_cm.queue_free()
	_log.clear()
	_cm = CombatManager.new()
	add_child(_cm)
	_cm.combate_atualizado.connect(_redesenhar)
	_cm.log_adicionado.connect(_ao_log)
	_cm.combate_finalizado.connect(_ao_finalizar)
	var inimigo: EnemyData = load(INIMIGOS_CICLO_1[GameManager.fase_atual - 1])
	_cm.iniciar(inimigo)
	_redesenhar()


func _ao_finalizar(venceu: bool, motivo: String) -> void:
	_redesenhar()
	if venceu:
		var texto := "+%d PO (total: %d)\nHP: %d/%d" % [_cm.ouro_ganho, GameManager.ouro,
			_cm.jogador.hp_atual, _cm.jogador.hp_max]
		_mostrar_overlay("Vitória!", texto, [{"texto": "Próxima fase", "acao": _proxima_fase}])
	else:
		var causa := "Seu HP chegou a 0." if motivo == "hp_zero" else "Acabaram as cartas (mão e pilha)."
		_mostrar_overlay("Game Over", causa, [{"texto": "Nova run", "acao": _mostrar_selecao_classe}])


func _proxima_fase() -> void:
	GameManager.avancar_fase()
	if GameManager.ciclo_atual > 1:
		_mostrar_overlay("Ciclo 1 concluído!",
			"Fim do protótipo (por enquanto).\nNível %d • Ouro %d" % [GameManager.nivel, GameManager.ouro],
			[{"texto": "Nova run", "acao": _mostrar_selecao_classe}])
	else:
		_iniciar_fase()


func _mostrar_overlay(titulo: String, texto: String, opcoes: Array[Dictionary]) -> void:
	_overlay_titulo.text = titulo
	_overlay_texto.text = texto
	for f in _overlay_botoes.get_children():
		_overlay_botoes.remove_child(f)
		f.queue_free()
	for op in opcoes:
		var b := Button.new()
		b.text = op["texto"]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(op["acao"])
		_overlay_botoes.add_child(b)
	_overlay.show()


# ---------------------------------------------------------------- redesenho

func _redesenhar() -> void:
	if _cm == null or _cm.inimigo_stats == null:
		return
	var ini := _cm.inimigo
	var ini_stats := _cm.inimigo_stats
	_lbl_inimigo_nome.text = ini.nome + ("  [CHEFE]" if ini.eh_chefe else "")
	_barra_inimigo.max_value = ini_stats.hp_max
	_barra_inimigo.value = ini_stats.hp_atual
	var info := "HP %d/%d   CA %d   Ataque +%d, %dd%d" % [ini_stats.hp_atual, ini_stats.hp_max,
		ini_stats.ca, ini.bonus_ataque, ini.qtd_dados, ini.faces_dado]
	info += _linha_tipos("Fraco", ini.fraquezas) + _linha_tipos("Resiste", ini.resistencias) \
		+ _linha_tipos("Imune", ini.imunidades)
	if _cm.turnos_inimigo_perdidos > 0:
		info += "\nPRESO: perde %d turno(s)" % _cm.turnos_inimigo_perdidos
	_lbl_inimigo_info.text = info

	_lbl_fase.text = "Ciclo %d • Fase %d/%d\nTurno %d\nNível %d • Ouro %d" % [GameManager.ciclo_atual,
		GameManager.fase_atual, GameManager.FASES_POR_CICLO, _cm.turno, GameManager.nivel, GameManager.ouro]

	var jog := _cm.jogador
	_lbl_jogador_nome.text = GameManager.dados_da_classe().nome
	_barra_jogador.max_value = jog.hp_max
	_barra_jogador.value = jog.hp_atual
	var extra_ca := _cm.ca_jogador() - jog.ca
	_lbl_jogador_info.text = "HP %d/%d\nCA %d%s\nAções: %d/%d • Bônus: %d/%d\nTrocas: %d no turno, %d na fase" % [
		jog.hp_atual, jog.hp_max, _cm.ca_jogador(), (" (+%d)" % extra_ca) if extra_ca > 0 else "",
		_cm.acoes_restantes, _cm.acoes_max, _cm.bonus_restantes, CombatManager.BONUS_POR_TURNO,
		_cm.mulligans_turno, _cm.mulligans_fase]
	if _cm.mulligans_extras > 0:
		_lbl_jogador_info.text += "\nTrocas extras: %d" % _cm.mulligans_extras
	if _cm.bonus_acerto_proxima > 0:
		_lbl_jogador_info.text += "\nPróximo ataque: +%d no d20" % _cm.bonus_acerto_proxima
	if _cm.rerrolar_ate > 0:
		_lbl_jogador_info.text += "\nRerrola d20 de 1 ou 2"

	_lbl_pilha.text = "Pilha: %d\nDescarte: %d\nMão: %d" % [_cm.deck.pilha.size(),
		_cm.deck.descarte.size(), _cm.deck.mao.size()]

	_reconstruir_mao()
	_btn_fim_turno.disabled = _cm.encerrado or not _cm.turno_do_jogador


func _reconstruir_mao() -> void:
	for f in _mao.get_children():
		_mao.remove_child(f)
		f.queue_free()
	for cn in _cm.deck.mao:
		var b := Button.new()
		b.custom_minimum_size = Vector2(172, 220)
		b.text = _texto_carta(cn)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = _cm.encerrado or not _cm.turno_do_jogador
		b.modulate = _cor_da_carta(cn.carta)
		b.pressed.connect(_ao_clicar_carta.bind(cn))
		_mao.add_child(b)


func _texto_carta(cn: CartaNoDeck) -> String:
	var c := cn.carta
	var texto := c.nome
	if cn.tier > 0:
		texto += "  [T%d]" % cn.tier
	texto += "\n" + ("[AÇÃO BÔNUS]" if c.tipo_acao == Enums.TipoAcao.ACAO_BONUS else "[AÇÃO]") + "\n"
	if c.causa_dano():
		texto += "%s %s\n" % [c.texto_dado(), _nome_tipo(c.tipo_dano)]
	return texto + "\n" + c.descricao


func _cor_da_carta(c: CardData) -> Color:
	match c.tipo_carta:
		Enums.TipoCarta.ATAQUE:
			return Color(1.0, 0.85, 0.85)
		Enums.TipoCarta.DEFESA:
			return Color(0.85, 0.9, 1.0)
	return Color(0.9, 1.0, 0.85)


func _nome_tipo(tipo: Enums.TipoDano) -> String:
	return Enums.TipoDano.keys()[tipo].capitalize()


func _linha_tipos(rotulo: String, tipos: Array[Enums.TipoDano]) -> String:
	if tipos.is_empty():
		return ""
	var nomes := ""
	for t in tipos:
		nomes += ("" if nomes == "" else ", ") + _nome_tipo(t)
	return "\n%s: %s" % [rotulo, nomes]


# ---------------------------------------------------------------- entradas

func _ao_clicar_carta(cn: CartaNoDeck) -> void:
	if _cm == null:
		return
	if _modo_troca.button_pressed:
		_cm.trocar_carta(cn)
	else:
		_cm.jogar_carta(cn)


func _ao_terminar_turno() -> void:
	if _cm != null:
		_cm.terminar_turno()


func _ao_log(texto: String) -> void:
	_log.append_text(texto + "\n")
