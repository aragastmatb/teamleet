#!/bin/bash
# Double-click in Finder: starts the text editor and opens it in the browser. Close this window to stop it.
cd "$(dirname "$0")/../.."
python3 tools/text_editor/server.py
