import QtQuick

// A style's search on the screen: where it sits, how it comes in, and the
// mouse on it (a click stays on it rather than closing the search; a drag
// moves it, where it isn't docked). Its `placeX`/`placeY` are what
// Spotlight.qml asks when a drag ends, as it asks Tahoe's.
Item {
  id: card

  property var ui: null
  readonly property Item stage: parent
  // "center": high in the middle, where you left it; "top": under the top
  // bar, full width; "left": the full height at the left; "island": at the
  // very top, over the bar.
  property string dock: "center"
  // The tallest it gets, so dragging keeps all of it on screen.
  property real tallest: height
  // How it comes in: "rise", "drop", "slide", "grow" or "fade".
  property string entrance: "rise"

  readonly property real t: ui ? ui.enter : 1
  readonly property real eased: 1 - Math.pow(1 - t, 3)
  readonly property real back: {
    var u = t - 1
    return 1 + 2.2 * u * u * u + 1.2 * u * u
  }
  readonly property var reserved: ui ? ui.reserved : [0, 26, 0, 0]

  readonly property real homeX: Math.round((stage.width - width) / 2)
  readonly property real homeY: Math.round(stage.height * 0.2)
  readonly property real offsetX: ui && ui.dragging ? ui.dragX : (ui && ui.settings.offsetX || 0)
  readonly property real offsetY: ui && ui.dragging ? ui.dragY : (ui && ui.settings.offsetY || 0)
  function placeX(offset) { return Math.min(Math.max(8, stage.width - width - 8), Math.max(8, homeX + offset)) }
  function placeY(offset) { return Math.min(Math.max(8, stage.height - tallest - 8), Math.max(8, homeY + offset)) }

  x: dock === "center" ? placeX(offsetX) : dock === "island" ? homeX : reserved[0]
  y: dock === "center" ? placeY(offsetY) : dock === "island" ? 5 : reserved[1]
  opacity: ui && ui.revealed ? ui.progress : 0

  transform: [
    Translate {
      x: card.entrance === "slide" ? -(1 - card.eased) * (card.width + 30) : 0
      y: card.entrance === "rise" ? (1 - card.eased) * 12
        : card.entrance === "drop" ? -(1 - card.eased) * 28 : 0
    },
    Scale {
      origin.x: card.width / 2
      origin.y: 0
      xScale: card.entrance === "grow" ? 0.35 + 0.65 * card.back : card.entrance === "rise" ? 0.97 + 0.03 * card.eased : 1
      yScale: card.entrance === "grow" ? 0.25 + 0.75 * card.back : card.entrance === "rise" ? 0.97 + 0.03 * card.eased : 1
    }
  ]

  MouseArea {
    id: area
    anchors.fill: parent
    z: -1
    acceptedButtons: Qt.AllButtons
    cursorShape: card.ui && card.ui.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
    onPressed: function(mouse) {
      if (card.ui) card.ui.field.forceActiveFocus()
      if (card.dock === "center" && mouse.button === Qt.LeftButton && card.ui) card.ui.dragPressed(area, mouse)
    }
    onPositionChanged: function(mouse) { if (card.ui) card.ui.dragMoved(area, mouse) }
    onReleased: if (card.ui) card.ui.dragReleased()
    onCanceled: if (card.ui) card.ui.dragReleased()
  }
}
