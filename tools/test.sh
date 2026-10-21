#!/bin/sh
# Opens Team1337 right where a playtest starts, so there's no playing through everything to get there.
#   tools/test.sh               — list the test points
#   tools/test.sh vika_call     — a story scene (data/dialogues), a chat scene, or chapter2..chapter4
# The days before are played automatically (teamlead/devtest.gd). This overwrites the local save.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
if [ -z "$1" ]; then
	echo "Story scenes:"
	grep -h '^==' data/dialogues/*.dlg | sed 's/^== */  /'
	echo "Chat scenes:"
	echo "  dima_question"
	echo "Chapters:"
	echo "  chapter2  chapter3  chapter4"
	exit 0
fi
exec "$GODOT" --path . -- --start "$1"
