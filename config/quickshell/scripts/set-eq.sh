#!/usr/bin/env bash
# usage: set-eq.sh <gain1> ... <gain10>      (dB, one per band)
#
# Pushes band gains into the PipeWire filter-chain sink created in
# configuration.nix. The node id is looked up each time because it changes
# whenever PipeWire restarts.
set -uo pipefail

[ "$#" -eq 10 ] || { echo "need 10 gains, got $#" >&2; exit 1; }

id=$(pw-cli ls Node 2>/dev/null |
     awk '/id [0-9]+,/ { cur = $2; sub(",", "", cur) }
          /node.name = "effect_input.eq10"/ { print cur; exit }')

[ -n "${id:-}" ] || { echo "equalizer sink not found" >&2; exit 1; }

params=""
for i in $(seq 1 10); do
    [ -n "$params" ] && params="$params, "
    params="$params\"eq_band_$i:Gain\" $(eval echo \${$i})"
done

pw-cli s "$id" Props "{ params = [ $params ] }" >/dev/null
