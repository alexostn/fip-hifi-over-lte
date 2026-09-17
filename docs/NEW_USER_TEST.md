# Testing a fresh clone as a new user

This documents how *I* verify the repo works for someone who has never seen
it before — no aliases, no `~/.config/fip/env`, no leftover state from this
machine. Run it after any change to `fip-stream.sh` or `lib/output.sh`.

This is a maintainer checklist. The page for people testing on their own
machines is [TESTING.md](TESTING.md).

The core idea: isolate `$HOME` for the test process so nothing on the real
system leaks in, then clone fresh at a tag and run the entry point directly,
not through the `fip` alias.

---

## Setup

Clone at the tag you are releasing, not `main` — otherwise you are testing a
moving target.

```bash
mkdir -p /tmp/newuser-test
cd /tmp/newuser-test
git clone --branch v16.4 --depth 1 \
  https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
```

## Test 1 — analog works with zero configuration

The default profile must play with nothing set up beyond a clone.

```bash
HOME=/tmp/newuser-test ./fip-stream.sh jazz
```

Expected: the script prints its version line, the output profile, and starts
audio.

```
(⌐■_■) analog · S32LE 48000
٩(◕‿◕) FIP 16.4 jazz — 192kbps Hi-Fi (PipeWire s32 + xrun fix)
```

No `FIP_BT_MAC`, no env file, no prior `pactl` or `wpctl` setup required.
`HOME=/tmp/newuser-test` matters here — without it the script would still
find this machine's real `~/.config/fip/env` and any other personal state,
defeating the point of the test.

On a machine where PipeWire does not own the card, a third line appears and
is correct:

```
(゜.゜) PipeWire is not the audio server - leaving quantum alone
```

Stop with a single Ctrl+C. This also verifies `cleanup()` — it must kill the
tracked mpv PID and exit on the first press, not require two. Confirm nothing
survived:

```bash
pgrep -a mpv
```

Empty output. A surviving mpv means `cleanup()` is broken, which matters
because mpv runs sandboxed under Flatpak and signal propagation to a
grandchild is not reliable.

### Test 1b — the quantum is put back (v16.4)

Only meaningful where PipeWire owns the card. Elsewhere the script skips the
write and this test has nothing to check.

```bash
pw-metadata -n settings | grep force-quantum      # before
HOME=/tmp/newuser-test ./fip-stream.sh jazz &
sleep 8
pw-metadata -n settings | grep force-quantum      # during → 8192, or clamped
kill %1 ; sleep 2
pw-metadata -n settings | grep force-quantum      # after → same as before
```

Then repeat with Ctrl+C instead of `kill`. Different trap path — `INT` goes
through `cleanup()`, a normal exit through the `EXIT` trap.

## Test 2 — bluetooth without a MAC fails clearly

`FIP_OUT=bt` with no `FIP_BT_MAC` set must refuse in plain language instead
of hanging, silently falling back, or connecting to whatever Bluetooth device
happens to be paired.

```bash
HOME=/tmp/newuser-test FIP_OUT=bt ./fip-stream.sh jazz
```

Expected output:

```
No Bluetooth speaker configured (◔_◕ .･ﾟ✧) Copy config/env.example, fill in your speaker's MAC, then run again.
```

This comes from an explicit check in `lib/output.sh`:

```bash
if [ -z "$FIP_BT_MAC" ]; then
    echo "No Bluetooth speaker configured (◔_◕ .･ﾟ✧) Copy config/env.example, ..."
    exit 1
fi
```

Earlier versions used the bash `:?` parameter form, which produced a raw
`lib/output.sh: line 18: FIP_BT_MAC: ...` message. That was replaced because
it reads like a crash rather than an instruction. If you see the old form,
you are running a pre-v16.3 clone.

Run Test 1 to completion before starting Test 2 — two mpv processes
competing for the same audio sink makes the output harder to read and isn't
what the test is checking.

## Test 3 (optional) — bluetooth with a real MAC

Confirms the happy path once a MAC is supplied. This is no longer a new-user
simulation — it plays through the real speaker on this machine — but it's
worth a quick check after touching `lib/output.sh`.

```bash
HOME=/tmp/newuser-test FIP_BT_MAC=<speaker-mac> FIP_OUT=bt ./fip-stream.sh jazz
```

Expected: `(⌐■_■) bluetooth · ldac · 48000`, or whichever codec the speaker
negotiates, and audio over Bluetooth. The LDAC profile is reported as bare
`a2dp-sink` — `a2dp-sink-ldac` is not an entity and returns *No such entity*.

---

## Stricter isolation (when `$HOME` alone isn't enough)

`HOME=` isolation is enough for checking the script's own logic, but it still
runs as your real Linux user with your real installed packages and your real
PipeWire/BlueZ state. Two options go further.

### A dedicated system user

Catches missing dependencies and permission issues that `HOME=` isolation
can't — a fresh user may not have `mpv` or `dig` installed.

```bash
sudo useradd -m -s /bin/bash fiptest
sudo su - fiptest

git clone --branch v16.4 --depth 1 \
  https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
./fip-stream.sh jazz
```

Clean up afterward:

```bash
sudo pkill -u fiptest
sudo userdel -r fiptest
```

### A container

The most honest test — no PipeWire, no BlueZ, no audio hardware at all. Won't
produce sound, but surfaces every undocumented dependency immediately, which
is exactly what a real new user hits first.

```bash
docker run -it --rm ubuntu:24.04 bash
```

```bash
apt update && apt install -y git mpv curl dnsutils
git clone --branch v16.4 --depth 1 \
  https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
./fip-stream.sh jazz
```

Runtime dependencies are `mpv`, `dig` (from `dnsutils`) and `curl`. `jq` is
**not** one — it only appears in commented-out diagnostic one-liners for
reading `~/fip-diagnostics.jsonl` afterwards. Don't install it here; if the
script ever fails without it, that's a bug to fix rather than a dependency
to document.

---

## Result of the last run

**v16.4, 17 Sep 2026, 42 campus lab machine (managed, no sudo):**

- Test 1 — analog profile played with a clean `$HOME`, no configuration.
  `AO: [pulse]` rather than `[pipewire]`: a standalone `pulseaudio 15.99.1`
  owns the card here, and the fallback chain handled it.
- Test 1b — skipped. PipeWire does not own the card on this machine, so the
  script correctly printed the skip message and wrote nothing. **The restore
  path is still unverified on a PipeWire machine.**
- Ctrl+C and `kill` both left `pgrep -a mpv` empty.
- Test 2 — not re-run since the message changed in v16.3.

Open from this run: `Cache:` settles at ~3.2s, not the 60s the readahead flag
asks for. Icecast streams in real time, so there is no future to read ahead
into — the flag is a ceiling, not a target. One macOS report showed 22s and
that difference is not yet explained.

## Cleanup

```bash
rm -rf /tmp/newuser-test
ls /tmp/newuser-test    # should say: No such file or directory
```

`/tmp` is cleared on reboot regardless, but there's no reason to leave a
cloned copy sitting around if you're done with it sooner.