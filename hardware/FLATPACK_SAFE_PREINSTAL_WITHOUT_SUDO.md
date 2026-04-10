# ♫ FIP HiFi — Pre-setup on Ubuntu (no sudo, no external speakers)

>  Minimal environment setup to run `fip-stream.sh` on any Ubuntu machine
> where you have no `sudo` access and no external speakers — just laptop audio.

---

## 0 · Check what's already there 
Run all at once and read the output:

```bash
# Check tools and audio
echo "=== flatpak ===" && flatpak --version 2>/dev/null || echo "MISSING"
echo "=== mpv ===" && mpv --version 2>/dev/null | head -1 || echo "MISSING — will install via flatpak"
echo "=== dig ===" && dig -v 2>&1 | head -1 || echo "MISSING — DNS pre-warm will be skipped (safe)"
echo "=== curl ===" && curl --version | head -1 || echo "MISSING"
echo "=== audio ===" && pactl info | grep -E "Server Name|Default Sink"
```
Expected good output:
```
| Tool    | Status | Conclusion                                     |
| ------- | -----  | ---------------------------------------------- |
| flatpak | [✔]    | 1.12.7 — install mpv with its help             |
| mpv     | [✘]    | MISSING                                        |
| dig     | [✔]    | 9.18.39 — DNS pre-warm works                   |
| curl    | [✔]    | 7.81.0                                         |
| audio   | [✔]    | PulseAudio + analog-stereo — built-in dynamics |
```
then
```
# Add Flathub repo for current user only
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install mpv
flatpak install --user flathub io.mpv.Mpv
```
verify
```
flatpak run --command=mpv io.mpv.Mpv --version | head -1
# Expected: mpv 0.3x.x
```
## 2 · Make `mpv` callable from scripts
```
`fip-stream.sh` calls `mpv` directly. Create a thin wrapper in `~/.local/bin`
(this directory is already in PATH on Ubuntu 22.04+).
`
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

Verify wrapper works
```
which mpv     # should print: ~/.local/bin/mpv
mpv --version # should print: mpv 0.3x.x
```

## 3 · Verify audio on laptop speakers

**Smoke test** — 5 seconds of silence-free audio from FIP:

```
# 5-second audio test via laptop speakers
mpv --no-video --length=5 --ao=pulse \
  "https://icecast.radiofrance.fr/fip-hifi.aac?id=radiofrance"
```
If you hear music — everything is ready.


> **Troubleshoot / no sound:**
> ```
> # List available audio outputs
> pactl list short sinks
> # Try explicit output
> mpv --no-video --length=5 --ao=alsa \
>   "https://icecast.radiofrance.fr/fip-hifi.aac?id=radiofrance"
> ```

---

## 4 · Download and run the main script

```
# Download
curl -O https://raw.githubusercontent.com/alexostn/fip-hifi-over-lte/main/fip-stream.sh
chmod +x fip-stream.sh

# Run FIP main
./fip-stream.sh

# Or with genre alias
./fip-stream.sh jazz
```

Stop playback  `Ctrl+C`

---

## Quick checklist

| Step  | Command | Expected  |
|---|---|---|
| flatpak OK | `flatpak --version` | `flatpak 1.x` |
| mpv installed | `mpv --version` | `mpv 0.3x` |
| audio works | `pactl info` | sink: `alsa_output...` |
| smoke test | `mpv --no-video --length=5 <url>` | music heard |
| script runs | `./fip-stream.sh` | `٩(◕‿◕) FIP fip — 192kbps...` |

---

*fip-hifi-over-lte · pre-setup v1 · tested: Ubuntu 22.04 · no-sudo · flatpak*





