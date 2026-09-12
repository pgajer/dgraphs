#!/bin/zsh
set -e
LAB_ROOT="$(cd "$(dirname "$0")" && pwd)"
LAB_URL="$(/usr/bin/python3 "$LAB_ROOT/scripts/start.py")"
open "$LAB_URL"
