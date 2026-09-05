class_name Bark
extends Label
## Een regel die iemand of iets zégt, zonder de wereld stil te zetten.
##
## De dialoogbox is modaal: `Session.lock_input()`, een tik per regel, de wereld
## wacht. Dat is goed voor een gesprek en te zwaar voor een terzijde — een
## collega die iets mompelt als je langsloopt, een opgelost ticket dat je nog
## eens aanraakt. Zo'n regel hoort in de wereld te staan, boven degene die hem
## zegt, en vanzelf weer te verdwijnen. Dezelfde contourletters als de labels
## op wereldobjecten (`WorldObject._maak_label()`), zodat het één taal blijft.
##
## Eén bark per ouder: een nieuwe vervangt de vorige. Geen invoer, geen
## signaal, geen save — dit is presentatie en niets anders.

const BREEDTE := 112.0
const HOOGTE := 24.0
## Hoe lang de regel volop staat voordat hij wegvaagt.
const STANDAARD_DUUR := 2.6
const VAAG_DUUR := 0.45
## Hoe hoog boven de oorsprong van de ouder. Boven het tikkaartje van
## `TapMarker` ("Praten Willem", "Onderzoeken"), dat ook boven het ding hangt
## waar je naast staat — een terzijde en een tikkaartje op dezelfde hoogte
## lezen door elkaar heen.
const STANDAARD_HOOGTE := 54.0


## Zet `tekst` boven `ouder` (een Node2D in de wereld), `hoogte` pixels boven
## zijn oorsprong, en ruimt zichzelf na `duur` + de vervaagtijd op. Geeft de
## Bark terug voor wie hem wil volgen; de aanroeper hoeft er niets mee.
static func toon(ouder: Node2D, tekst: String, duur: float = STANDAARD_DUUR,
		hoogte: float = STANDAARD_HOOGTE) -> Bark:
	if ouder == null or tekst.strip_edges() == "":
		return null
	var oude := ouder.get_node_or_null("Bark") as Bark
	if oude != null:
		oude.queue_free()
	var b := Bark.new()
	b.name = "Bark"
	b.text = tekst
	b.size = Vector2(BREEDTE, HOOGTE)
	b.position = Vector2(-BREEDTE * 0.5, -hoogte - HOOGTE)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.z_index = 20
	b.add_theme_font_size_override("font_size", UiKit.FS_SMALL)
	b.add_theme_color_override("font_color", UiKit.WIT)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", UiKit.INK)
	ouder.add_child(b)
	b._start(duur)
	return b


func _start(duur: float) -> void:
	# Kort opkomen, even staan, wegvagen. `create_tween()` hangt aan deze node,
	# dus een vervangen bark neemt zijn eigen tween mee het graf in.
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	tw.tween_interval(maxf(0.0, duur))
	tw.tween_property(self, "modulate:a", 0.0, VAAG_DUUR)
	tw.tween_callback(queue_free)
