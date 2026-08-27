# Testing a fresh clone as a new user

This documents how to verify the repo works for someone who has never seen
it before — no aliases, no `~/.config/fip/env`, no leftover state from this
machine. Useful after any change to `fip-stream.sh` or `lib/output.sh`.

The core idea: isolate `$HOME` for the test process so nothing on the real
system leaks in, then clone fresh and run the entry point directly, not
through the `fip` alias.

---

## Setup

```bash
mkdir -p /tmp/newuser-test
cd /tmp/newuser-test
git clone https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
```

## Test 1 — analog works with zero configuration

The default profile must play with nothing set up beyond a clone.

```bash
HOME=/tmp/newuser-test ./fip-stream.sh jazz
```

Expected: the script prints

```
(⌐■_■) analog · S32LE 48000
```

and audio starts. No `FIP_BT_MAC`, no env file, no prior `pactl` or `wpctl`
setup required. `HOME=/tmp/newuser-test` matters here — without it the
script would still find this machine's real `~/.config/fip/env` and any
other personal state, defeating the point of the test.

Stop with a single Ctrl+C — this also verifies the `trap 'exit 0' INT TERM`
added in `fip-stream.sh` exits cleanly on the first press rather than
requiring two.

## Test 2 — bluetooth without a MAC fails loudly, not silently

`FIP_OUT=bt` with no `FIP_BT_MAC` set must refuse clearly instead of
hanging, silently falling back, or connecting to whatever Bluetooth device
happens to be paired.

```bash
HOME=/tmp/newuser-test FIP_OUT=bt ./fip-stream.sh jazz
```

Expected output:

```
lib/output.sh: line 18: FIP_BT_MAC: FIP_OUT=bt requires FIP_BT_MAC (see config/env.example)
```

This comes from a bash parameter check in `lib/output.sh`:

```bash
: "${FIP_BT_MAC:?FIP_OUT=bt requires FIP_BT_MAC (see config/env.example)}"
```

The `:?` form aborts immediately with the given message if the variable is
unset — this is what produces the error above, and it points the user at
`config/env.example` rather than leaving them to guess.

Run Test 1 to completion (Ctrl+C once) before starting Test 2 — two mpv
processes competing for the same audio sink makes the output harder to
read and isn't what the test is checking.

## Test 3 (optional) — bluetooth with a real MAC

Confirms the happy path once a MAC is supplied. This is no longer a
new-user simulation — it plays through the real speaker on this machine —
but it's worth a quick check after touching `lib/output.sh`.

```bash
HOME=/tmp/newuser-test FIP_BT_MAC=<speaker-mac> FIP_OUT=bt ./fip-stream.sh jazz
```

Expected: `(⌐■_■) bluetooth · ldac · 48000` (or whichever codec the speaker
negotiates), audio plays over Bluetooth.

---

## Stricter isolation (when `$HOME` alone isn't enough)

`HOME=` isolation is sufficient for checking the script's own logic, but it
still runs as your real Linux user with your real installed packages and
your real PipeWire/BlueZ state. Two options go further.

### A dedicated system user

Catches missing dependencies and permission issues that `HOME=` isolation
can't — a fresh user may not have `mpv`, `dig`, or `jq` installed.

```bash
sudo useradd -m -s /bin/bash fiptest
sudo su - fiptest

git clone https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
./fip-stream.sh jazz
```

Clean up afterward:

```bash
sudo pkill -u fiptest
sudo userdel -r fiptest
```

### A container

The most honest test — no PipeWire, no BlueZ, no audio hardware at all.
Won't produce sound, but surfaces every undocumented dependency immediately,
which is exactly the kind of thing a real new user hits first.

```bash
docker run -it --rm ubuntu:24.04 bash
```

```bash
apt update && apt install -y git mpv curl dnsutils jq
git clone https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
./fip-stream.sh jazz
```

---

## Result of the last run

Both required tests passed on first try, no changes needed to
`lib/output.sh`:

- analog profile played with a clean `$HOME`, no configuration
- bluetooth profile failed with the exact intended message when
  `FIP_BT_MAC` was unset, pointing at `config/env.example`

## Cleanup

```bash
rm -rf /tmp/newuser-test
```
ch◔ck
```bash
ls /tmp/newuser-test
```

`/tmp` is cleared on reboot regardless, but there's no reason to leave a
cloned copy sitting around if you're done with it sooner.
