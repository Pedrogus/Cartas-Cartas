class_name MercadorUI
extends Control
## Tela MÍNIMA do mercador comum (protótipo). Monta os nós por código, como a combate_ui.
## Sem regra de jogo aqui: compra pelo MerchantManager e descansa pelo RestService.
## Quem cria esta tela escuta 'mercador_fechado' para seguir para a próxima fase.

signal mercador_fechado

const COR_FUNDO := Color(0.1, 0.08, 0.06)
const COR_CARTA := Color(1.0, 0.95, 0.85)
const COR_ARCANO := Color(0.85, 0.8, 1.0)

var _mm: MerchantManager

var _lbl_status: Label
var _lbl_arcanos: Label
var _caixa_ofertas: HBoxContainer
var _btn_descanso: Button
var _btn_refresh: Button
var _lbl_mensagem: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mm = MerchantManager.new()
	_mm.gerar_oferta_comum()
	_construir()
	_redesenhar()


# ---------------------------------------------------------------- construção

func _construir() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margem.add_theme_constant_override(lado, 24)
	add_child(margem)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 14)
	margem.add_child(raiz)

	var titulo := _novo_label(32)
	titulo.text = "Mercador"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(titulo)

	_lbl_status = _novo_label(18)
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(_lbl_status)

	_lbl_arcanos = _novo_label(15)
	_lbl_arcanos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(_lbl_arcanos)

	_caixa_ofertas = HBoxContainer.new()
	_caixa_ofertas.alignment = BoxContainer.ALIGNMENT_CENTER
	_caixa_ofertas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caixa_ofertas.add_theme_constant_override("separation", 20)
	raiz.add_child(_caixa_ofertas)

	_lbl_mensagem = _novo_label(16)
	_lbl_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.add_child(_lbl_mensagem)

	var rodape := HBoxContainer.new()
	rodape.alignment = BoxContainer.ALIGNMENT_CENTER
	rodape.add_theme_constant_override("separation", 20)
	raiz.add_child(rodape)

	_btn_refresh = Button.new()
	_btn_refresh.custom_minimum_size = Vector2(220, 48)
	_btn_refresh.pressed.connect(_ao_refrescar)
	rodape.add_child(_btn_refresh)

	_btn_descanso = Button.new()
	_btn_descanso.custom_minimum_size = Vector2(300, 48)
	_btn_descanso.pressed.connect(_ao_descansar)
	rodape.add_child(_btn_descanso)

	var btn_seguir := Button.new()
	btn_seguir.text = "Seguir para a fase %d" % (GameManager.fase_atual + 1)
	btn_seguir.custom_minimum_size = Vector2(300, 48)
	btn_seguir.pressed.connect(func() -> void: mercador_fechado.emit())
	rodape.add_child(btn_seguir)


func _novo_label(tamanho: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tamanho)
	return l


# ---------------------------------------------------------------- redesenho

func _redesenhar() -> void:
	var jog := GameManager.stats_jogador
	var classe := GameManager.dados_da_classe()
	var con := jog.modificador(Enums.Atributo.CON)
	_lbl_status.text = "Ouro: %d PO   •   HP %d/%d   •   Dados de vida: %d (d%d %s)   •   Deck %d/%d" % [
		GameManager.ouro, jog.hp_atual, jog.hp_max, GameManager.dados_vida_restantes,
		classe.dado_vida, ("+%d" % con) if con >= 0 else str(con),
		GameManager.deck_da_run.size(), GameManager.DECK_MAX]

	var nomes: Array[String] = []
	for a in GameManager.arcanos:
		nomes.append("%s (%s)" % [a.nome, a.texto_efeito()])
	_lbl_arcanos.text = "Arcanos %d/%d: %s" % [GameManager.arcanos.size(), GameManager.ARCANOS_MAX,
		", ".join(nomes) if not nomes.is_empty() else "nenhum"]

	_btn_descanso.text = "Descanso curto (gasta 1 dado de vida)"
	_btn_descanso.disabled = GameManager.dados_vida_restantes <= 0 or jog.hp_atual >= jog.hp_max

	var bloqueio_refresh := _mm.motivo_bloqueio_refresh()
	_btn_refresh.text = "Atualizar (%d PO)" % _mm.custo_refresh()
	_btn_refresh.disabled = bloqueio_refresh != ""
	_btn_refresh.tooltip_text = bloqueio_refresh

	for f in _caixa_ofertas.get_children():
		_caixa_ofertas.remove_child(f)
		f.queue_free()
	for i in _mm.ofertas.size():
		_caixa_ofertas.add_child(_painel_oferta(i, _mm.ofertas[i]))


func _painel_oferta(indice: int, o: MerchantManager.Oferta) -> PanelContainer:
	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(240, 0)
	caixa.add_theme_constant_override("separation", 8)

	var tag := _novo_label(13)
	tag.text = "ARCANO" if o.eh_arcano() else _rotulo_carta(o.carta)
	caixa.add_child(tag)

	var nome := _novo_label(20)
	nome.text = o.nome()
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(nome)

	if o.eh_arcano() and o.arcano.arte != null:
		var arte := TextureRect.new()
		arte.texture = o.arcano.arte
		arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arte.custom_minimum_size = Vector2(0, 220)
		caixa.add_child(arte)

	var desc := _novo_label(15)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if o.eh_arcano():
		desc.text = o.arcano.texto_efeito() + "\n" + o.arcano.descricao
	else:
		var dado := o.carta.texto_dado()
		desc.text = (dado + "\n" if dado != "" and o.carta.causa_dano() else "") + o.carta.descricao
	caixa.add_child(desc)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	if o.vendida:
		btn.text = "Comprada"
		btn.disabled = true
	else:
		btn.text = "Comprar (%d PO)" % o.preco
		var motivo := _mm.motivo_bloqueio(indice)
		btn.disabled = motivo != ""
		btn.tooltip_text = motivo
	btn.pressed.connect(_ao_comprar.bind(indice))
	caixa.add_child(btn)
	if not o.vendida and btn.disabled:
		var aviso := _novo_label(13)
		aviso.text = btn.tooltip_text   # botão desativado não mostra o motivo sozinho
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caixa.add_child(aviso)

	var painel := PanelContainer.new()
	painel.add_child(caixa)
	painel.modulate = COR_ARCANO if o.eh_arcano() else COR_CARTA
	if o.vendida:
		painel.modulate.a = 0.5
	return painel


func _rotulo_carta(c: CardData) -> String:
	if c.categoria == Enums.CategoriaCarta.ITEM:
		return "POÇÃO"
	return "CARTA • %s" % Enums.Classe.keys()[c.classe_origem]


# ---------------------------------------------------------------- entradas

func _ao_comprar(indice: int) -> void:
	var nome := _mm.ofertas[indice].nome()
	var motivo := _mm.comprar(indice)
	if motivo == "":
		_lbl_mensagem.text = "Você comprou %s." % nome
	else:
		_lbl_mensagem.text = motivo
	_redesenhar()


func _ao_refrescar() -> void:
	var custo := _mm.custo_refresh()
	var motivo := _mm.refrescar()
	_lbl_mensagem.text = ("Vitrine atualizada por %d PO." % custo) if motivo == "" else motivo
	_redesenhar()


func _ao_descansar() -> void:
	var r := RestService.descanso_curto()
	if r["ok"]:
		_lbl_mensagem.text = "Descanso curto: d%d (%d) %+d CON = %d de cura (HP %d → %d)." % [
			GameManager.dados_da_classe().dado_vida, r["dado"], r["con"], r["cura"], r["antes"], r["depois"]]
	else:
		_lbl_mensagem.text = r["motivo"]
	_redesenhar()
