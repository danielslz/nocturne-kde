import QtQuick 2.15

Rectangle {
    id: root
    color: "#1a1b26"
    anchors.fill: parent

    property int stage

    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true;
        }
    }

    Item {
        anchors.centerIn: parent
        width: 160
        height: 160

        Rectangle {
            id: dot
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 9
            color: "#7aa2f7"
            opacity: 0.0
            scale: 0.6
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dot.bottom
            anchors.topMargin: 28
            text: "Nocturne"
            color: "#c0caf5"
            font.pixelSize: 22
            font.letterSpacing: 2
            opacity: dot.opacity
        }
    }

    SequentialAnimation {
        id: introAnimation
        running: false

        ParallelAnimation {
            NumberAnimation { target: dot; property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { target: dot; property: "scale"; from: 0.6; to: 1.0; duration: 400; easing.type: Easing.OutBack }
        }
        NumberAnimation { target: dot; property: "opacity"; from: 1; to: 0.5; duration: 900; easing.type: Easing.InOutQuad }
        loops: Animation.Infinite
    }
}
