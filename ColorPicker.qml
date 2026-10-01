import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// The color picker that opens from a color's chip in the settings window: a
// square of saturation (across) and brightness (down) in the hue, a hue
// bar, the color as hex (editable), and swatches to start from. What you
// pick applies as you drag (picked); Done, Esc, or a click anywhere else
// closes it.
Rectangle {
  id: picker

  property string title: ""
  // [{ label, colors: ["#rrggbb", ...] }]
  property var swatches: []

  signal picked(string color)
  signal done()

  // The color as hue, saturation and brightness (0 to 1), kept here so a
  // grey you drag through doesn't lose its hue.
  property real hue: 0
  property real sat: 0
  property real val: 0
  readonly property color current: Qt.hsva(hue, sat, val, 1)
  readonly property string hex: String(current)

  function clamp(v) { return Math.max(0, Math.min(1, v)) }

  // Opens on a color (no picking yet).
  function show(color) {
    var c = Qt.color(String(color || "#000000"))
    if (c.hsvHue >= 0) hue = c.hsvHue
    sat = c.hsvSaturation
    val = c.hsvValue
    hexField.text = hex
    visible = true
    forceActiveFocus()
  }

  function pick(h, s, v) {
    hue = clamp(h)
    sat = clamp(s)
    val = clamp(v)
    hexField.text = hex
    picked(hex)
  }

  function pickHex(text) {
    var v = String(text || "").trim()
    if (v.charAt(0) !== "#") v = "#" + v
    if (!/^#[0-9a-fA-F]{6}$/.test(v)) {
      hexField.text = hex
      return
    }
    show(v.toLowerCase())
    picked(v.toLowerCase())
  }

  readonly property color fg: Color.foreground
  readonly property color line: Qt.rgba(fg.r, fg.g, fg.b, 0.16)

  width: 276
  height: column.implicitHeight + 28
  radius: 12
  color: Color.background
  border.width: 1
  border.color: line
  visible: false

  Keys.onEscapePressed: done()

  RectangularShadow {
    anchors.fill: parent
    z: -1
    radius: picker.radius
    offset: Qt.vector2d(0, 14)
    blur: 34
    spread: -4
    color: Qt.rgba(0, 0, 0, 0.45)
  }

  // Clicks inside stay inside.
  MouseArea { anchors.fill: parent }

  Column {
    id: column
    x: 14
    y: 14
    width: parent.width - 28
    spacing: 12

    Text {
      width: parent.width
      text: picker.title
      textFormat: Text.PlainText
      color: picker.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.weight: Font.DemiBold
      elide: Text.ElideRight
    }

    // Saturation across, brightness down.
    Item {
      id: square
      width: parent.width
      height: 150

      Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.hsva(picker.hue, 1, 1, 1)
      }
      Rectangle {
        anchors.fill: parent
        radius: 8
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: "#ffffffff" }
          GradientStop { position: 1; color: "#00ffffff" }
        }
      }
      Rectangle {
        anchors.fill: parent
        radius: 8
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.2)
        gradient: Gradient {
          GradientStop { position: 0; color: "#00000000" }
          GradientStop { position: 1; color: "#ff000000" }
        }
      }
      Rectangle {
        x: picker.sat * square.width - width / 2
        y: (1 - picker.val) * square.height - height / 2
        width: 16
        height: 16
        radius: 8
        color: picker.current
        border.width: 2
        border.color: "white"
        Rectangle {
          anchors.fill: parent
          anchors.margins: -1
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(0, 0, 0, 0.45)
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        preventStealing: true
        function at(mouse) { picker.pick(picker.hue, mouse.x / width, 1 - mouse.y / height) }
        onPressed: function(mouse) { at(mouse) }
        onPositionChanged: function(mouse) { at(mouse) }
      }
    }

    // The hue.
    Item {
      id: hueBar
      width: parent.width
      height: 14

      Rectangle {
        anchors.fill: parent
        radius: 7
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.2)
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0 / 6; color: "#ff0000" }
          GradientStop { position: 1 / 6; color: "#ffff00" }
          GradientStop { position: 2 / 6; color: "#00ff00" }
          GradientStop { position: 3 / 6; color: "#00ffff" }
          GradientStop { position: 4 / 6; color: "#0000ff" }
          GradientStop { position: 5 / 6; color: "#ff00ff" }
          GradientStop { position: 6 / 6; color: "#ff0000" }
        }
      }
      Rectangle {
        x: picker.hue * hueBar.width - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: Qt.hsva(picker.hue, 1, 1, 1)
        border.width: 2
        border.color: "white"
        Rectangle {
          anchors.fill: parent
          anchors.margins: -1
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(0, 0, 0, 0.45)
        }
      }
      MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        // Just short of 1, so the far end stays red rather than wrapping.
        function at(mouse) { picker.pick(Math.min(0.999, (mouse.x - 4) / hueBar.width), picker.sat, picker.val) }
        onPressed: function(mouse) { at(mouse) }
        onPositionChanged: function(mouse) { at(mouse) }
      }
    }

    // The color, as hex.
    Row {
      width: parent.width
      spacing: 10
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: 8
        color: picker.current
        border.width: 1
        border.color: picker.line
      }
      TextField {
        id: hexField
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 30 - doneButton.width - 20
        onAccepted: picker.pickHex(text)
        onEditingFinished: picker.pickHex(text)
      }
      Button {
        id: doneButton
        anchors.verticalCenter: parent.verticalCenter
        bordered: true
        text: "Done"
        onClicked: picker.done()
      }
    }

    // Colors to start from.
    Repeater {
      model: picker.swatches
      Column {
        required property var modelData
        width: column.width
        spacing: 6
        Text {
          text: parent.modelData.label
          textFormat: Text.PlainText
          color: picker.fg
          opacity: 0.55
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Flow {
          width: parent.width
          spacing: 6
          Repeater {
            model: parent.parent.modelData.colors
            Rectangle {
              required property string modelData
              readonly property bool chosen: picker.hex === modelData.toLowerCase()
              width: 22
              height: 22
              radius: 11
              color: modelData
              border.width: chosen ? 2 : 1
              border.color: chosen ? picker.fg : picker.line
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  picker.show(parent.modelData)
                  picker.picked(parent.modelData.toLowerCase())
                }
              }
            }
          }
        }
      }
    }
  }
}
