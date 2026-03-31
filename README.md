# fixaudio  ٩(◕‿◕)۶

**EN:** Personal audiophile toolkit for uninterrupted HiFi audio on Ubuntu —
focused on stable FIP radio streaming over unstable LTE connections.

**FR:** Boîte à outils audio personnelle sous Ubuntu —
streaming FIP HiFi AAC 192kbps stable via connexion LTE instable.

---

## ≡≡≡ヽ(゜∀゜)ノ fip-stream.sh — FIP HiFi over LTE

Stable FIP stream on Ubuntu, tuned for mobile network instability without audio dropouts.
DNS pre-resolved at startup, reconnects handled at both mpv and shell level.

**Stack:** `bash` · `mpv` · `dig` (dnsutils)

```bash
chmod +x fip-stream.sh && ./fip-stream.sh        # FIP main
./fip-stream.sh jazz                              # FIP Jazz
```

Tested on Ubuntu 22.04 · FIP stream v11 · Radio France HiFi AAC 192kbps

---

## (・∀・)つ Stations

| key | stream |
|-----|--------|
| `fip` | FIP main |
| `jazz` | FIP Jazz |
| `rock` | FIP Rock |
| `groove` | FIP Groove |
| `world` | FIP World |
| `electro` | FIP Electro |
| `hiphop` | FIP Hip-Hop |
| `pop` | FIP Pop |
| `metal` | FIP Metal |
| `reggae` | FIP Reggae |
| `nouveautes` | FIP Nouveautés |
| `sacre` | FIP Sacré Français |
| `cultes` | FIP Cultes |

All streams: `icecast.radiofrance.fr` — HiFi AAC 192kbps

---

## ( ･∀･)ﾉ━━━━━► shell aliases

```bash
# add to ~/.bashrc or ~/.zshrc
alias fip='~/fixaudio/fip-stream.sh'
alias fjazz='~/fixaudio/fip-stream.sh jazz'
alias frock='~/fixaudio/fip-stream.sh rock'
alias fgroove='~/fixaudio/fip-stream.sh groove'
alias fworld='~/fixaudio/fip-stream.sh world'
alias felectro='~/fixaudio/fip-stream.sh electro'
alias fhiphop='~/fixaudio/fip-stream.sh hiphop'
alias fpop='~/fixaudio/fip-stream.sh pop'
alias fmetal='~/fixaudio/fip-stream.sh metal'
alias freggae='~/fixaudio/fip-stream.sh reggae'
alias fnouveautes='~/fixaudio/fip-stream.sh nouveautes'
alias fsacre='~/fixaudio/fip-stream.sh sacre'
alias fcultes='~/fixaudio/fip-stream.sh cultes'
```

---

## (づ￣ ³￣)づ ⚙⚙⚙ hardware/fix-audio.sh — PipeWire 48kHz

Hardware-specific audio fix for external DAC/receiver (Onkyo).
Forces PipeWire to 48000Hz for bit-perfect playback.
