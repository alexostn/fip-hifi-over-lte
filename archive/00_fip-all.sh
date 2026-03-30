# initial script
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
    echo "🎵 FIP $NAME — 192kbps Hi-Fi (auto-reconnect)"
    while true; do
        mpv --no-video \
            --audio-channels=stereo \
            --audio-format=s16  \
            --audio-samplerate=48000 \
            --audio-buffer=2.0 \
            "$URL"
        echo "▲(⊙_⊙)▲~~~  interrupted — reconnect after 3 sec..."
        sleep 3
    done
else
    echo "fip rock jazz groove world reggae electro hiphop pop metal sacre cultes nouveautes"
fi

# -audio-format=floatp \ # for easy effects or --audio-format=s16 \ # for easyCPUQual-same
#            --audio-buffer=2.0 \ # used in this version (￣ω￣) ══►
# --audio-buffer=4.0   # instead 2.0 for easy effects


