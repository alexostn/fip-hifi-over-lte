# lib/output.sh — output profile selection
#
#   FIP_OUT=analog   (default) built-in ALSA sink, tuned in v16.3
#   FIP_OUT=bt                 A2DP/LDAC, needs FIP_BT_MAC
#
# Exports OUT_ARGS[] for mpv. Rationale for every flag: hardware/BLUETOOTH_LDAC.md

FIP_OUT="${FIP_OUT:-analog}"
OUT_ARGS=()

_out_analog() {
    # s32 matches the PipeWire ALSA graph — zero conversion (v16.2)
    OUT_ARGS=( --ao=pipewire --audio-format=s32 --volume=100 )
    echo "(⌐■_■) analog · S32LE 48000"
}

_out_bt() {
    # ◐ take FIP_BT_MAC · ◐ if empty, stop · ◐ say this exact thing
    #   ":?" is bash's built-in "required or die" check — not a loop, not an
    #   if, just: read the variable, and if it's unset, print the message and
    #   exit right here. The leading ":" is a no-op, only there to host the check.
    : "${FIP_BT_MAC:?FIP_OUT=bt requires FIP_BT_MAC (see config/env.example)}"

    local id="${FIP_BT_MAC//:/_}"
    BT_CARD="bluez_card.${id}"
    BT_SINK="bluez_output.${id}.1"

    # LDAC profile is bare "a2dp-sink" — "a2dp-sink-ldac" is not an entity
    bt_codec() {
        pactl list sinks 2>/dev/null \
            | sed -n "/Name: ${BT_SINK}\$/,/^Sink #/p" \
            | grep -m1 -oP 'api\.bluez5\.codec = "\K[^"]+'
    }

    bluetoothctl info "$FIP_BT_MAC" 2>/dev/null | grep -q "Connected: yes" \
        || bluetoothctl connect "$FIP_BT_MAC" >/dev/null 2>&1 && sleep 2

    local codec; codec=$(bt_codec)
    if [ "$codec" != "ldac" ] && [ -n "$codec" ]; then
        pactl set-card-profile "$BT_CARD" a2dp-sink >/dev/null 2>&1
        sleep 2; codec=$(bt_codec)
    fi

    if [ -z "$codec" ]; then
        echo "(⊙_⊙) no BT sink — falling back to default"
        OUT_ARGS=( --ao=pipewire --volume=100 )
        return
    fi

    # no --audio-format here: forcing one adds a conversion right before
    # the LDAC encoder. F32P -> F32LE is de-interleave only.
    OUT_ARGS=( --ao=pipewire --volume=100 --audio-device="pipewire/${BT_SINK}" )
    echo "(⌐■_■) bluetooth · ${codec} · 48000"
}

out_preflight() {
    case "$FIP_OUT" in
        analog) _out_analog ;;
        bt)     _out_bt ;;
        *)      echo "(・_・ヾ unknown FIP_OUT=$FIP_OUT — using analog"; _out_analog ;;
    esac
}
