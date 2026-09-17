# ♫ FIP Radio on weak LTE

٩(◕‿◕) **EN:** Personal toolkit for uninterrupted HiFi audio on Ubuntu —
stable FIP radio streaming over unstable LTE connections.
> ...work in progress — tested in the field, open for improvements

٩(◕‿◕) **FR:** Boîte à outils audio personnelle sous Ubuntu —
streaming FIP HiFi AAC 192kbps stable via connexion LTE instable.

> Independent personal project. Not affiliated with, endorsed by, or connected
> to Radio France. FIP and Radio France are trademarks of Radio France; this
> tool only plays their publicly available streams and never records or
> redistributes them.

---

## ≡≡≡ヽ(゜゜)ノ Quick start

## [if no sudo and for other pre-install adjustments    (゜.゜) look here>](hardware/FLATPACK_SAFE_PREINSTAL_WITHOUT_SUDO.md)

```bash
git clone --branch v16.4 --depth 1 \
  https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
less fip-stream.sh lib/output.sh   # one bash file plus an output profile
./fip-stream.sh                   # FIP main
./fip-stream.sh jazz              # FIP Jazz
```

A single-file download will not work: `fip-stream.sh` sources `lib/output.sh`.

Add aliases so you type `fjazz` from anywhere — adjust the path to wherever
you cloned:

```bash
# add to ~/.bashrc or ~/.zshrc
FIP=~/fip-hifi-over-lte/fip-stream.sh
alias fip="$FIP"
alias fjazz="$FIP jazz"
alias frock="$FIP rock"
alias fgroove="$FIP groove"
alias fworld="$FIP world"
alias felectro="$FIP electro"
alias fhip="$FIP hiphop"
alias fpop="$FIP pop"
alias fmetal="$FIP metal"
alias freggae="$FIP reggae"
alias fnouveau="$FIP nouveautes"
alias fsacre="$FIP sacre"
alias fcultes="$FIP cultes"
```

```
source ~/.bashrc
```

---

## Installation

Two separate things: **mpv** (the player, not mine) and **this project**
(a bash script plus one output profile).

### 1. Install mpv

| Path | Command | When |
|---|---|---|
| apt | `sudo apt install mpv dnsutils` | own Linux machine; signed Ubuntu packages |
| Flatpak | `flatpak install --user flathub io.mpv.Mpv` | no `sudo` — managed or school machine |
| Homebrew | `brew install mpv` | macOS |

Verify with `mpv --version`. The Flatpak path needs one extra step, a wrapper
so scripts can call `mpv` directly — see the
[no-sudo pre-setup](hardware/FLATPACK_SAFE_PREINSTAL_WITHOUT_SUDO.md).

mpv is an independent open-source player. There is no apt, Flatpak or Homebrew
package of **this project** — only of mpv.

### 2. Get the project

Clone it, as in Quick start above.

---

## Platform status

| Platform | Status | Notes |
|---|---|---|
| Linux + PipeWire | Experimental | the tuned path; Ubuntu 24.04 and a managed lab machine |
| Linux + standalone PulseAudio | Experimental | works via the `pipewire,pulse,alsa` fallback; PipeWire-specific flags are skipped |
| macOS | Exploratory | the script exits — `--ao` has no `coreaudio`. Stream and reconnect logic is testable: [macOS test](docs/MACOS_TEST.md) |
| Windows / WSL | Not tested | out of scope for now |

`Experimental` — works here, few external tests. `Exploratory` — a scenario
prepared to collect data. Nothing is marked `Supported` yet; that needs
reports from machines other than mine.

---

## (∩˘0˘∩).｡O Stations

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
logged to `/tmp/fip-mpv-last.log`.

`--audio-format=s32` matches the native S32LE PipeWire graph, so nothing is
converted on the way out. That flag is PipeWire-specific and is ignored when a
standalone PulseAudio daemon owns the card.

---

(◕‿◕) RF API Integration — Metadata Sync

**Ce projet prépare l'intégration de l'API Radio France pour synchroniser les
métadonnées live (titre, artiste, station) avec le flux audio.**

Objectifs :
- suivre le titre en cours via RF Open API
- détecter changements de piste et désynchronisations
- logger events pour analyse (Prometheus-ready)
- brique réutilisable pour MVP curation humaine (ft_transcendence)

**Statut :** documentation de l'API Open Radio France étudiée. Pas encore de
clé ni d'implémentation — aucun partenariat ni validation éditoriale.

---

## (◐↓◑) What's inside

```
fip-stream.sh       main script — run this
lib/output.sh       output profile (analog / bluetooth), sourced by the script
fip-aliases.sh      shell aliases (optional)
config/env.example  Bluetooth MAC and other local settings
tools/              audio-check.sh and diagnostics
hardware/           no-sudo pre-setup, Bluetooth/LDAC notes
```

Key mpv flags explained in comments inside the script. The notable ones:

- `--demuxer-max-bytes=64MiB` — absorbs LTE burst retransmission
- `--demuxer-readahead-secs=60` — reads far ahead to survive short outages
- `--cache-pause=yes` — waits for the buffer instead of playing from empty
- `--stream-lavf-o-append=reconnect_streamed=1` — Icecast has no range-request, this is the fix
- `--audio-format=s32` — matches the native S32LE graph, no conversion loop
- `--log-file=/tmp/fip-mpv-last.log` — events logged directly by mpv, no pipe noise
- DNS pre-warm via Quad9 `9.9.9.9` at startup — reduces silence after LTE reconnect

---

## Findings log

Things that turned out to be wrong, kept on purpose.

- **`--audio-buffer` — removed in v16.3.** It looked like a cushion for LTE
  dips. `pw-top` showed mpv ERR=29 and sink ERR=576 at `2.0`, ERR=2 at `0.5`,
  and a stable non-growing ERR=6 with the flag absent. An explicit buffer
  fights PipeWire's own quantum (1024, ~21 ms).
- **`--audio-format=s16` — changed to `s32` in v16.2.** Forcing s16 created a
  conversion loop into the native S32LE graph. The flag does apply on the
  `pulse` fallback path too — an early report suggested otherwise, but the
  `AO:` line showed `s32` there as well.
- **`--ao=alsa` — replaced by `pipewire,pulse,alsa`.** The ALSA bridge rejected
  s16 and bypassed the graph.
- **`force-quantum` above `max-quantum` — silently ineffective.** Metadata
  accepts any value; the cap applies further down the graph. The two must be
  set to match.
- **`force-quantum` on a machine where PulseAudio owns the card** — written
  into a graph nothing uses, and left set after exit. A patch for v16.4 saves
  and restores it and skips the write when PipeWire is not the audio server;
  not yet released, it needs testing on a PipeWire machine first.
- **`--demuxer-readahead-secs=60` is unreachable on a live stream.** Icecast
  sends in real time, so there is no future to read ahead into. Measured on
  two machines: the cache fills to ~3.2s in the first second and stays there.
  The real cushion against an outage is ~3s, not 60. The flag is a ceiling,
  not a target.
- **Is the quantum setting needed at all?** Open. Where PulseAudio owns the
  card it changes nothing. On a PipeWire machine its effect has never been
  measured separately from the other settings. A `pw-top` comparison with and
  without `force-quantum` would settle it — until then this is a flag kept on
  reasoning, not on evidence.
- **LDAC profile** is reported as bare `a2dp-sink`; `a2dp-sink-ldac` returns
  *No such entity*.

Diagnosis method throughout: the `pw-top` ERR column, not audible artefacts.

---

## ٩(◕‿◕) Stream info while playing

The script runs mpv with `--no-video`, so there is no window and no stats
overlay — `i` and `Shift+I` do nothing. The terminal status line carries what
matters:

```
A: 00:04:12 Cache: 22.4s
```

`Cache:` dropping to `0.0s` is an underrun. The backend actually in use is in
the log:

```bash
grep AO: /tmp/fip-mpv-last.log
# AO: [pipewire] 48000Hz stereo 2ch s32
```

---

## Testing feedback

Reports from machines other than mine are the most useful contribution right
now — including runs where everything worked.

**[Open a test report](https://github.com/alexostn/fip-hifi-over-lte/issues/new/choose)**
— one minute, seven quick fields.

You don't have to run the script to be useful: one mpv command tests the same
stream and reconnect logic. See [macOS test](docs/MACOS_TEST.md), which works
as a script-free test on Linux too.

Please strip passwords, tokens, IP addresses, private Wi-Fi names and MAC
addresses from anything you paste — `/tmp/fip-mpv-last.log` can contain network
details. Note that GitHub always shows your account as the author of an issue;
if you would rather stay unnamed, message me and I'll file it without your
handle.

Results so far: [docs/TESTED_ENVIRONMENTS.md](docs/TESTED_ENVIRONMENTS.md)

---

## (づ￣³￣)づ Open questions / experiments in progress

An ongoing log of what works and what doesn't on mobile. Particularly
interested in:

- SmokePing or similar latency heatmaps against `icecast.radiofrance.fr`
- PipeWire quantum: currently `force-quantum 8192` matched to `max-quantum
  16384`. Whether that is right on other hardware is open.
- macOS — `coreaudio` needs to go into the `--ao` chain, or the list has to be
  built per platform
- Other Radio France streams or similar Icecast sources
- Reconnect logs welcome, with network type (LTE / Wi-Fi / tethering)

If you use a different stack (mpd, VLC CLI, liquidsoap) and have reconnect
tricks — open an issue or PR.

---

## ( ˘・з・)・・・ Log

```bash
tail -f /tmp/fip-mpv-last.log
# format: [HH:MM:SS.mmm] [module] warn: message
```

The log is recreated on every run.

---

## ≡≡≡ Requirements

- `mpv` (tested on 0.37+)
- `dig` (from `dnsutils`) — optional; DNS pre-warm is skipped without it
- PipeWire or PulseAudio

```bash
sudo apt install mpv dnsutils
```

**`[ao] Failed to initialize audio driver 'pipewire'`?** `lib/output.sh` sets
`--ao=pipewire,pulse,alsa` — mpv tries each in order, so this shows up as a
harmless first attempt when the PipeWire graph has no audio nodes (e.g. a
standalone `pulseaudio` daemon owns the card instead of `pipewire-pulse`).
Confirm the real output with `grep AO: /tmp/fip-mpv-last.log`.

**Diagnosing a no-audio machine from scratch:**
1. `pactl info | grep "Server Name"` — a real `pulseaudio` server here (not
   `PulseAudio (on PipeWire ...)`) means bare PipeWire has no bridge.
2. `pw-cli list-objects Node | grep -B2 'media.class.*Audio'` — empty output
   means PipeWire's own graph has no audio nodes to attach to.
3. `mpv --ao=pulse ...` — confirm which backend actually produces sound.
4. Reorder or trim the `--ao=` priority list in `lib/output.sh` to put the
   working backend first.

Confirmed in the field: on a managed lab machine `pipewire` and a separate
`pulseaudio 15.99.1` were running side by side, `pactl` reported plain
`pulseaudio`, and playback went through `ao=pulse` — the fallback chain worked
as intended.

---

## What this does not do

- it is not an official Radio France application
- it does not record, store, re-broadcast or proxy any stream
- it does not circumvent geo-restrictions or any technical protection measure
- total loss of network does not guarantee uninterrupted playback — the buffer
  covers short outages, not long ones
- PipeWire is not used on macOS, and the PipeWire-specific flags do not apply
  there

---

## Acknowledgements

This project is a thin shell wrapper. Everything that makes it work was built
by other people, and most of it is copyleft — `mpv`, `FFmpeg`, `BlueZ` and
`bash` are GPL or LGPL.

- [mpv](https://mpv.io) — all the actual playback and reconnection
- [FFmpeg](https://ffmpeg.org) — demuxing and AAC decoding underneath mpv
- [PipeWire](https://pipewire.org) and WirePlumber — the audio graph, and the
  `pw-top` ERR counter that made the xrun diagnosis possible
- [BlueZ](http://www.bluez.org) and Sony's LDAC encoder — the Bluetooth path
- Radio France — for publishing FIP as open HTTP streams with no login, no
  client and no DRM. That decision is what makes a bash script a viable way to
  listen to the radio.

This repository is MIT-licensed, which is permissive, while the stack under it
is largely copyleft. That is legally fine — these are separate processes, not
linked code — but it is worth stating plainly which direction the debt runs.

---

## License

MIT — see [LICENSE](LICENSE).

---

Tested on Ubuntu 24.04 · also on a managed 22.04 lab machine ·
fip-stream v16.4 · Radio France HiFi AAC 192kbps · Onkyo external DAC
