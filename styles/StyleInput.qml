import QtQuick
import "../Palette.js" as Palette

// A style's search field. What you type goes to Spotlight.qml's search and
// the keys to its keyboard handling, exactly as in Tahoe; the look is the
// style's: the cursor (a bar, or a block), the words while it's empty, and
// the Top Hit completing what you typed in a dimmer color ("chr" then
// "omium — Open"), which → accepts.
TextInput {
  id: input

  property var ui: null
  // The style's words for an empty field (a view's name replaces them,
  // unless the style shows the view as a token already).
  property string placeholder: "Search"
  property bool namesView: true
  property color placeholderColor: "gray"
  property string cursorStyle: "bar"          // "bar" or "block"
  property color cursorColor: "white"
  property real cursorWidth: 2
  property real cursorHeight: Math.round(font.pixelSize * 1.15)
  property bool cursorGlow: false
  property bool completes: true
  property color completionColor: "gray"
  property color actionColor: completionColor
  property bool showAction: true
  property int actionSize: Math.round(font.pixelSize * 0.8)
  property string actionFont: font.family

  readonly property real blockWidth: Math.round(font.pixelSize * 0.56)

  focus: true
  clip: true
  selectByMouse: true
  maximumLength: 500
  verticalAlignment: TextInput.AlignVCenter
  selectionColor: Palette.a(ui ? ui.pal.accent : "#7aa2f7", 0.4)
  selectedTextColor: color

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) { if (input.ui) input.ui.handleKey(event) }
  Keys.onReleased: function(event) { if (input.ui) input.ui.handleKeyRelease(event) }
  onTextChanged: if (input.ui && input.ui.field === input) input.ui.fieldEdited(text)

  cursorDelegate: Item {
    width: input.cursorStyle === "block" ? input.blockWidth : input.cursorWidth
    height: input.height
    visible: input.activeFocus && input.cursorVisible && input.selectedText === ""

    Rectangle {
      anchors.centerIn: bar
      width: bar.width + 8
      height: bar.height + 6
      radius: width / 2
      color: input.cursorColor
      opacity: 0.28
      visible: input.cursorGlow
    }
    Rectangle {
      id: bar
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: input.cursorHeight
      color: input.cursorColor
    }
  }

  Text {
    x: input.cursorStyle === "block" ? input.blockWidth + Math.round(input.font.pixelSize * 0.4) : 0
    width: parent.width - x
    height: parent.height
    verticalAlignment: Text.AlignVCenter
    visible: input.text === ""
    text: !input.ui ? input.placeholder
      : input.namesView || input.ui.hoveredMode !== "" ? input.ui.placeholderText(input.placeholder)
      : input.placeholder
    textFormat: Text.PlainText
    color: input.placeholderColor
    font: input.font
    elide: Text.ElideRight
  }

  // The rest of the Top Hit's name after what you typed, and what Return does.
  Row {
    x: input.contentWidth + (input.ui && input.ui.completionPrefix ? 0 : Math.round(input.font.pixelSize * 0.45))
      + (input.cursorStyle === "block" ? 1 : 0)
    anchors.verticalCenter: parent.verticalCenter
    visible: input.completes && !!input.ui && input.ui.field === input && input.ui.completionShown

    Text {
      id: rest
      text: input.ui ? input.ui.completionRemainder : ""
      textFormat: Text.PlainText
      color: input.completionColor
      font: input.font
    }
    Text {
      anchors.baseline: rest.baseline
      visible: input.showAction
      text: input.ui ? input.ui.completionSuffix : ""
      textFormat: Text.PlainText
      color: input.actionColor
      font.family: input.actionFont
      font.pixelSize: input.actionSize
    }
  }
}
