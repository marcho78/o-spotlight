import QtQuick

// A section header in a style's list: Files' Suggestions and Recents,
// Actions' menus, the Drawer's kinds (which a click picks).
Item {
  id: header

  required property string section
  property var ui: null

  property string fontFamily: "sans-serif"
  property int size: 12
  property int weight: Font.DemiBold
  property bool upper: false
  property real tracking: 0
  property color color: "gray"
  property color rule: "transparent"
  property real inset: 12
  property real sectionHeight: 30
  // Clicking the title keeps that kind only (the Drawer's groups).
  property bool pickable: false

  width: ListView.view ? ListView.view.width : 0
  height: section === "" ? 0 : sectionHeight
  visible: section !== ""

  Text {
    x: header.inset
    anchors.bottom: parent.bottom
    anchors.bottomMargin: header.rule.a > 0 ? 7 : 5
    text: header.upper ? header.section.toUpperCase() : header.section
    textFormat: Text.PlainText
    color: header.color
    font.family: header.fontFamily
    font.pixelSize: header.size
    font.weight: header.weight
    font.letterSpacing: header.tracking
    MouseArea {
      anchors.fill: parent
      enabled: header.pickable
      cursorShape: header.pickable ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: {
        var kinds = header.ui && header.ui.engine ? header.ui.engine.kinds : []
        for (var i = 0; i < kinds.length; i++) {
          if (kinds[i].title === header.section) {
            header.ui.pickScope(kinds[i].id)
            header.ui.field.forceActiveFocus()
            return
          }
        }
      }
    }
  }
  Rectangle {
    x: header.inset
    anchors.bottom: parent.bottom
    width: parent.width - 2 * header.inset
    height: 1
    color: header.rule
    visible: header.rule.a > 0
  }
}
