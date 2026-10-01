import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Drawer (designs 1f and 2c): the full height of the screen at the left,
// large type on an accent rule, results grouped by kind like classic
// Spotlight (the engine groups them for this style; a group's title keeps
// only that kind). With nothing typed, the views are listed under the rule.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool idle: !!ui && ui.collapsedMain && !ui.showOnboarding

  gridColumns: 3
  gridGap: 6
  gridTileWidth: (body.width - gridGap * (gridColumns - 1)) / gridColumns
  gridTileHeight: ui && ui.mode === "files" ? 112 : 100
  gridHeaderHeight: 32

  function reveal(index) { body.reveal(index) }
  function flashCopied() { toast.flash() }

  StyleCard {
    id: card
    ui: look.ui
    dock: "left"
    width: 380
    height: stage.height - reserved[1] - reserved[3]
    entrance: "slide"

    RectangularShadow {
      anchors.fill: panel
      offset: Qt.vector2d(20, 0)
      blur: 50
      spread: -10
      color: Palette.a("#000000", look.pal.dark ? 0.4 : 0.18)
    }

    Rectangle {
      id: panel
      anchors.fill: parent
      color: look.pal.bg

      Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: look.pal.border
      }

      Item {
        id: header
        z: 2
        x: 22
        y: 22
        width: parent.width - 44
        height: 52

        StyleToken {
          id: token
          ui: look.ui
          what: look.ui && look.ui.mode !== "all" && look.ui.scope === "" ? "mode" : "scope"
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -4
          fontFamily: look.sans
          size: 15
          textColor: look.pal.onAccent
          fill: look.pal.accent
          hoverFill: look.pal.accentDeep
        }
        StyleInput {
          id: input
          ui: look.ui
          namesView: false
          x: token.visible ? token.width + 10 : 0
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -4
          width: trailing.x - x - 8
          height: 38
          color: look.pal.text
          font.family: look.sans
          font.pixelSize: 26
          font.weight: Font.Medium
          placeholder: "search"
          placeholderColor: look.pal.faint
          cursorColor: look.pal.text
          cursorWidth: 3
          cursorHeight: 30
          completionColor: look.pal.faint
          actionColor: look.pal.faint
          actionSize: 16
        }
        Row {
          id: trailing
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -4
          StyleViewMenu {
            ui: look.ui
            fontFamily: look.sans
            color: look.pal.muted
            hoverFill: look.pal.surface
            menuFill: look.pal.bg
            menuBorder: look.pal.borderStrong
            menuText: look.pal.text
            menuFaint: look.pal.muted
            menuRadius: 8
          }
        }
        // The rule.
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 2
          color: look.pal.accent
        }
      }

      // ---- nothing typed: the views, numbered ----
      Flow {
        id: modeList
        x: 22
        y: header.y + header.height + 16
        width: parent.width - 44
        spacing: 18
        visible: look.idle
        Repeater {
          model: look.idle ? look.modes : []
          Item {
            id: modeItem
            required property var modelData
            width: itemRow.implicitWidth
            height: itemRow.implicitHeight
            Row {
              id: itemRow
              spacing: 5
              Text {
                text: "⌃" + modeItem.modelData.key
                textFormat: Text.PlainText
                color: look.pal.accent
                font.family: look.mono
                font.pixelSize: 12
              }
              Text {
                text: look.shortLabel(modeItem.modelData.id).toUpperCase()
                textFormat: Text.PlainText
                color: itemMouse.containsMouse ? look.pal.text : look.pal.muted
                font.family: look.sans
                font.pixelSize: 12
                font.letterSpacing: 1.2
              }
            }
            MouseArea {
              id: itemMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: look.hoverMode(modeItem.modelData.id, containsMouse)
              onClicked: look.pickMode(modeItem.modelData.id)
            }
          }
        }
      }

      StyleChips {
        id: chips
        ui: look.ui
        x: 22
        y: header.y + header.height + 12
        width: parent.width - 44
        visible: shown && !!look.ui && (look.ui.mode === "apps" || look.ui.slashFilter)
        fontFamily: look.sans
        size: 12
        itemHeight: 24
        itemPadding: 9
        radius: 5
        hoverFill: look.pal.surface
        activeFill: look.pal.surface
        textColor: look.pal.muted
        activeTextColor: look.pal.accent
        onPicked: function(id) { look.ui.pickChip(id) }
      }

      StyleBody {
        id: body
        ui: look.ui
        x: 12
        y: header.y + header.height + 14 + (chips.visible ? chips.height + 8 : 0)
        width: parent.width - 24
        height: footer.y - y - 8
        visible: look.expanded
        spacing: 2
        emptyFont: look.sans
        emptyColor: look.pal.muted

        rowDelegate: Component {
          StyleRow {
            ui: look.ui
            fontFamily: look.sans
            rowHeight: 44
            radius: 6
            padding: 10
            gap: 12
            iconSize: 26
            titleSize: 14
            selectedTitleWeight: Font.Medium
            subtitleSize: 11
            titleColor: look.pal.text
            subtitleColor: look.pal.muted
            selectedFill: look.pal.surface
            barColor: look.pal.accent
            barWidth: 3
            controlFill: look.pal.surface
            controlHover: look.pal.border
          }
        }

        tileDelegate: Component {
          StyleTile {
            ui: look.ui
            fontFamily: look.sans
            radius: 8
            iconSize: 44
            titleSize: 12
            lines: look.ui && look.ui.mode === "files" ? 2 : 1
            titleColor: look.pal.text
            selectedFill: look.pal.surface
          }
        }

        sectionDelegate: Component {
          StyleSection {
            ui: look.ui
            fontFamily: look.mono
            size: 10
            weight: Font.Normal
            upper: true
            tracking: 1.4
            color: look.pal.faint
            inset: 10
            sectionHeight: 30
            pickable: !!look.ui && look.ui.mode === "all" && look.ui.scope === ""
          }
        }

        gridHeader: Component {
          StyleGridHeader {
            ui: look.ui
            fontFamily: look.mono
            size: 10
            weight: Font.Normal
            upper: true
            tracking: 1.4
            color: look.pal.faint
            rule: "transparent"
            inset: 10
          }
        }

        welcome: Component {
          StyleWelcome {
            ui: look.ui
            fontFamily: look.sans
            keyFont: look.mono
            titleColor: look.pal.text
            textColor: look.pal.textSoft
            faintColor: look.pal.faint
            keyFill: look.pal.surface
            keyBorder: look.pal.border
            keyText: look.pal.muted
            keyRadius: 4
            buttonFill: look.pal.accent
            buttonHover: look.pal.accentDeep
            buttonText: look.pal.onAccent
            buttonRadius: 6
            sidePadding: 10
          }
        }
      }

      Item {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        height: 42
        Rectangle { width: parent.width; height: 1; color: look.pal.border }
        Row {
          x: 22
          anchors.verticalCenter: parent.verticalCenter
          spacing: 16
          Repeater {
            model: ["↑↓ move", "↵ open", "⌃1–4 views", "esc close"]
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
      }
    }

    StyleToast {
      id: toast
      anchors.horizontalCenter: parent.horizontalCenter
      y: 96
      radius: 6
      fontFamily: look.sans
      color: look.pal.accent
      textColor: look.pal.onAccent
    }
  }
}
