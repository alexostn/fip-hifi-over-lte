# FIP Radio on weak LTE

٩(◕‿◕) **EN:** Personal toolkit for uninterrupted HiFi audio on Ubuntu —
stable FIP radio streaming over unstable LTE connections.
> ...work in progress — tested in the field, open for improvements

٩(◕‿◕) **FR:** Boîte à outils audio personnelle sous Ubuntu —
streaming FIP HiFi AAC 192kbps stable via connexion LTE instable.

---

## ≡≡≡ヽ(゜∀゜)ノ Quick start

```bash
curl -O https://raw.githubusercontent.com/alexostn/fip-hifi-over-lte/main/fip-stream.sh
chmod +x fip-stream.sh
./fip-stream.sh          # FIP main
./fip-stream.sh jazz     # FIP Jazz
```

Add aliases so you type `fjazz` from anywhere:

```bash
# add to ~/.bashrc or ~/.zshrc
alias fip='~/fip-stream.sh'
alias fjazz='~/fip-stream.sh jazz'
alias frock='~/fip-stream.sh rock'
alias fgroove='~/fip-stream.sh groove'
alias fworld='~/fip-stream.sh world'
alias felectro='~/fip-stream.sh electro'
alias fhip='~/fip-stream.sh hiphop'
alias fpop='~/fip-stream.sh pop'
alias fmetal='~/fip-stream.sh metal'
alias freggae='~/fip-stream.sh reggae'
alias fnouveau='~/fip-stream.sh nouveautes'
alias fsacre='~/fip-stream.sh sacre'
alias fcultes='~/fip-stream.sh cultes'
```

```bash
source ~/.bashrc
```

---

## (・∀・)つ Stations

All streams: `icecast.radiofrance.fr` — HiFi AAC 192kbps

| alias | station |
|-------|---------|
| `fip` | FIP main |
| `fjazz` | FIP Jazz |
| `frock` | FIP Rock |
| `fgroove` | FIP Groove |
| `fworld` | FIP World |
| `felectro` | FIP Electro |
| `fhip` | FIP Hip-Hop |
| `fpop` | FIP Pop |
| `fmetal` | FIP Metal |
| `freggae` | FIP Reggae |
| `fnouveau` | FIP Nouveautés |
| `fsacre` | FIP Sacré Français |
| `fcultes` | FIP Cultes |

---

## ( ˘・з・) Why this exists

GUI players freeze on mobile networks. Browser tabs eat RAM, forget your station,
and don't reconnect cleanly.

This is a single bash script that keeps mpv alive through LTE drops — DNS pre-warm
on start, native reconnect flags inside mpv, `while true` as a fallback, all events
logged to `~/fip-reconnects.log`.

Tested on Ubuntu 22.04 + PipeWire, external DAC via Onkyo receiver.
`--audio-format=s16` — faster on mobile, fewer underruns.
Switch to `floatp` only if you add DSP processing.

---

## ( ･∀･)ﾉ━━━► What's inside

```
fip-stream.sh       main script — run this
fip-aliases.sh      shell aliases (optional)
```

Key mpv flags explained in comments inside the script. The notable ones:

- `--audio-buffer=6.0` — 6s cushion for LTE dips (was 2.0)
- `--demuxer-readahead-secs=20` — reads 20s ahead to survive short outages
- `--stream-lavf-o-append=reconnect_streamed=1` — Icecast has no range-request, this is the fix
- `--log-file=~/fip-reconnects.log` — events logged directly by mpv, no pipe noise
- DNS pre-warm via Quad9 `9.9.9.9` at startup — reduces silence after LTE reconnect

---

## ٩(◕‿◕) Stream info while playing

Press `i` (latin layout) inside mpv to see live stats:

```
Audio: AAC 191 kbps · 48000 Hz · stereo · s16
Total Cache: 562 KiB (11.7 sec)
```

---

## (づ￣³￣)づ Open questions / experiments in progress

This is an ongoing log of what works and what doesn't on mobile.
If you've tried similar setups — PipeWire quantum tuning, DNS pre-warming,
buffer strategies — **issues and comments are open**. Particularly interested in:

- SmokePing or similar latency heatmaps against `icecast.radiofrance.fr`
- Better PipeWire quantum settings for streaming (currently default 1024)
- macOS / non-PipeWire setups
- Other Radio France streams or similar Icecast sources
- Collected reconnect logs welcome — open an issue with your `fip-reconnects.log`
  snippet and network type (LTE/WiFi/tethering)

If you use a different stack (mpd, VLC CLI, liquidsoap) and have reconnect tricks —
feel free to open an issue or PR.

---

## ( ˘・з・)・・・ Log

```bash
tail -f ~/fip-reconnects.log
# format: [HH:MM:SS.mmm] [module] warn: message
# session markers: [START] and [RESTART #N] with full timestamp
```

---

## ≡≡≡ Requirements

- `mpv` (tested on 0.37+)
- `dig` (from `dnsutils`)
- PipeWire or PulseAudio

```bash
sudo apt install mpv dnsutils
```

Tested on Ubuntu 22.04 · fip-stream v14 · Radio France HiFi AAC 192kbps · Onkyo external DAC
