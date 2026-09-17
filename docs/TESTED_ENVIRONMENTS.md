# Tested environments

Results from machines other than mine. Entries come from Issues labelled
`test-report`, or from reports sent to me directly and filed on request.

Nothing here identifies a private network or a person who didn't ask to be
credited. Wi-Fi names, IP and MAC addresses are never recorded.

| Version | System | Network | Output | Level | Result | Report |
|---|---|---|---|---|---|---|
| v16.3 | Ubuntu, managed lab machine, no sudo | Wi-Fi | built-in | 2 | played via `ao=pulse` fallback; `Cache:` 3.2s; 0 underruns | [#1](../../issues/1) |
| v16.3 | macOS | Wi-Fi | built-in | 1 | recovered on its own; `Cache:` 22s; underrun at start; DNS lag after reconnect | sent directly |

**Level** — 1 is the mpv command alone, 2 includes `fip-stream.sh`.

## What these two reports already changed

- the `pipewire,pulse,alsa` fallback was a hypothesis in the README; the lab
  machine confirmed it works when a standalone PulseAudio owns the card
- `force-quantum` was found to be written into an unused graph and left
  behind on exit → fixed in v16.4
- `--demuxer-readahead-secs=60` turned out to be unreachable on a live
  stream; the two reports disagree on the actual cache depth (3.2s vs 22s),
  which is still open
- `--audio-format=s32` is not applied on the `pulse` path — output came out
  as float

## Open questions a report could settle

- what the `Cache:` depth actually depends on — 3s and 22s were both measured
- whether `underrun` at startup and DNS lag after reconnect reproduce on a
  second Mac, or belonged to one network
- whether `force-quantum` does anything measurable on a PipeWire machine

## Testers

Thanks to the people who ran this on machines that aren't mine. Names appear
here only when asked for — say so in the Issue, or stay unlisted.

- _(first named tester goes here)_