import QtQuick
import ".."

// Applications and Files as a grid or a list: the "…" button and its menu,
// in a style's colors (Tahoe has its own).
Item {
  id: view

  property var ui: null
  property string fontFamily: "sans-serif"
  property color color: "gray"
  property color hoverFill: "#22ffffff"
  property color menuFill: "#1a1b26"
  property color menuBorder: "#33ffffff"
  property color menuText: "white"
  property color menuFaint: "gray"
  property real menuRadius: 10

  readonly property bool available: !!ui && (ui.mode === "apps" || ui.mode === "files") && ui.styleInfo.grid === true
  readonly property bool open: !!ui && ui.popup === "view"

  width: 26
  height: 26
  visible: available

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: moreMouse.containsMouse || view.open ? view.hoverFill : "transparent"
    border.width: 1.5
    border.color: view.color
    Icon {
      anchors.centerIn: parent
      width: 16
      height: 16
      name: "more"
      color: view.color
      weight: 3
    }
    MouseArea {
      id: moreMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: view.ui.popup = view.open ? "" : "view"
    }
  }

  Rectangle {
    visible: view.open
    anchors.right: parent.right
    anchors.top: parent.bottom
    anchors.topMargin: 8
    z: 50
    width: 170
    height: column.implicitHeight + 12
    radius: view.menuRadius
    color: view.menuFill
    border.width: 1
    border.color: view.menuBorder

    MouseArea { anchors.fill: parent }

    Column {
      id: column
      x: 6
      y: 6
      width: parent.width - 12
      Text {
        x: 8
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: "View content as"
        textFormat: Text.PlainText
        color: view.menuFaint
        font.family: view.fontFamily
        font.pixelSize: 12
      }
      Repeater {
        model: [{ value: "grid", label: "Grid" }, { value: "list", label: "List" }]
        Rectangle {
          required property var modelData
          readonly property string key: view.ui && view.ui.mode === "files" ? "filesView" : "appsView"
          readonly property bool chosen: view.ui && (view.ui.settings[key] || "grid") === modelData.value
          width: column.width
          height: 28
          radius: 6
          color: optionMouse.containsMouse ? view.hoverFill : "transparent"
          Icon {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            visible: parent.chosen
            name: "check"
            color: view.menuText
            weight: 2.4
          }
          Text {
            x: 30
            anchors.verticalCenter: parent.verticalCenter
            text: parent.modelData.label
            textFormat: Text.PlainText
            color: view.menuText
            font.family: view.fontFamily
            font.pixelSize: 14
          }
          MouseArea {
            id: optionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (view.ui.service) view.ui.service.setSetting(parent.key, parent.modelData.value)
              view.ui.popup = ""
              view.ui.resetSelection = true
              Qt.callLater(function() { view.ui.engine.rebuild(false) })
            }
          }
        }
      }
    }
  }
}
