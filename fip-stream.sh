#!/bin/bash
# ٩(◕‿◕)~*✲ FIP RADIO — mobile-stable HiFi stream v16.2
# AUDIO: PipeWire backend (s32 format) — native graph, no ALSA bridge errors
# Diagnostics: JSONL + Prometheus textfile for node_exporter
# Logs: ~/fip-diagnostics.jsonl | ~/.prom-textfile/fip_stream.prom | /tmp/fip-mpv-last.log
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  v16 CHANGES — micro-cut fix (confirmed by grep corrupt/discard = 2)   │
# │                                                                         │
# │  PROBLEM: fflags=+discardcorrupt silently dropped damaged AAC frames    │
# │           causing 20-50ms silent gaps (audible as micro-cuts on LTE)   │
# │                                                                         │
# │  1. fflags=+discardcorrupt  → +genpts   (concealment instead of drop)  │
# │  2. err_detect=ignore_err   → careful   (soft error recovery)          │
# │  3. cache-pause=no          → yes       (pause > play on underrun)     │
# │  4. cache-pause-wait        → 0.5       (trigger threshold in seconds) │
# │  5. demuxer-max-bytes       → 32MiB     (double headroom for LTE burst)│
# │  6. audio-buffer            → 2.0       (shift reserve to demuxer)     │
# │                                                                         │
# │  v16.2 CHANGES — AO fix + term-msg fix + network tuning                │
# │                                                                         │
# │  FINDING: ao=alsa → AO:(error) floatp on every session                 │
# │           PipeWire-ALSA bridge rejected s16 format request             │
# │           real AO was fine: [cplayer] showed [pipewire] s32 correctly  │
# │           (error) in term-msg = ${audio-out-detected-device} returned  │
# │           empty string before PipeWire stream reached streaming state  │
# │           pw-top ERR=0, sink s32le RUNNING — stack confirmed healthy   │
# │           mtr hop3 26.7% loss — LTE tower instability, not script      │
# │           CPU 50°C — no thermal throttling                             │
# │                                                                         │
# │  7. ao=alsa           → pipewire  (direct native PipeWire graph)       │
# │  8. audio-format=s16  → s32       (match PipeWire native S32LE graph)  │
# │  9. term-playing-msg  → fixed     (remove ${audio-out-detected-device})│
# │  10. network-timeout  → 15        (more tolerance for LTE stall)       │
# │  11. reconnect_delay_max → 5      (faster retry on short LTE drops)    │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ——— HOW TO VERIFY ————————————————————————————————————————————————————————
#
#   1. real AO health — check [cplayer] line, NOT [term-msg]:
#        grep "\[cplayer\].*AO:" /tmp/fip-mpv-last.log | tail -1
#        v16.2 OK: [cplayer] AO: [pipewire] 48000Hz stereo 2ch s32
#        NOTE: [term-msg] AO: line may show (error) — known false alarm,
#              ${audio-out-detected-device} is empty before stream=streaming
#
#   2. sink running — confirm PipeWire output is active:
#        pactl list sinks short
#        OK: alsa_output...analog-stereo  s32le 2ch 48000Hz  RUNNING
#
#   3. corrupt/discard frame count — root cause of micro-cuts:
#        grep -c "corrupt\|discarding\|DTS" /tmp/fip-mpv-last.log
#        v15 baseline: 2  |  v16+ target: 0
#
#   4. PipeWire xrun check — audio stack health:
#        pw-top
#        ERR column all zeros = clean (confirmed Jun 26 2026)
#
#   5. network quality — real TCP, not ping (Icecast blocks ICMP):
#        for i in $(seq 1 10); do
#          curl -o /dev/null -s -w "connect:%{time_connect}s  ttfb:%{time_starttransfer}s\n" \
#          --max-time 3 "https://icecast.radiofrance.fr/fip-hifi.aac?id=radiofrance"
#        done
#        ttfb stable <0.8s = good LTE | ttfb >1s or 0.000s = jitter/cut source
#
#   6. LTE path quality — hop-by-hop loss:
#        mtr --report --report-cycles 15 --tcp --port 443 icecast.radiofrance.fr
#        hop3 loss% = your LTE tower  (v16.2 baseline: 26.7% StDev 33ms)
#        hop7 ~93% loss = transit ICMP block, not real traffic loss
#
#   7. live cache depth — run in second terminal while streaming:
#        watch -n1 "grep -oP 'Cache: \K[0-9.]+' /tmp/fip-mpv-last.log | tail -5"
#        0.0s = underrun event = cut source confirmed
#
# ————————————————————————————————————————————————————————————————————————————

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
JSONL="${HOME}/fip-diagnostics.jsonl"
PROM_DIR="${HOME}/.prom-textfile"
PROM_FILE="${PROM_DIR}/fip_stream.prom"
MPV_LOG="/tmp/fip-mpv-last.log"
mkdir -p "$PROM_DIR"
# ————————————————————————————————————————————————————————————————————————————

COUNT=0

# ——— helper: gather network context (~2s max, all parallel) ——————————————————
collect_diagnostics() {
local exit_code=$1 duration=$2

# 1. ping — NOTE: Icecast blocks ICMP → null result is expected, not an error
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
if [ "$ping_rtt" = "null" ]; then cause="no_network"
elif [ "$exit_code" -eq 0 ]; then cause="clean_exit"
elif [ "$http_code" -ge 500 ] 2>/dev/null; then cause="server_error"
elif [ "$http_code" -ge 400 ] 2>/dev/null; then cause="http_4xx"
elif [ "$duration" -lt 5 ]; then cause="fast_fail"
else cause="stream_drop"
fi

# ——— write JSONL ——————————————————————————————————————————————————————————
printf '{"ts":"%s","count":%d,"station":"%s","duration_s":%d,"exit_code":%d,"ping_ms":%s,"http_code":%s,"dns_ms":%s,"lte_signal":%s,"cause":"%s"}\n' \
"$(date -Iseconds)" "$COUNT" "$NAME" "$duration" "$exit_code" \
"${ping_rtt:-null}" "$http_code" "$dns_ms" "$signal" "$cause" \
>> "$JSONL"

# ——— write Prometheus textfile ————————————————————————————————————————————
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
mv "${PROM_FILE}.tmp" "$PROM_FILE" # atomic write — no partial scrape

}
# ————————————————————————————————————————————————————————————————————————————

if [ -n "$URL" ]; then
echo "٩(◕‿◕) FIP 16.2 $NAME — 192kbps Hi-Fi (PipeWire s32 + micro-cut fix)"

while true; do
SESSION_START=$(date +%s)

MPV_ARGS=(
# --- audio -------------------------------------------------------
--no-video
--audio-channels=stereo

# [v16.2 CHANGED] ao: alsa → pipewire
#   alsa: PipeWire-ALSA bridge rejected s16 → AO:(error) in [cplayer]
#   pipewire: direct native graph, s32, ERR=0 confirmed by pw-top
--ao=pipewire
# --ao=alsa  # v15-v16.1: PipeWire-ALSA bridge path — caused AO:(error)

# [v16.2 CHANGED] audio-format: s16 → s32
#   s32 matches PipeWire native S32LE graph — zero-copy, no upmix conversion
#   confirmed: pactl list sinks short → s32le 2ch 48000Hz RUNNING
--audio-format=s32
# --audio-format=s16  # v15-v16.1: forced extra s16→S32LE conversion loop

--audio-samplerate=48000    # matches FIP native rate

# --- terminal stats ----------------------------------------------
# press i in terminal → shows codec, bitrate, cache depth live
# verify AO via: grep "\[cplayer\].*AO:" /tmp/fip-mpv-last.log | tail -1
#
# [v16.2 FIXED] removed ${audio-out-detected-device} from term-playing-msg
#   that variable returns empty string before PipeWire stream reaches
#   "streaming" state → mpv rendered it as (error) → misleading in log
#   real AO status is always in [cplayer] line, not [term-msg]
--term-playing-msg='(+) Audio: ${audio-codec} ${audio-params/channels}ch ${audio-params/samplerate}Hz ${audio-params/format}\nA: ${playback-time} Cache: ${demuxer-cache-duration:.1}s'
# --term-playing-msg='...AO: [${audio-out-detected-device}]...'  # v15-v16.1: showed (error)

# --- buffer: micro-cut prevention (v16 changes) ------------------
#
# [v16 CHANGED] audio-buffer: 10.0 → 2.0
#   large AO buffer masked underruns instead of triggering cache-pause
--audio-buffer=2.0
# --audio-buffer=10.0  # v15

--cache=yes

# [v16 CHANGED] demuxer-max-bytes: 16MiB → 32MiB
#   absorbs LTE burst retransmissions without starving decoder
--demuxer-max-bytes=32MiB
# --demuxer-max-bytes=16MiB  # v15

--demuxer-readahead-secs=30

# [v16 CHANGED] cache-pause: no → yes
#   brief pause on underrun > playing from empty buffer (= micro-cut)
--cache-pause=yes
# --cache-pause=no  # v15: played through empty buffer → audible micro-cuts

# [v16 NEW] cache-pause-wait=0.5 — pause when cache drops below 0.5s
--cache-pause-wait=0.5

--cache-pause-initial=no    # start immediately, no pre-buffer wait

# [v16 CHANGED] fflags: +discardcorrupt → +genpts
#   discardcorrupt: silently drops damaged AAC frames → 20-50ms silence gaps
#   genpts: regenerates timestamps, decoder applies error concealment instead
#   ROOT CAUSE CONFIRMED: grep -c "corrupt\|discarding\|DTS" = 2 on v15
--demuxer-lavf-o-append=fflags=+genpts
# --demuxer-lavf-o-append=fflags=+discardcorrupt  # v15: root cause of micro-cuts

# [v16 CHANGED] err_detect: ignore_err → careful
#   ignore_err: silent broken frame delivery to decoder
#   careful: soft concealment — fills gap with interpolated audio
--demuxer-lavf-o-append=err_detect=careful
# --demuxer-lavf-o-append=err_detect=ignore_err  # v15

# --- network -----------------------------------------------------
--stream-buffer-size=512KiB

# [v16.2 CHANGED] network-timeout: 10 → 15
#   mtr confirmed 26.7% packet loss on LTE hop3 — need more stall tolerance
--network-timeout=15
# --network-timeout=10  # v16

# --- reconnect ---------------------------------------------------
--stream-lavf-o-append=reconnect=1
--stream-lavf-o-append=reconnect_streamed=1
--stream-lavf-o-append=reconnect_on_network_error=yes
--stream-lavf-o-append=reconnect_on_http_error=4xx,5xx

# [v16.2 CHANGED] reconnect_delay_max: 10 → 5
#   LTE drops are short bursts — faster retry reduces audible gap
--stream-lavf-o-append=reconnect_delay_max=5
# --stream-lavf-o-append=reconnect_delay_max=10  # v16

--stream-lavf-o-append=rw_timeout=15000000
--stream-lavf-o-append=user_agent='Mozilla/5.0 (compatible; fip-hifi-stream/16.2; LTE)'

--log-file="$MPV_LOG"
--msg-level=network=debug
)

mpv "${MPV_ARGS[@]}" "$URL"
EXIT_CODE=$?

SESSION_END=$(date +%s)
SESSION_DURATION=$((SESSION_END - SESSION_START))
COUNT=$((COUNT + 1))

collect_diagnostics "$EXIT_CODE" "$SESSION_DURATION" & # non-blocking

echo "( ˘・з・)・・・ #${COUNT} interrupted (${SESSION_DURATION}s) — reconnect after 1s…"
sleep 1
done
else
echo "stations: fip rock jazz groove world reggae electro hiphop pop metal sacre cultes nouveautes"
fi

# ——— analysis shortcuts ——————————————————————————————————————————————————————
# tail live:       tail -f ~/fip-diagnostics.jsonl | jq .
# cause breakdown: jq -r '.cause' ~/fip-diagnostics.jsonl | sort | uniq -c | sort -rn
# short sessions:  jq 'select(.duration_s < 10)' ~/fip-diagnostics.jsonl
# no-network:      jq 'select(.cause == "no_network")' ~/fip-diagnostics.jsonl
# dns stalls:      jq 'select(.dns_ms > 500)' ~/fip-diagnostics.jsonl
# ————————————————————————————————————————————————————————————————————————————
# ——— v15 → v16 → v16.2 diagnostic evidence ——————————————————————————————————
#
# TEST 1 — corrupt frame count (v15, Jun 26 2026 ~17:29 CEST):
#   grep -c "corrupt\|discarding\|DTS" /tmp/fip-mpv-last.log
#   result: 2 → fflags=+discardcorrupt dropped 2 AAC frames → micro-cuts
#
# TEST 2 — AO health (v16.2, Jun 26 2026 ~19:04 CEST):
#   grep "\[cplayer\].*AO:" /tmp/fip-mpv-last.log | tail -1
#   result: [cplayer] AO: [pipewire] 48000Hz stereo 2ch s32  ← correct
#   NOTE: [term-msg] showed AO:(error) floatp — false alarm,
#         ${audio-out-detected-device} was empty pre-streaming-state
#   pactl list sinks short → s32le 2ch 48000Hz RUNNING  ← confirmed healthy
#
# TEST 3 — network path (Jun 26 2026 ~18:29 CEST):
#   curl ttfb loop     → 0.45–1.04s jitter (580ms spread), 1 timeout
#   mtr hop3           → 26.7% loss, StDev 33ms — LTE tower instability
#   mtr hop7 par1.neo  → 93.3% loss — transit ICMP block, not real loss
#   pw-top ERR         → 0 everywhere — PipeWire graph clean
#   sensors CPU        → 50°C Package — no thermal throttling
#   ping 100% loss     → expected: Icecast blocks ICMP
#
# POST-PATCH TARGETS:
#   grep "[cplayer].*AO:" /tmp/fip-mpv-last.log | tail -1
#   → [cplayer] AO: [pipewire] 48000Hz stereo 2ch s32
#   grep -c "corrupt\|discarding\|DTS" /tmp/fip-mpv-last.log
#   → 0
# ————————————————————————————————————————————————————————————————————————————
