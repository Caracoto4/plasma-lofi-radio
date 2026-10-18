pragma Singleton

import QtQuick
import QtMultimedia

Item {
    id: engine

    readonly property var stations: [
        {
            name: qsTr("lofi hip hop"),
            url: "http://live.lofiradio.ru:8000/lofi_mp3_128"
        },
        {
            name: qsTr("lofi chill"),
            url: "http://live.lofiradio.ru:8000/lofi_mp3_96"
        }
    ]
    property int stationIndex: 0
    property url streamUrl: stations[stationIndex].url

    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property bool buffering: player.mediaStatus === MediaPlayer.BufferingMedia
                                        || player.mediaStatus === MediaPlayer.LoadingMedia

    property string title: ""
    property string artist: ""
    property string stationName: ""
    property string lastError: ""
    property real volume: 0.75

    signal trackChanged()

    property int reconnectCount: 0

    readonly property var nowPlayingPorts: [8731, 8732, 8733]
    property int nowPlayingPortIndex: 0
    property string lastRaw: ""

    function applyTrack(newArtist, newTitle, raw) {
        var a = String(newArtist === undefined || newArtist === null ? "" : newArtist).trim();
        var t = String(newTitle === undefined || newTitle === null ? "" : newTitle).trim();
        var r = String(raw === undefined || raw === null ? "" : raw).trim();
        if (t === "" && a === "")
            return false;
        if (t === title && a === artist && r === lastRaw)
            return false;
        artist = a;
        title = t;
        lastRaw = r;
        trackChanged();
        return true;
    }

    property var nowPlayingReq: null

    function nowPlayingUrlFor(index) {
        return "http://127.0.0.1:" + nowPlayingPorts[index] + "/nowplaying.json";
    }

    function readNowPlaying() {
        if (nowPlayingPorts.length === 0)
            return;
        if (nowPlayingReq !== null) {
            try {
                nowPlayingReq.abort();
            } catch (e) {
            }
            nowPlayingReq = null;
        }
        var xhr = new XMLHttpRequest();
        nowPlayingReq = xhr;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            nowPlayingReq = null;
            if (xhr.status !== 200) {
                nowPlayingState = 1;
                nowPlayingPortIndex = (nowPlayingPortIndex + 1) % nowPlayingPorts.length;
                return;
            }
            nowPlayingState = 0;
            var data = xhr.response;
            if (data === null || data === undefined)
                return;
            if (data.station)
                stationName = String(data.station);
            applyTrack(data.artist, data.title, data.raw);
        };
        xhr.onerror = function () {
            nowPlayingReq = null;
            nowPlayingState = 1;
            nowPlayingPortIndex = (nowPlayingPortIndex + 1) % nowPlayingPorts.length;
        };
        try {
            xhr.open("GET", nowPlayingUrlFor(nowPlayingPortIndex), true);
            xhr.responseType = "json";
            xhr.send();
        } catch (e) {
            nowPlayingReq = null;
            nowPlayingState = 1;
            nowPlayingPortIndex = (nowPlayingPortIndex + 1) % nowPlayingPorts.length;
        }
    }

    property int nowPlayingState: 1

    Timer {
        id: nowPlayingTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: engine.readNowPlaying()
    }

    function toggle() {
        if (playing)
            player.pause();
        else
            player.play();
    }

    function play() {
        player.play();
    }

    function pause() {
        player.pause();
    }

    function setStation(i) {
        stationIndex = (i + stations.length) % stations.length;
        player.stop();
        player.source = stations[stationIndex].url;
        player.play();
    }

    function nextStation() {
        setStation(stationIndex + 1);
    }

    function previousStation() {
        setStation(stationIndex - 1);
    }

    function setVolume(v) {
        engine.volume = Math.max(0, Math.min(1, v));
    }

    Connections {
        target: player
        function onErrorChanged() {
            if (player.error !== MediaPlayer.NoError) {
                engine.lastError = player.errorString;
                engine.scheduleReconnect();
            }
        }
        function onMediaStatusChanged() {
            if (player.mediaStatus === MediaPlayer.EndOfMedia
                    || player.mediaStatus === MediaPlayer.InvalidMedia
                    || player.mediaStatus === MediaPlayer.StalledMedia)
                engine.scheduleReconnect();
        }
    }

    MediaPlayer {
        id: player
        source: engine.streamUrl
        audioOutput: AudioOutput {
            id: audio
            volume: engine.volume
        }
    }

    function scheduleReconnect() {
        if (!reconnectTimer.running)
            reconnectTimer.restart();
    }

    Timer {
        id: reconnectTimer
        interval: 2500
        onTriggered: {
            engine.reconnectCount++;
            player.stop();
            player.source = "";
            player.source = engine.streamUrl;
            player.play();
        }
    }

    onPlayingChanged: {
        if (playing)
            readNowPlaying();
    }

    Component.onCompleted: {
        play();
    }
}
