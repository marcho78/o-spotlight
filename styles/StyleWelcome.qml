import QtQuick
import ".."

// The welcome the first time the search opens (Tahoe has the same one):
// what's there, the views and their keys, and that what you open is only
// remembered here. The style gives it its fonts and colors.
Column {
  id: welcome

  property var ui: null
  property string fontFamily: "sans-serif"
  property string keyFont: fontFamily
  property int titleSize: 17
  property int textSize: 14
  property int smallSize: 12
  property color titleColor: "white"
  property color textColor: "gray"
  property color faintColor: "gray"
  property color keyFill: "#22ffffff"
  property color keyBorder: "#22ffffff"
  property color keyText: textColor
  property real keyRadius: 6
  property color buttonFill: keyFill
  property color buttonHover: keyBorder
  property color buttonText: titleColor
  property real buttonRadius: 15
  property bool showIcons: true
  // Terminal: "›" instead of the icons.
  property string bullet: ""
  property real sidePadding: 20

  spacing: 12
  topPadding: 12
  bottomPadding: 14
  leftPadding: sidePadding
  rightPadding: sidePadding

  readonly property real inner: width - leftPadding - rightPadding

  Text {
    width: welcome.inner
    text: "Search everything on Omarchy"
    textFormat: Text.PlainText
    color: welcome.titleColor
    font.family: welcome.fontFamily
    font.pixelSize: welcome.titleSize
    font.weight: Font.DemiBold
  }
  Text {
    width: welcome.inner
    wrapMode: Text.WordWrap
    text: "Apps, Omarchy's settings and actions, themes, your files and what's in them, math and conversions. Start typing, or browse:"
    textFormat: Text.PlainText
    color: welcome.textColor
    font.family: welcome.fontFamily
    font.pixelSize: welcome.textSize
  }
  Column {
    width: welcome.inner
    spacing: 0
    Repeater {
      model: welcome.ui ? welcome.ui.modes.map(function(m) { return { icon: m.icon, label: m.label, keys: ["Ctrl", m.key] } }).concat([
        { icon: "back", label: "Your last searches", keys: ["↑"], turn: true },
        { icon: "folder", label: "Where a file is: hold Ctrl", keys: ["Ctrl"] }
      ]) : []
      Item {
        required property var modelData
        width: parent.width
        height: 30
        Icon {
          anchors.verticalCenter: parent.verticalCenter
          visible: welcome.showIcons
          width: 18
          height: 18
          name: parent.modelData.icon
          rotation: parent.modelData.turn ? 90 : 0
          color: welcome.textColor
          weight: 1.9
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: !welcome.showIcons
          text: welcome.bullet
          textFormat: Text.PlainText
          color: welcome.faintColor
          font.family: welcome.keyFont
          font.pixelSize: welcome.textSize
        }
        Text {
          x: welcome.showIcons ? 30 : 18
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          textFormat: Text.PlainText
          color: welcome.titleColor
          font.family: welcome.fontFamily
          font.pixelSize: welcome.textSize
        }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4
          Repeater {
            model: parent.parent.modelData.keys
            Rectangle {
              required property string modelData
              width: Math.max(22, keyText.implicitWidth + 12)
              height: 22
              radius: welcome.keyRadius
              color: welcome.keyFill
              border.width: 1
              border.color: welcome.keyBorder
              Text {
                id: keyText
                anchors.centerIn: parent
                text: parent.modelData
                textFormat: Text.PlainText
                color: welcome.keyText
                font.family: welcome.keyFont
                font.pixelSize: welcome.smallSize
              }
            }
          }
        }
      }
    }
  }
  Item {
    width: welcome.inner
    height: Math.max(32, privacy.implicitHeight)
    Text {
      id: privacy
      anchors.left: parent.left
      anchors.right: continueButton.left
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      wrapMode: Text.WordWrap
      text: "What you open is remembered only on this computer, to put it first next time."
      textFormat: Text.PlainText
      color: welcome.faintColor
      font.family: welcome.fontFamily
      font.pixelSize: welcome.smallSize
    }
    Rectangle {
      id: continueButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: continueText.implicitWidth + 30
      height: 30
      radius: welcome.buttonRadius
      color: continueMouse.containsMouse ? welcome.buttonHover : welcome.buttonFill
      border.width: 1
      border.color: welcome.keyBorder
      Text {
        id: continueText
        anchors.centerIn: parent
        text: "Continue"
        textFormat: Text.PlainText
        color: welcome.buttonText
        font.family: welcome.fontFamily
        font.pixelSize: welcome.textSize
        font.weight: Font.Medium
      }
      MouseArea {
        id: continueMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          welcome.ui.engine.finishOnboarding()
          welcome.ui.field.forceActiveFocus()
        }
      }
    }
  }
}
