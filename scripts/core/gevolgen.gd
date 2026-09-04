class_name Gevolgen
extends RefCounted
## Wat de dag met je heeft gedaan.
##
## De tien tickets zijn geen losse sketches. Hóe je ze oploste bepaalt hoe de
## rest van de dag zich gedraagt, en de finale begint met de opgetelde stand.
## Dit is de enige plek waar een minigame-uitkomst betekenis krijgt buiten zijn
## eigen minigame.
##
## Eén richting, altijd: minigame -> payload -> `boek()` -> Session. Een
## minigame schrijft nooit zelf in Session, en niemand anders zet deze sleutels.
##
## Twee soorten uitkomst, bewust gescheiden:
##
## - **Narratieve feiten worden gewone flags.** "Je hebt Jonathan afgekapt" is
##   een `flags_all`-conditie waar elke dialoogvariant al op kan filteren. Dat
##   scheelt een nieuwe conditie-key in `Conditions.KEYS`, het serialiseert
##   gratis mee, en de bestaande validator dekt het meteen.
## - **Getallen komen in `Session.gevolgen`.** Alleen de finale leest die, en
##   alleen via `finale_start()`.

## De vlaggen die deze klasse kan zetten. Staat hier zodat de testsuite kan
## controleren dat elke vlag die de dialoog verwacht ook echt gezet wórdt —
## een typefout in een `flags_all` is anders onzichtbaar: die variant valt
## gewoon nooit.
const VLAGGEN: Array[StringName] = [
	&"gevolg_geen_webshop",
	&"gevolg_paard_beloofd",
	&"gevolg_comicsans_beloofd",
	&"gevolg_scope_te_groot",
	&"gevolg_cro_gehaald",
	&"gevolg_uitlijn_perfect",
	&"gevolg_credits_verbrand",
	&"gevolg_klant_ontevreden",
	&"gevolg_backend_fout_gekozen",
	&"gevolg_veel_geprobeerd",
	&"gevolg_paard_gemist",
]

## Wat er uit een payload wordt overgenomen, per minigame-id. Buiten deze tabel
## wordt géén enkel payload-veld gelezen: een minigame die er morgen een veld
## bij krijgt verandert het spel dan niet stilletjes mee.
const GETALLEN := {
	&"mg_user_story": {&"blij": &"scope_blij", &"punten": &"scope_punten"},
	&"mg_cro": {&"conversie": &"cro_conversie"},
	&"mg_video": {&"gepubliceerd": &"video_gepubliceerd", &"credits_over": &"video_credits"},
	&"mg_planning": {&"tijd_over": &"standup_tijd_over"},
	&"mg_frontend_fix": {&"afwijking_totaal": &"uitlijn_afwijking"},
	&"mg_klantfeedback": {&"score": &"klant_score", &"drempel": &"klant_drempel"},
	&"mg_backend_fix": {&"juist": &"backend_juist"},
	&"mg_abgevecht": {&"hp_a_over": &"ab_hp_a_over"},
	&"mg_paarden": {&"zelf_gevonden": &"paard_zelf_gevonden"},
}

## De wensen uit BBD-201 die groot genoeg zijn om bugs op te leveren. Een app
## en een loyaliteitsprogramma zijn geen features maar projecten; wie die
## belooft, levert ze half af.
const ZWARE_WENSEN: Array[String] = ["app", "loyaliteit", "ai"]


## Neemt één minigame-uitkomst op in de sessie. Aangeroepen door
## `QuestEngine.complete()`, vóór `ticket_completed` en vóór de save, zodat een
## luisteraar op dat signaal de gevolgen al kan lezen.
static func boek(minigame_id: StringName, result: MinigameResult) -> void:
	if result == null:
		return
	var p: Dictionary = result.payload

	for veld: StringName in (GETALLEN.get(minigame_id, {}) as Dictionary):
		if p.has(veld):
			var sleutel: StringName = (GETALLEN[minigame_id] as Dictionary)[veld]
			Session.gevolgen[sleutel] = p[veld]

	match minigame_id:
		&"mg_user_story":
			var mee: Array = p.get(&"meegenomen", [])
			# Je kunt deze minigame halen door het paard en Comic Sans te
			# beloven en de webshop weg te laten. Dat mag, dat is de grap, en
			# dit is waar die grap zich later meldt.
			Session.set_flag(&"gevolg_geen_webshop", not ("vergelijker" in mee))
			Session.set_flag(&"gevolg_paard_beloofd", "paard" in mee)
			Session.set_flag(&"gevolg_comicsans_beloofd", "comicsans" in mee)
			var zwaar := 0
			for w: Variant in mee:
				if String(w) in ZWARE_WENSEN:
					zwaar += 1
			Session.set_flag(&"gevolg_scope_te_groot", zwaar >= 2)
		&"mg_cro":
			Session.set_flag(&"gevolg_cro_gehaald", bool(p.get(&"boven_doel", false)))
		&"mg_frontend_fix":
			Session.set_flag(&"gevolg_uitlijn_perfect", bool(p.get(&"perfect", false)))
		&"mg_video":
			# Niet "heb je gehaald" maar "wat heeft het gekost": vijf clips met
			# tien credits over is een ander verhaal dan vijf met tachtig.
			Session.set_flag(&"gevolg_credits_verbrand", int(p.get(&"credits_over", 100)) < 25)
		&"mg_deploy":
			# Buiten de GETALLEN-tabel gehouden omdat dit geen getallen zijn maar
			# de tekst waarmee de dag afloopt. Het eindscherm is de enige lezer:
			# de oplevering gebeurt in de minigame, maar je hoort pas buiten wat
			# je hebt opgeleverd.
			Session.gevolgen[&"oplevering_titel"] = String(p.get(&"titel", ""))
			Session.gevolgen[&"oplevering_tekst"] = String(p.get(&"tekst", ""))
			Session.gevolgen[&"oplevering_score"] = int(p.get(&"score", 0))
			Session.gevolgen[&"oplevering_foutcode"] = String(p.get(&"foutcode", ""))
		&"mg_klantfeedback":
			# De drempel is per speeldoorloop hetzelfde; de score is wat jij ervan
			# maakte in de drie rondes. Onder de drempel hangt de klant ontevreden
			# op, en dat hoort de finale duurder te maken.
			Session.set_flag(&"gevolg_klant_ontevreden",
				int(p.get(&"score", 0)) < int(p.get(&"drempel", 0)))
		&"mg_backend_fix":
			# Eén kabel, en die kun je goed of fout leggen. Fout gelegd betekent:
			# het werkt zolang niemand er nog eens naar kijkt.
			Session.set_flag(&"gevolg_backend_fout_gekozen", not bool(p.get(&"juist", true)))
		&"mg_abgevecht":
			# Elke oplevering hier is A die wint: verliezen laat het ticket gewoon
			# openstaan voor een nieuwe poging (zie `mg_abgevecht.gd::_afronden()`),
			# dus `a_wint` is bij een geboekte SUCCESS altijd waar — precies
			# hetzelfde patroon als de stand-up (Deel 4). Wat wél varieert is hoe
			# vaak het moest, via de teller die de minigame zelf ophoogt bij elk
			# verlies (`Session.add_counter(&"ab_pogingen")`).
			Session.set_flag(&"gevolg_veel_geprobeerd", Session.get_counter(&"ab_pogingen") >= 2)
		&"mg_paarden":
			# Via het scrumbord of via Bastiaans vakgebiedvoordeel kom je hier
			# zonder ooit zelf een paard te hebben aangesproken. Dat is een
			# geldige route, en toch een andere dag dan wie het paard zelf vond.
			#
			# Ontdekt tijdens het dialoogplan (Ronde C): deze vlag kan alléén
			# true worden als BBD-209 via geen_zoektocht wordt opgelost, en dat
			# is exclusief Bastiaans eigen vakgebiedvoordeel (t09.owner_character
			# == "bastiaan"; TicketController._wh_paarden() blokkeert de route
			# via het bord voor iedereen anders). `npc_layer.gd` spawnt geen NPC
			# voor je eigen personage, dus Bastiaan ziet `collega_bastiaan`'s
			# eigen reactie op deze vlag (`dialogue/npcs.json`) nooit — die
			# variant is dus niet alleen door zijn plek in de variantenlijst
			# onbereikbaar (dat is nu gefixt), maar sowieso, voor de enige
			# speler die 'm ooit kan zetten. Vlag blijft staan (kost geen getest
			# meer sinds P1-6, en misschien leest de finale 'm ooit voor
			# Bastiaan zelf), maar dat is een apart ontwerpbesluit.
			Session.set_flag(&"gevolg_paard_gemist", not bool(p.get(&"zelf_gevonden", true)))


static func getal(sleutel: StringName, fallback: Variant = 0) -> Variant:
	return Session.gevolgen.get(sleutel, fallback)


# --- De finale ------------------------------------------------------------

## De begintoestand van de oplevering, opgeteld uit de hele dag.
##
## Dit is waar de spanningsboog uitkomt. Een zorgvuldige dag begint met twee
## bugs en zeven vertrouwen; een dag waarop je scope te groot liet worden en de
## klant ontevreden hield begint met vier bugs en vier vertrouwen. Dat is een
## merkbaar andere finale, en geen van beide is onhaalbaar — er is geen game
## over, dus een slechte dag maakt de oplevering duurder, niet onmogelijk.
## BBD-202 (Deel 4): de stand-up won ooit een `gevolg_jonathan_gemist`-bonusbug
## op een geslaagde speelbeurt waarin je hem tóch had afgekapt. Die combinatie
## bestaat niet meer: sinds de infobalk is het slagen van de minigame zelf al
## "beide nuttige regels gehoord", dus een geboekte SUCCESS kan `gemist` nooit
## meer gevuld hebben — precies zoals `gevolg_paard_gemist` hierboven (P1-6)
## nooit een straf mocht worden omdat alleen een vakgebiedvoordeel 'm ooit zet.
## Geen compensatie hier, met opzet: de makkelijker-wordende aftocht die deze
## bug voorkwam bestaat niet meer als aftocht — wie Jonathan mist, verliest de
## minigame nu meteen (een retry, geen finale-tax), dus de opgave werd op het
## moment zelf strenger in plaats van dat er verderop iets zachter werd.
## `gevolg_danny_gemist` (`getest` hieronder) is om dezelfde reden weg.
static func finale_start() -> Dictionary:
	var bugs := 3
	if Session.get_flag(&"gevolg_scope_te_groot"):
		bugs += 1
	if Session.get_flag(&"gevolg_uitlijn_perfect"):
		bugs -= 1
	# Een verkeerd gelegde kabel werkt vandaag, en morgen weet niemand nog
	# waarom hij het deed. Dat is een bug die nog moet gebeuren.
	if Session.get_flag(&"gevolg_backend_fout_gekozen"):
		bugs += 1

	var vertrouwen := 5
	vertrouwen += -1 if Session.get_flag(&"gevolg_geen_webshop") else 1
	if Session.get_flag(&"gevolg_paard_beloofd"):
		vertrouwen += 1
	if Session.get_flag(&"gevolg_credits_verbrand"):
		vertrouwen -= 1
	# Een ontevreden klant is iets dat zij hoort of ziet vóór jij het kunt
	# gladstrijken.
	if Session.get_flag(&"gevolg_klant_ontevreden"):
		vertrouwen -= 1

	var getest := 0
	if Session.get_flag(&"gevolg_cro_gehaald"):
		getest += 1
	# BBD-207 (Deel 3): geen client-gevolg meer — Danny's A/B-gevecht speelt
	# zich intern af, dus wat langer duurde om A te laten winnen hoort bij
	# zíjn testwerk (`getest`), niet bij klantvertrouwen (`vertrouwen`). Dat
	# verving de oude `gevolg_verkeerde_merksound`, die client-facing was:
	# een verkeerd gekozen merksound klonk letterlijk door het kantoor.
	if Session.get_flag(&"gevolg_veel_geprobeerd"):
		getest -= 1
	# P1-6: hier stond een `getest -= 1` bij `gevolg_paard_gemist`. Alleen
	# Bastiaans vakgebiedvoordeel (`geen_zoektocht`) kan die vlag ooit zetten —
	# zonder de trait blokkeert `_wh_paarden()` de route via het bord juist
	# (`ticket_controller.gd`), dus "het paard zelf nooit gezien" gebeurde
	# nooit door onoplettendheid, alleen door de trait te gebruiken. Dat botst
	# met de harde regel in `TraitModifier`: een trait geeft alleen voordeel,
	# nooit een straf. De vlag blijft staan (Bastiaan krijgt er een eigen
	# regel over — "wist ik meteen waar hij zat" in dialogue/npcs.json), maar
	# kost geen `getest` meer.

	# Scope is wat je beloofd hebt, niet wat je gebouwd hebt: hoe meer wensen
	# je meenam, hoe meer er in de oplevering mis kan gaan.
	var scope := int(getal(&"scope_punten", 4))

	return {
		&"bugs": clampi(bugs, 1, 6),
		&"vertrouwen": clampi(vertrouwen, 1, 9),
		&"getest": clampi(getest, 0, 3),
		&"scope": clampi(scope, 1, 9),
	}


## Extra configsleutels die een ticket bij zijn minigame krijgt, boven op de
## trait-aanpassing. Alleen de finale gebruikt dit; hij staat hier en niet in
## `TicketController` zodat er één plek is die weet wat de dag betekent.
static func minigame_config(ticket_id: StringName) -> Dictionary:
	if GameData.ticket(ticket_id) == null:
		return {}
	if GameData.ticket(ticket_id).minigame_id != &"mg_deploy":
		return {}
	return {"start_override": finale_start()}


# --- De druk --------------------------------------------------------------

## In welke fase van de dag je zit, 0 t/m 4. Stuurt uitsluitend wanneer De
## Klant zich meldt.
##
## Bewust op ticketaantal en niet op de klok of op je fouten: de tickets staan
## allemaal tegelijk open, dus voortgang is het enige dat voor elke speler in
## dezelfde richting loopt. Wát ze stuurt hangt wél van je keuzes af — dat
## staat in `data/klant_berichten.json` achter gewone `when`-condities.
const DREMPELS: Array[int] = [1, 3, 5, 6, 7, 9]


static func druk() -> int:
	var n := Session.done_count()
	var fase := 0
	for d: int in DREMPELS:
		if n >= d:
			fase += 1
	return fase


## P1-8: tot nu toe had `druk()` precies één afnemer — De Klants
## telefoonberichten. De escalatie was daarmee bijna volledig tekst, terwijl
## GAME_DESIGN.md ook "hoe zwaar de finale begint" aan de opgetelde dag hangt.
## Deze functie geeft elke zone-tint (`scripts/world/main.gd._tint_zone()`)
## dezelfde fase mee: hoe verder de dag gevorderd is, hoe meer een zone naar
## `DRUK_GLOED` toe kantelt.
##
## Puur sfeer, met opzet: `Urenstaat` staat er expliciet bij dat tijd en
## voortgang nooit meer dan een gevoel mogen zijn, nooit een grondstof die iets
## blokkeert. Vandaar een kleurmenging en geen enkele nieuwe conditie.
const DRUK_GLOED := Color(1.05, 0.94, 0.90)
## Bij de zwaarste fase mag de gloed hoogstens dit aandeel van de zone-tint
## overnemen. Hoger voelde bij het uitproberen als een filter over het beeld,
## niet als een kantoor dat drukker aanvoelt.
const DRUK_MAX_MENGING := 0.35


static func tint(zone_kleur: Color) -> Color:
	var sterkte := (float(druk()) / float(DREMPELS.size())) * DRUK_MAX_MENGING
	return zone_kleur.lerp(DRUK_GLOED, sterkte)
