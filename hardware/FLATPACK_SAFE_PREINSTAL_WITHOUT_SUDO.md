# ♫ FIP HiFi — Pre-setup on Ubuntu (no sudo, no external speakers)

> Minimal environment setup to run `fip-stream.sh` on any Ubuntu machine
> where you have no `sudo` access and no external speakers — just laptop audio.

---

## 0 · Check what's already there

Run all at once and read the output:

```bash
# Check tools and audio
echo "=== flatpak ===" && flatpak --version 2>/dev/null || echo "MISSING"
echo "=== mpv ===" && mpv --version 2>/dev/null | head -1 || echo "MISSING — will install via flatpak"
echo "=== git ===" && git --version 2>/dev/null || echo "MISSING"
echo "=== dig ===" && dig -v 2>&1 | head -1 || echo "MISSING — DNS pre-warm will be skipped (safe)"
echo "=== curl ===" && curl --version | head -1 || echo "MISSING"
echo "=== audio ===" && pactl info | grep -E "Server Name|Default Sink"
```

Expected good output:

| Tool    | Status | Conclusion                                     |
| ------- | ------ | ---------------------------------------------- |
| flatpak | [✔]    | 1.12.7 — install mpv with its help             |
| mpv     | [✘]    | MISSING                                        |
| git     | [✔]    | needed in step 4 — the script sources `lib/`   |
| dig     | [✔]    | 9.18.39 — DNS pre-warm works                   |
| curl    | [✔]    | 7.81.0                                         |
| audio   | [✔]    | see the note below — read `Server Name` closely |

### Reading `Server Name`

This line decides which audio path the script takes, so it is worth a look:

| `Server Name` reports            | What it means                                              |
| -------------------------------- | ---------------------------------------------------------- |
| `PulseAudio (on PipeWire 1.x.y)` | PipeWire owns the card — the tuned path, all flags apply    |
| `pipewire`                       | same, bare PipeWire without the Pulse layer                |
| `pulseaudio`                     | a standalone PulseAudio daemon owns the card               |

The last case still works — mpv falls through `pipewire,pulse,alsa` and keeps
the first backend that initializes. But the PipeWire-specific flags
(`--audio-format=s32`, quantum tuning) are skipped or ignored on that path.
Confirmed on a managed lab machine where `pipewire` and a separate
`pulseaudio 15.99.1` were running side by side.

If you see plain `pulseaudio`, that is a valid and interesting test result —
please mention it in your report.

---

## 1 · Install mpv via Flatpak

```bash
# Add Flathub repo for current user only
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install mpv
flatpak install --user flathub io.mpv.Mpv
```

Verify:

```bash
flatpak run --command=mpv io.mpv.Mpv --version | head -1
# Expected: mpv 0.4x.x
```

> **If your admin prefers distribution packages:** `sudo apt install mpv
> dnsutils` installs the same player from the Ubuntu repositories — signed and
> maintained by the distribution. That needs `sudo`; this whole page exists for
> the case where you don't have it. Either path is a valid test, just say which
> one you used.

---

## 2 · Make `mpv` callable from scripts

`fip-stream.sh` calls `mpv` directly. Create a thin wrapper in `~/.local/bin`.

> **⚠ Shell note — bash vs zsh:**
> On **bash** (default Ubuntu shell), `~/.local/bin` is added to `PATH` automatically.
> On **zsh**, this does NOT happen automatically — you must add it once manually (see note after wrapper setup).

```bash
# Create local bin dir if missing
mkdir -p ~/.local/bin

# Write wrapper
cat > ~/.local/bin/mpv << 'EOF'
#!/bin/bash
exec flatpak run --user io.mpv.Mpv "$@"
EOF

# Make executable
chmod +x ~/.local/bin/mpv
```

Verify wrapper works:

```bash
which mpv      # should print: /home/<user>/.local/bin/mpv
mpv --version  # should print: mpv 0.4x.x
```

> **⚠ zsh users — if `which mpv` returns `mpv not found`:**
> `~/.local/bin` is not added to PATH automatically in zsh.
> Run once, then reopen your terminal or source the config:
> ```bash
> # Register ~/.local/bin for zsh — run once
> echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
> ```
> Then re-run `which mpv` — should print `~/.local/bin/mpv`.

---

## 3 · Verify audio on laptop speakers

**Smoke test** — 5 seconds of audio from FIP. No `--ao` here on purpose: mpv
picks the backend itself, and which one it picks is the first useful data point.

```bash
# 5-second audio test via laptop speakers
mpv --no-video --length=5 \
  "https://icecast.radiofrance.fr/fip-hifi.aac?id=radiofrance"
```

Watch the `AO:` line in the output — it names the backend, sample rate and
format that actually got used, e.g. `AO: [pipewire] 48000Hz stereo 2ch s32`.
Note it down; that line answers half of the test report.

If you hear music — everything is ready.

> **Troubleshoot / no sound:**
> ```bash
> # What outputs does this mpv build have?
> mpv --audio-device=help
>
> # What sinks does the system offer?
> pactl list short sinks
>
> # Force the Pulse backend explicitly
> mpv --no-video --length=5 --ao=pulse \
>   "https://icecast.radiofrance.fr/fip-hifi.aac?id=radiofrance"
> ```
> `--ao=alsa` is deliberately not suggested here: it bypasses the PipeWire
> graph and was dropped from this project in v16.0 for that reason. If nothing
> else works it is worth a try, but a failure at that point is a finding, not
> something to work around — please report it instead.

---

## 4 · Get the project and run it

`fip-stream.sh` sources `lib/output.sh`, so a single-file download will not
work — fetch the whole tree at a fixed tag:

```bash
# Shallow clone of one tag — nothing is installed, nothing leaves this folder
git clone --branch v16.3 --depth 1 \
  https://github.com/alexostn/fip-hifi-over-lte.git
cd fip-hifi-over-lte
```

Read before running — it is one bash file plus a small output profile:

```bash
less fip-stream.sh
less lib/output.sh
```

Then:

```bash
# Run FIP main
./fip-stream.sh

# Or with genre alias
./fip-stream.sh jazz
```

Stop playback: `Ctrl+C`

> **No git available?** Then two files, in the right places:
> ```bash
> mkdir -p fip/lib && cd fip
> curl -fsSLO https://raw.githubusercontent.com/alexostn/fip-hifi-over-lte/v16.3/fip-stream.sh
> curl -fsSL -o lib/output.sh https://raw.githubusercontent.com/alexostn/fip-hifi-over-lte/v16.3/lib/output.sh
> chmod +x fip-stream.sh
> ```

### What the script touches

- writes a log to `/tmp/fip-mpv-last.log` and `/tmp/fip-reconnects.log`
- sets the global PipeWire quantum via `pw-metadata` while it runs
- installs nothing, needs no `sudo`, changes no file outside `/tmp`

On a shared machine the quantum setting is worth knowing about: up to and
including v16.3 it is **not** reset when the script exits. To put it back:

```bash
pw-metadata -n settings 0 clock.force-quantum 0
```

From v16.4 onward the script saves and restores it itself, and skips the write
entirely when PipeWire does not own the card.

---

## Quick checklist

| Step         | Command                              | Expected                     |
| ------------ | ------------------------------------ | ---------------------------- |
| flatpak OK   | `flatpak --version`                  | `Flatpak 1.x`                |
| mpv installed| `mpv --version`                      | `mpv 0.4x.x`                 |
| PATH (zsh)   | `which mpv`                          | `~/.local/bin/mpv`           |
| audio server | `pactl info`                         | see the `Server Name` table above |
| smoke test   | `mpv --no-video --length=5 <url>`    | music heard, note the `AO:` line |
| project tree | `ls fip-stream.sh lib/output.sh`     | both present                 |
| script runs  | `./fip-stream.sh`                    | `٩(◕‿◕) FIP fip — 192kbps...`|

---

## Report the result

One minute, and a run that worked is just as useful as one that didn't:

https://github.com/alexostn/fip-hifi-over-lte/issues/new/choose

Handy to have ready: the `AO:` line, what `pactl info` said for `Server Name`,
your Ubuntu version, and whether you used Flatpak or apt.

---

[back to README.md](../README.md)
*fip-hifi-over-lte · pre-setup v2 · tested: Ubuntu 24.04 · also on a managed 22.04 lab machine · no-sudo · flatpak · zsh-compatible*
