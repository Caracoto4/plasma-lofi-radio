// Lofi Player — the visual card.
//
// Deliberately independent of Plasma, so it can be loaded on its own with
// qml6 for quick visual iteration.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: card

    // ---- public API -------------------------------------------------------
    /// The shared radio engine (the StreamPlayer singleton). Without it the
    /// card is a pure picture, which is exactly what the panel mirror wants.
    property var engine: null

    property bool compact: false
    /// used by the offscreen preview harness to render a fixed state
    property bool previewActive: false
    property bool previewPlaying: true
    property string previewTitle: ""
    property string previewArtist: ""

    /// false inside a panel, where Plasma already draws a background
    property bool drawBackground: true

    /// The plasmoid hands over the StreamPlayer singleton. Without one the card
    /// renders as a still picture with safe defaults.
    readonly property var stream: engine !== null
                                  ? engine
                                  : ({
                                        playing: false,
                                        buffering: false,
                                        title: "",
                                        artist: "",
                                        stationName: "",
                                        volume: 0.75
                                    })

    readonly property bool playing: previewActive ? previewPlaying : stream.playing
    readonly property bool buffering: previewActive ? false : stream.buffering
    readonly property string trackTitle: previewActive ? previewTitle : stream.title
    readonly property string trackArtist: previewActive ? previewArtist : stream.artist
    /// mirrored so the volume binding stays reactive
    property real volume: stream.volume

    implicitWidth: 296
    implicitHeight: 452

    // ---- equalizer --------------------------------------------------------
    // Decorative, but a smoothed random walk reads as music rather than noise.
    property var eqBars: [0.20, 0.36, 0.24, 0.42, 0.30, 0.46, 0.26, 0.32]
    property var eqTargets: [0.20, 0.36, 0.24, 0.42, 0.30, 0.46, 0.26, 0.32]

    onEqBarsChanged: eqCanvas.requestPaint()

    function stepEqualizer() {
        var out = [];
        for (var i = 0; i < eqTargets.length; i++) {
            if (Math.random() < 0.32)
                eqTargets[i] = 0.12 + Math.random() * 0.88;
            var v = eqBars[i] + (eqTargets[i] - eqBars[i]) * 0.32;
            out.push(Math.max(0.06, Math.min(1.0, v)));
        }
        eqBars = out;
    }

    Timer {
        interval: 130
        repeat: true
        running: card.playing && !card.compact
        onTriggered: card.stepEqualizer()
    }

    // ---- card background --------------------------------------------------
    Rectangle {
        id: backdrop
        anchors.fill: parent
        visible: card.drawBackground
        radius: 26
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#31234a"
            }
            GradientStop {
                position: 0.55
                color: "#1e1730"
            }
            GradientStop {
                position: 1.0
                color: "#140f20"
            }
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.09)

        // warm glow that breathes with the music
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.82
            height: width
            radius: width / 2
            y: parent.height * 0.10
            color: "#ff8fd0"
            opacity: card.playing ? 0.16 : 0.07
            Behavior on opacity {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // soft highlight along the top edge
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 46
            radius: parent.radius
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(1, 1, 1, 0.06)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }
    }

    // ---- layout -----------------------------------------------------------
    Column {
        id: layout
        anchors.fill: parent
        anchors.margins: card.compact ? 0 : 18
        spacing: card.compact ? 0 : 12

        // ---------------------------------------------------------------- header
        Item {
            width: parent.width
            height: 18
            visible: !card.compact

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: card.playing ? "#7ef0c0" : "#6b6480"
                    SequentialAnimation on opacity {
                        running: card.playing
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.25
                            duration: 800
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            to: 1.0
                            duration: 800
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.buffering ? qsTr("BUFFERING…") : qsTr("LIVE · LOFI RADIO")
                    color: "#cdbce9"
                    font.pixelSize: 10
                    font.letterSpacing: 1.6
                    font.bold: true
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "128 kbps · mp3"
                color: "#6f6689"
                font.pixelSize: 10
            }
        }

        // ----------------------------------------------------------------- vinyl
        Item {
            id: vinylArea
            width: parent.width
            height: card.compact ? parent.height : 176

            // NB: referenced through the id on purpose — a bare `parent` inside
            // a binding on this item resolves to the enclosing layout, not to
            // the item itself.
            readonly property real discSize: card.compact
                                             ? Math.min(vinylArea.width, vinylArea.height) - 2
                                             : Math.min(vinylArea.width, vinylArea.height) - 10

            // platter shadow
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: vinylArea.discSize + 14
                height: width
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.45)
                visible: !card.compact
            }

            Item {
                id: vinyl
                width: vinylArea.discSize
                height: width
                anchors.centerIn: parent

                // ---- spinning record ----
                Item {
                    id: disc
                    anchors.fill: parent
                    rotation: 0

                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 5000
                        loops: Animation.Infinite
                        running: card.playing
                    }

                    Canvas {
                        id: discCanvas
                        anchors.fill: parent
                        antialiasing: true
                        // the record only needs painting when its size changes
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            var c = width / 2;
                            var rMax = c - 1;
                            ctx.reset();

                            // record body
                            var body = ctx.createRadialGradient(c, c * 0.72, rMax * 0.1, c, c, rMax);
                            body.addColorStop(0.0, "#241e31");
                            body.addColorStop(0.45, "#12101a");
                            body.addColorStop(1.0, "#07060b");
                            ctx.beginPath();
                            ctx.arc(c, c, rMax, 0, 2 * Math.PI);
                            ctx.fillStyle = body;
                            ctx.fill();

                            // grooves: uneven spacing keeps it from looking printed
                            if (!card.compact) {
                                var r = rMax * 0.40;
                                var k = 0;
                                while (r < rMax * 0.985) {
                                    var alpha = 0.05 + 0.03 * Math.sin(k * 1.7);
                                    ctx.beginPath();
                                    ctx.arc(c, c, r, 0, 2 * Math.PI);
                                    ctx.strokeStyle = "rgba(255,255,255," + alpha.toFixed(3) + ")";
                                    ctx.lineWidth = (k % 4 === 0) ? 1.2 : 0.8;
                                    ctx.stroke();
                                    r += (k % 5 === 0) ? 4.5 : 3.0;
                                    k++;
                                }

                                // the wide band between grooves and label
                                ctx.beginPath();
                                ctx.arc(c, c, rMax * 0.375, 0, 2 * Math.PI);
                                ctx.strokeStyle = "rgba(255,255,255,0.10)";
                                ctx.lineWidth = 1.4;
                                ctx.stroke();
                            }

                            // sheen sweeping across the record
                            var sheen = ctx.createLinearGradient(0, 0, width, height);
                            sheen.addColorStop(0.0, "rgba(255,255,255,0.0)");
                            sheen.addColorStop(0.42, "rgba(255,255,255,0.10)");
                            sheen.addColorStop(0.50, "rgba(255,255,255,0.02)");
                            sheen.addColorStop(0.62, "rgba(255,255,255,0.09)");
                            sheen.addColorStop(1.0, "rgba(255,255,255,0.0)");
                            ctx.beginPath();
                            ctx.arc(c, c, rMax, 0, 2 * Math.PI);
                            ctx.fillStyle = sheen;
                            ctx.fill();

                            // rim light
                            ctx.beginPath();
                            ctx.arc(c, c, rMax - 0.5, 0, 2 * Math.PI);
                            ctx.strokeStyle = "rgba(255,255,255,0.14)";
                            ctx.lineWidth = 1;
                            ctx.stroke();
                        }
                    }

                    // ---- centre label ----
                    Rectangle {
                        id: label
                        anchors.centerIn: parent
                        width: parent.width * (card.compact ? 0.52 : 0.40)
                        height: width
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: "#ffb3d6"
                            }
                            GradientStop {
                                position: 0.6
                                color: "#e58ec9"
                            }
                            GradientStop {
                                position: 1.0
                                color: "#8f6bd6"
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 0
                            visible: !card.compact

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "lofi"
                                color: "#2b1f42"
                                font.pixelSize: Math.round(label.width * 0.24)
                                font.bold: true
                                font.italic: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "radio"
                                color: Qt.rgba(0.17, 0.12, 0.26, 0.72)
                                font.pixelSize: Math.round(label.width * 0.12)
                                font.letterSpacing: 1.2
                            }
                        }
                    }

                    // spindle hole
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.max(6, parent.width * 0.035)
                        height: width
                        radius: width / 2
                        color: "#160f22"
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.6)
                    }
                }

                // ---- tonearm ----
                Item {
                    id: arm
                    anchors.fill: parent
                    visible: !card.compact
                    // pivot at the top-right, the arm reaches towards the label
                    transformOrigin: Item.TopRight
                    rotation: card.playing ? 0 : -13
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 650
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        x: parent.width - 17
                        y: -6
                        width: 17
                        height: 17
                        radius: 8.5
                        color: "#cdbfe8"
                        border.width: 2
                        border.color: Qt.rgba(0, 0, 0, 0.25)
                    }

                    Rectangle {
                        x: parent.width - 13
                        y: 2
                        width: 4
                        height: parent.height * 0.60
                        radius: 2
                        color: "#ded3f2"
                        transformOrigin: Item.Top
                        rotation: 26
                    }

                    Rectangle {
                        x: parent.width - parent.width * 0.335
                        y: parent.height * 0.545
                        width: 15
                        height: 9
                        radius: 3
                        color: "#b9a6e0"
                        rotation: 26
                    }
                }
            }
        }

        // ------------------------------------------------------------- equalizer
        Item {
            id: eq
            width: parent.width
            height: 30
            visible: !card.compact

            Canvas {
                id: eqCanvas
                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var bars = card.eqBars;
                    var n = bars.length;
                    var gap = 4;
                    var bw = (width - gap * (n - 1)) / n;
                    var radius = Math.min(bw / 2, 3);
                    for (var i = 0; i < n; i++) {
                        var h = Math.max(3, bars[i] * height);
                        var x = i * (bw + gap);
                        var y = height - h;
                        var g = ctx.createLinearGradient(0, height, 0, 0);
                        g.addColorStop(0.0, "#63e6c0");
                        g.addColorStop(0.55, "#9fe8d8");
                        g.addColorStop(1.0, "#ff9ecb");
                        ctx.beginPath();
                        ctx.moveTo(x + radius, y);
                        ctx.lineTo(x + bw - radius, y);
                        ctx.quadraticCurveTo(x + bw, y, x + bw, y + radius);
                        ctx.lineTo(x + bw, height);
                        ctx.lineTo(x, height);
                        ctx.lineTo(x, y + radius);
                        ctx.quadraticCurveTo(x, y, x + radius, y);
                        ctx.closePath();
                        ctx.fillStyle = card.playing ? g : "rgba(150,140,175,0.35)";
                        ctx.fill();
                    }
                }
            }
        }

        // ------------------------------------------------------------------ info
        Item {
            width: parent.width
            height: 40
            visible: !card.compact

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Item {
                    width: parent.width
                    height: titleText.implicitHeight
                    clip: true

                    Text {
                        id: titleText
                        text: card.trackTitle.length > 0 ? card.trackTitle : qsTr("Подключение к радио…")
                        color: "#f4eeff"
                        font.pixelSize: 15
                        font.bold: true
                        elide: Text.ElideNone

                        readonly property bool overflow: implicitWidth > parent.width + 2

                        NumberAnimation on x {
                            running: titleText.overflow
                            loops: Animation.Infinite
                            from: 0
                            to: -(titleText.implicitWidth - titleText.parent.width + 16)
                            duration: Math.max(4500, titleText.implicitWidth * 24)
                            easing.type: Easing.InOutSine
                            onRunningChanged: if (!running)
                                titleText.x = 0
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: card.trackArtist.length > 0 ? card.trackArtist : "lofiradio.ru"
                    color: "#a99cc6"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        // -------------------------------------------------------------- controls
        Item {
            width: parent.width
            height: 44
            visible: !card.compact

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                height: parent.height

                Item {
                    width: 30
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: "media-skip-backward"
                        color: hoverPrev.containsMouse ? "#ffffff" : "#cbb8e8"
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    MouseArea {
                        id: hoverPrev
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.stream.previousStation()                    }
                }

                Rectangle {
                    id: playButton
                    width: 44
                    height: 44
                    radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: playArea.containsMouse ? "#ffb0d9" : "#ff9ecb"
                        }
                        GradientStop {
                            position: 1.0
                            color: playArea.containsMouse ? "#9d78e4" : "#8f6bd6"
                        }
                    }
                    scale: playArea.pressed ? 0.94 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: card.playing ? "media-playback-pause" : "media-playback-start"
                        color: "#1b1329"
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.previewActive)
                                card.previewPlaying = !card.previewPlaying;
                            else
                                card.stream.toggle();
                        }
                    }
                }

                Item {
                    width: 30
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: "media-skip-forward"
                        color: hoverNext.containsMouse ? "#ffffff" : "#cbb8e8"
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    MouseArea {
                        id: hoverNext
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.stream.nextStation()
                    }
                }
            }
        }

        // --------------------------------------------------------------- volume
        Row {
            width: parent.width
            spacing: 8
            visible: !card.compact

            Kirigami.Icon {
                width: 15
                height: 15
                anchors.verticalCenter: parent.verticalCenter
                source: card.volume <= 0.01
                        ? "audio-volume-muted"
                        : (card.volume < 0.5 ? "audio-volume-medium" : "audio-volume-high")
                color: "#8d82a8"
            }

            Item {
                id: volumeTrack
                width: parent.width - 23
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.10)

                    Rectangle {
                        height: parent.height
                        radius: 2
                        width: parent.width * card.volume
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: "#7ef0c0"
                            }
                            GradientStop {
                                position: 1.0
                                color: "#ff9ecb"
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11
                            height: 11
                            radius: 5.5
                            color: "#fdf6ff"
                            visible: volumeArea.containsMouse || volumeArea.pressed
                        }
                    }
                }

                MouseArea {
                    id: volumeArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function setFromX(mx) {
                        card.stream.setVolume((mx - 4) / volumeTrack.width);
                    }

                    onPressed: (mouse) => setFromX(mouse.x)
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            setFromX(mouse.x);
                    }
                }
            }
        }

        // keeps the card balanced when it is stretched taller than its content
        Item {
            width: 1
            height: 12
            visible: !card.compact
        }
    }
}
