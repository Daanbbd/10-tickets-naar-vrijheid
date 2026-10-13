#!/usr/bin/env bash
# Laat de bot elke dag van de rush spelen met een paar personages en print de
# eindtijden. Bedoeld om te zien of een balanswijziging in
# scripts/rush/rush_data.gd de curve heel laat: maandag ruim drie sterren,
# vrijdag zweten.
#
#     tools/rush_balans.sh [personages...]
set -euo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
WIE=("${@:-victor danny daan jonathan willem}")
for d in 1 2 3 4 5; do
	for s in ${WIE[@]}; do
		"$GODOT" --headless --path . --quit-after 40000 -- --rush-bot --dag=$d --speler=$s --tempo=10 2>&1 \
			| grep --line-buffered -m1 -E "RUSH-BOT|SCRIPT ERROR" &
	done
	wait
done
