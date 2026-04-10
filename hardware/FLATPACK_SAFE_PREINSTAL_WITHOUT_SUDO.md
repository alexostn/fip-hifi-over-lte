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
=== flatpak === flatpak 1.x.x          ← needed
=== mpv === MISSING — will install via flatpak
=== dig === MISSING — DNS pre-warm will be skipped (safe)
=== curl === curl 7.x.x
=== audio === Server Name: PulseAudio   ← or PipeWire-pulse, both fine
              Default Sink: alsa_output.pci... ← laptop speakers
```
if
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
`````





