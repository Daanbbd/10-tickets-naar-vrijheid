#!/usr/bin/env bash
# Exporteert de webbuild en zet hem live op GitHub Pages.
#
# De build staat op een losse gh-pages-branch en niet in de hoofdgeschiedenis:
# een wasm van 38 MB en een pck van 29 MB per versie laten die anders in korte
# tijd ontsporen. Die branch wordt elke keer opnieuw aangelegd en force-pushed,
# dus er is precies één versie van de build in de repo.
#
#     tools/deploy_web.sh
#
# Draai eerst de testsuite. Dit script publiceert de werkboom zoals hij is,
# ongecommitte wijzigingen inbegrepen.

set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
WORTEL="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(git -C "$WORTEL" remote get-url origin)"
TIJD="$(date '+%Y-%m-%d %H:%M')"

cd "$WORTEL"

echo "==> Exporteren"
# Eerst leegmaken, en niet alleen aanmaken. `build/web` ligt binnen de
# projectmap, dus de PNG's die een vorige export daar achterliet (index.png,
# index.icon.png, index.apple-touch-icon.png) worden bij de volgende run door
# Godot geïmporteerd als gewone projectresources -- en belanden dan in de pck,
# met hun .import-bestanden erbij in de gepubliceerde map. Elke deploy
# vervuilde zo de volgende: de webbuild van 3 september 08:03 droeg 13 kB dode
# iconen mee en drie .import-bestanden die niemand opvraagt.
rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --path . --export-release Web build/web/index.html

# Godot herschrijft project.godot bij elke run en gooit daarbij instellingen weg
# die op hun standaardwaarde staan, commentaar incluis. Zie de commit
# "Webexport op het LAN". Vandaar deze waarschuwing in plaats van een stille diff.
if ! git diff --quiet project.godot; then
	echo "!! project.godot is door de export gewijzigd. Controleer met:"
	echo "     git diff project.godot"
fi

echo "==> Publiceren"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp build/web/* "$TMP/"
touch "$TMP/.nojekyll"

git -C "$TMP" init -q -b gh-pages
git -C "$TMP" remote add origin "$REPO"
git -C "$TMP" add -A
git -C "$TMP" commit -q -m "Webbuild $TIJD"
git -C "$TMP" push -f -q origin gh-pages

echo "==> Live (Pages heeft ~1 minuut nodig)"
echo "    https://daanbbd.github.io/10-tickets-naar-vrijheid/"
