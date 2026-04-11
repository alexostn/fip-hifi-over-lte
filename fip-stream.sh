#!/bin/bash
# ٩(◕‿◕)~*✲ FIP RADIO — mobile-stable HiFi stream v14
# Diagnostics layer: replaces fip-reconnects.log with structured JSONL
# + Prometheus textfile metrics for node_exporter --collector.textfile
# Goal: detect root cause of LTE interruptions (DNS / TCP / HTTP / buffer)

declare -A STATIONS
STATIONS[fip]="https://icecast.radiofrance.fr/fip-hifi.aac?id=radiofrance"
STATIONS[rock]="https://icecast.radiofrance.fr/fiprock-hifi.aac?id=radiofrance"
STATIONS[jazz]="https://icecast.radiofrance.fr/fipjazz-hifi.aac?id=radiofrance"
STATIONS[groove]="https://icecast.radiofrance.fr/fipgroove-hifi.aac?id=radiofrance"
STATIONS[world]="https://icecast.radiofrance.fr/fipworld-hifi.aac?id=radiofrance"
STATIONS[nouveautes]="https://icecast.radiofrance.fr/fipnouveautes-hifi.aac?id=radiofrance"
STATIONS[reggae]="https://icecast.radiofrance.fr/fipreggae-hifi.aac?id=radiofrance"
STATIONS[electro]="https://icecast.radiofrance.fr/fipelectro-hifi.aac?id=radiofrance"
STATIONS[hiphop]="https://icecast.radiofrance.fr/fiphiphop-hifi.aac?id=radiofrance"
STATIONS[pop]="https://icecast.radiofrance.fr/fippop-hifi.aac?id=radiofrance"
STATIONS[metal]="https://icecast.radiofrance.fr/fipmetal-hifi.aac?id=radiofrance"
STATIONS[sacre]="https://icecast.radiofrance.fr/fipsacrefrancais-hifi.aac?id=radiofrance"
STATIONS[cultes]="https://icecast.radiofrance.fr/fipcultes-hifi.aac?id=radiofrance"

NAME="${1:-fip}"
URL="${STATIONS[$NAME]}"

# ——( ˘・з・)—— DNS pre-warm via Quad9 ————————————————————————————————————————
HOST=$(echo "$URL" | sed 's|https://||' | cut -d'/' -f1)
dig +short +time=2 +tries=1 "$HOST" @9.9.9.9 >/dev/null 2>&1 &
# ————————————————————————————————————————————————————————————————————————————

# ——( ˘・з・)—— Diagnostics paths ——————————————————————————————————————————————
JSONL="${HOME}/fip-diagnostics.jsonl"       # structured log — one JSON per reconnect
PROM_DIR="${HOME}/.prom-textfile"           # node_exporter textfile dir
PROM_FILE="${PROM_DIR}/fip_stream.prom"
MPV_LOG="/tmp/fip-mpv-last.log"            # mpv's own log — last session only
mkdir -p "$PROM_DIR"
# ————————————————————————————————————————————————————————————————————————————

COUNT=0
SCRIPT_START=$(date +%s)

# ——— helper: gather network context (runs in ~2s max, all parallel) ————————
collect_diagnostics() {
    local exit_code=$1 duration=$2

    # 1. ping — distinguishes "no network" from "server error"
    local ping_rtt
    ping_rtt=$(ping -c 1 -W 2 "$HOST" 2>/dev/null \
        | grep -oP 'time=\K[0-9.]+' || echo "null")
    [ "$ping_rtt" != "null" ] && ping_rtt="${ping_rtt}" || true

    # 2. HTTP probe — did Icecast answer at all?
    local http_code
    http_code=$(curl -o /dev/null -s -w "%{http_code}" \
        --max-time 3 --connect-timeout 2 "$URL" 2>/dev/null || echo "0")

    # 3. DNS resolution time — stall detector
    local dns_ms
    dns_ms=$(dig +stats +time=2 +tries=1 "$HOST" @9.9.9.9 2>/dev/null \
        | grep -i "query time" | grep -oP '\d+(?= msec)' || echo "-1")

    # 4. LTE signal (nmcli — works for WiFi; for LTE modem: mmcli -m 0 --signal-get)
    local signal
    signal=$(nmcli -t -f active,signal dev wifi 2>/dev/null \
        | grep "^yes" | cut -d: -f2 || echo "-1")
    # uncomment if on ModemManager LTE:
    # signal=$(mmcli -m 0 --signal-get 2>/dev/null | grep rssi | grep -oP '[-0-9.]+' || echo "-1")

    # 5. Classify cause from exit_code + network state
    local cause
    if   [ "$ping_rtt" = "null" ];     then cause="no_network"
    elif [ "$exit_code" -eq 0 ];       then cause="clean_exit"
    elif [ "$http_code" -ge 500 ] 2>/dev/null; then cause="server_error"
    elif [ "$http_code" -ge 400 ] 2>/dev/null; then cause="http_4xx"
    elif [ "$duration" -lt 5 ];        then cause="fast_fail"    # DNS/TCP likely
    else                                    cause="stream_drop"  # genuine LTE drop
    fi

    # ——— write JSONL ———————————————————————————————————————————————————————
    printf '{"ts":"%s","count":%d,"station":"%s","duration_s":%d,"exit_code":%d,"ping_ms":%s,"http_code":%s,"dns_ms":%s,"lte_signal":%s,"cause":"%s"}\n' \
        "$(date -Iseconds)" "$COUNT" "$NAME" "$duration" "$exit_code" \
        "${ping_rtt:-null}" "$http_code" "$dns_ms" "$signal" "$cause" \
        >> "$JSONL"

    # ——— write Prometheus textfile ————————————————————————————————————————
    # node_exporter reads this if started with:
    # --collector.textfile.directory=$HOME/.prom-textfile
    cat > "${PROM_FILE}.tmp" << PROM
# HELP fip_reconnect_total Total reconnections since script start
# TYPE fip_reconnect_total counter
fip_reconnect_total{station="$NAME"} $COUNT
# HELP fip_session_duration_seconds Duration of last playback session in seconds
# TYPE fip_session_duration_seconds gauge
fip_session_duration_seconds{station="$NAME"} $duration
# HELP fip_ping_ms Ping RTT to Icecast host at reconnect time (-1 = no network)
# TYPE fip_ping_ms gauge
fip_ping_ms{station="$NAME",host="$HOST"} ${ping_rtt/-1/0}
# HELP fip_http_response_code HTTP response code from stream URL probe
# TYPE fip_http_response_code gauge
fip_http_response_code{station="$NAME"} $http_code
# HELP fip_dns_ms DNS resolution time in ms at reconnect (-1 = skipped)
# TYPE fip_dns_ms gauge
fip_dns_ms{station="$NAME",resolver="quad9"} $dns_ms
# HELP fip_lte_signal LTE/WiFi signal level 0-100 (-1 = unavailable)
# TYPE fip_lte_signal gauge
fip_lte_signal $signal
# HELP fip_cause_total Reconnect count by inferred cause
# TYPE fip_cause_total counter
fip_cause_total{station="$NAME",cause="$cause"} $COUNT
PROM
    mv "${PROM_FILE}.tmp" "$PROM_FILE"   # atomic write — no partial scrape
}
# ————————————————————————————————————————————————————————————————————————————

if [ -n "$URL" ]; then
    echo "٩(◕‿◕) FIP 14 $NAME — 192kbps Hi-Fi (mobile-stable + diagnostics)"
    echo "  log:   $JSONL"
    echo "  prom:  $PROM_FILE"
    echo "  mpv:   $MPV_LOG"

    while true; do
        SESSION_START=$(date +%s)

        MPV_ARGS=(
            --no-video
            --audio-channels=stereo
            --audio-format=s16
            --audio-samplerate=48000
            --audio-buffer=6.0

            # cache
            --cache=yes
            --demuxer-max-bytes=8MiB
            --demuxer-readahead-secs=20
            --cache-pause=no
            --cache-pause-initial=no
            --demuxer-lavf-o-append=fflags=+discardcorrupt
            --demuxer-lavf-o-append=err_detect=ignore_err

            # network
            --stream-buffer-size=512KiB
            --network-timeout=10

            # reconnect
            --stream-lavf-o-append=reconnect=1
            --stream-lavf-o-append=reconnect_streamed=1
            --stream-lavf-o-append=reconnect_on_network_error=yes
            --stream-lavf-o-append=reconnect_on_http_error=4xx,5xx
            --stream-lavf-o-append=reconnect_delay_max=10

            # mpv own log — overwrites each session (keep last only)
            --log-file="$MPV_LOG"
            --msg-level=all=warn,network=debug  # network debug, rest warn-only
        )

        mpv "${MPV_ARGS[@]}" "$URL"
        EXIT_CODE=$?

        SESSION_END=$(date +%s)
        SESSION_DURATION=$((SESSION_END - SESSION_START))
        COUNT=$((COUNT + 1))

        # diagnostics in background — does NOT block the reconnect
        collect_diagnostics "$EXIT_CODE" "$SESSION_DURATION" &

        echo "( ˘・з・)・・・ #${COUNT} interrupted (${SESSION_DURATION}s) — reconnect after 1s…"
        sleep 1
    done
else
    echo "stations: fip rock jazz groove world reggae electro hiphop pop metal sacre cultes nouveautes"
fi

# ——— analysis shortcuts ———————————————————————————————————————————————————————
# tail JSON:          tail -f ~/fip-diagnostics.jsonl | jq .
# cause breakdown:    jq -r '.cause' ~/fip-diagnostics.jsonl | sort | uniq -c | sort -rn
# short sessions:     jq 'select(.duration_s < 10)' ~/fip-diagnostics.jsonl
# no-network events:  jq 'select(.cause == "no_network")' ~/fip-diagnostics.jsonl
# dns stalls (>500ms):jq 'select(.dns_ms > 500)' ~/fip-diagnostics.jsonl
# —————————————————————————————————————————————————————————————————————————————
