#!/bin/bash
# ٩(◕‿◕)~*✲ FIP RADIO — mobile-stable HiFi stream v13

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

# ——( ˘・з・)—— DNS pre-warm via Quad9 (9.9.9.9 — no-log, Switzerland) ————————
# Problem: after LTE drop+reconnect, operator DNS can stall 2–10s before
# resolving — adds silence on every reconnect even before mpv starts.
# Fix: fire a dig at startup → populates OS resolver cache (systemd-resolved).
# Each subsequent mpv reconnect reuses the cached entry — no DNS round-trip.
# URL stays unchanged (hostname, not IP) → HTTPS cert validates correctly.
HOST=$(echo "$URL" | sed 's|https://||' | cut -d'/' -f1)
dig +short +time=2 +tries=1 "$HOST" @9.9.9.9 >/dev/null 2>&1 &
# ————————————————————————————————————————————————————————————————————————————

LOG="${HOME}/fip-reconnects.log"
COUNT=0

if [ -n "$URL" ]; then
    echo "٩(◕‿◕) FIP 13 $NAME — 192kbps Hi-Fi (mobile-stable)"
    while true; do
        MPV_ARGS=(
            --no-video
            --audio-channels=stereo
            --audio-format=s16              # 16-bit int — enough for AAC 192k; floatp for DSP
            --audio-samplerate=48000        # matches FIP stream native rate
            --audio-buffer=6.0             # 6s buffer — absorbs mobile network dips (was 2.0)

            # --- cache: live-stream safe mode --------------------------------
            --cache=yes                     # enable demuxer cache for smoother playback
            --demuxer-max-bytes=8MiB        # ~5min max demuxer buffer at 192k AAC
            --demuxer-readahead-secs=20     # read 20s ahead to survive short outages
            --cache-pause=no                # no freezes — errors handled by reconnect loop
            --cache-pause-initial=no        # no silence while cache fills on start/reconnect
            --demuxer-lavf-o-append=fflags=+discardcorrupt   # drop corrupt AAC frames after mid-stream reconnect
            --demuxer-lavf-o-append=err_detect=ignore_err    # ignore AAC decoder errors — no crash on malformed frames

            # --- network -----------------------------------------------------
            --stream-buffer-size=512KiB    # TCP-level read buffer; smooths burst drops at LTE layer
            --network-timeout=10           # drop hung TCP instead of freezing forever

            # --- reconnect: Icecast -----------------------------------------
            --stream-lavf-o-append=reconnect=1                       # enable HTTP reconnect
            --stream-lavf-o-append=reconnect_streamed=1              # KEY: Icecast has no range-request support
            --stream-lavf-o-append=reconnect_on_network_error=yes    # reconnect on LTE/WiFi drops
            --stream-lavf-o-append=reconnect_on_http_error=4xx,5xx  # reconnect on server errors
            --stream-lavf-o-append=reconnect_delay_max=10            # max 10s between reconnect attempts
        )
        mpv "${MPV_ARGS[@]}" "$URL"

        COUNT=$((COUNT + 1))
        echo "$(date '+%Y-%m-%d %H:%M:%S')  #${COUNT}  ${NAME}" | tee -a "$LOG"
        echo "( ˘・з・)・・・  interrupted — reconnect after 1 sec..."
        sleep 1
    done
else
    echo "stations: fip rock jazz groove world reggae electro hiphop pop metal sacre cultes nouveautes"
fi

# ——— notes ——————————————————————————————————————————————————————————————————
# --audio-format=floatp      # for DSP effects instead of s16
# --audio-buffer=4.0         # middle ground if 6.0 feels too laggy on weak signal
# reconnect log: tail -f ~/fip-reconnects.log
# —————————
