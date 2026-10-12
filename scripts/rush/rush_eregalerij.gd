class_name RushEregalerij
extends Control
## De eregalerij. (Tijdelijk leeg; wordt gebouwd.)

signal terug


func _ready() -> void:
	terug.emit.call_deferred()
