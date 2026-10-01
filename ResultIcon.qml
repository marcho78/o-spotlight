import QtQuick
import Quickshell.Widgets

// A result's icon at any size: an app or file icon from the icon theme (with
// the file's own picture over it when there is one), a colored tile with a
// glyph or symbol for Omarchy's things, or a picture (a theme's preview).
Item {
  id: icon

  property string iconType: "badge"   // "image", "file", "badge", "thumb"
  property string iconSource: ""
  property string glyph: ""
  property string glyphFont: ""
  property string badge: "#8e8e93"
  property string symbol: ""
  property string thumbs: ""          // "|"-separated pictures to try, in order
  property string fallbackFont: ""
  // Omarchy's tiles and pictures as circles (app and file icons keep their shape).
  property bool round: false

  implicitWidth: 32
  implicitHeight: 32

  Image {
    id: themed
    anchors.fill: parent
    visible: (icon.iconType === "image" || icon.iconType === "file") && !picture.shown
    source: icon.iconType === "image" || icon.iconType === "file" ? icon.iconSource : ""
    sourceSize.width: Math.ceil(width * 2)
    sourceSize.height: Math.ceil(height * 2)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 90 } }
  }

  // The file itself, or a thumbnail of it: framed like a photo, as Finder does.
  Item {
    id: picture
    readonly property var candidates: icon.thumbs ? icon.thumbs.split("|") : []
    property int attempt: 0
    readonly property bool shown: pictureImage.status === Image.Ready && candidates.length > 0
    anchors.fill: parent
    visible: shown
    onCandidatesChanged: attempt = 0

    Rectangle {
      anchors.centerIn: parent
      width: pictureImage.paintedWidth + 2
      height: pictureImage.paintedHeight + 2
      radius: 2
      color: "white"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.12)
    }

    Image {
      id: pictureImage
      anchors.fill: parent
      anchors.margins: 1
      source: picture.attempt < picture.candidates.length ? picture.candidates[picture.attempt] : ""
      sourceSize.width: 128
      sourceSize.height: 128
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      cache: true
      smooth: true
      onStatusChanged: if (status === Image.Error && picture.attempt < picture.candidates.length) picture.attempt++
    }
  }

  // Omarchy's own things: a colored tile like the icons in macOS System
  // Settings, with the menu's glyph or one of O-Spotlight's icons on it.
  Rectangle {
    visible: icon.iconType === "badge"
    anchors.fill: parent
    anchors.margins: Math.round(icon.width * 0.03)
    radius: icon.round ? width / 2 : Math.round(width * 0.25)
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.lighter(icon.badge || "#8e8e93", 1.2) }
      GradientStop { position: 1; color: icon.badge || "#8e8e93" }
    }
    border.width: 0.5
    border.color: Qt.rgba(0, 0, 0, 0.16)

    Text {
      anchors.centerIn: parent
      visible: icon.glyph !== ""
      text: icon.glyph
      textFormat: Text.PlainText
      color: "white"
      font.family: icon.glyphFont || icon.fallbackFont
      font.pixelSize: Math.round(parent.width * 0.56)
    }
    Icon {
      anchors.centerIn: parent
      visible: icon.glyph === "" && icon.symbol !== ""
      width: Math.round(parent.width * 0.66)
      height: width
      name: icon.symbol
      color: "white"
      weight: 2
    }
  }

  // A picture: a theme's preview, an image from the clipboard.
  ClippingRectangle {
    visible: icon.iconType === "thumb"
    anchors.fill: parent
    radius: icon.round ? width / 2 : Math.round(width * 0.2)
    color: Qt.rgba(0.5, 0.5, 0.5, 0.2)
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.14)
    Image {
      anchors.fill: parent
      source: icon.iconType === "thumb" ? icon.iconSource : ""
      sourceSize.width: 160
      sourceSize.height: 160
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
    }
  }
}
