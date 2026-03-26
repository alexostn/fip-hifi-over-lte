# fip-all.sh ↔ ft_irc: пересечения концепций

## TCP-буферизация и MessageBuffer

`--stream-buffer-size=512KiB` и блок `--demuxer-max-bytes=8MiB` / `--demuxer-readahead-secs=20` решают ту же задачу, что `MessageBuffer` в ft_irc: TCP — потоковый протокол (stream protocol, от лат. *stringere* — тянуть), данные приходят кусками (chunks), и нужен буфер, который накапливает их до получения полного "сообщения". В ft_irc полным сообщением считается строка, оканчивающаяся на `\r\n` (CRLF, RFC 1459). В Icecast-стриме — аудио-фрейм.

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

## Non-blocking I/O и `--cache-pause=no`

`--cache-pause=no` + `--cache-pause-initial=no` — это логика **non-blocking I/O** (неблокирующий ввод-вывод): не замирать в ожидании данных, продолжать event loop. В ft_irc это обеспечивается `fcntl(fd, F_SETFL, O_NONBLOCK)` + `poll()`. Без этого один зависший клиент блокирует весь сервер — то же самое, что mpv, зависший на паузе буфера.

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

## Обработка обрывов соединения (POLLHUP / `recv()==0`)

Блок reconnect в скрипте — `reconnect_on_network_error=yes`, `reconnect_on_http_error=4xx,5xx`, `reconnect_delay_max=5` — точный аналог обработки `POLLHUP` и `recv()==0` в ft_irc: обнаружил обрыв → `disconnectClient()` → цикл продолжается. Разница: в ft_irc сервер не переподключается сам — это задача клиента; сервер только чистит ресурсы.

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

## Event loop: `while true` ↔ `poll()`

`while true` с перезапуском mpv — упрощённый аналог `poll()`-цикла сервера. Оба работают бесконечно, оба восстанавливаются после сбоя одного соединения. Разница: `poll()` мониторит **несколько fd одновременно** (I/O multiplexing, от лат. *multiplex* — многократный), тогда как bash-цикл — только один поток.

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

## Icecast ↔ IRC: push-протоколы

`reconnect_streamed=1` нужен потому, что Icecast — **push-протокол** (push protocol): сервер льёт данные непрерывно без range-запросов, HTTP-заголовок `Range` не поддерживается. IRC — то же самое: сервер **пушит** сообщения клиенту через `sendToClient()`, нет механизма "запрос → ответ" в классическом REST-смысле. Оба протокола — персистентный TCP + непрерывный поток событий.

---

## `declare -A STATIONS` ↔ `std::map`

Ассоциативный массив (associative array) `STATIONS[jazz]="url"` — прямой аналог `std::map<std::string, Channel*>` и `std::map<std::string, Client*>` из архитектуры ft_irc. Lookup по строковому ключу → объект/ресурс. В обоих случаях ключ — human-readable имя (название станции / название канала или никнейм).

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

## Таблица пересечений

| Скрипт `fip-all.sh` | Концепция ft_irc | Общий принцип |
|---|---|---|
| `--stream-buffer-size=512KiB` | `MessageBuffer` — TCP recv-buffer | Накопление чанков до полного блока |
| `--demuxer-max-bytes` / `readahead` | Буферизация до `\r\n` | Неполные данные не обрабатываются |
| `--cache-pause=no` | `O_NONBLOCK` + `poll()` | Не блокировать event loop |
| `--cache-pause-initial=no` | non-blocking с первого байта | Старт без ожидания |
| `reconnect_on_network_error=yes` | `POLLHUP` → `disconnectClient()` | Обнаружение и обработка обрыва |
| `reconnect_on_http_error=4xx,5xx` | ERR_* numeric replies + disconnect | Реакция на ошибки сервера |
| `--network-timeout=10` | Hang detection, принудительный disconnect | Не зависать на мёртвом соединении |
| `while true; sleep 1` | `poll()`-event loop | Бесконечный цикл обработки событий |
| `reconnect_streamed=1` | IRC push + `sendToClient()` | Push-протокол без range-запросов |
| `declare -A STATIONS` | `std::map<string, Channel*>` | Lookup по строковому ключу |
