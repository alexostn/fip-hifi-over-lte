# Testing

One page for every platform. Six steps, four answers.

**What is being tested:** whether a live radio stream survives a dropping
connection — and whether these instructions make sense on a machine that
isn't mine.

Nothing is graded. A test that fails, or instructions that confuse you, are
the most useful outcomes.

---

## Two levels

**Level 1 — the stream test.** One mpv command, any OS. Tests buffering,
network timeout and reconnect. No script, nothing to trust.

**Level 2 — the script test.** Runs `fip-stream.sh`. Adds the output profile
and the audio tuning on top of Level 1. Linux only for now.

Level 1 alone is a useful report.

---

## The six steps

1. Install mpv — see your platform below.
2. Start playback — the command or the script. **Do this before anything
   else.** The log commands in step 6 read a file that doesn't exist yet.
3. Note what `Cache:` settles at in the status line.
4. Disconnect the network for 15 seconds. Wi-Fi off, or unplug the cable.
   **Not your network?** Skip this step — see below.
5. Reconnect and wait up to a minute **without touching anything**.
6. `Ctrl+C`, then read two numbers out of the log.

### The four answers

- did audio come back on its own, and roughly how long it took
- what `Cache:` settled at
- how many `underrun` lines in the log
- how many `Failed to resolve` lines in the log

That's the whole report. Anything else is a bonus.

### If the network isn't yours

On a school, work or shared machine, don't cut it. Pulling the cable or
killing the Wi-Fi affects other people, and no test is worth that.

Just run it, note the `Cache:` value, and report
**"played, network cut not tested"** — that's a complete result, not a gap.
It still tells me the stream opens and the buffer behaves on hardware I've
never seen.

If you want the reconnect half anyway: tether to your phone and toggle
*that* instead. Your own hotspot is yours to interrupt.

---

## Level 1 · the stream test

```bash
mpv --no-video \
  --cache=yes --demuxer-max-bytes=64MiB --demuxer-readahead-secs=60 \
  --cache-pause=yes --cache-pause-wait=0.5 --cache-pause-initial=no \
  --stream-buffer-size=512KiB --network-timeout=15 \
  --stream-lavf-o-append=reconnect=1 \
  --stream-lavf-o-append=reconnect_streamed=1 \
  --stream-lavf-o-append=reconnect_on_network_error=yes \
  --stream-lavf-o-append=reconnect_delay_max=5 \
  --log-file=/tmp/fip-test.log \
  --term-playing-msg='A: ${playback-time} Cache: ${demuxer-cache-duration:.1}s' \
  'https://icecast.radiofrance.fr/fip-hifi.aac?id=radiofrance'
```

After `Ctrl+C`:

```bash
grep -c "underrun" /tmp/fip-test.log
grep -c "Failed to resolve" /tmp/fip-test.log
grep -E "Will reconnect|underrun|resolve|AO:" /tmp/fip-test.log | tail -20
```

Clean up with `rm /tmp/fip-test.log`.

**One line that looks alarming and isn't:** a `Will reconnect ...
Input/output error` right at the moment you press Ctrl+C is normal. ffmpeg
notices the closed socket about a millisecond before the process exits —
check the timestamps and you'll see them land together. Only reconnect lines
*during* playback mean anything.

### About that `Cache:` number

Don't expect it to climb to 60 seconds despite the flag. Icecast sends in real
time, so there is no future to read ahead into — measured on two Linux
machines, the cache fills to about 3 seconds in the first second and stays
there. One macOS report showed 22s, which is why this number is worth
collecting: I don't yet know what it depends on.

Whatever you get is the answer. There is no wrong value here.

---

## Level 2 · the script test

Linux only. On a Mac the script won't start: it asks for a Linux audio system
that macOS doesn't have. Use Level 1 there instead.

```bash
git clone --branch v16.4 --depth 1 \
  https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
less fip-stream.sh lib/output.sh   # one bash file plus an output profile
./fip-stream.sh
```

Then the same six steps. The log is `/tmp/fip-mpv-last.log`, recreated on
every run.

Also report the two lines it prints on start — the output profile and the
version — plus the `AO:` line from the log.

### What the script touches

- writes logs to `/tmp/`
- sets the global PipeWire quantum while it runs, and restores it on exit
- installs nothing, needs no `sudo`, changes no file outside `/tmp/`

Since v16.4 the quantum is saved and put back when the script exits, and it is
skipped entirely when PipeWire doesn't own the card. On v16.3 and earlier it
was left behind; if you ran an older version, `pw-metadata -n settings 0
clock.force-quantum 0` resets it.

### Bonus, if you're on PipeWire and curious

There is an open question in the findings log: whether the quantum setting
does anything useful at all. If you run it twice —

```bash
./fip-stream.sh                    # default 8192
FIP_QUANTUM=1024 ./fip-stream.sh   # near-default
```

— and can't hear or measure a difference, that is a genuinely useful finding.
`pw-top` and its ERR column is the honest way to compare; ears are not.

---

## Ubuntu / Debian

```bash
sudo apt install mpv dnsutils
```

No `sudo`? Flatpak needs one extra wrapper step:
[no-sudo pre-setup](../hardware/FLATPACK_SAFE_PREINSTAL_WITHOUT_SUDO.md)

Both levels apply. This is the platform the project is tuned for, so a report
here carries the most weight.

One line worth adding to your report:

```bash
pactl info | grep "Server Name"
```

`PulseAudio (on PipeWire ...)` or `pipewire` — PipeWire owns the card, the
tuned path. Plain `pulseaudio` — a standalone daemon owns it and mpv falls
through to `ao=pulse`. Both are valid; I want to know which you got.

The `AO:` line also tells you the sample format. Level 1 has no
`--audio-format` flag, so mpv negotiates its own — `float` is normal there.
Level 2 asks for `s32`, and it does get applied even on the `pulse` path.
A mismatch between what the script asks for and what `AO:` reports is worth
mentioning.

---

## macOS

```bash
brew install mpv
```

**Level 1 works. Level 2 doesn't yet** — `lib/output.sh` sets
`--ao=pipewire,pulse,alsa`, CoreAudio isn't in that list, so mpv has nothing
to initialize and the script exits before playing. A `coreaudio` profile is in
progress.

So on a Mac, Level 1 is the test. Fair warning: it validates mpv and ffmpeg,
which aren't my code. A success here is upstream's success. What it does
answer is how much work a port needs — and one report already did that.

If you'd like to test *my* code on a Mac, the interesting moment is after the
coreaudio profile lands. Say so and I'll ping you.

---

## Windows / WSL

Exploratory. Not supported, not promised, and audio may not work at all.

```bash
wsl.exe --status        # from PowerShell — distro and WSL version
uname -a                # inside WSL
cat /etc/os-release
```

Ubuntu-based WSL:

```bash
sudo apt update
sudo apt install mpv dnsutils
```

This needs `sudo` inside WSL. On a work or school laptop it may be blocked —
if it is, that's the end of the test and a fine result to report.

Then **Level 1 only**, and report each part separately, because they fail
independently:

```
mpv starts:        yes / no
stream opens:      yes / no
audio is audible:  yes / no / not tested
reconnect works:   yes / no / not tested
```

WSL routes audio through a bridge to Windows rather than a Linux audio server,
so mpv running silently is a real and expected outcome here, not a failure on
your part. Don't go configuring PulseAudio or WSLg to chase it — no sound *is*
the finding.

Level 2 isn't worth running on WSL: the script tunes PipeWire, which isn't
what plays the audio there.

---

## What each platform actually validates

| Platform | Level 1 | Level 2 | What a report here answers |
|---|---|---|---|
| Ubuntu + PipeWire | yes | yes | does the tuning hold up on hardware that isn't mine |
| Ubuntu + standalone PulseAudio | yes | yes | does the fallback chain work, and what gets skipped |
| macOS | yes | not yet | is the stream logic portable; how much work a port needs |
| Windows / WSL | partly | no | are the instructions followable in an alien environment |

The last row is the one people underrate. WSL is the harshest test of whether
this documentation makes sense to someone who isn't already inside my head. If
you get stuck on step 2 and can't tell why, that's a bug in my writing and
exactly what I need to hear.

---

## Send the result

**[Open a test report](https://github.com/alexostn/fip-hifi-over-lte/issues/new/choose)**
— one minute, seven quick fields.

Or message me and I'll file it. GitHub always shows your account as the author
of an issue, so if you'd rather not appear publicly, that's the route.

Please strip passwords, tokens, IP addresses, private Wi-Fi names and MAC
addresses from anything you paste — the logs can contain network details.

Results so far: [TESTED_ENVIRONMENTS.md](TESTED_ENVIRONMENTS.md)