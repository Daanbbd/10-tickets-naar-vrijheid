#!/usr/bin/env bash
# Exporteert de webbuild naar build/web, zonder te publiceren.
#
# Voor lokaal playtesten: daarna `python3 tools/serve_web.py --http` (of de
# "web"-configuratie in .claude/launch.json) en open
# http://127.0.0.1:8060/index.html. Publiceren doet tools/deploy_web.sh.
#
# Twee dingen die in een worktree anders misgaan:
#   * export_presets.cfg is gitignored en bestaat alleen in de hoofdcheckout;
#     hij wordt hier gekopieerd als hij ontbreekt.
#   * een verse worktree heeft geen importcache (.godot/), dan eerst
#     `Godot --headless --path . --import`; dit script doet dat als de cache
#     ontbreekt.
#
#     tools/export_web.sh

set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
WORTEL="$(cd "$(dirname "$0")/.." && pwd)"
HOOFD="${HOOFDCHECKOUT:-/Users/daan/Documents/fun}"

cd "$WORTEL"

if [[ ! -f export_presets.cfg ]]; then
	if [[ -f "$HOOFD/export_presets.cfg" ]]; then
		echo "==> export_presets.cfg ontbreekt, kopiëren uit $HOOFD"
		cp "$HOOFD/export_presets.cfg" .
	else
		echo "!! Geen export_presets.cfg hier en niet in $HOOFD" >&2
		exit 1
	fi
fi

if [[ ! -f .godot/global_script_class_cache.cfg ]]; then
	echo "==> Geen importcache, eerst importeren (~1 minuut)"
	"$GODOT" --headless --path . --import
fi

echo "==> Exporteren naar build/web"
# Leegmaken en niet alleen aanmaken: zie de toelichting in tools/deploy_web.sh.
rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --path . --export-release Web build/web/index.html

if ! git diff --quiet project.godot; then
	echo "!! project.godot is door de export gewijzigd. Controleer met:"
	echo "     git diff project.godot"
fi

echo "==> Klaar. Serveren: python3 tools/serve_web.py --http"
echo "    http://127.0.0.1:8060/index.html"
