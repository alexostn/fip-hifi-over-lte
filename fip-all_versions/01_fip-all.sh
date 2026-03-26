
ll
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

NAME="${1:-fip}"
URL="${STATIONS[$NAME]}"

if [ -n "$URL" ]; then
    echo "٩(◕‿◕)۶FIP $NAME — 192kbps Hi-Fi (mobile-stable)"
    while true; do
        MPV_ARGS=(
            --no-video
            --audio-channels=stereo
            --audio-format=s16            # 16-bit int — enough for AAC 192k; use floatp for DSP effects
            --audio-samplerate=48000      # matches FIP stream native rate
            --audio-buffer=6.0            # 6s buffer — absorbs mobile network dips (was 2.0)
            --cache=yes                   # enable demuxer cache for smoother playback
            --demuxer-max-bytes=8MiB      # ~40s lookahead buffer for 192k AAC
            --demuxer-readahead-secs=20   # read 20s ahead to survive short outages
            --network-timeout=15          # drop hung TCP instead of freezing forever
            --stream-lavf-o-append=reconnect=1                  # enable HTTP reconnect
            --stream-lavf-o-append=reconnect_streamed=1         # KEY: Icecast has no range-request support
            --stream-lavf-o-append=reconnect_on_network_error=yes   # reconnect on LTE/WiFi drops
            --stream-lavf-o-append=reconnect_on_http_error=4xx,5xx  # reconnect on server errors
            --stream-lavf-o-append=reconnect_delay_max=5        # max 5s between reconnect attempts
        )
        mpv "${MPV_ARGS[@]}" "$URL"
        echo "( ˘・з・)・・・  interrupted — reconnect after 3 sec..."
        sleep 3
    done
else
    echo "fip rock jazz groove world reggae electro hiphop pop metal sacre cultes nouveautes"
fi

# -audio-format=floatp \ # for easy effects or --audio-format=s16 \ # for easyCPUQual-same
#            --audio-buffer=2.0 \ # used to be in previous version
# --audio-buffer=4.0   # instead 2.0 for easy effects

# mpv ... with \\ replaced by the MPV_ARGS=(...) array + mpv “${MPV_ARGS[@]}” “$URL” — comments on each line now work correctly
