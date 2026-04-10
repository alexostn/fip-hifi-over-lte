# ♫ FIP HiFi — Pre-setup on Ubuntu (no sudo, no external speakers)

> Minimal environment setup to run `fip-stream.sh` on any Ubuntu machine
> where you have no `sudo` access and no external speakers — just laptop audio.

---

## 0 · Check what's already there

# Show all permissions baked into the app manifest
flatpak info --show-permissions io.mpv.Mpv

# Show only user overrides (what YOU changed)
flatpak override --user --show io.mpv.Mpv

# Inspect the raw override file directly
cat ~/.local/share/flatpak/overrides/io.mpv.Mpv


## back to default
```
c2r9s4% flatpak override --user --reset io.mpv.Mpv      # back to default           
c2r9s4% flatpak override --user --show io.mpv.Mpv       # check
c2r9s4%
# download & run 
curl -O https://raw.githubusercontent.com/alexostn/fip-hifi-over-lte/main/fip-stream.sh
# access rights given to executive
chmod +x fip-stream.sh
```
