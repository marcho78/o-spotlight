import QtQuick
import QtQuick.Effects
import ".."

// One app, file or result in a style's grid, where Spotlight.qml laid it
// out (ui.tilePositions): the icon over its name ("center", like Tahoe's
// Applications), or at the top left of a card with a line under the name
// ("card"). Hovering and clicking work as in Tahoe.
Item {
  id: tile

  required property int index
  required property string kind
  required property string title
  required property string subtitle
  required property string iconType
  required property string iconSource
  required property string glyph
  required property string glyphFont
  required property string badge
  required property string symbol
  required property string thumbs

  property var ui: null
  readonly property bool selected: !!ui && ui.selectedIndex === tile.index
  readonly property var place: ui && ui.tilePositions[index] ? ui.tilePositions[index] : null

  // ---- the style's look ----
  property string layout: "center"
  property string fontFamily: "sans-serif"
  property real radius: 12
  property real padding: 12
  property real iconSize: 48
  property bool roundIcons: false
  property int titleSize: 13
  property int titleWeight: Font.Normal
  property int selectedTitleWeight: titleWeight
  property int subtitleSize: 11
  property int lines: 1
  property color titleColor: "white"
  property color selectedTitleColor: titleColor
  property color subtitleColor: "gray"
  property color fill: "transparent"
  property color selectedFill: "#33ffffff"
  property color border: "transparent"
  property color selectedBorder: "transparent"
  property real borderWidth: 0
  property color glowColor: "transparent"
  property real selectedScale: 1

  // In a ListView (the Command strip's cards) rather than the grid: the
  // view places it, at this size.
  property bool listed: false
  property real listedWidth: 150
  property real listedHeight: 128

  x: listed ? 0 : place ? place.x : 0
  y: listed ? 0 : place ? place.y : 0
  width: listed ? listedWidth : ui ? ui.gridMetrics.tileWidth : 100
  height: listed ? listedHeight : ui ? ui.gridMetrics.tileHeight : 100
  visible: listed || (!!place && !place.hero)
  z: selected ? 2 : 1

  Item {
    anchors.fill: parent
    scale: tile.selected ? tile.selectedScale : 1
    Behavior on scale {
      enabled: !tile.ui || !tile.ui.reduceMotion
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    RectangularShadow {
      anchors.fill: parent
      radius: tile.radius
      blur: 18
      color: tile.glowColor
      visible: tile.selected && tile.glowColor.a > 0
    }
    Rectangle {
      anchors.fill: parent
      radius: tile.radius
      color: tile.selected ? tile.selectedFill : tile.fill
      border.width: tile.borderWidth
      border.color: tile.selected ? tile.selectedBorder : tile.border
    }
  }

  ResultIcon {
    id: icon
    x: tile.layout === "card" ? tile.padding : (tile.width - width) / 2
    y: tile.layout === "card" ? tile.padding : Math.max(6, (tile.height - height - label.height - 7) / 2)
    width: tile.iconSize
    height: tile.iconSize
    round: tile.roundIcons
    iconType: tile.iconType
    iconSource: tile.iconSource
    glyph: tile.glyph
    glyphFont: tile.glyphFont
    badge: tile.badge
    symbol: tile.symbol
    thumbs: tile.thumbs
    fallbackFont: tile.ui ? tile.ui.glyphFont : ""
  }

  Column {
    id: label
    x: tile.layout === "card" ? tile.padding : 6
    y: tile.layout === "card" ? tile.height - height - tile.padding : icon.y + icon.height + 7
    width: tile.width - 2 * x
    spacing: 1

    Text {
      width: parent.width
      horizontalAlignment: tile.layout === "card" ? Text.AlignLeft : Text.AlignHCenter
      text: tile.title
      textFormat: Text.PlainText
      color: tile.selected ? tile.selectedTitleColor : tile.titleColor
      font.family: tile.fontFamily
      font.pixelSize: tile.kind === "answer" ? tile.titleSize + 4 : tile.titleSize
      font.weight: tile.selected ? tile.selectedTitleWeight : tile.titleWeight
      wrapMode: tile.lines > 1 ? Text.Wrap : Text.NoWrap
      maximumLineCount: tile.lines
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      visible: tile.layout === "card" && text !== ""
      text: tile.subtitle
      textFormat: Text.PlainText
      color: tile.subtitleColor
      font.family: tile.fontFamily
      font.pixelSize: tile.subtitleSize
      elide: Text.ElideRight
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPositionChanged: function(mouse) {
      var at = mapToItem(null, mouse.x, mouse.y)
      if (tile.ui) tile.ui.pointerMoved(tile.index, at.x, at.y)
    }
    onClicked: function(mouse) {
      if (!tile.ui) return
      tile.ui.selectedIndex = tile.index
      tile.ui.activateSelected(mouse.modifiers & Qt.ControlModifier ? "reveal" : "open")
    }
  }
}
