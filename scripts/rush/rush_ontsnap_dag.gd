class_name RushOntsnapDag
extends RefCounted
## Wat de ontsnapping op één dag van de week eigen maakt.
##
## Vijf keer dezelfde rit door hetzelfde kantoor was precies wat Daan saai
## vond. Dus elke dag begint ergens anders in het echte kantoor en heeft één
## ding dat hem anders maakt: maandag leer je sturen, dinsdag staat de
## stand-up in de weg, woensdag zit Dirk je op de hielen, donderdag liggen er
## spoedtickets op riskante plekken en vrijdag is de finale: alles brandt, en
## je moet eerst nog terug naar Weekend om de laptop met de deploy te redden.
##
## De ontsnapping leest alleen deze waarden. Zo staat de hele week op één
## plek, en hoeft niemand door de code te zoeken waar vrijdag sneller is.

enum Dirk {
	GEEN,        ## vandaag niet
	HIELEN,      ## vanaf de eerste seconde vlak achter je
	HALVERWEGE,  ## halverwege de route, van voren of van achteren
}

## Dagnaam in hoofdletters en de titel, voor de uitleg aan het begin.
var naam := ""
var titel := ""
## Eén regel: wat er vandaag anders is.
var regel := ""
## Waar je begint, in tegels van `floor.json`.
var start := Vector2i.ZERO
## Waar je heen rent: -1 naar links (de voordeur), +1 naar rechts. Beweging,
## camera, vuur, pijltjes, voortgangsbalk en de bot lezen allemaal hierop.
var richting := -1
## Waar dit deel ophoudt, in tegels. Leeg: bij de voordeur, en dan ben je
## buiten. Anders pak je daar iets op en gaat het verder met `verder`.
var doel := Rect2i()
## Het volgende deel van de rit (vrijdag: eerst naar de laptop, dan naar huis).
var verder: RushOntsnapDag = null
## Waar de laptop ligt, als je die vandaag moet redden.
var laptop := Vector2i(-1, -1)
## Binnendeuren die vandaag openstaan, bovenop die naar de entree.
var deuren: Array[Vector2i] = []
## Het vuurfront: snelheid als deel van de jouwe, hoe ver het hooguit achter je
## zit, en hoe ver achter je het begint (in pixels).
var vuur := 0.7
var vuur_gat := 100.0
var vuur_begin := 150.0
## Losse collega's langs de route, en hoeveel daarvan je pad in stappen of
## heen en weer lopen. `stap_snel` in px/s, `opmerk` extra px vooruit kijken.
var collegas := 3
var stappers := 1
var ijsberen := 0
var stap_snel := 42.0
var opmerk := 0.0
## Of juist precies hier: tegel en gedrag. Gaat voor `collegas`.
var vaste: Array[Dictionary] = []
var koffie := 3
var kaartjes := 4
## Gouden spoedtickets, op deze tegels.
var spoed: Array[Vector2i] = []
## Kolommen (van, tot) waar de stand-up achtereenvolgens staat.
var standup: Array[Vector2i] = []
var dirk := Dirk.GEEN
## Seconden tussen twee duiken van Dirk, van en tot.
var duik := Vector2(3.0, 4.5)
var plafond := false
## Waar jij op het scherm staat, van links. Verder naar rechts zie je meer
## vooruit; als Dirk achter je zit wil je juist hem kunnen zien.
var camera := 0.66


static func voor(dag: int) -> RushOntsnapDag:
	var d := RushOntsnapDag.new()
	match clampi(dag, 0, 4):
		0:
			# Vanaf je bureau, rechts op De Werkvloer. Rustig: hier leer je
			# sturen, maar het vuur zit je wel al in de nek.
			d.naam = "MAANDAG"
			d.titel = "De gewone weg"
			d.regel = "Brand! Stuur om je collega's heen."
			d.start = Vector2i(67, 19)
			d.vuur = 0.72
			d.vuur_gat = 96.0
			d.collegas = 3
			d.stappers = 1
			d.ijsberen = 1
			d.stap_snel = 46.0
			d.koffie = 2
			d.kaartjes = 2
		1:
			# Rechts in De Gang, waar Birdhouse uitkomt. De stand-up staat drie
			# keer dwars over de vloer: bij Team 1, bij Sales en bij de koffie.
			d.naam = "DINSDAG"
			d.titel = "Stand-up op de gang"
			d.regel = "De stand-up staat in de weg. Zoek het gat!"
			d.start = Vector2i(67, 13)
			d.vuur = 0.74
			d.vuur_gat = 92.0
			d.collegas = 0
			d.standup = [Vector2i(57, 61), Vector2i(39, 42), Vector2i(22, 24)]
			d.koffie = 2
			d.kaartjes = 3
			# Verder vooruit kijken: het gat moet je zien aankomen.
			d.camera = 0.72
		2:
			# Bij Team Run, en Dirk stond al naast je bureau. Het vuur is er
			# ook, maar trager: vandaag is Dirk het probleem.
			d.naam = "WOENSDAG"
			d.titel = "Dirk op je hielen"
			d.regel = "Rode streep? Dirk duikt. Stap opzij!"
			d.start = Vector2i(57, 21)
			d.vuur = 0.6
			d.vuur_gat = 130.0
			d.vuur_begin = 170.0
			d.collegas = 3
			d.stappers = 1
			d.stap_snel = 48.0
			d.dirk = Dirk.HIELEN
			d.duik = Vector2(2.6, 4.0)
			d.koffie = 3
			d.kaartjes = 3
			d.camera = 0.56
		3:
			# Net de deur van Basecamp uit. Vijf spoedtickets, elk op een plek
			# waar het pakken je iets kan kosten: vlak voor iemand, voor de
			# blauwe tijger, in de smalle gang langs het Vergaderhokje, tussen
			# een ijsbeerder en de plantenbak, en vlak voor de deur.
			d.naam = "DONDERDAG"
			d.titel = "Spoed onderweg"
			d.regel = "Gouden spoedtickets: -1,5 s per stuk!"
			d.start = Vector2i(46, 8)
			d.vuur = 0.8
			d.vuur_gat = 80.0
			d.vuur_begin = 80.0
			d.vaste = [
				{"t": Vector2i(38, 9), "g": RushOntsnapCollega.Gedrag.STAAN},
				{"t": Vector2i(28, 17), "g": RushOntsnapCollega.Gedrag.STAPPEN},
				{"t": Vector2i(20, 17), "g": RushOntsnapCollega.Gedrag.IJSBEREN},
				{"t": Vector2i(13, 12), "g": RushOntsnapCollega.Gedrag.STAPPEN},
			]
			d.stap_snel = 52.0
			d.spoed = [Vector2i(40, 9), Vector2i(27, 8), Vector2i(31, 14), Vector2i(20, 15), Vector2i(12, 22)]
			d.koffie = 2
			d.kaartjes = 0
			d.camera = 0.7
		4:
			# De finale, heen en terug. Eerst vanaf je bureau, links op De
			# Werkvloer, met het vuur van links naar rechts: de laptop met de
			# deploy ligt nog in Weekend. Aan de kop van je bureaublok, dus je
			# moet meteen kiezen: boven langs of onder langs het raam. En bij
			# het volgende blok weer.
			d.naam = "VRIJDAG"
			d.titel = "De finale"
			d.regel = "Red eerst de laptop, dan naar buiten!"
			d.start = Vector2i(14, 19)
			d.richting = 1
			# Op het bureau rechtsboven in Weekend; je pakt hem van de twee
			# rijen erboven. Daar kom je alleen via de kolom links van het
			# bureau.
			d.laptop = Vector2i(77, 4)
			d.doel = Rect2i(76, 2, 3, 2)
			_vrijdag(d)
			d.camera = 0.62
			# Dan alles brandt: terug naar de voordeur, de langste weg. Snel
			# vuur, Dirk die halverwege opduikt, collega's die je overal in de
			# weg stappen en een plafond dat naar beneden komt.
			var t := RushOntsnapDag.new()
			t.naam = d.naam
			t.titel = d.titel
			t.regel = d.regel
			t.start = Vector2i(77, 3)
			_vrijdag(t)
			t.dirk = Dirk.HALVERWEGE
			t.duik = Vector2(2.8, 4.4)
			t.camera = 0.62
			d.verder = t
	return d


## Wat beide helften van vrijdag delen. Koffie is er nog één per keer;
## kaartjes zijn al verbrand.
static func _vrijdag(d: RushOntsnapDag) -> void:
	d.deuren = [Vector2i(69, 11), Vector2i(69, 12), Vector2i(69, 13), Vector2i(69, 14)]
	d.vuur = 0.88
	d.vuur_gat = 84.0
	d.vuur_begin = 110.0
	d.collegas = 7
	d.stappers = 5
	d.ijsberen = 1
	d.stap_snel = 70.0
	d.opmerk = 30.0
	d.plafond = true
	d.koffie = 1
	d.kaartjes = 0
