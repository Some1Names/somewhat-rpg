#!/bin/bash
# Runs the Luau unit tests with Lune (cargo install lune). Only pure
# modules are tested; anything needing the game is checked in Studio.
cd "$(dirname "$0")/.." && lune run tests/Keybinds.spec.luau
