#!/bin/bash
# ( ˘・з・) restore PipeWire + Realtek / restauration PipeWire + Realtek

# 1. unmask services if masked / démasquer les services si nécessaire
systemctl --user unmask pipewire pipewire-pulse wireplumber 2>/dev/null

# 2. full ALSA reload / rechargement complet ALSA
sudo alsa force-reload

# 3. restart PipeWire stack / redémarrage de la pile PipeWire
systemctl --user restart pipewire pipewire-pulse wireplumber

sleep 3

# 4. check Realtek sink / vérifier la sortie Realtek
pactl list sinks short | grep alsa_output || {
    systemctl --user restart wireplumber
    sleep 3
}

# 5. set Realtek as default / définir Realtek par défaut
SINK=$(pactl list sinks short | grep alsa_output | head -1 | awk '{print $2}')
[ -n "$SINK" ] && pactl set-default-sink "$SINK"

# 6. audio test / test audio
speaker-test -t sine -f 1000 -l 1 &>/dev/null \
    && echo "[✔] (ﾉ゜▽゜)ﾉ  Realtek OK" \
    || echo "[✘] (╥_╥)  ALSA broken — check journalctl --user -u pipewire"

# 7. enable autostart on boot / activer le démarrage automatique
systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null

echo "≡≡≡ヽ(゜∀゜)ノ  done! run: ./fip-stream.sh"