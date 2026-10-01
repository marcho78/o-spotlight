import QtQuick

// A filter chip under the search field: a kind of result ("Images"), an app
// category ("Utilities"). Chips share the row equally when they fit.
Rectangle {
  id: chip

  property var ui: null
  property string text: ""
  property bool active: false

  signal clicked()

  implicitWidth: label.implicitWidth + 28
  height: 24
  radius: 8
  color: active ? Qt.rgba(ui.highlight.r, ui.highlight.g, ui.highlight.b, ui.dark ? 0.35 : 0.22)
    : mouse.containsMouse ? ui.chipHover : ui.chipFill
  Behavior on color { ColorAnimation { duration: 110 } }

  Text {
    id: label
    anchors.centerIn: parent
    width: Math.min(implicitWidth, chip.width - 16)
    text: chip.text
    textFormat: Text.PlainText
    color: chip.active ? ui.textPrimary : ui.textSecondary
    font.family: ui.uiFont
    font.pixelSize: 15
    elide: Text.ElideRight
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: chip.clicked()
  }
}
