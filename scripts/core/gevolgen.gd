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
	&"gevolg_jonathan_gemist",
	&"gevolg_danny_gemist",
	&"gevolg_geen_webshop",
	&"gevolg_paard_beloofd",
	&"gevolg_comicsans_beloofd",
	&"gevolg_scope_te_groot",
	&"gevolg_cro_gehaald",
	&"gevolg_uitlijn_perfect",
	&"gevolg_credits_verbrand",
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
		&"mg_planning":
			# Wie je afkapte weet je zelf; wát je daarmee misliep niet. Jonathan
			# meldde een structurele bug, Danny dat de checkout wegvalt. Die
			# informatie is precies wat de finale duurder maakt.
			var gemist: Array = p.get(&"gemist", [])
			Session.set_flag(&"gevolg_jonathan_gemist", "jonathan" in gemist)
			Session.set_flag(&"gevolg_danny_gemist", "danny" in gemist)
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


static func getal(sleutel: StringName, fallback: Variant = 0) -> Variant:
	return Session.gevolgen.get(sleutel, fallback)


# --- De finale ------------------------------------------------------------

## De begintoestand van de oplevering, opgeteld uit de hele dag.
##
## Dit is waar de spanningsboog uitkomt. Een zorgvuldige dag begint met twee
## bugs en zeven vertrouwen; een dag waarop je Jonathan afkapte en een app
## beloofde begint met vijf bugs en drie vertrouwen. Dat is een merkbaar
## andere finale, en geen van beide is onhaalbaar — er is geen game over, dus
## een slechte dag maakt de oplevering duurder, niet onmogelijk.
static func finale_start() -> Dictionary:
	var bugs := 3
	if Session.get_flag(&"gevolg_jonathan_gemist"):
		bugs += 1
	if Session.get_flag(&"gevolg_scope_te_groot"):
		bugs += 1
	if Session.get_flag(&"gevolg_uitlijn_perfect"):
		bugs -= 1

	var vertrouwen := 5
	vertrouwen += -1 if Session.get_flag(&"gevolg_geen_webshop") else 1
	if Session.get_flag(&"gevolg_paard_beloofd"):
		vertrouwen += 1
	if Session.get_flag(&"gevolg_credits_verbrand"):
		vertrouwen -= 1

	var getest := 0
	if Session.get_flag(&"gevolg_cro_gehaald"):
		getest += 1
	if Session.get_flag(&"gevolg_danny_gemist"):
		getest -= 1

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
const DREMPELS: Array[int] = [3, 5, 7, 9]


static func druk() -> int:
	var n := Session.done_count()
	var fase := 0
	for d: int in DREMPELS:
		if n >= d:
			fase += 1
	return fase
