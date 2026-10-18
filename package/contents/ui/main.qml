import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property var tracks: [
        Qt.resolvedUrl("../audio/midnight_study.ogg"),
        Qt.resolvedUrl("../audio/rainy_window.ogg"),
        Qt.resolvedUrl("../audio/coffee_break.ogg")
    ]
    readonly property var titles: [
        "Midnight Study",
        "Rainy Window",
        "Coffee Break"
    ]

    property int currentIndex: 0
    property bool playing: player.playbackState === MediaPlayer.PlayingState

    preferredRepresentation: fullRepresentation

    function next() {
        currentIndex = (currentIndex + 1) % tracks.length
    }
    function prev() {
        currentIndex = (currentIndex - 1 + tracks.length) % tracks.length
    }
    function toggle() {
        if (player.playbackState === MediaPlayer.PlayingState)
            player.pause()
        else
            player.play()
    }

    MediaPlayer {
        id: player
        source: root.tracks[root.currentIndex]
        audioOutput: AudioOutput {
            id: audio
            volume: 0.7
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                root.next()
        }
    }

    fullRepresentation: Item {
        id: card
        implicitWidth: 250
        implicitHeight: 330
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        // ---- background card ----
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: 24
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2a1f3d" }
                GradientStop { position: 1.0; color: "#161020" }
            }
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            // soft glow behind the vinyl
            Rectangle {
                width: vinyl.width * 1.5
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: vinyl.y + vinyl.height / 2 - height / 2
                color: "#ff8fd0"
                opacity: root.playing ? 0.16 : 0.07
                Behavior on opacity { NumberAnimation { duration: 600 } }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.playing ? "#7ef0c0" : "#6b6480"
                    SequentialAnimation on opacity {
                        running: root.playing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 700 }
                        NumberAnimation { to: 1.0; duration: 700 }
                    }
                }
                Text {
                    text: "LOFI RADIO"
                    color: "#cbb8e8"
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: (root.currentIndex + 1) + "/" + root.tracks.length
                    color: "#7d7396"
                    font.pixelSize: 11
                }
            }

            // ---- vinyl ----
            Item {
                id: vinyl
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 168
                Layout.preferredHeight: 168

                // spinning disc
                Item {
                    id: disc
                    anchors.fill: parent
                    rotation: 0
                    NumberAnimation on rotation {
                        from: 0; to: 360
                        duration: 5000
                        loops: Animation.Infinite
                        running: root.playing
                    }

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d");
                            var c = width / 2;
                            ctx.reset();
                            // disc body
                            ctx.beginPath();
                            ctx.arc(c, c, c - 1, 0, 2 * Math.PI);
                            ctx.fillStyle = "#0c0a12";
                            ctx.fill();
                            // grooves
                            for (var r = c * 0.40; r < c * 0.97; r += 3) {
                                ctx.beginPath();
                                ctx.arc(c, c, r, 0, 2 * Math.PI);
                                ctx.strokeStyle = "rgba(255,255,255,0.045)";
                                ctx.lineWidth = 1;
                                ctx.stroke();
                            }
                            // light sheen
                            var g = ctx.createLinearGradient(0, 0, width, height);
                            g.addColorStop(0.0, "rgba(255,255,255,0.10)");
                            g.addColorStop(0.5, "rgba(255,255,255,0.0)");
                            g.addColorStop(1.0, "rgba(255,255,255,0.06)");
                            ctx.beginPath();
                            ctx.arc(c, c, c - 1, 0, 2 * Math.PI);
                            ctx.fillStyle = g;
                            ctx.fill();
                        }
                    }

                    // center label
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.42
                        height: width
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ff9ecb" }
                            GradientStop { position: 1.0; color: "#8f6bd6" }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "lofi"
                            color: "#2a1f3d"
                            font.pixelSize: 15
                            font.bold: true
                            font.italic: true
                        }
                    }
                    // spindle hole
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8; height: 8; radius: 4
                        color: "#161020"
                    }
                }

                // tonearm
                Item {
                    id: arm
                    anchors.fill: parent
                    rotation: root.playing ? 0 : -14
                    transformOrigin: Item.TopRight
                    Behavior on rotation { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    Rectangle {
                        x: parent.width - 14
                        y: 6
                        width: 5
                        height: parent.height * 0.62
                        radius: 3
                        color: "#d9cff0"
                        transformOrigin: Item.Top
                        rotation: 24
                    }
                    Rectangle {
                        x: parent.width - 20
                        y: 2
                        width: 16; height: 16; radius: 8
                        color: "#b9a6e0"
                    }
                }
            }

            // ---- equalizer ----
            Row {
                id: eq
                Layout.alignment: Qt.AlignHCenter
                spacing: 5
                property var levels: [0.3, 0.6, 0.4, 0.8, 0.5, 0.7, 0.35]

                Repeater {
                    model: 7
                    delegate: Item {
                        width: 8
                        height: 34
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            radius: 3
                            color: Qt.rgba(0.6, 0.9, 0.8, 0.9)
                            height: root.playing
                                ? Math.max(4, eq.levels[index] * parent.height)
                                : 4
                            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }

            // ---- title ----
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.titles[root.currentIndex]
                color: "#f2ecff"
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
            }

            // ---- progress ----
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.10)
                Rectangle {
                    height: parent.height
                    radius: 2
                    color: "#ff9ecb"
                    width: player.duration > 0
                        ? parent.width * (player.position / player.duration)
                        : 0
                }
            }

            // ---- controls ----
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18

                Kirigami.Icon {
                    source: "media-skip-backward"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    color: "#cbb8e8"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: root.prev()
                    }
                }

                Rectangle {
                    width: 52; height: 52; radius: 26
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ff9ecb" }
                        GradientStop { position: 1.0; color: "#8f6bd6" }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: root.playing ? "media-playback-pause" : "media-playback-start"
                        width: 24; height: 24
                        color: "#1a1226"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggle()
                    }
                }

                Kirigami.Icon {
                    source: "media-skip-forward"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    color: "#cbb8e8"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: root.next()
                    }
                }
            }
        }

        // equalizer level driver
        Timer {
            interval: 150
            repeat: true
            running: root.playing
            onTriggered: {
                var l = [];
                for (var i = 0; i < 7; i++)
                    l.push(0.15 + Math.random() * 0.85);
                eq.levels = l;
            }
        }
    }
}
