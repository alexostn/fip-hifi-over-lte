# macOS test

The script is Linux-only for now. This page is what a Mac can test: whether
the stream comes back on its own after the connection drops.

10 minutes. Nothing is installed except mpv, and nothing is configured.

Full testing page for all platforms: [TESTING.md](TESTING.md)

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

1. Wait for audio. Note what `Cache:` settles at — see below, any value is
   a valid answer.
2. Turn Wi-Fi off for 10–20 seconds.
3. Turn it back on and wait up to a minute without touching anything.
4. `Ctrl+C` to stop.

Twice or three times if you have the patience — one recovery can be luck.

### About that `Cache:` number

Don't expect it to reach the 60 seconds the flag asks for. Icecast sends in
real time, so there's no future to read ahead into. On two Linux machines it
filled to about 3 seconds in the first second and stayed there. One macOS
report showed 22s — which is exactly why this number is worth collecting:
I don't know yet what the difference depends on.

Whatever you get is the answer. There's no wrong value.

## 4. Report

Four things:

- did audio come back on its own, and roughly how long it took
- what `Cache:` settled at
- your macOS version and `mpv --version`
- these two counts:

```bash
grep -c "underrun" /tmp/fip-mac.log
grep -c "Failed to resolve" /tmp/fip-mac.log
```

The first macOS report had hits on both. If yours doesn't, that was their
network rather than my settings — which is the kind of thing a single report
can't tell me.

**[Open a test report](https://github.com/alexostn/fip-hifi-over-lte/issues/new/choose)**

Failure is just as useful — it means the settings don't hold up outside my
machine, which is the thing I can't find out alone.

Paste the log if you like, or its last 30 lines. Worth a glance first: it
records your local paths and the hostnames it connected to.

## Clean up

```bash
brew uninstall mpv
rm /tmp/fip-mac.log
```

---

<details>
<summary>Why the script itself doesn't run here</summary>

`lib/output.sh` sets `--ao=pipewire,pulse,alsa`. CoreAudio isn't in that
list, so mpv has no audio backend it can open and the script stops with an
error instead of playing. Either `coreaudio` goes into the chain, or the list
gets built per platform — a report from this page is what decides whether
that's worth doing.

Also Linux-only and therefore not tested here: PipeWire quantum tuning, the
PulseAudio fallback chain, and the Bluetooth/LDAC path.

Flags dropped from the Linux command: `--ao=pipewire,pulse,alsa` (none exist
on macOS), `--audio-format=s32` (PipeWire-specific), `--audio-samplerate=48000`
(mpv takes it from the stream), and the `pw-metadata` quantum call.

Worth a look if you're curious: `mpv --audio-device=help` lists what your
build actually has.

If you'd like to test the script itself on a Mac, the interesting moment is
after the coreaudio profile lands. Say so and I'll ping you.

</details>