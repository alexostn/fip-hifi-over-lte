#!/bin/bash
# tools/audio-check.sh — one-shot verification of the output chain
#
#   ./audio-check.sh          state only, silent
#   ./audio-check.sh --tone   + sine 440 and pink noise (stop playback first)
#
# Interpretation table: hardware/BLUETOOTH_LDAC.md

set -u
[ -f ~/.config/fip/env ] && . ~/.config/fip/env

echo "── graph ──────────────────────────────────────────"
pw-top -b -n1 2>/dev/null | grep -E "^(R|ID)" || echo "pw-top unavailable"

echo
echo "── sink ───────────────────────────────────────────"
wpctl status | grep -A4 "Sinks:" | grep -v "^--"
echo "volume: $(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)"

echo
echo "── bluetooth ──────────────────────────────────────"
if [ -n "${FIP_BT_MAC:-}" ]; then
    printf 'codec:   %s\n' "$(pactl list sinks 2>/dev/null \
        | grep -A80 bluez_output | grep -m1 -oP 'api\.bluez5\.codec = "\K[^"]+' || echo none)"
    printf 'profile: %s\n' "$(pactl list cards 2>/dev/null \
        | grep -m1 -oP 'Active Profile: \Ka2dp.*' || echo none)"
else
    echo "FIP_BT_MAC unset — analog only"
fi

echo
echo "── expected ───────────────────────────────────────"
cat <<'EOF'
ERR      0, frozen under load
RATE     48000 on every active node
FORMAT   analog: S32LE   bt: F32P -> F32LE
QUANT    2048 on the driver node
volume   <= 1.00 (above that PipeWire clips digitally)
codec    ldac
EOF

[ "${1:-}" = "--tone" ] || exit 0

echo
echo "── tone (Ctrl+C to stop) ──────────────────────────"
pgrep -f fip-stream.sh >/dev/null && echo "(・_・ヾ fip-stream.sh is running — stop it first" && exit 1
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.15
echo "sine 440 — must be dull and even; any rasp = overload or hardware"
speaker-test -c2 -t sine -f 440 -l1 >/dev/null
echo "pink — loads the bass section; pulsing or hoarse = low-end overload"
speaker-test -c2 -t pink -l1 >/dev/null
