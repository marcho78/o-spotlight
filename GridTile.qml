import QtQuick

// One app or file in a grid, as in Tahoe's Applications and Files views: a
// 64 icon (or a picture of the file) over its name.
Item {
  id: tile

  required property int index
  required property string title
  required property string iconType
  required property string iconSource
  required property string glyph
  required property string glyphFont
  required property string badge
  required property string symbol
  required property string thumbs

  property var ui: null
  property int lines: 1
  readonly property bool selected: !!ui && ui.selectedIndex === tile.index

  Rectangle {
    anchors.fill: parent
    anchors.margins: 3
    radius: 16
    color: ui.selectionColor
    visible: tile.selected
  }

  ResultIcon {
    id: icon
    anchors.horizontalCenter: parent.horizontalCenter
    y: 10
    width: 64
    height: 64
    iconType: tile.iconType
    iconSource: tile.iconSource
    glyph: tile.glyph
    glyphFont: tile.glyphFont
    badge: tile.badge
    symbol: tile.symbol
    thumbs: tile.thumbs
    fallbackFont: ui.glyphFont
  }

  Text {
    anchors.top: icon.bottom
    anchors.topMargin: 7
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width - 12
    horizontalAlignment: Text.AlignHCenter
    text: tile.title
    textFormat: Text.PlainText
    color: ui.rowText(tile.selected)
    font.family: ui.uiFont
    font.pixelSize: 13
    wrapMode: tile.lines > 1 ? Text.Wrap : Text.NoWrap
    maximumLineCount: tile.lines
    elide: Text.ElideRight
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPositionChanged: function(mouse) {
      var at = mapToItem(null, mouse.x, mouse.y)
      if (ui) ui.pointerMoved(tile.index, at.x, at.y)
    }
    onClicked: function(mouse) {
      if (!ui) return
      ui.selectedIndex = tile.index
      ui.activateSelected(mouse.modifiers & Qt.ControlModifier ? "reveal" : "open")
    }
  }
}
