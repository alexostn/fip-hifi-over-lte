```
╔══════════════════════════════════════════════════════════════════════════════╗
║                      FIP RADIO  ──  mpv PIPELINE                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

  ┌─────────────────────────────────┐
  │  icecast.radiofrance.fr         │
  │  Icecast 2 server               │
  │  AAC 192kbps, 48000Hz, stereo   │
  │  HTTP/1.1  ·  no Range support  │
  │  Transfer-Encoding: chunked     │
  │  → infinite single response     │
  └────────────────┬────────────────┘
                   │  HTTP over TCP
                   │  (one persistent connection)
  ╔════════════════╪═══════════════════════════════════╗
  ║  NETWORK LAYER │                                   ║
  ║                ▼                                   ║
  ║  ┌─────────────────────────────────────────────┐  ║
  ║  │  TCP recv-buffer                            │  ║
  ║  │  --stream-buffer-size=512KiB                │  ║
  ║  │  absorbs TCP burst packets & micro-jitter   │  ║
  ║  └──────────────────────┬──────────────────────┘  ║
  ║                         │                         ║
  ║  timeout watchdog ───►  │  --network-timeout=10s  ║
  ║  if no data in 10s:     │  → force-close hung TCP ║
  ║  drop connection        │                         ║
  ╚═════════════════════════╪═════════════════════════╝
                            │
  ╔═════════════════════════╪═════════════════════════╗
  ║  RECONNECT LAYER        │   (libavformat / lavf)  ║
  ║                         ▼                         ║
  ║  reconnect=1          ──── try HTTP reconnect     ║
  ║  reconnect_streamed=1 ──── no Range header        ║
  ║                            (Icecast-safe mode)    ║
  ║  reconnect_on_network_error=yes                   ║
  ║         └── LTE drop, WiFi handoff, IP change     ║
  ║  reconnect_on_http_error=4xx,5xx                  ║
  ║         └── server restart, 503 overload          ║
  ║  reconnect_delay_max=5s                           ║
  ║         └── wait up to 5s between attempts        ║
  ║                                                   ║
  ║  if lavf reconnect fails → mpv exits              ║
  ║         │                                         ║
  ╚═════════╪═════════════════════════════════════════╝
            │
  ╔═════════╪═════════════════════════════════════════╗
  ║  BASH LOOP (outer failsafe)                       ║
  ║                                                   ║
  ║   while true                                      ║
  ║   ┌──────────────────────────────────────────┐    ║
  ║   │  mpv ... "$URL"   ◄── runs until failure │    ║
  ║   └──────────────────┬───────────────────────┘    ║
  ║                      │ mpv exits (any reason)     ║
  ║                    sleep 1s  ◄── hard backoff     ║
  ║                      │                            ║
  ║                      └──► restart mpv             ║
  ╚══════════════════════════════════════════════════ ╝
            │
            │  raw AAC bitstream (192kbps chunks)
            ▼
  ╔══════════════════════════════════════════════════╗
  ║  DEMUXER CACHE  (mpv internal ring-buffer)       ║
  ║                                                  ║
  ║  --cache=yes                                     ║
  ║  --demuxer-max-bytes=8MiB  ≈ 5 min of audio      ║
  ║  --demuxer-readahead-secs=20  read 20s ahead     ║
  ║                                                  ║
  ║  [============================·····] ←write      ║
  ║   read→                                          ║
  ║                                                  ║
  ║  --cache-pause=no        → never freeze on       ║
  ║  --cache-pause-initial=no   underrun;            ║
  ║                             playback continues   ║
  ║                             while bash retries   ║
  ╚═════════════════════┬════════════════════════════╝
                        │  buffered AAC frames
                        ▼
  ╔══════════════════════════════════════════════════╗
  ║  AAC DECODER  (ffmpeg / libavcodec)              ║
  ║                                                  ║
  ║  AAC 192kbps → PCM float32 (internal)            ║
  ║  48000 Hz · stereo · compressed→uncompressed     ║
  ╚═════════════════════┬════════════════════════════╝
                        │  raw PCM (float32)
                        ▼
  ╔══════════════════════════════════════════════════╗
  ║  AUDIO CONVERSION  (mpv ao chain)                ║
  ║                                                  ║
  ║  --audio-samplerate=48000  (native = no resamp.) ║
  ║  --audio-channels=stereo   (native = passthrough)║
  ║  --audio-format=s16        float32 → int16 PCM   ║
  ║                            (enough for 192k AAC; ║
  ║                             use floatp for DSP)  ║
  ╚═════════════════════┬════════════════════════════╝
                        │  s16 PCM · 48kHz · stereo
                        ▼
  ╔══════════════════════════════════════════════════╗
  ║  AUDIO PLAYBACK BUFFER                           ║
  ║                                                  ║
  ║  --audio-buffer=6.0s                             ║
  ║  6 seconds of decoded PCM held before output    ║
  ║  absorbs LTE jitter & reconnect gaps             ║
  ║  (was 2.0s → 4.0s → now 6.0s for mobile)        ║
  ╚═════════════════════┬════════════════════════════╝
                        │
                        ▼
              ALSA / PulseAudio / PipeWire
                        │
                        ▼
                   ( ◕‿◕ )  speakers
```

```
BUFFER SUMMARY (outer → inner):
┌──────────────────────────────────┬──────────┬─────────────────────────────┐
│ Buffer                           │ Size     │ Purpose                     │
├──────────────────────────────────┼──────────┼─────────────────────────────┤
│ TCP recv  (stream-buffer-size)   │ 512 KiB  │ OS-level packet bursts      │
│ Demuxer cache (demuxer-max-bytes)│ 8 MiB    │ ≈5min AAC — network outages │
│ Readahead (demuxer-readahead)    │ 20 sec   │ pre-fetch before gap hits   │
│ Audio playback (audio-buffer)    │ 6 sec    │ decoded PCM — jitter/LTE    │
└──────────────────────────────────┴──────────┴─────────────────────────────┘

RECONNECT LAYERS (fast → slow):
  1. lavf internal  →  up to 5s delay, no bash involvement
  2. bash while     →  1s sleep, full mpv restart (last resort)
```

There are two independent reconnection levels: `lavf` tries first (quickly, without restarting mpv), and only if that fails does `while true` kick in.[^1]

<div align="center">⁂</div>

[^1]: fip-all_sh.md

