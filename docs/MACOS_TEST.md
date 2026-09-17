# macOS test

The script is Linux-only for now. This page is what a Mac can test: whether
the stream comes back on its own after the connection drops.

10 minutes. Nothing is installed except mpv, and nothing is configured.

## 1. Install mpv

```bash
brew install mpv
```

mpv is an independent open-source player, not part of this project.

## 2. Run

One command. The flags are the same as in the script, minus the Linux ones.

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

## 3. Cut the network

1. Wait for audio. `Cache:` should climb past 20s.
2. Turn Wi-Fi off for 10–20 seconds.
3. Turn it back on and wait up to a minute without touching anything.
4. `Ctrl+C` to stop.

Twice or three times if you have the patience — one recovery can be luck.

## 4. Report

Three things:

- did audio come back on its own, and roughly how long it took
- what `Cache:` settles at when stable
- your macOS version and `mpv --version`

**[Open a test report](https://github.com/alexostn/fip-hifi-over-lte/issues/new/choose)**

Failure is just as useful — it means the settings don't hold up outside my
machine, which is the thing I can't find out alone.

The log is at `/tmp/fip-mac.log` if you want to paste it. Only your local
paths are in there, nothing else personal.

## Clean up

```bash
brew uninstall mpv
rm /tmp/fip-mac.log
```

---

<details>
<summary>Why the script itself doesn't run here</summary>

`lib/output.sh` sets `--ao=pipewire,pulse,alsa`. CoreAudio is not in that
list, so mpv has nothing to initialize and the script exits before playing.
Either `coreaudio` goes into the chain, or the list gets built per platform —
a report from this page is what decides whether that's worth doing.

Also Linux-only and therefore not tested here: PipeWire quantum tuning, the
PulseAudio fallback chain, and the Bluetooth/LDAC path.

Flags dropped from the Linux command: `--ao=pipewire,pulse,alsa` (none exist
on macOS), `--audio-format=s32` (PipeWire-specific), `--audio-samplerate=48000`
(mpv takes it from the stream), and the `pw-metadata` quantum call.

Worth a look if you're curious: `mpv --audio-device=help` lists what your
build actually has.

</details>
