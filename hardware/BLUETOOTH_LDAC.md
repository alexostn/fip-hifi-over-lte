# Tuning journey

Chain: `FIP AAC 192k/48k → mpv → PipeWire 48k → output`

The ceiling is the 192 kbps AAC source. Nothing downstream adds information —
every decision below is about not degrading it.

Analog is the primary profile. Bluetooth is an episode that stayed as an option.

---

## Analog baseline (v15 → v16.3)

Measured against `alsa_output.pci-0000_00_1f.3.analog-stereo`.

| Change | From | To | Evidence |
|---|---|---|---|
| `ao` | alsa | pipewire | ALSA bridge rejected s16 → `AO:(error)` in `[cplayer]` |
| `audio-format` | s16 | s32 | matches the native S32LE graph, no conversion loop |
| `fflags` | `+discardcorrupt` | `+genpts` | discard dropped 2 AAC frames → 20–50 ms gaps |
| `err_detect` | `ignore_err` | `careful` | soft concealment instead of silent broken frames |
| `cache-pause` | no | yes | playing from an empty buffer = audible micro-cut |
| `demuxer-max-bytes` | 16 MiB | 64 MiB | absorbs LTE burst retransmission |
| `audio-buffer` | 2.0 | *removed* | fought the PipeWire quantum → `mpv ERR=29, sink ERR=576` |

`pw-top` after removal: `mpv ERR=6`, frozen. Quantum 1024 (~21 ms).

Network context at the time: LTE, `ttfb` 0.45–1.04 s, hop3 loss 26.7 %.
`ping` to Icecast is always 100 % loss — ICMP is blocked, not a fault.

---

## Bluetooth episode (v17)

Target: Sony SRS-XP500, A2DP/LDAC.

Every analog tuning above had to be re-derived — the driver node changed.

| Change | Why |
|---|---|
| `audio-format=s32` dropped | s32 was right for ALSA; on bluez it adds a conversion in the last hop before the LDAC encoder |
| `force-quantum` dropped | the bluez node *is* the driver at 2048; forcing only clamped other apps, and values above `default.clock.max-quantum` are silently refused |
| `--audio-device` pinned | a BT drop silently reroutes audio to the laptop speakers |
| `--volume=100` | soft volume attenuates before encoding → lost LSBs; hw volume goes out over AVRCP |
| `cache-pause-wait` 2.0 → 0.5 | a short pause is less audible over BT than a dropout |

Final `pw-top`: `ERR 0` on both nodes, `F32P → F32LE`, 48000 throughout,
`BUSY 85 µs` against a `2048/48000 = 42667 µs` budget.

### Persisting LDAC

WirePlumber 0.4.x uses Lua, 0.5.x uses SPA-JSON — check `wireplumber --version`.
Config lives in `config/`. The LDAC profile is named bare `a2dp-sink`;
`a2dp-sink-ldac` returns *No such entity*.

LDAC quality: `hq` 990k · `sq` 660k · `auto` ABR.
`sq` is the default here — 3x headroom over a 192k source with better link margin.

---

## Verification

```bash
./tools/audio-check.sh          # state
./tools/audio-check.sh --tone   # + sine and pink noise
```

Sine 440 must be dull and even. Pink must be an even hiss.
Both clean = the chain is fine and any distortion is downstream DSP or the source.

Node IDs change on every PipeWire restart — always reference sinks by name.

---

## Symptom map

| Symptom | Cause | Fix |
|---|---|---|
| Hoarse bass, worse when loud | MEGA BASS + level | button off, level down |
| Random crackle, digital debris | LDAC link dropouts | `hq` → `sq` |
| Muffled, telephone-like | HFP profile | `pactl set-card-profile <card> a2dp-sink` |
| Glassy hiss on cymbals | 192k AAC artifacts | source limit, not fixable |
| Audio jumps to laptop speakers | unpinned sink | `FIP_OUT=bt` sets `--audio-device` |
| `ReserveDevice1` warnings | duplicate wireplumber instance | `pkill -f '^wireplumber$'`, restart via systemd |

---

## Speaker-side (SRS-XP500)

No Linux software exists. On-device DSP is the largest remaining variable.

| Control | Where |
|---|---|
| MEGA BASS | top panel, short press |
| STAMINA | same button, hold ~2 s — kills lighting and all effects |
| LIVE SOUND | Sony Music Center app only, no physical button |
| Custom EQ | Music Center → Settings → Sound → Sound Effect → CUSTOM |
| Codec priority | Music Center, speaker off and on AC — must stay on *Priority on sound quality* |
| PARTY CONNECT | rear panel, keep off for normal stereo |
