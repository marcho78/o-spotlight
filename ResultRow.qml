import QtQuick

// One row of the list, as in Spotlight in macOS Tahoe: 56 tall, a 32 icon,
// the name, and a line about it (for a file: kind · size · date · folder,
// or its path while Ctrl is held). A calculation shows its answer large.
Item {
  id: row

  // From the model (see Engine.displayRow).
  required property int index
  required property string key
  required property string kind
  required property string source
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

  // From the window.
  property var ui: null
  readonly property bool selected: !!ui && ui.selectedIndex === row.index
  readonly property bool answer: row.kind === "answer"
  readonly property bool showPath: !!ui && ui.showPaths && row.path !== ""
  readonly property bool hasSecondLine: row.subtitle !== "" || row.folder !== "" || row.showPath

  width: ListView.view ? ListView.view.width : 0
  height: row.answer ? 76 : 56

  // The selection: a neutral glass tint, as in Tahoe (or the accent color,
  // if the settings ask for the older look).
  Rectangle {
    x: 10
    width: parent.width - 20
    height: parent.height
    radius: 18
    color: ui.selectionColor
    visible: row.selected
  }

  ResultIcon {
    id: iconBox
    x: row.answer ? 17 : 21
    anchors.verticalCenter: parent.verticalCenter
    width: row.answer ? 40 : 32
    height: width
    iconType: row.iconType
    iconSource: row.iconSource
    glyph: row.glyph
    glyphFont: row.glyphFont
    badge: row.badge
    symbol: row.symbol
    thumbs: row.thumbs
    fallbackFont: ui.glyphFont
  }

  Column {
    id: texts
    x: 72
    anchors.verticalCenter: parent.verticalCenter
    width: trailing.x - x - 14
    spacing: row.answer ? 0 : 1

    Text {
      width: parent.width
      text: row.title
      textFormat: Text.PlainText
      color: ui.rowText(row.selected)
      font.family: ui.uiFont
      font.pixelSize: row.answer ? 26 : 17
      font.weight: row.answer ? Font.DemiBold : Font.Normal
      elide: Text.ElideRight
    }

    Item {
      width: parent.width
      height: secondLine.implicitHeight
      visible: row.hasSecondLine

      Text {
        id: secondLine
        width: Math.min(implicitWidth, parent.width - (folderPart.visible ? Math.min(folderPart.implicitWidth, parent.width * 0.45) : 0))
        text: row.showPath ? row.path : row.subtitle + (row.subtitle !== "" && row.folder !== "" ? " · " : "")
        textFormat: Text.PlainText
        color: ui.rowSubtext(row.selected)
        font.family: ui.uiFont
        font.pixelSize: 15
        elide: Text.ElideRight
      }

      Row {
        id: folderPart
        anchors.left: secondLine.right
        anchors.verticalCenter: secondLine.verticalCenter
        visible: !row.showPath && row.folder !== ""
        width: Math.min(implicitWidth, parent.width - secondLine.width)
        spacing: 4
        clip: true

        Icon {
          anchors.verticalCenter: parent.verticalCenter
          width: 15
          height: 15
          name: "folder"
          color: ui.rowSubtext(row.selected)
          weight: 1.8
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: row.folder
          textFormat: Text.PlainText
          color: ui.rowSubtext(row.selected)
          font.family: ui.uiFont
          font.pixelSize: 15
          elide: Text.ElideRight
        }
      }
    }
  }

  Row {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: 21
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10

    Icon {
      visible: row.checked
      anchors.verticalCenter: parent.verticalCenter
      width: 16
      height: 16
      name: "check"
      color: ui.rowSubtext(row.selected)
      weight: 2.4
    }

    Text {
      visible: row.detail !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: row.detail
      textFormat: Text.PlainText
      color: ui.rowSubtext(row.selected)
      font.family: ui.uiFont
      font.pixelSize: 15
    }

    // Copy, for the clipboard and for answers.
    Rectangle {
      id: copyButton
      visible: row.copyable
      anchors.verticalCenter: parent.verticalCenter
      width: 26
      height: 26
      radius: 13
      color: copyMouse.containsMouse ? ui.controlHover : ui.controlFill
      Icon {
        anchors.centerIn: parent
        width: 15
        height: 15
        name: "copy"
        color: ui.rowText(row.selected)
        weight: 1.8
      }
      MouseArea {
        id: copyMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          ui.selectedIndex = row.index
          ui.activateSelected("copy")
        }
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
      if (ui) ui.pointerMoved(row.index, at.x, at.y)
    }
    onClicked: function(mouse) {
      if (!ui) return
      ui.selectedIndex = row.index
      ui.activateSelected(mouse.modifiers & Qt.ControlModifier ? "reveal" : "open")
    }
  }
}
