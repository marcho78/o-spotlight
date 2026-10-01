import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Command strip (designs 1b and 2b): docked under the top bar, the full
// width of the screen. Search results scroll sideways as cards (→ and ← at
// the ends of the text move through them); the views, or the kinds found,
// are segments fused to the bar's right end.
StyleBase {
  id: look
  field: input
  card: card
  horizontal: !!ui && ui.mode === "all" && !ui.gridView

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool typed: !!ui && ui.query.trim() !== ""
  readonly property real maxBody: 420
  readonly property real cardWidth: 150
  readonly property real cardHeight: 128

  // The segments: while you search, "All" and the kinds found; otherwise
  // "All" and the views.
  readonly property bool kindSegments: !!ui && ui.mode === "all" && typed && !ui.slashFilter && ui.engine && (ui.engine.kinds.length > 1 || ui.scope !== "")
  readonly property var segments: {
    if (!ui) return []
    if (kindSegments) return [{ id: "", title: "All" }].concat(ui.engine.kinds.map(function(k) { return { id: "kind:" + k.id, title: k.title } }))
    return [{ id: "", title: "All" }].concat(ui.modes.map(function(m) { return { id: "mode:" + m.id, title: look.shortLabel(m.id) } }))
  }
  readonly property string activeSegment: !ui ? "" : kindSegments ? (ui.scope ? "kind:" + ui.scope : "") : (ui.mode !== "all" ? "mode:" + ui.mode : "")
  function pickSegment(id) {
    if (id === "") {
      if (ui.scope !== "") ui.engine.setScope("")
      else ui.engine.setMode("all")
    } else if (id.indexOf("kind:") === 0) {
      ui.pickScope(id.slice(5))
    } else {
      ui.engine.setMode(id.slice(5))
    }
    ui.field.forceActiveFocus()
  }

  gridGap: 10
  gridColumns: Math.max(3, Math.floor((body.width + gridGap) / (cardWidth + gridGap)))
  gridTileWidth: (body.width - gridGap * (gridColumns - 1)) / gridColumns
  gridTileHeight: ui && ui.mode === "files" ? 128 : 116
  gridHeaderHeight: 34

  function reveal(index) { body.reveal(index) }
  function flashCopied() { toast.flash() }

  StyleCard {
    id: card
    ui: look.ui
    dock: "top"
    width: stage.width - reserved[0] - reserved[2]
    height: panel.height + 2
    entrance: "drop"

    RectangularShadow {
      anchors.fill: panel
      offset: Qt.vector2d(0, 20)
      blur: 40
      spread: -6
      color: Palette.a("#000000", look.pal.dark ? 0.45 : 0.2)
    }

    Rectangle {
      id: panel
      width: parent.width
      height: fieldRow.height + (look.expanded ? 1 + (chipsRow.visible ? chipsRow.height : 0) + body.height + 32 + hints.height : 0)
      color: look.pal.bg
      Behavior on height {
        enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
      }

      Item {
        id: fieldRow
        z: 2
        width: parent.width
        height: 56

        Text {
          id: slash
          x: 24
          anchors.verticalCenter: parent.verticalCenter
          text: "/"
          textFormat: Text.PlainText
          color: look.pal.accent
          font.family: look.mono
          font.pixelSize: 15
        }
        StyleToken {
          id: token
          ui: look.ui
          x: slash.x + slash.implicitWidth + 14
          anchors.verticalCenter: parent.verticalCenter
          fontFamily: look.sans
          size: 15
          textColor: look.pal.onAccent
          fill: look.pal.accent
          hoverFill: look.pal.accentDeep
        }
        StyleInput {
          id: input
          ui: look.ui
          x: token.visible ? token.x + token.width + 10 : slash.x + slash.implicitWidth + 14
          anchors.verticalCenter: parent.verticalCenter
          width: viewMenu.x - x - 16
          height: 30
          color: look.pal.text
          font.family: look.sans
          font.pixelSize: 20
          placeholder: "Search"
          placeholderColor: look.pal.faint
          cursorColor: look.pal.accent
          cursorHeight: 24
          completionColor: look.pal.faint
          actionColor: look.pal.faint
          actionSize: 20
        }
        StyleViewMenu {
          id: viewMenu
          anchors.right: segmentsRow.left
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          ui: look.ui
          fontFamily: look.sans
          color: look.pal.muted
          hoverFill: look.pal.surface
          menuFill: look.pal.bg
          menuBorder: look.pal.borderStrong
          menuText: look.pal.text
          menuFaint: look.pal.muted
          menuRadius: 6
        }

        // Fused to the right end of the bar.
        Row {
          id: segmentsRow
          anchors.right: parent.right
          height: parent.height
          Repeater {
            model: look.segments
            Rectangle {
              id: segment
              required property var modelData
              readonly property bool on: look.activeSegment === modelData.id
              width: segmentText.implicitWidth + 36
              height: segmentsRow.height
              color: on ? look.pal.accent : segmentMouse.containsMouse ? look.pal.surface : "transparent"
              Rectangle {
                width: 1
                height: parent.height
                color: look.pal.borderStrong
              }
              Text {
                id: segmentText
                anchors.centerIn: parent
                text: segment.modelData.title
                textFormat: Text.PlainText
                color: segment.on ? look.pal.onAccent : look.pal.textSoft
                font.family: look.sans
                font.pixelSize: 14
                font.weight: segment.on ? Font.DemiBold : Font.Normal
              }
              MouseArea {
                id: segmentMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (segment.modelData.id.indexOf("mode:") === 0) look.hoverMode(segment.modelData.id.slice(5), containsMouse)
                onClicked: look.pickSegment(segment.modelData.id)
              }
            }
          }
        }
      }

      Rectangle {
        y: fieldRow.height
        width: parent.width
        height: 1
        color: look.pal.border
        visible: look.expanded
      }

      // Applications' categories.
      StyleChips {
        id: chipsRow
        ui: look.ui
        x: 24
        y: fieldRow.height + 12
        width: parent.width - 48
        visible: look.expanded && shown && !!look.ui && (look.ui.mode === "apps" || look.ui.slashFilter)
        fontFamily: look.sans
        size: 12
        itemHeight: 26
        itemPadding: 10
        radius: 4
        fill: "transparent"
        hoverFill: look.pal.surface
        activeFill: look.pal.accent
        textColor: look.pal.textSoft
        activeTextColor: look.pal.onAccent
        onPicked: function(id) { look.ui.pickChip(id) }
      }

      StyleBody {
        id: body
        ui: look.ui
        x: 24
        y: fieldRow.height + 1 + 16 + (chipsRow.visible ? chipsRow.height + 4 : 0)
        width: parent.width - 48
        height: Math.min(look.maxBody, contentHeight)
        sidewaysHeight: look.cardHeight
        visible: look.expanded
        orientation: look.horizontal ? ListView.Horizontal : ListView.Vertical
        spacing: look.horizontal ? 10 : 2
        emptyFont: look.sans
        emptyColor: look.pal.muted

        rowDelegate: look.horizontal ? cardDelegate : rowComponent

        tileDelegate: Component {
          StyleTile {
            ui: look.ui
            layout: "card"
            fontFamily: look.sans
            radius: 8
            padding: 14
            iconSize: 40
            titleSize: 14
            titleWeight: Font.Medium
            selectedTitleWeight: Font.DemiBold
            subtitleSize: 11
            titleColor: look.pal.text
            subtitleColor: look.pal.muted
            fill: look.pal.surfaceLow
            selectedFill: look.pal.surface
            borderWidth: 2
            border: "transparent"
            selectedBorder: look.pal.accent
          }
        }

        sectionDelegate: Component {
          StyleSection {
            ui: look.ui
            fontFamily: look.mono
            size: 11
            weight: Font.Normal
            color: look.pal.faint
            upper: true
            tracking: 1.2
            inset: 0
            sectionHeight: 30
          }
        }

        gridHeader: Component {
          StyleGridHeader {
            ui: look.ui
            fontFamily: look.mono
            size: 11
            weight: Font.Normal
            color: look.pal.faint
            upper: true
            tracking: 1.2
            inset: 0
            rule: look.pal.border
          }
        }

        welcome: Component {
          StyleWelcome {
            ui: look.ui
            width: Math.min(680, body.width)
            fontFamily: look.sans
            keyFont: look.mono
            titleColor: look.pal.text
            textColor: look.pal.textSoft
            faintColor: look.pal.faint
            keyFill: look.pal.surface
            keyBorder: look.pal.border
            keyText: look.pal.textSoft
            keyRadius: 4
            buttonFill: look.pal.accent
            buttonHover: look.pal.accentDeep
            buttonText: look.pal.onAccent
            buttonRadius: 4
            sidePadding: 0
          }
        }
      }

      Row {
        id: hints
        x: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        height: 14
        visible: look.expanded
        spacing: 18
        Repeater {
          model: (look.horizontal ? ["← → move"] : ["↑ ↓ move"]).concat(["↵ open", "⌃↵ show in Files", "⌃1–4 views", "esc close"])
          Text {
            required property string modelData
            text: modelData
            textFormat: Text.PlainText
            color: look.pal.faint
            font.family: look.mono
            font.pixelSize: 11
          }
        }
      }

      Rectangle {
        anchors.top: parent.bottom
        width: parent.width
        height: 2
        color: look.pal.accent
      }
    }

    StyleToast {
      id: toast
      x: 24
      y: fieldRow.height + 20
      radius: 4
      fontFamily: look.sans
      color: look.pal.accent
      textColor: look.pal.onAccent
    }
  }

  Component {
    id: cardDelegate
    StyleTile {
      ui: look.ui
      listed: true
      listedWidth: look.cardWidth
      listedHeight: look.cardHeight
      layout: "card"
      fontFamily: look.sans
      radius: 8
      padding: 14
      iconSize: 40
      titleSize: 14
      titleWeight: Font.Medium
      selectedTitleWeight: Font.DemiBold
      subtitleSize: 11
      titleColor: look.pal.text
      subtitleColor: look.pal.muted
      fill: look.pal.surfaceLow
      selectedFill: look.pal.surface
      borderWidth: 2
      border: "transparent"
      selectedBorder: look.pal.accent
    }
  }

  Component {
    id: rowComponent
    StyleRow {
      ui: look.ui
      fontFamily: look.sans
      rowHeight: 44
      radius: 4
      padding: 12
      iconSize: 28
      titleSize: 14
      subtitleSize: 12
      subtitleMode: "inline"
      titleColor: look.pal.text
      selectedTitleColor: look.pal.onAccent
      subtitleColor: look.pal.muted
      selectedSubtitleColor: Palette.a(look.pal.onAccent, 0.7)
      selectedFill: look.pal.accent
      selectedTitleWeight: Font.DemiBold
      controlFill: look.pal.surface
      controlHover: look.pal.surfaceLow
    }
  }
}
