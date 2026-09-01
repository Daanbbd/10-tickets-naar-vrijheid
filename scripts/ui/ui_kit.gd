class_name UiKit
extends RefCounted
## Gedeelde UI-bouwstenen en kleuren. Eén plek voor de look van dialogen,
## HUD en alle tien de minigames.
##
## De kleurconstanten hieronder worden gegenereerd door
## tools/generators/gen_ui_kit_colors.py uit tools/generators/palette.py —
## niet handmatig bewerken. Wijzig de brontabel in palette.py en draai:
##   python3 tools/generators/gen_ui_kit_colors.py

# --- GEGENEREERD UIT palette.py, NIET HANDMATIG BEWERKEN — START ---
const INK              := Color("#242424")  # bb_night — letterlijk bb-night
const PANEL            := Color("#f3f3f3")  # bb_day — letterlijk bb-day
const PANEL_DARK       := Color("#2e2e2e")  # ui_panel_donker — neutrale derivaat
const LINE             := Color("#4a4a4a")  # ui_line — neutrale derivaat
const GRIJS            := Color("#8a8a8a")  # ui_grijs — neutrale derivaat
const WIT              := Color("#eef0f4")  # wit — neutraal
const BLUEBIRD_INK     := Color("#243cec")  # bb_blue — letterlijk bb-blue, voor lichte ondergrond
const BLUEBIRD_BRIGHT  := Color("#3a86ff")  # ui_bluebird_bright — derivaat voor donkere ondergrond — bb-blue zelf is daar te donker om te lezen
const BLUEBIRD_TINT    := Color("#dbe9ff")  # bb_light_blue — letterlijk bb-light-blue
const GROEN            := Color("#3fae6e")  # ui_groen — derivaat van bb-green, leesbaar op 8-10px
const GROEN_TINT       := Color("#d8ffe0")  # bb_green — letterlijk bb-green
const ROOD             := Color("#e05263")  # ui_rood — game-only utility — BBD heeft geen foutkleur
const ORANJE           := Color("#f4a259")  # ui_oranje — derivaat van bb-orange, leesbaar op 8-10px
const ORANJE_TINT      := Color("#f7d6c2")  # bb_orange — letterlijk bb-orange
const ROZE_TINT        := Color("#ffcee3")  # bb_pink — letterlijk bb-pink — gereserveerd voor mensen/cultuur
const NEUTRAAL_TINT    := Color("#e4e4e4")  # ui_neutraal_tint — letterlijk --color-line — voor niet-accent states
const POSTIT           := Color("#f7e28a")  # postit_geel — papier van een ticket-briefje
const POSTIT_RAND      := Color("#ceb458")  # postit_geel_rand — donkerder papier, geen zwarte lijn
const POSTIT_LEEG      := Color("#dedad0")  # postit_leeg — lege plek op het bord
const POSTIT_LEEG_RAND := Color("#c4bfb4")  # postit_leeg_rand — rand van een lege plek
# --- GEGENEREERD UIT palette.py, NIET HANDMATIG BEWERKEN — EINDE ---

# Ark Pixel is ontworpen op 10 px. Alleen hele veelvouden blijven scherp, dus
# de ladder is 10 / 20 / 30. Klein onderscheid gaat via kleur, niet via 8 px:
# een pixelfont onder zijn ontwerpmaat wordt onleesbaar.
const FS_SMALL := 10
const FS_BODY := 10
const FS_HEAD := 20
const FS_TITLE := 30


static func panel(bg: Color = PANEL, border: Color = INK, width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(6)
	return sb


## Let op: labels breken standaard af. Een label zonder autowrap rapporteert de
## volledige tekstbreedte als minimum, en een Container groeit daar buiten zijn
## ankers voor uit. Op een canvas van 192 px trekt een enkele lange regel zo de
## hele indeling van het scherm af.
## Een ticket is een briefje op het bord, geen tabelrij. Vandaar papierkleur met
## een rand in een donkerdere tint van datzelfde papier: een zwarte lijn van 1 px
## maakt er op deze schaal een invoerveld van.
static func postit(bg: Color = POSTIT, rand: Color = POSTIT_RAND) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = rand
	sb.set_border_width_all(1)
	# de onderrand iets dikker: dat leest als een briefje dat een beetje omkrult
	sb.border_width_bottom = 2
	sb.set_content_margin_all(4)
	return sb


## Papierkleur per vakgebied. De merk-tinten zijn al pastel, dus ze lezen
## vanzelf als briefjes; geel is de neutrale die BBD zelf niet heeft.
const POSTIT_KLEUREN := {
	&"geel": POSTIT, &"roze": ROZE_TINT, &"blauw": BLUEBIRD_TINT,
	&"groen": GROEN_TINT, &"oranje": ORANJE_TINT,
}


static func postit_kleur(naam: StringName) -> Color:
	return POSTIT_KLEUREN.get(naam, POSTIT)


## Zelfde paneel, maar met een krappe binnenmarge. Voor lijstrijen, waar de
## standaard 6 px een rij van 26 px op 42 px brengt.
static func panel_krap(bg: Color = PANEL, border: Color = INK, width: int = 1) -> StyleBoxFlat:
	var sb := panel(bg, border, width)
	sb.set_content_margin_all(2)
	return sb


static func label(text: String, size: int = FS_BODY, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func rich(size: int = FS_BODY, color: Color = INK) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	return r


static func button(text: String, size: int = FS_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", BLUEBIRD_INK)
	b.add_theme_color_override("font_focus_color", BLUEBIRD_INK)
	b.add_theme_stylebox_override("normal", panel(PANEL, LINE))
	b.add_theme_stylebox_override("hover", panel(WIT, BLUEBIRD_INK))
	b.add_theme_stylebox_override("pressed", panel(BLUEBIRD_TINT, INK))
	b.add_theme_stylebox_override("focus", panel(WIT, BLUEBIRD_INK, 2))
	b.focus_mode = Control.FOCUS_ALL
	return b


static func card(text: String, tint: Color = PANEL) -> Button:
	var b := button(text, FS_SMALL)
	b.add_theme_stylebox_override("normal", panel(tint, LINE))
	b.add_theme_stylebox_override("hover", panel(tint.lightened(0.18), BLUEBIRD_INK))
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(94, 22)
	return b


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	return c


## Een Control die in code onder een eveneens in code gemaakte CanvasLayer hangt
## krijgt geen viewportrect mee en blijft 0x0. Deze helper zet het formaat zelf
## en houdt het bij als het venster verandert.
static func fill_viewport(c: Control) -> Control:
	full_rect(c)
	var fit := func() -> void:
		if is_instance_valid(c) and c.is_inside_tree():
			c.position = Vector2.ZERO
			c.size = c.get_viewport_rect().size
	if c.is_inside_tree():
		fit.call()
		c.get_viewport().size_changed.connect(fit)
	else:
		c.ready.connect(func() -> void:
			fit.call()
			c.get_viewport().size_changed.connect(fit))
	return c


## Halfdoorzichtige achtergrond waardoor je het kantoor nog ziet liggen.
static func dimmer(alpha: float = 0.62) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.05, 0.05, 0.08, alpha)
	full_rect(r)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


static func title_bar(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel(PANEL_DARK, INK))
	var l := label(text, FS_BODY, WIT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return p


## Insets van de veilige zone (notch, statusbalk, home-indicator) in
## canvaspixels, in de volgorde links / boven / rechts / onder.
##
## `DisplayServer.get_display_safe_area()` rekent in fysieke schermpixels,
## terwijl een Control op dit canvas in 192x416 rekent. De schermtransform van
## de viewport is de enige omrekening die zowel de integer-schaal als de
## letterbox-offset meeneemt; een deling door de vensterbreedte doet dat niet
## en schuift de HUD op elk toestel met balken de verkeerde kant op.
static func veilige_insets(c: Control) -> Vector4i:
	if not OS.has_feature("mobile") or not c.is_inside_tree():
		return Vector4i.ZERO
	var scherm := Rect2(DisplayServer.get_display_safe_area())
	if scherm.size.x <= 0.0 or scherm.size.y <= 0.0:
		return Vector4i.ZERO
	var veilig := c.get_viewport().get_screen_transform().affine_inverse() * scherm
	var canvas := c.get_viewport_rect()
	return Vector4i(
		maxi(0, int(ceilf(veilig.position.x - canvas.position.x))),
		maxi(0, int(ceilf(veilig.position.y - canvas.position.y))),
		maxi(0, int(ceilf(canvas.end.x - veilig.end.x))),
		maxi(0, int(ceilf(canvas.end.y - veilig.end.y))))


## Een Control die het scherm vult op de notch na, en die zichzelf bijstelt als
## het venster draait of van formaat verandert.
##
## Hang hier alles aan wat aan een rand plakt. Schermvullende overlays (het
## ticketbord, een dimmer) horen juist aan de ouder: die moeten de hele ruit
## dekken, ook het stuk naast de camera-uitsparing.
static func veilige_laag(ouder: Control) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(c)
	ouder.add_child(c)
	var pas_toe := func() -> void:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		var i := veilige_insets(c)
		c.offset_left = i.x
		c.offset_top = i.y
		c.offset_right = -i.z
		c.offset_bottom = -i.w
	if c.is_inside_tree():
		pas_toe.call()
		c.get_viewport().size_changed.connect(pas_toe)
	else:
		c.ready.connect(func() -> void:
			pas_toe.call()
			c.get_viewport().size_changed.connect(pas_toe))
	return c
