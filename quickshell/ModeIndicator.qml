import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    readonly property real labelMaxWidth: 96
    readonly property real hPad: 8

    readonly property string modeFull: modeFile.text().trim().toUpperCase()
    readonly property string modeDisplay: {
        const u = root.modeFull;
        if (u === "LEGAL AND CONFIDENTIAL")
            return "Legal";
        if (u === "NON WORK")
            return "Off-work";
        return u;
    }

    readonly property bool modeTruncated: modeLabel.truncated || root.modeDisplay !== root.modeFull

    implicitHeight: 20
    implicitWidth: Math.min(modeLabel.implicitWidth + root.hPad * 2, root.labelMaxWidth + root.hPad * 2)
    width: implicitWidth

    FileView {
        id: modeFile
        path: FileUtils.trimFileProtocol(`${Directories.home}/.config/neko-flow/current_mode`)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: modeFile.reload()
    }

    MouseArea {
        id: modeHit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        StyledToolTip {
            visible: modeHit.containsMouse && root.modeFull.length > 0
            text: root.modeFull
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "#2a2a3a"

        Text {
            id: modeLabel
            anchors.centerIn: parent
            width: parent.width - root.hPad * 2
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.modeDisplay
            color: "#a6e3a1"
            font.bold: true
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
