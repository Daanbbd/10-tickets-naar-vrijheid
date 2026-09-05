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

## Hoe vaak de speler bij een mislukte poging "Goed genoeg. Shippen." koos.
## `TicketController._ship_gebrekkig()` hoogt hem op; een teller en geen vlag,
## want de tweede keer is een andere dag dan de eerste: de finale rekent elke
## keer als een bug door (`finale_start()`), het eindscherm noemt het aantal.
const GEBREKKIG_TELLER := &"gebrekkig_geshipt"


## De vlag per ticket dat gebrekkig live ging, zodat een dialoog erop kan
## filteren. De teller hierboven weet hoe vaak; deze weet wélk.
static func gebrekkig_vlag(ticket_id: StringName) -> StringName:
	return StringName("geshipt_gebrekkig_%s" % ticket_id)


## Hoe vaak je vandaag "goed genoeg" zei tegen iets dat het niet was.
static func gebrekkig_geshipt() -> int:
	return Session.get_counter(GEBREKKIG_TELLER)


## Hoeveel tickets pas na je acht uur dichtgingen — de finale zelf (t10) niet
## meegerekend, die ís het na-vijven-werk dat hier beoordeeld wordt. Leest
## `Session.completed_at`, gevuld in `QuestEngine.complete()` ná de boeking van
## de ticketuren, dus "af om 17:30" is inclusief het werk zelf. Na vijven test
## niemand meer: wat dan dichtgaat, gaat ongetest de oplevering in.
##
## Na een JSON-save zijn de minuten floats; vandaar `int()` eromheen.
static func ongetest_na_vijf() -> int:
	var n := 0
	for id: StringName in Session.completed_at:
		if id == &"t10":
			continue
		if int(Session.completed_at[id]) >= Urenstaat.BUDGET_MIN:
			n += 1
	return n


## De ene som die de minigame (`mg_oplevering._score()`) en de testsuite delen,
## zodat er geen kopie is die stilletjes uit de pas kan lopen. Vertrouwen en
## scope zijn wat je oplevert, bugs is wat je meelevert (dubbel, want elke bug
## is er één die zíj vindt), en getest is wat je erover weet — tot een plafond
## van twee controles per bug waarmee je begon; daarna moet winst uit fixen
## komen, anders is acht keer de suite draaien de hoogste score van het spel.
## Wie nooit heeft gekeken (`bugs_bekend` false) betaalt per bug nog eens
## extra: blind deployen was met nul handelingen te winnen, en dat is precies
## het gedrag dat de minigame wil afleren.
##
## Ontbrekende sleutels in `toestand` tellen als nul, zodat de suite ook met
## een halve toestand kan rekenen.
static func oplevering_score(toestand: Dictionary, start_bugs: int, bugs_bekend: bool) -> int:
	var plafond := maxi(2, start_bugs * 2)
	var bugs := int(toestand.get(&"bugs", 0))
	var s := (int(toestand.get(&"vertrouwen", 0))
		+ mini(int(toestand.get(&"getest", 0)), plafond)
		- bugs * 2
		+ int(toestand.get(&"scope", 0)))
	if not bugs_bekend:
		# Blind deployen: elke ongeteste bug telt dubbel.
		s -= bugs
	return s


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
## Dit is waar de spanningsboog uitkomt. Vier getallen, elk met zijn bereik en
## zijn reden:
##
## - **bugs (1..8)** — wat je meelevert. Twee heb je altijd; er komt één bij
##   voor een te grote scope en één voor de verkeerd gelegde kabel, er gaat
##   één af voor een perfecte uitlijning. Daarbovenop wat de dag zelf deed:
##   elk ticket dat pas na je acht uur dichtging is ongetest (tot drie), elke
##   keer "goed genoeg, shippen" is een bug waar je zelf bij stond (tot drie),
##   en per drie scope-punten boven de acht komt er één bij — hoe meer je
##   belooft, hoe meer er mis kan gaan.
## - **vertrouwen (1..9)** — wat zij van je gelooft. Vijf, plus één mét de
##   webshop of min één zonder, min één voor verbrande credits en min één voor
##   een ontevreden klant (dat hoort zij vóór jij het kunt gladstrijken). Het
##   paard levert geen vertrouwen meer op: het zit in elke winnende set van
##   BBD-201, dus die bonus had nul variantie. De vlag blijft voor de dialoog.
## - **getest (0..3)** — wat je erover weet. Eén voor de CRO-doelstelling, één
##   voor een stand-up met adem over (>= 8 s) en één voor een pijplijn met
##   credits over (>= 60): tijd die je overhield is tijd die je ergens in stak.
##   Min één als A pas na twee verliezen won.
## - **scope (1..9)** — wat je beloofd hebt, niet wat je gebouwd hebt:
##   `scope_punten - 6`, zodat de 8..13 die BBD-201 kan opleveren als 2..7
##   binnenkomt in plaats van als altijd-negen.
##
## Een zorgvuldige dag begint dus met één bug en zes vertrouwen; een dag met te
## grote scope, een foute kabel, drie tickets na vijven en een ontevreden klant
## met zeven bugs en drie vertrouwen. Merkbaar anders, en geen van beide
## onhaalbaar — er is geen game over, een slechte dag maakt de oplevering
## duurder, niet onmogelijk.
##
## Historie, beknopt. P1-6: `gevolg_paard_gemist` kostte hier ooit `getest`,
## maar alleen Bastiaans vakgebiedvoordeel (`geen_zoektocht`) kan die vlag
## zetten en een trait geeft nooit een straf (`TraitModifier`); de vlag blijft
## voor zijn eigen dialoogregel. BBD-202 (Deel 4): `gevolg_jonathan_gemist` en
## `gevolg_danny_gemist` zijn weg — sinds de infobalk is slagen zelf al "beide
## regels gehoord", en wie mist verliest de minigame meteen (een retry, geen
## finale-tax). BBD-207 (Deel 3): Danny's A/B-gevecht speelt zich intern af,
## dus veel proberen kost `getest` en niet `vertrouwen` — dat verving de
## client-facing `gevolg_verkeerde_merksound`.
static func finale_start() -> Dictionary:
	var scope_punten := int(getal(&"scope_punten", 4))

	var bugs := 2
	if Session.get_flag(&"gevolg_scope_te_groot"):
		bugs += 1
	# Een verkeerd gelegde kabel werkt vandaag, en morgen weet niemand nog
	# waarom hij het deed. Dat is een bug die nog moet gebeuren.
	if Session.get_flag(&"gevolg_backend_fout_gekozen"):
		bugs += 1
	if Session.get_flag(&"gevolg_uitlijn_perfect"):
		bugs -= 1
	# Na vijven test niemand meer, en "goed genoeg" is een bug waar je zelf bij
	# stond. Allebei afgetopt op drie: een rampdag moet duur zijn, niet
	# onspeelbaar.
	bugs += mini(3, ongetest_na_vijf())
	bugs += mini(3, gebrekkig_geshipt())
	# Per drie punten boven de acht die je minimaal belooft komt er één bij.
	# Integer-deling, met opzet: 8..10 kost niets, 11..13 kost één.
	bugs += maxi(0, (scope_punten - 8) / 3)

	var vertrouwen := 5
	vertrouwen += -1 if Session.get_flag(&"gevolg_geen_webshop") else 1
	if Session.get_flag(&"gevolg_credits_verbrand"):
		vertrouwen -= 1
	# Een ontevreden klant is iets dat zij hoort of ziet vóór jij het kunt
	# gladstrijken.
	if Session.get_flag(&"gevolg_klant_ontevreden"):
		vertrouwen -= 1

	var getest := 0
	if Session.get_flag(&"gevolg_cro_gehaald"):
		getest += 1
	# Tijd die je overhield is tijd die je ergens in stak: een stand-up met
	# adem over en een pijplijn met credits over tellen als testwerk.
	if float(getal(&"standup_tijd_over", 0.0)) >= 8.0:
		getest += 1
	if int(getal(&"video_credits", 0)) >= 60:
		getest += 1
	# BBD-207 (Deel 3): Danny's gevecht is intern werk, dus dit kost `getest`.
	if Session.get_flag(&"gevolg_veel_geprobeerd"):
		getest -= 1

	# Scope is wat je beloofd hebt, niet wat je gebouwd hebt. BBD-201 levert
	# 8..13 punten; min zes maakt daar 2..7 van, en dan verschilt het ook echt.
	var scope := scope_punten - 6

	return {
		&"bugs": clampi(bugs, 1, 8),
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
