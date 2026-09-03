#!/usr/bin/env python3
"""Verschuift de x-coordinaten in objects.json en npcs.json mee met de
ingekorte vloer, en laat zien waar het handwerk zit.

Wegwerpgereedschap voor één verhuizing. De tabel zelf staat in gen_floor.py,
want dat is de enige plek waar de oude en de nieuwe maat samen betekenis hebben;
hier importeren we hem zodat er niet twee definities ontstaan die uit elkaar
kunnen lopen.

Een mechanische afbeelding kan niet kloppen, want ze weet niet waar een object
vóór is. Vandaar dat dit script per coordinaat de oude en de nieuwe buren print:
verschillen die twee, dan moet je het met de hand zetten.
"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "generators"))
import gen_floor

def remap_x(x):
    for lo, hi, lo2, hi2 in gen_floor.X_REMAP:
        if lo <= x <= hi:
            if hi == lo:
                return lo2
            return lo2 + round((x - lo) * (hi2 - lo2) / (hi - lo))
    raise ValueError("x=%d valt buiten X_REMAP" % x)

def buren(grid, x, y):
    uit = []
    for dx, dy, naam in ((0, 0, "op"), (-1, 0, "w"), (1, 0, "o"), (0, -1, "n"), (0, 1, "z")):
        nx, ny = x + dx, y + dy
        if 0 <= ny < len(grid) and 0 <= nx < len(grid[0]):
            uit.append("%s=%s" % (naam, grid[ny][nx]))
    return " ".join(uit)

def main():
    oud = json.load(open("/tmp/floor_oud.json"))["grid"]
    nieuw = json.load(open(os.path.join(gen_floor._data(), "floor.json")))["grid"] \
        if False else json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "floor.json")))["grid"]

    for pad, sleutels in (("objects.json", None), ("npcs.json", None)):
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", pad)
        data = json.load(open(p, encoding="utf-8"))
        print("=" * 78)
        print(pad)
        print("=" * 78)
        for e in data:
            naam = e.get("world_id") or e.get("id")
            punten = []
            if "tile" in e:
                punten.append(("tile", e["tile"]))
            if "home_tile" in e:
                punten.append(("home", e["home_tile"]))
            for i, wp in enumerate(e.get("route", [])):
                punten.append(("route[%d]" % i, wp))
            for label, (x, y) in punten:
                nx = remap_x(x)
                bo, bn = buren(oud, x, y), buren(nieuw, nx, y)
                vlag = "   " if bo == bn else " ! "
                print("%s%-22s %-9s (%3d,%2d) -> (%3d,%2d)  oud[%s]  nieuw[%s]"
                      % (vlag, naam, label, x, y, nx, y, bo, bn))

if __name__ == "__main__":
    main()
