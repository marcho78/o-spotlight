import QtQuick
import "../Palette.js" as Palette
import "../Web.js" as Web

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
  property color regularTextColor: "white"

  readonly property real blockWidth: Math.round(font.pixelSize * 0.56)

  focus: true
  clip: true
  selectByMouse: true
  maximumLength: 500
  verticalAlignment: TextInput.AlignVCenter
  selectionColor: Palette.a(ui ? ui.pal.accent : "#7aa2f7", 0.4)
  selectedTextColor: color
  Component.onCompleted: regularTextColor = color
  onColorChanged: if (!ui || !ui.providerPrefixActive) regularTextColor = color

  // Paint a rich text copy over the plain TextInput so only the provider token
  // takes the accent. Selection uses TextInput's normal rendering.
  states: [State {
    name: "providerSearch"
    when: !!input.ui && input.ui.providerPrefixActive && input.selectedText === ""
    PropertyChanges { target: input; color: "transparent" }
  }]

  TextMetrics {
    id: cursorMetrics
    font: input.font
    text: input.text.slice(0, input.cursorPosition)
  }
  readonly property real providerTextOffset: Math.max(0, cursorMetrics.advanceWidth - input.cursorRectangle.x)

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) { if (input.ui) input.ui.handleKey(event) }
  Keys.onReleased: function(event) { if (input.ui) input.ui.handleKeyRelease(event) }
  onTextChanged: if (input.ui && input.ui.field === input) input.ui.fieldEdited(text)

  cursorDelegate: Item {
    z: 2
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

  Text {
    x: -input.providerTextOffset
    width: input.width
    height: input.height
    z: 1
    visible: !!input.ui && input.ui.field === input && input.ui.providerPrefixActive && input.selectedText === ""
    verticalAlignment: Text.AlignVCenter
    text: Web.providerMarkup(input.text, input.ui ? input.ui.pal.accent : "#0a84ff")
    textFormat: Text.RichText
    color: input.regularTextColor
    font: input.font
    elide: Text.ElideNone
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
