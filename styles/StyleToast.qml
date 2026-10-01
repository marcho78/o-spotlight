import QtQuick

// "Copied", after Ctrl+C or a copy button, in a style's colors.
Rectangle {
  id: toast

  property string fontFamily: "sans-serif"
  property color textColor: "white"

  function flash() { flashAnim.restart() }

  width: label.implicitWidth + 28
  height: 30
  radius: 15
  color: "#cc000000"
  opacity: 0
  z: 60

  Text {
    id: label
    anchors.centerIn: parent
    text: "Copied"
    textFormat: Text.PlainText
    color: toast.textColor
    font.family: toast.fontFamily
    font.pixelSize: 14
    font.weight: Font.Medium
  }

  SequentialAnimation {
    id: flashAnim
    NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 90 }
    PauseAnimation { duration: 750 }
    NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 220 }
  }
}
