#!/bin/bash
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

# ——( ˘・з・)—— DNS pre-resolve via Quad9 (9.9.9.9 Switzerland no-log) ——————————
# ask once at startup — mpv connects by IP, no DNS needed on reconnects ↓↓↓
HOST=$(echo "$URL" | sed 's|https://||' | cut -d'/' -f1)
RESOLVED_IP=$(dig +short "$HOST" @9.9.9.9 2>/dev/null | grep -E '^[0-9]+\.' | tail -1)
if [ -n "$RESOLVED_IP" ]; then
    URL=$(echo "$URL" | sed "s|$HOST|$RESOLVED_IP|")
    SNI_ARG="--tls-server-name=$HOST"  # keep original hostname for TLS/SNI handshake
else
    SNI_ARG=""                          # fallback: no IP found, use URL as-is
fi
# ————————————————————————————————————————————————————————————————————————————————

NAME="${1:-fip}"
URL="${STATIONS[$NAME]}"

if [ -n "$URL" ]; then
    echo "٩(◕‿◕)۶FIP 5 $NAME — 192kbps Hi-Fi (mobile-stable)"
    while true; do
        MPV_ARGS=(
            --no-video
            --audio-channels=stereo
            --audio-format=s16            # 16-bit int — enough for AAC 192k; use floatp for DSP effects
            --audio-samplerate=48000      # matches FIP stream native rate
            --audio-buffer=6.0            # 6s buffer — absorbs mobile network dips (was 2.0)

            # --- cache: live-stream safe mode ---
            --cache=yes                   # enable demuxer cache for smoother playback
            --demuxer-max-bytes=8MiB      # ~340s/5min max demuxer buffer for 192k AAC
            --demuxer-readahead-secs=20   # read 20s ahead to survive short outages
            --cache-pause=no              # no freezes — errors handled by while true reconnect
            --cache-pause-initial=no      # no silence while cache fills on start/reconnect
            --demuxer-lavf-o-append=fflags=+discardcorrupt  # drop corrupt AAC frames after mid-stream reconnect

            # --- network ---
            --stream-buffer-size=512KiB   # TCP-level read buffer; smooths burst drops at LTE layer
            --network-timeout=10          # drop hung TCP instead of freezing forever

            # --- reconnect: Icecast ---
            --stream-lavf-o-append=reconnect=1                   # enable HTTP reconnect
            --stream-lavf-o-append=reconnect_streamed=1          # KEY: Icecast has no range-request support
            --stream-lavf-o-append=reconnect_on_network_error=yes    # reconnect on LTE/WiFi drops
            --stream-lavf-o-append=reconnect_on_http_error=4xx,5xx   # reconnect on server errors
            --stream-lavf-o-append=reconnect_delay_max=5         # max 5s between reconnect attempts
        )
        mpv "${MPV_ARGS[@]}" "$URL"
        echo "( ˘・з・)・・・  interrupted — reconnect after 1 sec..."
        sleep 1
    done
else
    echo "fip rock jazz groove world reggae electro hiphop pop metal sacre cultes nouveautes"
fi

# --audio-format=floatp  # for DSP effects instead of s16
# --audio-buffer=2.0     # was default before mobile tuning
# --audio-buffer=4.0     # middle ground if 6.0 feels too laggy

# mpv \\ lines replaced by MPV_ARGS=(...) array — inline comments now work correctly
