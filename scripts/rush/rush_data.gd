class_name RushData
extends RefCounted
## Alles wat de kantoor-rush inhoudelijk is: vakken, collega's, tickets en de
## vijf dagen van de sprint. Geen gedrag, alleen data — de rest leest hier.

enum Vak { FE, BE, DATA, KLANT, SCOPE }

const VAK_NAAM := {
	Vak.FE: "Frontend",
	Vak.BE: "Backend",
	Vak.DATA: "Data",
	Vak.KLANT: "Klant",
	Vak.SCOPE: "Scope",
}

const VAK_KLEUR := {
	Vak.FE: Color("#4f86f7"),
	Vak.BE: Color("#a463f2"),
	Vak.DATA: Color("#2fb67c"),
	Vak.KLANT: Color("#ef4f63"),
	Vak.SCOPE: Color("#f59a3c"),
}

## Wie welk vak doet. Twee frontenders en twee backenders, zodat het spel
## speelbaar blijft als je er zelf een van bent.
const VAK_VAN := {
	&"victor": Vak.FE,
	&"bastiaan": Vak.FE,
	&"jonathan": Vak.BE,
	&"koen": Vak.BE,
	&"danny": Vak.DATA,
	&"willem": Vak.KLANT,
	&"daan": Vak.SCOPE,
}

## Volgorde van de bureaus op de vloer: drie, drie, één.
const BUREAU_VOLGORDE: Array[StringName] = [
	&"victor", &"jonathan", &"danny",
	&"bastiaan", &"koen", &"willem",
	&"daan",
]

## Hoe lang een collega over een ticket doet, en hoe snel je het zelf doet als
## het jouw vak is (dan sta je wel stil aan je eigen bureau).
const WERKTIJD := 4.6
const ZELF_WERKTIJD := 2.2

const TITELS := {
	Vak.FE: [
		"Paard moet naar links",
		"Knop is te blauw",
		"Logo groter. Nee, kleiner.",
		"Comic Sans. Ze meent het.",
		"Menu klapt niet uit op haar iPad",
		"Footer staat boven de header",
		"Hero-foto: ander paard",
		"Kan de knop 'meer poppen'?",
		"Favicon is een ezel",
	],
	Vak.BE: [
		"Checkout geeft een 500",
		"Voorraad: -3 zakken hooi",
		"Koppeling met de boekhouding",
		"Database 'een beetje vol'",
		"API van de dierenarts ligt eruit",
		"Cronjob draait twee keer",
		"Wachtwoord vergeten-mail komt niet",
		"Btw op hoefijzers klopt niet",
	],
	Vak.DATA: [
		"Conversie is 0,3%",
		"Waarom kopen paarden niks?",
		"Heatmap: iedereen klikt op het paard",
		"A/B-test: A of B?",
		"Bounce rate 98%",
		"Dashboard is rood. Erg?",
	],
	Vak.KLANT: [
		"Ze belt. Weer.",
		"Kan het morgen al live?",
		"'Even snel' een vraagje",
		"Ze heeft het aan de dierenarts laten zien",
		"Haar neef 'doet ook websites'",
		"Ze stuurt een voice memo van 9 min",
	],
	Vak.SCOPE: [
		"Kan er ook een app bij?",
		"Ook in het Duits?",
		"Paarden-chatbot?",
		"Spaarpunten voor pony's",
		"AI-video van het paard",
		"Abonnement op hooi",
	],
}

## Wat een collega zegt als je hem een ticket brengt. Niet elke keer: een
## kantoor waar iedereen bij elke tik iets roept is geen kantoor maar een koor.
const ONTVANG := {
	&"victor": ["Staat het weer scheef?", "Pixel-perfect. Of niks.", "Wie heeft dit ontworpen?"],
	&"bastiaan": ["Komt goed.", "Even koptelefoon op.", "Ik fix 't."],
	&"jonathan": ["Kan. Maar eerst even uitleggen...", "Dat is eigenlijk heel interessant.", "Wie heeft dit gebouwd? O. Ik."],
	&"koen": ["Kan AI dit niet?", "Ik automatiseer het gewoon.", "Prompt staat klaar."],
	&"danny": ["Wat zegt de data?", "Alles is een funnel.", "Ik draai een test."],
	&"willem": ["Ik bel haar wel.", "Ik zeg dat het goed komt.", "Ze is echt heel aardig hoor."],
	&"daan": ["Past niet in de sprint. Doen we.", "Ik zet hem op de backlog. Bovenaan.", "Scope is scope."],
}

const KLAAR := {
	&"victor": ["Strak.", "Uitgelijnd."],
	&"bastiaan": ["Klaar!", "Gefixt."],
	&"jonathan": ["Klaar. Wil je weten hoe?", "Gedaan."],
	&"koen": ["De AI heeft 't gedaan.", "Geautomatiseerd."],
	&"danny": ["+0,1% conversie!", "Significant."],
	&"willem": ["Ze is blij.", "Opgelost. Voor nu."],
	&"daan": ["Gescoped.", "Afgekaderd."],
}

## Wat De Klant stuurt als een ticket te lang op het bord blijft hangen.
const KLANT_BELT := [
	"Hoi! Even checken hoe het gaat?",
	"Ik zie nog niks veranderen?",
	"Mijn dierenarts vraagt ernaar.",
	"Zal ik even langskomen?",
	"Is het al live? Het is toch klik klik?",
	"Ik heb een voice memo gestuurd!",
	"Mijn paard wordt er onrustig van.",
]

## Jonathan in de stand-up. Hij praat tot iemand hem afkapt.
const KLETS := [
	"Even over de architectuur...",
	"Wat ik eigenlijk wil zeggen...",
	"Kort puntje. Drie punten.",
	"Dus ik zat te denken...",
	"Even een zijstraatje...",
]

const DIRK := [
	"Uren al geboekt?",
	"Even je uren checken!",
	"Op welk ticket boek je dit?",
]

## De sprint. Elke dag voegt één ding toe; vrijdag zit alles erin.
##
## - `interval`: seconden tussen twee nieuwe tickets (met spreiding)
## - `geduld`: seconden voordat De Klant belt over een ticket dat blijft liggen
## - `minuten_per_sec`: hoe hard de klok loopt
const DAGEN := [
	{
		"naam": "Maandag", "kort": "MA",
		"nieuw": "Breng elk ticket naar de juiste collega. Klaar? Naar de server.",
		"vakken": [Vak.FE, Vak.BE],
		"interval": 7.5, "geduld": 34.0, "minuten_per_sec": 3.4,
		"koffie": false, "kletsen": false, "dirk": false, "brand": false,
		"muziek": &"mg_planning",
	},
	{
		"naam": "Dinsdag", "kort": "DI",
		"nieuw": "Danny doet data. En de koffie werkt weer: even sneller lopen.",
		"vakken": [Vak.FE, Vak.BE, Vak.DATA],
		"interval": 6.6, "geduld": 30.0, "minuten_per_sec": 3.4,
		"koffie": true, "kletsen": false, "dirk": false, "brand": false,
		"muziek": &"mg_cro",
	},
	{
		"naam": "Woensdag", "kort": "WO",
		"nieuw": "Willem doet de klant. En Jonathan begint te praten. Kap hem af.",
		"vakken": [Vak.FE, Vak.BE, Vak.DATA, Vak.KLANT],
		"interval": 6.0, "geduld": 28.0, "minuten_per_sec": 3.5,
		"koffie": true, "kletsen": true, "dirk": false, "brand": false,
		"muziek": &"mg_user_story",
	},
	{
		"naam": "Donderdag", "kort": "DO",
		"nieuw": "Daan bewaakt de scope. En Dirk wil je uren. Tik hem weg.",
		"vakken": [Vak.FE, Vak.BE, Vak.DATA, Vak.KLANT, Vak.SCOPE],
		"interval": 5.6, "geduld": 26.0, "minuten_per_sec": 3.6,
		"koffie": true, "kletsen": true, "dirk": true, "brand": false,
		"muziek": &"mg_abgevecht",
	},
	{
		"naam": "Vrijdag", "kort": "VR",
		"nieuw": "Livegang. De server vliegt soms in brand: blussen, dan deployen.",
		"vakken": [Vak.FE, Vak.BE, Vak.DATA, Vak.KLANT, Vak.SCOPE],
		"interval": 5.2, "geduld": 25.0, "minuten_per_sec": 3.6,
		"koffie": true, "kletsen": true, "dirk": true, "brand": true,
		"muziek": &"mg_deploy",
	},
]

const DOEL := 10
const START_MIN := 9 * 60
const EIND_MIN := 17 * 60
## Wanneer je nog twee sterren haalt.
const TWEE_STERREN_MIN := 18 * 60 + 30
## Wat het kost als De Klant belt.
const BEL_BOETE_MIN := 20


static func vak_van(persoon: StringName) -> int:
	return int(VAK_VAN.get(persoon, Vak.FE))


static func sterren_voor(minuut: float) -> int:
	if minuut <= EIND_MIN:
		return 3
	if minuut <= TWEE_STERREN_MIN:
		return 2
	return 1


static func klok(minuut: float) -> String:
	var m := int(minuut)
	return "%02d:%02d" % [(m / 60) % 24, m % 60]


static func kies(lijst: Array) -> String:
	return String(lijst[randi() % lijst.size()])
