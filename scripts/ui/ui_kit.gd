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
const GRIJS            := Color("#8a8a8a")  # ui_grijs — neutrale derivaat — GEEN tekstkleur, haalt 4,5:1 nergens
const GRIJS_OP_LICHT   := Color("#5a5a5a")  # ui_grijs_op_licht — secundaire tekst op een licht vlak — PANEL, WIT, PAPIER, POSTIT
const GRIJS_OP_DONKER  := Color("#b0b4c2")  # lichtgrijs — secundaire tekst op een donker vlak — PANEL_DARK, INK, de startschermen
const WIT              := Color("#eef0f4")  # wit — neutraal
const BLUEBIRD_INK     := Color("#243cec")  # bb_blue — letterlijk bb-blue, voor lichte ondergrond
const BLUEBIRD_BRIGHT  := Color("#3a86ff")  # ui_bluebird_bright — derivaat voor donkere ondergrond — bb-blue zelf is daar te donker om te lezen
const BLUEBIRD_TINT    := Color("#dbe9ff")  # bb_light_blue — letterlijk bb-light-blue
const GROEN            := Color("#3fae6e")  # ui_groen — derivaat van bb-green, leesbaar op 8-10px — DONKERE ondergrond, zie GROEN_OP_LICHT
const GROEN_TINT       := Color("#d8ffe0")  # bb_green — letterlijk bb-green
const GROEN_OP_LICHT   := Color("#256842")  # ui_groen_op_licht — GROEN op een lichte ondergrond — het scrumbord, de titelscherm-bevestiging
const ROOD             := Color("#e05263")  # ui_rood — game-only utility — BBD heeft geen foutkleur — DONKERE ondergrond, zie ROOD_OP_LICHT
const ROOD_OP_LICHT    := Color("#9c3945")  # ui_rood_op_licht — ROOD op een lichte ondergrond — zelfde reden als GROEN_OP_LICHT
const ORANJE           := Color("#f4a259")  # ui_oranje — derivaat van bb-orange, leesbaar op 8-10px — alleen nog 'doel'
const VASTGEZET        := Color("#9b5de5")  # ui_vastgezet — rand om een vastgeprikt ticket
const OVERWERK         := Color("#e94c82")  # ui_overwerk — de klok voorbij het urenbudget
const GEBOEKT          := Color("#6dcdd6")  # ui_geboekt — tijd die zojuist geboekt is
const ORANJE_TINT      := Color("#f7d6c2")  # bb_orange — letterlijk bb-orange
const ROZE_TINT        := Color("#ffcee3")  # bb_pink — letterlijk bb-pink — gereserveerd voor mensen/cultuur
const NEUTRAAL_TINT    := Color("#e4e4e4")  # ui_neutraal_tint — letterlijk --color-line — voor niet-accent states
const MUUR             := Color("#484e60")  # muur — de muur van het kantoor, ook op het selectiepodium
const SCHERM_NACHT     := Color("#141824")  # ui_scherm_nacht — ondergrond van titel- en uitlegscherm
const SCHERM_DIEP      := Color("#0b0d14")  # ui_scherm_diep — ondergrond van de aftiteling, één tint dieper
const PAPIER           := Color("#e9e4d6")  # ui_papier — een papieren vlak in een minigame
const VAK_LEEG         := Color("#2b3144")  # ui_vak_leeg — een ticketvakje dat niet van jou is
const POSTIT           := Color("#f7e28a")  # postit_geel — papier van een ticket-briefje
const POSTIT_RAND      := Color("#ceb458")  # postit_geel_rand — donkerder papier, geen zwarte lijn
const POSTIT_LEEG      := Color("#dedad0")  # postit_leeg — lege plek op het bord
const POSTIT_LEEG_RAND := Color("#c4bfb4")  # postit_leeg_rand — rand van een lege plek
# --- GEGENEREERD UIT palette.py, NIET HANDMATIG BEWERKEN — EINDE ---

# --- Typografie -----------------------------------------------------------
#
# Ark Pixel wordt per ontwerpmaat als eigen snit uitgeleverd. Dat is de hele
# reden dat deze ladder kan bestaan: `font_size` op één TTF *schaalt* die snit,
# dus een 10px-snit op 12 px is geen 12px-letter maar een uitgerekte 10px-letter
# met halve pixels. 12 en 16 vragen dus een eigen bestand; 20 en 30 zijn hele
# veelvouden van 10 en blijven op de 10px-snit scherp.
#
# Waarom dit moest. FS_SMALL en FS_BODY waren allebei 10, dus élk teken in het
# spel was even groot en de hele hiërarchie liep via kleur. Daardoor moest één
# kleur (ORANJE) vier dingen tegelijk betekenen. Grootte draagt nu het verschil
# tussen bijschrift, lopende tekst en kop; kleur draagt alleen nog betekenis.
const FONT_10 := preload("res://assets/fonts/ark-pixel-10px-proportional-latin.ttf")
const FONT_12 := preload("res://assets/fonts/ark-pixel-12px-proportional-latin.ttf")
const FONT_16 := preload("res://assets/fonts/ark-pixel-16px-proportional-latin.ttf")

const FS_SMALL := 10   ## bijschrift, legenda, secundaire regel
const FS_BODY := 12    ## lopende tekst, knoplabels
const FS_SUB := 16     ## tussenkop, het cijfer waar een minigame om draait
const FS_HEAD := 20    ## schermkop
const FS_TITLE := 30   ## alleen het titelscherm

## Welke snit bij welke maat hoort. 20 en 30 staan bewust op FONT_10: dat is
## 2x en 3x, en een pixelfont op een heel veelvoud blijft scherp.
##
## Er is geen `Theme`-resource in dit project — de globale font staat als los
## bestand in project.godot — dus er is geen plek waar Godot dit vanzelf per
## maat oppakt. Elke constructor hieronder zet daarom zelf zowel de font als de
## font-grootte. Vergeet je de font, dan krijg je een geschaalde 10px-snit en
## ziet niemand dat het mis is, alleen dat het wazig is.
const FONTS := {
	10: FONT_10, 12: FONT_12, 16: FONT_16, 20: FONT_10, 30: FONT_10,
}


## De snit die bij `size` hoort. Een maat buiten de ladder valt terug op de
## 10px-snit; dat is de enige snit waarvan we weten dat hij op elk veelvoud
## klopt.
static func font_voor(size: int) -> FontFile:
	return FONTS.get(size, FONT_10)


## Minimumhoogte van een knop, in canvaspixels. Een duimmaat, geen designkeuze:
## op een 1080-brede telefoon schaalt dit canvas 5x, dus 30 px is ~11 mm. Android
## vraagt 48 dp (~9 mm) als ondergrens; dit zit daar bewust boven, want 48 dp is
## de grens waaronder het misgaat en niet de maat waarop het prettig wordt.
##
## Stond op 24. Dat was krap genoeg dat de knop zijn eigen minimum nooit haalde:
## een Button meldt regelhoogte plus stijlmarges, en dat was al 26. Een
## ondergrens die altijd verliest van de gemeten hoogte stuurt niets aan.
##
## Staat hier en niet in de knoppenbalk omdat de balk zijn eigen hoogte hieruit
## afleidt en de HUD zijn onderste regels daar weer boven hangt: één getal, drie
## lezers.
const KNOP_MIN_H := 30


static func panel(bg: Color = PANEL, border: Color = INK, width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(6)
	return sb


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


## Let op: labels breken standaard af. Een label zonder autowrap rapporteert de
## volledige tekstbreedte als minimum, en een Container groeit daar buiten zijn
## ankers voor uit. Op een canvas van 192 px trekt een enkele lange regel zo de
## hele indeling van het scherm af.
static func label(text: String, size: int = FS_BODY, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font_voor(size))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func rich(size: int = FS_BODY, color: Color = INK) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = false
	r.add_theme_font_override("normal_font", font_voor(size))
	r.add_theme_font_override("bold_font", font_voor(size))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	return r


## Zelfde valkuil als bij `label()`: een Button zonder autowrap meldt zijn
## volledige tekstbreedte als minimum. Een dialoogkeuze als "BBD-202 Waarom sta
## ik hier eigenlijk?" duwde het dialoogpaneel daardoor breder dan het canvas,
## en omdat dat paneel `GROW_DIRECTION_BOTH` heeft viel de tekst aan *beide*
## kanten buiten beeld — de ticketcode links, de titel rechts. Vandaar dat
## afbreken hier de standaard is en niet iets wat elke aanroeper zelf regelt.
##
## De minimumhoogte komt uit `KNOP_MIN_H`; de rekensom staat daar.
##
## **Geen autowrap.** Een gewone knop moet met zijn tekst meegroeien, en een
## Button met autowrap meldt zijn tekstbreedte niet als minimum. Gemeten op
## FS_BODY, met `custom_minimum_size` op 34x34:
##
## | tekst | zonder autowrap | met autowrap |
## |---|---|---|
## | Praten | 55 x 34 | 34 x 34 |
## | Oppakken | 74 x 34 | 34 x 34 |
## | Onderzoeken | 96 x 34 | 34 x 34 |
##
## De actieknop van de duimbesturing draagt het werkwoord van waar je voor
## staat en is rechtsonder verankerd; met autowrap bleef die op 34 px staan en
## las "Oppakken" als "Oppa" met "kken" afgekapt onder de rand.
##
## Een knop die juist in een vaste breedte moet passen — een dialoogkeuze, een
## regel in een keuzelijst — hoort daarom `keuzeknop()` te gebruiken. Die twee
## behoeften zijn tegengesteld en kunnen niet één standaard zijn.
static func button(text: String, size: int = FS_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, KNOP_MIN_H)
	b.add_theme_font_override("font", font_voor(size))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", BLUEBIRD_INK)
	b.add_theme_color_override("font_focus_color", BLUEBIRD_INK)
	b.add_theme_stylebox_override("normal", panel(PANEL, LINE))
	b.add_theme_stylebox_override("hover", panel(WIT, BLUEBIRD_INK))
	b.add_theme_stylebox_override("pressed", panel(BLUEBIRD_TINT, INK))
	b.add_theme_stylebox_override("focus", panel(WIT, BLUEBIRD_INK, 2))
	# Zonder deze override valt een uitgeschakelde knop terug op Godots eigen
	# grijze doos met ronde hoeken, en die komt zichtbaar uit een andere game.
	# Uitgeschakeld hoort hier hetzelfde te zijn als ingeschakeld, maar dan
	# uitgebleekt: zelfde rand, zelfde marges, alleen minder aanwezig.
	b.add_theme_stylebox_override("disabled", panel(NEUTRAAL_TINT, GRIJS))
	b.add_theme_color_override("font_disabled_color", GRIJS)
	b.focus_mode = Control.FOCUS_ALL
	return b


## De knop die het scherm afmaakt: blauw gevuld, één per scherm.
##
## Dit is het antwoord op schermen waar elke knop er hetzelfde uitzag.
## "Beginnen" en "Afsluiten" op het titelscherm waren pixelidentiek, en dan is
## de gevaarlijke knop even uitnodigend als de goede. Een gevulde knop in
## bb-blue leest van een afstand als "hier klik je", en al het andere op dat
## scherm wordt daarmee vanzelf secundair — juist doordat het níet verandert.
##
## Gebruik hem voor de bevestigende actie: doorgaan, starten, opleveren,
## vastleggen. Niet voor weglopen, annuleren of sluiten; die horen de gewone
## `button()` te houden, anders is er weer geen verschil.
##
## De vulling is BLUEBIRD_INK met witte letters. Niet BLUEBIRD_TINT met zwarte:
## die tint is zo licht dat hij naast PANEL nauwelijks opvalt, en dat was
## precies het probleem bij DEPLOYEN — de enige "primaire" knop die het spel
## had, en je zag hem alsnog over het hoofd.
static func knop_primair(text: String, size: int = FS_BODY) -> Button:
	var b := button(text, size)
	b.add_theme_color_override("font_color", WIT)
	b.add_theme_color_override("font_hover_color", WIT)
	b.add_theme_color_override("font_focus_color", WIT)
	b.add_theme_color_override("font_pressed_color", WIT)
	b.add_theme_stylebox_override("normal", panel(BLUEBIRD_INK, BLUEBIRD_INK))
	b.add_theme_stylebox_override("hover", panel(BLUEBIRD_BRIGHT, BLUEBIRD_INK))
	# Ingedrukt gaat donkerder, niet lichter: de knop zakt weg onder je duim.
	b.add_theme_stylebox_override("pressed", panel(BLUEBIRD_INK.darkened(0.35), INK))
	# De focusrand moet leesbaar zijn óp het blauw, dus wit en niet blauw.
	b.add_theme_stylebox_override("focus", panel(BLUEBIRD_BRIGHT, WIT, 2))
	return b


## Een knop voor een keuzelijst: hij past zich aan de beschikbare breedte aan
## in plaats van eraan te trekken.
##
## Dit is de tegenhanger van `button()`. Zonder autowrap meldt een keuze als
## "202 · Waarom sta ik hier eigenlijk?" zijn volle tekstbreedte als minimum,
## en dan groeit het dialoogpaneel — dat `GROW_DIRECTION_BOTH` heeft — aan
## *beide* kanten buiten het canvas: de ticketcode valt links weg en de titel
## rechts. Vandaar afbreken plus meegroeien in de breedte.
static func keuzeknop(text: String, size: int = FS_SMALL) -> Button:
	var b := button(text, size)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func card(text: String, tint: Color = PANEL) -> Button:
	var b := keuzeknop(text, FS_SMALL)
	b.add_theme_stylebox_override("normal", panel(tint, LINE))
	b.add_theme_stylebox_override("hover", panel(tint.lightened(0.18), BLUEBIRD_INK))
	b.custom_minimum_size = Vector2(94, 26)
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
	if not Invoer.is_telefoon() or not c.is_inside_tree():
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
