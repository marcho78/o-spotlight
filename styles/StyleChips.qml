import QtQuick

// A row of filters: the kinds of results found, or Applications'
// categories, or a style's own list (the views, with "All"). Drawn as chips,
// segments, tabs or plain words, whatever the style's tokens say.
Item {
  id: chips

  property var ui: null
  // [{ id, title }]; by default the filters Spotlight.qml would show.
  property var items: ui ? ui.chipItems : []
  property string activeId: ui && ui.mode === "apps" && ui.engine ? ui.engine.appCategory : ""
  signal picked(string id)

  property string fontFamily: "sans-serif"
  property int size: 13
  property int weight: Font.Normal
  property int activeWeight: Font.DemiBold
  property bool upper: false
  property real tracking: 0
  property real itemHeight: 26
  property real itemPadding: 12
  property real spacing: 8
  property real radius: 8
  property color fill: "transparent"
  property color hoverFill: "#22ffffff"
  property color activeFill: "#44ffffff"
  property color border: "transparent"
  property color activeBorder: border
  property real borderWidth: 0
  property color textColor: "gray"
  property color activeTextColor: "white"
  // Segments: a line between items instead of space.
  property color divider: "transparent"

  readonly property bool shown: items.length > 0
  implicitWidth: row.width
  implicitHeight: shown ? itemHeight : 0
  height: implicitHeight

  Flickable {
    anchors.fill: parent
    contentWidth: row.width
    interactive: contentWidth > width
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Row {
      id: row
      spacing: chips.divider.a > 0 ? 0 : chips.spacing
      Repeater {
        model: chips.items
        Rectangle {
          id: item
          required property var modelData
          required property int index
          readonly property bool active: chips.activeId === modelData.id
          width: label.implicitWidth + 2 * chips.itemPadding
          height: chips.itemHeight
          radius: chips.radius
          color: active ? chips.activeFill : mouse.containsMouse ? chips.hoverFill : chips.fill
          border.width: chips.borderWidth
          border.color: active ? chips.activeBorder : chips.border
          Rectangle {
            width: 1
            height: parent.height
            color: chips.divider
            visible: chips.divider.a > 0 && item.index > 0
          }
          Text {
            id: label
            anchors.centerIn: parent
            text: chips.upper ? item.modelData.title.toUpperCase() : item.modelData.title
            textFormat: Text.PlainText
            color: item.active ? chips.activeTextColor : chips.textColor
            font.family: chips.fontFamily
            font.pixelSize: chips.size
            font.weight: item.active ? chips.activeWeight : chips.weight
            font.letterSpacing: chips.tracking
          }
          MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chips.picked(item.modelData.id)
          }
        }
      }
    }
  }
}
