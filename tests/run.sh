#!/bin/bash
# Runs every Luau unit test (tests/*.spec.luau) with Lune (cargo install
# lune). Only pure modules are tested; anything needing the game is checked
# in Studio. Exits non-zero if any spec fails.
cd "$(dirname "$0")/.." || exit 1
status=0
for spec in tests/*.spec.luau; do
	echo "== $spec"
	lune run "$spec" || status=1
done
exit $status
