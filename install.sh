#!/usr/bin/env bash
# Link this repo into place. Kept for muscle memory — it is `rice link`.
#
#   ./install.sh            link everything
#   ./install.sh --dry-run  show what would happen, touch nothing
#
# On a fresh machine, `local/bin/rice install` does this and the rest
# (NixOS rebuild, Spotify, VS Code extensions) in one go.
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/local/bin/rice" link "$@"
