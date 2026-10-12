class_name RushProfielScherm
extends Control
## Jezelf maken. (Tijdelijk leeg; wordt gebouwd.)

signal klaar(opgeslagen: bool)


func _ready() -> void:
	klaar.emit.call_deferred(false)
