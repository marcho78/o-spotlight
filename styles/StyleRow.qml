import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import ".."
import "../Palette.js" as Palette

// One result in a style's list: its icon, its name and a line about it, and
// the selection drawn the style's way (a fill, a bar of light at the left, a
// glow, a lift). Everything Tahoe's row has is here too: a checkmark, a
// detail at the right, the copy button, where a file is while Ctrl is held,
// an answer shown large. Hovering and clicking work as in Tahoe.
Item {
  id: row

  // From the model (see Engine.displayRow).
  required property int index
  required property string kind
  required property string title
  required property string subtitle
  required property string folder
  required property string path
  required property string detail
  required property string iconType
  required property string iconSource
  required property string glyph
  required property string glyphFont
  required property string badge
  required property string symbol
  required property string thumbs
  required property bool checked
  required property bool copyable
  required property string action

  property var ui: null
  readonly property bool selected: !!ui && ui.selectedIndex === row.index
  readonly property bool answer: row.kind === "answer"
  readonly property bool showPath: !!ui && ui.showPaths && row.path !== ""
  readonly property string secondLine: row.showPath ? row.path
    : row.subtitle + (row.subtitle !== "" && row.folder !== "" ? " · " : "") + row.folder

  // ---- the style's look ----
  property string fontFamily: "sans-serif"
  property real rowHeight: 48
  property real selectedRowHeight: rowHeight
  property real answerHeight: rowHeight + 24
  property real sideInset: 0
  property real radius: 12
  property real padding: 12
  property real gap: 14
  property real iconSize: 30
  property real selectedIconSize: iconSize
  property bool roundIcons: false
  property bool showIcon: true
  property int titleSize: 14
  property int selectedTitleSize: titleSize
  property int titleWeight: Font.Normal
  property int selectedTitleWeight: Font.Medium
  property int subtitleSize: 12
  // "below" the name, "inline" after it, "trailing" at the right of the
  // selected row (below otherwise), or "none".
  property string subtitleMode: "below"
  property color titleColor: "white"
  property color selectedTitleColor: titleColor
  property color subtitleColor: "gray"
  property color selectedSubtitleColor: subtitleColor
  property color fill: "transparent"
  property color selectedFill: "#33ffffff"
  property color barColor: "transparent"
  property real barWidth: 0
  property color glowColor: "transparent"
  property real glowSize: 0
  property color highlightColor: "transparent"
  property real selectedScale: 1
  property color shadowColor: "transparent"
  // At the right of the selected row: "Open ↵", "↵"…
  property string hint: ""
  property string hintStyle: "text"           // "text", "circle", "pill"
  property string hintFont: fontFamily
  property int hintSize: 12
  property color hintColor: subtitleColor
  property color hintFill: "transparent"
  property real rowOpacity: 1
  // Drawn elsewhere (Bento shows the Top Hit as its own card).
  property bool hidden: false
  property color controlFill: Palette.a(titleColor, 0.1)
  property color controlHover: Palette.a(titleColor, 0.18)

  readonly property color currentTitle: selected ? selectedTitleColor : titleColor
  readonly property color currentSubtitle: selected ? selectedSubtitleColor : subtitleColor
  readonly property real currentIcon: answer ? Math.max(iconSize, 36) : selected ? selectedIconSize : iconSize
  readonly property bool trailingSubtitle: subtitleMode === "trailing" && selected && !answer

  width: ListView.view ? ListView.view.width : 0
  height: hidden ? 0 : answer ? answerHeight : selected ? selectedRowHeight : rowHeight
  visible: !hidden
  opacity: rowOpacity
  z: selected ? 2 : 1

  Item {
    id: plate
    x: row.sideInset
    width: row.width - 2 * row.sideInset
    height: row.height
    scale: row.selected ? row.selectedScale : 1
    Behavior on scale {
      enabled: !row.ui || !row.ui.reduceMotion
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    RectangularShadow {
      anchors.fill: parent
      radius: row.radius
      blur: row.glowSize
      spread: 0
      color: row.glowColor
      visible: row.selected && row.glowSize > 0
    }
    RectangularShadow {
      anchors.fill: parent
      radius: row.radius
      offset: Qt.vector2d(0, 10)
      blur: 24
      spread: -2
      color: row.shadowColor
      visible: row.selected && row.shadowColor.a > 0
    }
    ClippingRectangle {
      anchors.fill: parent
      radius: row.radius
      color: row.selected ? row.selectedFill : row.fill
      // A bar of light down the left edge.
      Rectangle {
        width: row.barWidth
        height: parent.height
        color: row.barColor
        visible: row.selected && row.barWidth > 0
      }
      // A line of light along the top edge.
      Rectangle {
        x: row.radius / 2
        width: parent.width - row.radius
        height: 1
        color: row.highlightColor
        visible: row.selected && row.highlightColor.a > 0
      }
    }
  }

  ResultIcon {
    id: iconBox
    visible: row.showIcon
    x: row.sideInset + row.padding + (row.answer ? 0 : (Math.max(row.iconSize, row.selectedIconSize) - width) / 2)
    anchors.verticalCenter: parent.verticalCenter
    width: row.currentIcon
    height: width
    round: row.roundIcons
    iconType: row.iconType
    iconSource: row.iconSource
    glyph: row.glyph
    glyphFont: row.glyphFont
    badge: row.badge
    symbol: row.symbol
    thumbs: row.thumbs
    fallbackFont: row.ui ? row.ui.glyphFont : ""
  }

  Item {
    id: texts
    x: row.showIcon ? row.sideInset + row.padding + Math.max(row.iconSize, row.selectedIconSize, row.answer ? 36 : 0) + row.gap : row.sideInset + row.padding
    width: trailing.x - x - 10
    height: parent.height

    // Name, and the line under it.
    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      visible: row.subtitleMode !== "inline" || row.answer
      spacing: 1

      Text {
        width: parent.width
        text: row.title
        textFormat: Text.PlainText
        color: row.currentTitle
        font.family: row.fontFamily
        font.pixelSize: row.answer ? Math.round(row.titleSize * 1.6) : row.selected ? row.selectedTitleSize : row.titleSize
        font.weight: row.answer ? Font.DemiBold : row.selected ? row.selectedTitleWeight : row.titleWeight
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        visible: text !== "" && row.subtitleMode !== "none" && !row.trailingSubtitle
        text: row.secondLine
        textFormat: Text.PlainText
        color: row.currentSubtitle
        font.family: row.fontFamily
        font.pixelSize: row.subtitleSize
        elide: Text.ElideRight
      }
    }

    // Name, then the line about it on the same line.
    Row {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      visible: row.subtitleMode === "inline" && !row.answer
      spacing: 8
      clip: true

      Text {
        id: inlineTitle
        width: Math.min(implicitWidth, parent.width)
        text: row.title
        textFormat: Text.PlainText
        color: row.currentTitle
        font.family: row.fontFamily
        font.pixelSize: row.selected ? row.selectedTitleSize : row.titleSize
        font.weight: row.selected ? row.selectedTitleWeight : row.titleWeight
        elide: Text.ElideRight
      }
      Text {
        anchors.baseline: inlineTitle.baseline
        width: Math.max(0, parent.width - inlineTitle.width - 8)
        visible: text !== "" && width > 20
        text: row.secondLine
        textFormat: Text.PlainText
        color: row.currentSubtitle
        font.family: row.fontFamily
        font.pixelSize: row.subtitleSize
        elide: Text.ElideRight
      }
    }
  }

  Row {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: row.sideInset + row.padding
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10

    Text {
      visible: row.trailingSubtitle && row.secondLine !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: row.secondLine
      textFormat: Text.PlainText
      color: row.currentSubtitle
      font.family: row.fontFamily
      font.pixelSize: row.subtitleSize
    }

    Icon {
      visible: row.checked
      anchors.verticalCenter: parent.verticalCenter
      width: 14
      height: 14
      name: "check"
      color: row.currentSubtitle
      weight: 2.4
    }

    Text {
      visible: row.detail !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: row.detail
      textFormat: Text.PlainText
      color: row.currentSubtitle
      font.family: row.fontFamily
      font.pixelSize: row.subtitleSize
    }

    // Copy, for the clipboard and for answers.
    Rectangle {
      visible: row.copyable
      anchors.verticalCenter: parent.verticalCenter
      width: 24
      height: 24
      radius: 12
      color: row.selected ? Palette.a(row.selectedTitleColor, copyMouse.containsMouse ? 0.26 : 0.16)
        : copyMouse.containsMouse ? row.controlHover : row.controlFill
      Icon {
        anchors.centerIn: parent
        width: 14
        height: 14
        name: "copy"
        color: row.currentTitle
        weight: 1.8
      }
      MouseArea {
        id: copyMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          row.ui.selectedIndex = row.index
          row.ui.activateSelected("copy")
        }
      }
    }

    // What Return does.
    Rectangle {
      visible: row.selected && row.hint !== ""
      anchors.verticalCenter: parent.verticalCenter
      width: row.hintStyle === "circle" ? 28 : row.hintStyle === "pill" ? hintText.implicitWidth + 20 : hintText.implicitWidth
      height: row.hintStyle === "text" ? hintText.implicitHeight : row.hintStyle === "circle" ? 28 : 22
      radius: height / 2
      color: row.hintStyle === "text" ? "transparent" : row.hintFill
      Text {
        id: hintText
        anchors.centerIn: parent
        text: row.hint
        textFormat: Text.PlainText
        color: row.hintColor
        font.family: row.hintFont
        font.pixelSize: row.hintSize
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    z: -1
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onPositionChanged: function(mouse) {
      var at = mapToItem(null, mouse.x, mouse.y)
      if (row.ui) row.ui.pointerMoved(row.index, at.x, at.y)
    }
    onClicked: function(mouse) {
      if (!row.ui) return
      row.ui.selectedIndex = row.index
      row.ui.activateSelected(mouse.modifiers & Qt.ControlModifier ? "reveal" : "open")
    }
  }
}
