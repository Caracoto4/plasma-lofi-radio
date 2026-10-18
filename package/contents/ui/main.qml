import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

import "components" as Components

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    readonly property Components.StreamPlayer engine: Components.StreamPlayer

    readonly property bool inPanel: plasmoid.location === PlasmaCore.Types.TopEdge
                                    || plasmoid.location === PlasmaCore.Types.LeftEdge
                                    || plasmoid.location === PlasmaCore.Types.RightEdge
                                    || plasmoid.location === PlasmaCore.Types.BottomEdge

    fullRepresentation: Item {
        implicitWidth: 296
        implicitHeight: 452
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth: 240
        Layout.minimumHeight: 380

        Components.PlayerCard {
            anchors.fill: parent
            engine: root.engine
            drawBackground: !root.inPanel
        }
    }

    compactRepresentation: Item {
        implicitWidth: 34
        implicitHeight: 34

        Components.PlayerCard {
            anchors.fill: parent
            compact: true
            drawBackground: false
            previewActive: true
            previewPlaying: root.engine.playing
            previewTitle: root.engine.title
            previewArtist: root.engine.artist
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.expanded = !root.expanded
        }
    }
}
