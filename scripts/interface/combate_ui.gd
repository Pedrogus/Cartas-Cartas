extends Control
## Interface MÍNIMA do combate (protótipo). Monta os nós por código, escuta o CombatManager
## e só chama jogar_carta / trocar_carta / terminar_turno. Não tem regra de jogo aqui.
## Layout (1280x720): inimigo no topo, jogador e pilha nas laterais, log no centro, mão embaixo.

## Inimigos de cada fase do ciclo 1 (GDD v3.2): 2 Ratos, Guerreiro Morto-vivo, Cultista Mago (chefe).
const FASES_CICLO_1: Array = [
	["res://data/inimigos/rato_esgoto.tres", "res://data/inimigos/rato_esgoto.tres"],
	["res://data/inimigos/esqueleto_guardiao.tres"],
	["res://data/inimigos/cultista_sombras.tres"],
]
const COR_ALVO := Color(1.0, 0.85, 0.3)

var _cm: CombatManager

var _lbl_fase: Label
var _caixa_inimigos: HBoxContainer   # um painel por inimigo; clique escolhe o alvo
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
	# Este Control fica dentro de um Node2D (sem layout pai): sem tamanho fixo ele encolhe
	# junto com o conteúdo (ex.: mão vazia). Fixa no tamanho da janela.
	var tela := get_viewport_rect().size
	custom_minimum_size = tela
	size = tela
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
	_caixa_inimigos = HBoxContainer.new()
	_caixa_inimigos.add_theme_constant_override("separation", 10)
	_caixa_inimigos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caixa_inimigos.custom_minimum_size = Vector2(0, 150)
	topo.add_child(_caixa_inimigos)
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
	_mao.custom_minimum_size = Vector2(5 * 172 + 4 * 10, 230)  # reserva o espaço de 5 cartas
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
	caixa.custom_minimum_size = Vector2(640, 0)
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
			"texto": _texto_classe(dados),
			"acao": _ao_escolher_classe.bind(c),
		})
	_mostrar_overlay("Cartas & Cartas", "Escolha sua classe", opcoes)


func _texto_classe(dados: ClassData) -> String:
	var s := dados.stats
	var texto := "%s   (HP %d • CA %d • d%d de vida)\n" % [dados.nome, s.hp_max, s.ca, dados.dado_vida]
	var attrs := ""
	for a in Enums.Atributo.values():
		var mod := s.modificador(a)
		attrs += "%s %d (%s)   " % [Enums.Atributo.keys()[a], s.valor_atributo(a), ("+%d" % mod) if mod >= 0 else str(mod)]
	texto += attrs.strip_edges() + "\nCartas: "
	var lista: Array[String] = []
	for carta in dados.cartas:
		lista.append("%dx %s" % [carta.copias_iniciais, carta.nome])
	return texto + ", ".join(lista)


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
	var inimigos: Array[EnemyData] = []
	for caminho in FASES_CICLO_1[GameManager.fase_atual - 1]:
		inimigos.append(load(caminho))
	_cm.iniciar(inimigos)
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
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 44 if opcoes.size() == 1 else 110)
		b.pressed.connect(op["acao"])
		_overlay_botoes.add_child(b)
	_overlay.show()


# ---------------------------------------------------------------- redesenho

func _redesenhar() -> void:
	if _cm == null or _cm.inimigos.is_empty():
		return
	_reconstruir_inimigos()

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
	if _cm.turnos_jogador_perdidos > 0:
		_lbl_jogador_info.text += "\nPRESO: perde %d turno(s)" % _cm.turnos_jogador_perdidos

	_lbl_pilha.text = "Pilha: %d\nDescarte: %d\nMão: %d" % [_cm.deck.pilha.size(),
		_cm.deck.descarte.size(), _cm.deck.mao.size()]

	_reconstruir_mao()
	_btn_fim_turno.disabled = _cm.encerrado or not _cm.turno_do_jogador


func _reconstruir_inimigos() -> void:
	for f in _caixa_inimigos.get_children():
		_caixa_inimigos.remove_child(f)
		f.queue_free()
	for i in _cm.inimigos.size():
		_caixa_inimigos.add_child(_painel_inimigo(i, _cm.inimigos[i]))


## Painel de um inimigo: nome, HP, CA, baralho e resistências. Clicar nele o escolhe como alvo.
func _painel_inimigo(indice: int, e: InimigoEmCombate) -> PanelContainer:
	var ini := e.data
	var caixa := VBoxContainer.new()
	var nome := _novo_label(20)
	nome.text = e.nome + ("  [CHEFE]" if ini.eh_chefe else "")
	var tipo := _novo_label(13)
	tipo.text = Enums.TipoCriatura.keys()[ini.tipo_criatura].capitalize().replace("_", " ")
	var barra := _nova_barra(Color(0.8, 0.2, 0.2))
	barra.max_value = e.stats.hp_max
	barra.value = e.stats.hp_atual
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := _novo_label(14)
	if e.vivo():
		var texto := "HP %d/%d   CA %d\nBaralho %d • Mão %d • Descarte %d" % [e.stats.hp_atual, e.stats.hp_max,
			e.ca(), e.deck.pilha.size(), e.deck.mao.size(), e.deck.descarte.size()]
		texto += _linha_tipos("Fraco", ini.fraquezas) + _linha_tipos("Resiste", ini.resistencias) \
			+ _linha_tipos("Imune", ini.imunidades)
		if e.turnos_perdidos > 0:
			texto += "\nPRESO: perde %d turno(s)" % e.turnos_perdidos
		info.text = texto
	else:
		info.text = "DERROTADO"
	caixa.add_child(nome)
	caixa.add_child(tipo)
	caixa.add_child(barra)
	caixa.add_child(info)
	var painel := _painel(caixa, true)
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	painel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if e.vivo() else Control.CURSOR_ARROW
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.14, 0.14, 0.2)
	var selecionado := e == _cm.alvo_atual and e.vivo()
	estilo.set_border_width_all(3 if selecionado else 1)
	estilo.border_color = COR_ALVO if selecionado else Color(0.35, 0.35, 0.45)
	estilo.set_content_margin_all(8)
	painel.add_theme_stylebox_override("panel", estilo)
	if not e.vivo():
		painel.modulate = Color(1, 1, 1, 0.4)
	painel.gui_input.connect(_ao_clicar_inimigo.bind(indice))
	return painel


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
	texto += "\n" + ("[AÇÃO BÔNUS]" if c.tipo_acao == Enums.TipoAcao.ACAO_BONUS else "[AÇÃO]")
	if c.causa_dano() or c.exige_salvaguarda or c.efeito == Enums.Efeito.INIMIGO_PERDE_TURNOS:
		match c.alvo:
			Enums.AlvoCarta.TODOS:
				texto += " [ÁREA]"
			Enums.AlvoCarta.DIVIDIDO:
				texto += " [DIVIDIDO]"
	texto += "\n"
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


func _ao_clicar_inimigo(evento: InputEvent, indice: int) -> void:
	if _cm == null:
		return
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		_cm.selecionar_alvo(indice)


func _ao_terminar_turno() -> void:
	if _cm != null:
		_cm.terminar_turno()


func _ao_log(texto: String) -> void:
	_log.append_text(texto + "\n")
