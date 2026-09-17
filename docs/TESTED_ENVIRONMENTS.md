# Tested environments

Results from machines other than mine. Entries come from Issues labelled
`test-report`, or from reports sent to me directly and filed on request.

Nothing here identifies a private network or a person who didn't ask to be
credited. Wi-Fi names, IP and MAC addresses are never recorded.

| Version | System | Network | Output | Level | Result | Report |
|---|---|---|---|---|---|---|
| v16.3 | Ubuntu, managed lab machine, no sudo | Wi-Fi | built-in | 2 | played via `ao=pulse` fallback, `s32` applied; `Cache:` 3.2s; 0 underruns; network cut not tested (shared machine) | [#1](../../issues/1) |
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
- the `AO:` line turned out to be the quickest way to tell which path is in
  use, so it now goes in every report. It also reports the sample format,
  which is how the `s32` question got settled: the flag *is* applied on the
  `pulse` path. `float` appears in Level 1 because that command carries no
  `--audio-format` at all, and on macOS because CoreAudio negotiates its own.
- documentation, from walking the instructions as a stranger would: the log
  commands invite being run before the test itself, cutting the network is
  not an option on a shared machine, and a `Will reconnect` line fires
  harmlessly at every Ctrl+C

## Open questions a report could settle

- what the `Cache:` depth actually depends on — 3s and 22s were both measured
- whether `underrun` at startup and DNS lag after reconnect reproduce on a
  second Mac, or belonged to one network
- whether `force-quantum` does anything measurable on a PipeWire machine
- whether the restore path added in v16.4 works where PipeWire owns the card
  — it has only been confirmed to correctly do nothing where it doesn't

## Testers

Thanks to the people who ran this on machines that aren't mine. Names appear
here only when asked for — say so in the Issue, or stay unlisted.

- _(first named tester goes here)_