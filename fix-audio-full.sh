#!/bin/bash
echo "🔧 Восстановление PipeWire + Realtek..."

# 1. Снимаем маску (если была)
systemctl --user unmask pipewire pipewire-pulse wireplumber 2>/dev/null

# 2. Полный рестарт ALSA
sudo alsa force-reload

# 3. Рестарт PipeWire/wireplumber
systemctl --user restart pipewire pipewire-pulse wireplumber

sleep 3

# 4. Проверяем Realtek
pactl list sinks short | grep alsa_output || {
    systemctl --user restart wireplumber
    sleep 3
}

# 5. Устанавливаем Realtek дефолтом
SINK=$(pactl list sinks short | grep alsa_output | head -1 | awk '{print $2}')
[ -n "$SINK" ] && pactl set-default-sink "$SINK"

# 6. Тест звука
speaker-test -t sine -f 1000 -l 1 &>/dev/null && echo "✅ Realtek OK" || echo "❌ ALSA сломан"

# 7. Автозапуск после перезагрузки
systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null

echo "🎵 Готово! Запускай: fip"
