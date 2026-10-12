class_name RushTicket
extends Node2D
## Eén ticket: een kaartje met de kleur en het icoon van zijn vak.
##
## Het kaartje hangt aan het bord, zit in je handen, ligt op een bureau of
## verdwijnt in de server. Het tekent zichzelf; waar het hangt bepaalt het spel.

enum Staat { BORD, HAND, WERK, KLAAR, LIVE }

const B := 12
const H := 14

## 5 breed; '#' is een pixel in de vakkleur.
const ICONEN := {
	RushData.Vak.FE: [".#.#.", "#...#", ".#.#."],
	RushData.Vak.BE: [".###.", "#...#", ".###.", "#...#", ".###."],
	RushData.Vak.DATA: ["....#", "..#.#", "..#.#", "#.#.#", "#.#.#"],
	RushData.Vak.KLANT: ["#####", "#...#", "#####", ".#...", "#...."],
	RushData.Vak.SCOPE: [".###.", "#...#", "..##.", ".....", "..#.."],
}

var vak: int = RushData.Vak.FE
var titel: String = ""
var nummer: int = 0
var staat: Staat = Staat.BORD
## 1 = net binnen, 0 = ze belt.
var geduld: float = 1.0
## Hoe vaak ze al over dit ticket gebeld heeft; elke keer raakt ze sneller op.
var gebeld: int = 0
var werker: Node = null

var _wiebel: float = 0.0


func _process(delta: float) -> void:
	_wiebel += delta
	if staat == Staat.BORD or staat == Staat.KLAAR:
		queue_redraw()


func _draw() -> void:
	var kleur: Color = RushData.VAK_KLEUR[vak]
	var o := Vector2(-B / 2.0, -H / 2.0)
	if staat == Staat.BORD and geduld < 0.3:
		o.x += sin(_wiebel * 40.0) * 1.0

	# Schaduw, papier, kleurband, rand.
	draw_rect(Rect2(o + Vector2(1, 1), Vector2(B, H)), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(o, Vector2(B, H)), Color("#fbf8ef"))
	draw_rect(Rect2(o, Vector2(B, 4)), kleur)
	draw_rect(Rect2(o, Vector2(B, H)), kleur.darkened(0.45), false, 1.0)

	var icoon: Array = ICONEN[vak]
	var start := o + Vector2(4, 5 + (5 - icoon.size()) / 2.0 * 1.0)
	for y: int in icoon.size():
		var rij: String = icoon[y]
		for x: int in rij.length():
			if rij[x] == "#":
				draw_rect(Rect2(start + Vector2(x - 0.5, y + 1), Vector2(1, 1)), kleur.darkened(0.25))

	# Geduld: een balkje onder het kaartje, van groen via geel naar rood.
	if staat == Staat.BORD or staat == Staat.KLAAR:
		var g := clampf(geduld, 0.0, 1.0)
		var bk := Color("#3fae6e").lerp(Color("#f2c14e"), clampf((0.7 - g) / 0.35, 0.0, 1.0))
		bk = bk.lerp(Color("#e5484d"), clampf((0.35 - g) / 0.3, 0.0, 1.0))
		draw_rect(Rect2(o + Vector2(0, H + 2), Vector2(B, 2)), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(o + Vector2(0, H + 2), Vector2(B * g, 2)), bk)
	if gebeld > 0 and staat != Staat.LIVE:
		draw_rect(Rect2(o + Vector2(B - 3, -3), Vector2(5, 5)), Color("#e5484d"))
		draw_rect(Rect2(o + Vector2(B - 1, -2), Vector2(1, 2)), Color.WHITE)
		draw_rect(Rect2(o + Vector2(B - 1, 1), Vector2(1, 1)), Color.WHITE)


func code() -> String:
	return "BBD-%d" % nummer
