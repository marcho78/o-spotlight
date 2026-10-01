import QtQuick

// A header (or a plain separator) between sections of a style's grid, where
// Spotlight.qml put it (ui.gridDecor): Files' Suggestions and Recents,
// Applications' most used line.
Item {
  id: header

  required property var modelData
  property var ui: null

  property string fontFamily: "sans-serif"
  property int size: 12
  property int weight: Font.DemiBold
  property bool upper: false
  property real tracking: 0
  property color color: "gray"
  property color rule: "#22ffffff"
  property real inset: 12

  readonly property bool separator: modelData.kind === "separator"

  y: modelData.y
  width: parent ? parent.width : 0
  height: separator ? ui.gridMetrics.separatorHeight : ui.gridMetrics.headerHeight

  Text {
    x: header.inset
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    visible: !header.separator
    text: header.upper ? String(header.modelData.title).toUpperCase() : String(header.modelData.title)
    textFormat: Text.PlainText
    color: header.color
    font.family: header.fontFamily
    font.pixelSize: header.size
    font.weight: header.weight
    font.letterSpacing: header.tracking
  }
  Rectangle {
    x: header.inset
    width: parent.width - 2 * header.inset
    height: 1
    anchors.bottom: header.separator ? undefined : parent.bottom
    anchors.verticalCenter: header.separator ? parent.verticalCenter : undefined
    color: header.rule
  }
}
