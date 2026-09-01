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
