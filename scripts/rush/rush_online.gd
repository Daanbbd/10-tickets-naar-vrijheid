class_name RushOnline
extends RefCounted
## Het online scorebord. Staat uit zolang `ADRES` leeg is; dan doet het spel
## niets online en blijft alles op het apparaat.
##
## (Tijdelijk: alleen de vorm. De echte versie komt met de server in `server/`.)

const ADRES := ""


static func actief() -> bool:
	return ADRES != ""
