#!/bin/bash
# ٩(◕‿◕)~*✲ FIP RADIO — mobile-stable HiFi stream v15
# AUDIO: ALSA backend (s16 format) — stable on weak LTE, bypasses PipeWire
# Diagnostics: JSONL + Prometheus textfile for node_exporter
# Logs: ~/fip-diagnostics.jsonl | ~/.prom-textfile/fip_stream.prom | /tmp/fip-mpv-last.log

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

# ——( ˘・з・)—— Diagnostics paths (shown in mpv window on start) ———————————————
JSONL="${HOME}/fip-diagnostics.jsonl"
PROM_DIR="${HOME}/.prom-textfile"
PROM_FILE="${PROM_DIR}/fip_stream.prom"
MPV_LOG="/tmp/fip-mpv-last.log"
mkdir -p "$PROM_DIR"
# ————————————————————————————————————————————————————————————————————————————

COUNT=0

# ——— helper: gather network context (~2s max, all parallel) ———————————————
collect_diagnostics() {
    local exit_code=$1 duration=$2

    # 1. ping — distinguishes "no network" from "server error"
    local ping_rtt
    ping_rtt=$(ping -c 1 -W 2 "$HOST" 2>/dev/null \
        | grep -oP 'time=\K[0-9.]+' || echo "null")

    # 2. HTTP probe — did Icecast answer at all?
    local http_code
    http_code=$(curl -o /dev/null -s -w "%{http_code}" \
        --max-time 3 --connect-timeout 2 "$URL" 2>/dev/null || echo "0")

    # 3. DNS resolution time — stall detector
    local dns_ms
    dns_ms=$(dig +stats +time=2 +tries=1 "$HOST" @9.9.9.9 2>/dev/null \
        | grep -i "query time" | grep -oP '\d+(?= msec)' || echo "-1")

    # 4. LTE signal (nmcli for WiFi; mmcli -m 0 --signal-get for LTE modem)
    local signal
    signal=$(nmcli -t -f active,signal dev wifi 2>/dev/null \
        | grep "^yes" | cut -d: -f2 || echo "-1")

    # 5. Classify cause
    local cause
    if   [ "$ping_rtt" = "null" ];             then cause="no_network"
    elif [ "$exit_code" -eq 0 ];               then cause="clean_exit"
    elif [ "$http_code" -ge 500 ] 2>/dev/null; then cause="server_error"
    elif [ "$http_code" -ge 400 ] 2>/dev/null; then cause="http_4xx"
    elif [ "$duration" -lt 5 ];                then cause="fast_fail"
    else                                            cause="stream_drop"
    fi

    # ——— write JSONL ——————————————————————————————————————————————————————
    printf '{"ts":"%s","count":%d,"station":"%s","duration_s":%d,"exit_code":%d,"ping_ms":%s,"http_code":%s,"dns_ms":%s,"lte_signal":%s,"cause":"%s"}\n' \
        "$(date -Iseconds)" "$COUNT" "$NAME" "$duration" "$exit_code" \
        "${ping_rtt:-null}" "$http_code" "$dns_ms" "$signal" "$cause" \
        >> "$JSONL"

    # ——— write Prometheus textfile ————————————————————————————————————————
    cat > "${PROM_FILE}.tmp" << PROM
# HELP fip_reconnect_total Total reconnections since script start
# TYPE fip_reconnect_total counter
fip_reconnect_total{station="$NAME"} $COUNT
# HELP fip_session_duration_seconds Duration of last playback session
# TYPE fip_session_duration_seconds gauge
fip_session_duration_seconds{station="$NAME"} $duration
# HELP fip_ping_ms Ping RTT to Icecast host at reconnect (-1 = no network)
# TYPE fip_ping_ms gauge
fip_ping_ms{station="$NAME",host="$HOST"} ${ping_rtt/-1/0}
# HELP fip_http_response_code HTTP response code from stream URL probe
# TYPE fip_http_response_code gauge
fip_http_response_code{station="$NAME"} $http_code
# HELP fip_dns_ms DNS resolution time in ms (-1 = skipped)
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
    echo "٩(◕‿◕) FIP 15 $NAME — 192kbps Hi-Fi (mobile-stable + diagnostics)"
    echo " "
    echo "  log:   $JSONL"
    echo "  prom:  $PROM_FILE"
    echo "  mpv:   $MPV_LOG"
    echo " "
    echo "  Shift+I to see detais (；゜゜)ノ "
    
    while true; do
        SESSION_START=$(date +%s)

        MPV_ARGS=(
            # --- audio -------------------------------------------------------
            --audio-channels=stereo
            --ao=alsa                 # ALSA backend is stable on weak LTE, supports int formats natively
            --audio-format=s16        # ALSA supports s16 without format errors (float not supported by ALSA in practice)
            --audio-samplerate=48000  # matches FIP native rate

            # --- buffer: absorbs 1-3s LTE gaps silently ----------------------
            --audio-buffer=10.0
            --cache=yes
            --demuxer-max-bytes=16MiB
            --demuxer-readahead-secs=30
            --cache-pause=no
            --cache-pause-initial=no
            --demuxer-lavf-o-append=fflags=+discardcorrupt
            --demuxer-lavf-o-append=err_detect=ignore_err

            # --- network -----------------------------------------------------
            --stream-buffer-size=512KiB
            --network-timeout=10

            # --- reconnect ---------------------------------------------------
            --stream-lavf-o-append=reconnect=1
            --stream-lavf-o-append=reconnect_streamed=1
            --stream-lavf-o-append=reconnect_on_network_error=yes
            --stream-lavf-o-append=reconnect_on_http_error=4xx,5xx
            --stream-lavf-o-append=reconnect_delay_max=10
            --stream-lavf-o-append=rw_timeout=15000000
            --stream-lavf-o-append=user_agent='Mozilla/5.0 (compatible; fip-hifi-stream/15; LTE)'

            --log-file="$MPV_LOG"
        )

        mpv "${MPV_ARGS[@]}" "$URL"
        EXIT_CODE=$?

        SESSION_END=$(date +%s)
        SESSION_DURATION=$((SESSION_END - SESSION_START))
        COUNT=$((COUNT + 1))

        collect_diagnostics "$EXIT_CODE" "$SESSION_DURATION" &  # non-blocking

        echo "( ˘・з・)・・・ #${COUNT} interrupted (${SESSION_DURATION}s) — reconnect after 1s…"
        sleep 1
    done
else
    echo "stations: fip rock jazz groove world reggae electro hiphop pop metal sacre cultes nouveautes"
fi

# ——— analysis shortcuts ——————————————————————————————————————————————————————
# tail live:          tail -f ~/fip-diagnostics.jsonl | jq .
# cause breakdown:    jq -r '.cause' ~/fip-diagnostics.jsonl | sort | uniq -c | sort -rn
# short sessions:     jq 'select(.duration_s < 10)' ~/fip-diagnostics.jsonl
# no-network events:  jq 'select(.cause == "no_network")' ~/fip-diagnostics.jsonl
# dns stalls >500ms:  jq 'select(.dns_ms > 500)' ~/fip-diagnostics.jsonl
# ————————————————————————————————————————————————————————————————————————————

