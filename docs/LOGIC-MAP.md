# fip-over-lte — logic map

Analog is the default. Bluetooth is an opt-in profile selected by one
environment variable. Nothing about the file layout makes one "the
branch" — the default lives in code, which is harder to accidentally
override than a git ref.

```
                              ┌──────────────────────┐
                              │   fip jazz	        ← alias, no flags
                              │   (or any station)   │
                              └──────────┬───────────┘
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │   fip-stream.sh      │
                              │                      │
                              │   trap INT/TERM      │
                              │  source lib/output.sh│
                              │   out_preflight      │
                              └──────────┬───────────┘
                                         │
                              ┌──────────┴───────────┐
                              │   FIP_OUT is set?    │
                              └──────────┬───────────┘
                          unset ─────────┼─────── "bt"
                              │                     │
                              ▼                       	      ▼
                  ┌──────────────────────┐   ┌───────────────────────┐
                  │   _out_analog()      │   │   _out_bt()           │
                  │   (default path)     │   │   (opt-in path)       │
                  │                      │   │                       │
                  │   ao=pipewire        │   │   needs FIP_BT_MAC    │
                  │   audio-format=s32   │   │   promotes to LDAC    │
                  │   volume=100         │   │   pins --audio-device │
                  └──────────┬───────────┘   └────────────┬──────────┘
                             │                            │
                             └─────────────┬──────────────┘
                                           │
                                           ▼
                              ┌──────────────────────────┐
                              │   OUT_ARGS[]             │
                              │	   → mpv "${OUT_ARGS[@]}"
                              └────────────┬─────────────┘
                                           │
                                           ▼
                              ┌───────────────────────┐
                              │   PipeWire graph      │
                              │   quantum 8192 forced │
                              │   (browser click fix, │
                              │   global, all clients)│
                              └──────────┬────────────┘
                                         │
                              ┌──────────┴───────────┐
                              ▼                                    ▼
                  ┌───────────────────────┐   ┌───────────────────────┐
                  │   alsa_output         │   │   bluez_output        │
                  │   (built-in speakers) │   │   (SRS-XP500, LDAC)   │
                  └───────────────────────┘   └───────────────────────┘
```

## Where the default actually lives

```
lib/output.sh
    FIP_OUT="${FIP_OUT:-analog}"
                     ^^^^^^^
                     this one line is the entire "analog is primary"
                     decision — no branch, no file path, no flag
                     required at the call site
```

Calling `fip jazz` with no variable set walks the left column every
time. `FIP_OUT=bt fip jazz` walks the right column once, for that
process only — nothing persists.

## File map

```
fip-over-lte/
│
├── fip-stream.sh          entry point, both profiles run through it
│
├── lib/
│   └── output.sh          FIP_OUT switch — analog default, bt opt-in
│
├── tools/
│   └── audio-check.sh     state + tone test, works for either profile
│
├── config/
│   ├── env.example         placeholder MAC — never the real one
│   └── 51-latency.conf     PipeWire: 48 kHz lock, max-quantum 8192
│
├── docs/
│   └── TUNING.md           analog baseline v15 → v16.3, applies to both
│
└── hardware/
    └── BLUETOOTH_LDAC.md   bt-only: LDAC, XP500 buttons, Music Center
                             inert unless FIP_OUT=bt is actually used
```