# fixaudio
**EN:** Personal audiophile toolkit for uninterrupted high-quality audio on Ubuntu —  
focused on stable FIP radio streaming over unstable LTE connections.

**FR:** Boîte à outils audio personnelle sous Ubuntu — streaming FIP 192kbps  
stable via connexion LTE instable, avec Icecast et latence minimale.

---

##  fip-stream.sh — FIP 192kbps over LTE

Stable high-quality FIP stream via Icecast relay on Ubuntu.  
Built to handle mobile network instability without audio dropouts.

**Stack:** `bash` · `Icecast2` · `ffmpeg` · `systemd`

```bash
# Quick start
chmod +x fip-stream.sh && ./fip-stream.sh
```

→ Tested on Ubuntu 22.04, FIP stream v10 (Radio France Open API)

---

##  hardware/fix-audio.sh — PipeWire 48kHz

Hardware-specific audio fix for external DAC/receiver (Onkyo).  
Forces PipeWire to 48000Hz for bit-perfect playback.

---

##  docs/ — Integration notes

Notes on integrating FIP metadata into a larger audio platform  
(work in progress, connected to [ft_transcendence](#)).
