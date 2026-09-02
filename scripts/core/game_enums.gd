class_name GameEnums
extends RefCounted
## Gedeelde enums. Staat los van de autoloads zodat signal-signatures ze
## op parse-time kunnen typeren zonder circulaire afhankelijkheid.

enum TicketState {
	LOCKED,     ## Nog niet vrijgespeeld.
	AVAILABLE,  ## Vrijgespeeld, speler heeft hem nog niet opgepakt.
	ACTIVE,     ## Opgepakt, in behandeling.
	DONE,       ## Opgelost.
}

## Hoe de collega van een ticket ervoor staat. Vier standen in plaats van een
## bool, want "hij loopt met je mee" en "hij is er al geweest" zijn allebei niet
## "je moet hem nog halen" en lezen op het scherm heel anders.
enum HelperStand {
	EIGEN,     ## Jouw vakgebied; er hoeft niemand mee.
	NODIG,     ## Je moet hem nog ophalen.
	MEE,       ## Hij loopt achter je aan.
	GEWEEST,   ## Hij is bij het object geweest; er valt niets meer te halen.
}

enum Outcome {
	SUCCESS,
	FAIL,
	ABORT,
}

const TICKET_STATE_LABEL := {
	TicketState.LOCKED: "Geblokkeerd",
	TicketState.AVAILABLE: "Open",
	TicketState.ACTIVE: "In behandeling",
	TicketState.DONE: "Opgelost",
}
