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

## (づ￣ ³￣)づ ⚙⚙⚙ hardware/fix-audio.sh — PipeWire 48kHz

Hardware-specific audio fix for external DAC/receiver (Onkyo).
Forces PipeWire to 48000Hz for bit-perfect playback.