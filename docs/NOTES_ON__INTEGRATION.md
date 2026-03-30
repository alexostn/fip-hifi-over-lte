# fip-all.sh ↔ ft_irc: Concept Intersections

## TCP Buffering and MessageBuffer

`--stream-buffer-size=512KiB` and the block `--demuxer-max-bytes=8MiB` / `--demuxer-readahead-secs=20` solve the same problem as `MessageBuffer` in ft_irc: TCP is a stream protocol (from Latin *stringere* — to draw tight), data arrives in chunks, and a buffer is needed to accumulate them until a complete "message" is received. In ft_irc, a complete message is a line ending with `\r\n` (CRLF, RFC 1459). In an Icecast stream, it's an audio frame.

```bash
--stream-buffer-size=512KiB   # TCP recv-buffer — absorbs burst packets
--demuxer-max-bytes=8MiB      # ≈5min max demuxer buffer for 192k AAC
--demuxer-readahead-secs=20   # read 20s ahead to survive short outages
```

```cpp
// ft_irc: MessageBuffer accumulates incomplete TCP chunks until \r\n
void MessageBuffer::feed(const std::string& raw) {
    _buf += raw;
}
std::vector<std::string> MessageBuffer::extractMessages() { /* split by \r\n */ }
```

---

## Non-blocking I/O and `--cache-pause=no`

`--cache-pause=no` + `--cache-pause-initial=no` embodies **non-blocking I/O** logic: don't freeze waiting for data, keep the event loop alive. In ft_irc this is enforced via `fcntl(fd, F_SETFL, O_NONBLOCK)` + `poll()`. Without it, one stalled client blocks the entire server — exactly like mpv freezing on a buffer pause.

```bash
--cache-pause=no         # do not freeze on buffer underrun — keep event loop alive
--cache-pause-initial=no # no silence at start — non-blocking from frame 0
```

```cpp
// ft_irc: mandatory non-blocking socket setup
fcntl(fd, F_SETFL, O_NONBLOCK);
// poll() monitors ALL fds simultaneously without blocking on any single one
poll(_pollfds.data(), _pollfds.size(), -1);
```

---

## Disconnect Handling (POLLHUP / `recv()==0`)

The reconnect block — `reconnect_on_network_error=yes`, `reconnect_on_http_error=4xx,5xx`, `reconnect_delay_max=5` — is the exact equivalent of handling `POLLHUP` and `recv()==0` in ft_irc: detect drop → `disconnectClient()` → loop continues. The difference: in ft_irc the server doesn't reconnect itself — that's the client's job; the server only cleans up resources.

```bash
--stream-lavf-o-append=reconnect=1                 # enable HTTP reconnect
--stream-lavf-o-append=reconnect_streamed=1        # KEY: Icecast has no range-request
--stream-lavf-o-append=reconnect_on_network_error=yes
--stream-lavf-o-append=reconnect_on_http_error=4xx,5xx
--stream-lavf-o-append=reconnect_delay_max=5       # max 5s between attempts
--network-timeout=10                               # drop hung TCP — never freeze forever
```

```cpp
// ft_irc: unexpected disconnect path
if (revents & POLLHUP || bytes == 0) {
    server.disconnectClient(fd); // cleans channels, map, poller, socket, memory
}
```

---

## Event Loop: `while true` ↔ `poll()`

`while true` with mpv restart is a simplified analogue of the server's `poll()` loop. Both run indefinitely, both recover from a single connection failure. The key difference: `poll()` monitors **multiple fds simultaneously** (I/O multiplexing, from Latin *multiplex* — manifold), while the bash loop handles only one stream at a time.

```bash
while true; do
    mpv "${MPV_ARGS[@]}" "$URL"   # one connection attempt
    sleep 1                        # backoff before retry
done
```

```cpp
// ft_irc: poll() handles N clients in one syscall
while (true) {
    poll(_pollfds.data(), _pollfds.size(), -1);
    for (auto& pfd : _pollfds) {
        if (pfd.revents & POLLIN) handleClientInput(pfd.fd);
        if (pfd.revents & POLLHUP) disconnectClient(pfd.fd);
    }
}
```

---

## Icecast ↔ IRC: Push Protocols

`reconnect_streamed=1` is required because Icecast is a **push protocol**: the server streams data continuously without range requests — HTTP `Range` header is not supported. IRC works the same way: the server **pushes** messages to the client via `sendToClient()`, with no request→response mechanism in the classic REST sense. Both protocols rely on persistent TCP + continuous event stream.

---

## `declare -A STATIONS` ↔ `std::map`

The associative array `STATIONS[jazz]="url"` is a direct analogue of `std::map<std::string, Channel*>` and `std::map<std::string, Client*>` in ft_irc's architecture. String key → object/resource lookup. In both cases the key is a human-readable name (station name / channel name or nickname).

```bash
declare -A STATIONS
STATIONS[jazz]="https://icecast.radiofrance.fr/fipjazz-hifi.aac?id=radiofrance"
NAME="${1:-fip}"
URL="${STATIONS[$NAME]}"   # O(1) lookup by name
```

```cpp
// ft_irc: same pattern
std::map<std::string, Channel*> _channels;
std::map<int, Client*>          _clients;
Channel* ch = _channels[channelName]; // lookup by name
```

---

## Intersection Table

| `fip-all.sh` script | ft_irc concept | Shared principle |
|---|---|---|
| `--stream-buffer-size=512KiB` | `MessageBuffer` — TCP recv-buffer | Accumulate chunks until complete block |
| `--demuxer-max-bytes` / `readahead` | Buffer until `\r\n` | Incomplete data is not processed |
| `--cache-pause=no` | `O_NONBLOCK` + `poll()` | Never block the event loop |
| `--cache-pause-initial=no` | Non-blocking from first byte | Start without waiting |
| `reconnect_on_network_error=yes` | `POLLHUP` → `disconnectClient()` | Detect and handle connection drop |
| `reconnect_on_http_error=4xx,5xx` | ERR_* numeric replies + disconnect | React to server-side errors |
| `--network-timeout=10` | Hang detection, forced disconnect | Never stall on a dead connection |
| `while true; sleep 1` | `poll()` event loop | Infinite event processing loop |
| `reconnect_streamed=1` | IRC push + `sendToClient()` | Push protocol, no range requests |
| `declare -A STATIONS` | `std::map<string, Channel*>` | Lookup by string key |
