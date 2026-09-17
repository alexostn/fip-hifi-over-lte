# macOS test

The script does not run on macOS yet. This page is the test that does.

## What this tests

The portable half of the project: buffering, network timeout, and whether an
Icecast stream recovers on its own after the connection drops. That logic
lives in mpv and ffmpeg, so it behaves the same everywhere.

## What this does not test

The Linux half. `fip-stream.sh` sets `--ao=pipewire,pulse,alsa` in
`lib/output.sh` — CoreAudio is not in that list, so the script exits before
playing. PipeWire quantum tuning, the PulseAudio fallback chain and the
Bluetooth/LDAC path are all Linux-only and are not part of this test.

Fixing that is on the list: `coreaudio` needs to go in the fallback chain, or
the `--ao` list has to be built per platform. A report from this page is what
tells me whether the rest is worth porting.

## Install

```bash
brew install mpv
mpv --version
```

Homebrew formula: https://formulae.brew.sh/formula/mpv

`brew install mpv` installs the player, not this project. mpv is an
independent open-source player maintained by its own team — nothing here is
mine except the flags below.

Check which audio outputs your build has:

```bash
mpv --audio-device=help
```

Expect `coreaudio` entries. If you see something else, that alone is worth
reporting.

## Run

One command. Every flag is taken from `fip-stream.sh`, minus the Linux ones.

```bash
mpv --no-video \
  --cache=yes --demuxer-max-bytes=64MiB --demuxer-readahead-secs=60 \
  --cache-pause=yes --cache-pause-wait=0.5 --cache-pause-initial=no \
  --stream-buffer-size=512KiB --network-timeout=15 \
  --stream-lavf-o-append=reconnect=1 \
  --stream-lavf-o-append=reconnect_streamed=1 \
  --stream-lavf-o-append=reconnect_on_network_error=yes \
  --stream-lavf-o-append=reconnect_delay_max=5 \
  --log-file=/tmp/fip-mac.log \
  --term-playing-msg='A: ${playback-time} Cache: ${demuxer-cache-duration:.1}s' \
  'https://icecast.radiofrance.fr/fip-hifi.aac?id=radiofrance'
```

Removed from the Linux version and why:

| Flag | Why it's gone |
|---|---|
| `--ao=pipewire,pulse,alsa` | none of those exist on macOS |
| `--audio-format=s32` | PipeWire-specific; CoreAudio negotiates its own |
| `--audio-samplerate=48000` | mpv picks it up from the stream |
| `pw-metadata` quantum call | PipeWire only |

Added only for this test: `--log-file`, so you have something to paste.

## Procedure

1. Run the command, wait for audio.
2. Watch the bottom line — `Cache:` should climb to 20s or more.
3. Turn Wi-Fi off for 10–20 seconds.
4. Turn it back on.
5. Wait up to a minute without touching anything.
6. Note whether audio returned on its own.
7. Ctrl+C to stop. Nothing is left behind — no config, no daemon, no files
   outside `/tmp/fip-mac.log`.

Repeat two or three times if you have the patience. One recovery can be luck.

## What counts as success

Audio comes back without you restarting anything. How long it took is the
interesting number.

A failure is equally useful: it means the reconnect settings don't hold up
outside my machine, which is exactly what I can't find out alone.

## What to report

- did it recover on its own, and roughly how many seconds
- what `Cache:` settles at once stable
- whether `Failed to resolve hostname` appeared after the network returned
  (DNS lag — on Linux the script pre-warms DNS, this command does not)
- whether `Audio device underrun detected` showed up more than once
- macOS version, mpv version, network type

Form: https://github.com/alexostn/fip-hifi-over-lte/issues/new/choose → "Test report"

Paste `/tmp/fip-mac.log` as text, or its last 30 lines. It contains no
personal data beyond your local paths — check before pasting if you'd rather
be sure.

## Uninstall

```bash
brew uninstall mpv
rm /tmp/fip-mac.log
```

Nothing else was installed and nothing was configured.

## Files

- `fip-stream.sh` — the Linux script, one bash file
- `lib/output.sh` — where the `--ao` list lives, the reason this page exists
