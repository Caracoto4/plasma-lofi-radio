# Lofi Player — a Plasma 6 widget

A small, self-contained lofi radio widget for the KDE Plasma desktop: a spinning
vinyl record, a tonearm that lifts when you pause, an animated equalizer and the
**live track title** of whatever [lofiradio.ru](https://lofiradio.ru) is playing
right now.

![Lofi Player](preview.png)

## Features

- **Plays the stream** straight from `live.lofiradio.ru` via QtMultimedia — no
  external player, no browser tab. Two stations: *lofi hip hop* (128 kbps) and
  *lofi chill* (96 kbps).
- **Live track titles.** Icecast carries the song name in-band as
  `StreamTitle='Artist - Title'`, which Qt's FFmpeg backend does not expose.
  A tiny stdlib-only helper reads it off the socket and serves it as JSON on
  `127.0.0.1`, so the widget can show what is playing.
- **Hand-drawn visuals** — the record, its grooves and the equalizer are QML
  `Canvas` code, not images. Nothing to download, nothing to theme.
- **Marquee title** that scrolls when the name does not fit.
- **Auto-reconnect** if the stream drops, and a volume slider.
- Works both as a desktop widget (296×452) and as a **panel icon** that mirrors
  the same playback state.
- The stream engine is a QML *singleton*, so the desktop card, the panel icon
  and the popup all share a single `MediaPlayer` and one network connection.

## Requirements

| | |
|---|---|
| KDE Plasma | 6.0 or newer |
| Qt | Qt 6 with `qt6-multimedia` (the FFmpeg backend) |
| Kirigami | `kirigami` QML module (pulled in by `plasma-workspace`) |
| Python | 3.8+ — helper only, standard library only, no pip packages |
| systemd | optional, but recommended to keep the helper running |

Tested on Arch Linux with Plasma 6.7.5, Qt 6.11 and Python 3.14.

## Install

```bash
git clone https://github.com/Caracoto4/plasma-lofi-radio.git
cd plasma-lofi-radio
./install.sh
```

Everything is installed into your home directory, so **no root is required**:

- `~/.local/share/plasma/plasmoids/org.koda.lofiplayer` — the widget
- `~/.local/share/lofiplayer/lofi-nowplaying.py` — the track-title helper
- `~/.config/systemd/user/lofi-nowplaying.service` — the helper's user service

Then add the widget: right-click the desktop or panel → **Add Widgets…** →
**Lofi Player**.

If it does not show up in the list, restart the shell:

```bash
systemctl --user restart plasma-plasmashell.service
```

### Manual install

<details>
<summary>Without the script</summary>

```bash
# the widget
kpackagetool6 --type Plasma/Applet --install ./package
# ...or, to update an existing installation
kpackagetool6 --type Plasma/Applet --upgrade ./package

# the helper
install -Dm755 helper/lofi-nowplaying.py ~/.local/share/lofiplayer/lofi-nowplaying.py
install -Dm644 helper/lofi-nowplaying.service ~/.config/systemd/user/lofi-nowplaying.service
systemctl --user daemon-reload
systemctl --user enable --now lofi-nowplaying.service
```

</details>

## Uninstall

```bash
./uninstall.sh
```

The widget instance already placed on your desktop or panel has to be removed by
hand: right-click it → **Remove Widget**.

## The helper

`lofi-nowplaying.py` keeps one long-lived connection to the Icecast stream,
skips the audio bytes, and publishes every metadata block it sees:

```
GET http://127.0.0.1:8731/nowplaying.json
{
  "raw": "dryhope - Shade",
  "artist": "dryhope",
  "title": "Shade",
  "station": "LoFi Radio",
  "stream": "http://live.lofiradio.ru:8000/lofi_mp3_128",
  "updated": 1792329532,
  "connected": true
}
```

It binds to `127.0.0.1` only, tries ports `8731`, `8732`, `8733` in order, and
answers `GET /health` with `ok`. It reconnects on its own with exponential
backoff.

```bash
systemctl --user status lofi-nowplaying
journalctl --user -u lofi-nowplaying -f
```

The widget polls it every 2 seconds. **Audio does not go through the helper** —
if the helper is down you still get music, just without track titles.

## Repository layout

```
package/                     the Plasma package (this is what kpackagetool6 installs)
  metadata.json              id, name, version, category
  contents/ui/main.qml       applet: full representation + panel mirror
  contents/ui/components/
    StreamPlayer.qml         QML singleton: MediaPlayer, stations, title polling
    PlayerCard.qml           the visual card (Plasma-independent, qml6-loadable)
  contents/audio/            generated lofi loops (see note below)
helper/
  lofi-nowplaying.py         Icecast metadata -> localhost JSON
  lofi-nowplaying.service    systemd user unit
tools/
  generate_lofi.py           procedural lofi generator (stdlib only)
install.sh, uninstall.sh
```

`PlayerCard.qml` deliberately imports nothing from Plasma except Kirigami, so you
can iterate on the look with a plain `qml6` run instead of restarting plasmashell.

### Generating your own loops

`tools/generate_lofi.py` writes three loopable 16-bit WAV files — soft detuned
chords, a mellow bass, a gentle kick and vinyl crackle through a one-pole
low-pass filter. Pure `math`, `wave` and `struct`, no dependencies:

```bash
python3 tools/generate_lofi.py     # writes into package/contents/audio
```

Note: the current version of the widget streams lofiradio.ru and does not play
these loops — they are leftovers from the first iteration, kept as a starting
point if you want to add an offline mode. They cost ~700 KB in the package; feel
free to delete `package/contents/audio/` and the generator call above if you do
not need them.

## Troubleshooting

**No track titles, but music plays.**
The helper is not reachable. Check `systemctl --user status lofi-nowplaying` and
`curl http://127.0.0.1:8731/nowplaying.json`. Note that lofiradio.ru sometimes
broadcasts a station jingle instead of a song name; the widget shows whatever
the stream reports.

**Nothing plays at all.**
Qt 6 needs the FFmpeg backend for MP3-over-HTTP. Make sure `qt6-multimedia` is
installed and that `QT_MEDIA_BACKEND` is not forced to something else. Check the
Plasma log: `journalctl --user -u plasma-plasmashell -f`.

**The widget is missing from "Add Widgets…".**
`kpackagetool6 --type Plasma/Applet --list` should show `org.koda.lofiplayer`.
If it does, restart plasmashell (see above).

**A "port busy" loop in the helper log.**
Something else took 8731–8733. Both the helper and the widget walk the same
three ports, so it will still work; if all three are taken, edit `HTTP_PORTS`
and `nowPlayingPorts` in the two files.

## Credits

- Stream: [lofiradio.ru](https://lofiradio.ru) — all music is theirs.
- Code: MIT, see [LICENSE](LICENSE).
