import QtQuick
import ".."

// What the search is narrowed to, before the text: a kind you picked
// ("Images") or a view you're in ("Applications"), with a click taking it
// off, like Tahoe's token.
Rectangle {
  id: token

  property var ui: null
  // "scope": the kind picked; "mode": the view (for styles that show no
  // views of their own while you're in one).
  property string what: "scope"
  property string fontFamily: "sans-serif"
  property int size: 14
  property color textColor: "white"
  property color hoverFill: fill
  property color fill: "#33ffffff"
  property bool showIcon: what === "mode"

  readonly property var modeInfo: ui ? ui.modeInfo(ui.mode) : null
  readonly property string label: !ui ? ""
    : what === "scope" ? (ui.scope !== "" && ui.engine ? ui.engine.scopeTitle : "")
    : (modeInfo ? modeInfo.label : "")

  visible: label !== ""
  width: visible ? row.implicitWidth + 16 : 0
  height: Math.round(size * 1.75)
  radius: Math.min(8, height / 2)
  color: mouse.containsMouse ? hoverFill : fill

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5
    Icon {
      anchors.verticalCenter: parent.verticalCenter
      visible: token.showIcon && !!token.modeInfo
      width: token.size
      height: token.size
      name: token.modeInfo ? token.modeInfo.icon : ""
      color: token.textColor
      weight: 1.9
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: token.label
      textFormat: Text.PlainText
      color: token.textColor
      font.family: token.fontFamily
      font.pixelSize: token.size
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (token.what === "scope") token.ui.engine.setScope("")
      else token.ui.engine.setMode("all")
      token.ui.field.forceActiveFocus()
    }
  }
}
