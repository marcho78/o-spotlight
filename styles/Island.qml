import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Island (design 3b): a black pill that grows out of the top bar, like the
// island on a phone. A dot in the accent says it's listening; results are
// round-cornered rows inside it. The island stays black whatever the
// colors; the accent is the palette's.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool idle: !!ui && ui.opened && ui.collapsedMain && !ui.showOnboarding
  readonly property bool typed: !!ui && ui.query.trim() !== ""
  readonly property real maxBody: 440
  readonly property color ink: "#000000"
  readonly property color lift: pal.dark ? Palette.mix(pal.bg, "#ffffff", 0.03) : "#1c1d26"
  readonly property color bright: "#ffffff"
  readonly property color soft: "#d0d4e4"
  readonly property color dim: "#6b7089"

  gridColumns: 4
  gridGap: 4
  gridTileWidth: (body.width - gridGap * (gridColumns - 1)) / gridColumns
  gridTileHeight: ui && ui.mode === "files" ? 104 : 92
  gridHeaderHeight: 30

  function reveal(index) { body.reveal(index) }
  function flashCopied() { toast.flash() }

  StyleCard {
    id: card
    ui: look.ui
    dock: "island"
    width: 460
    height: pill.height
    entrance: "grow"

    RectangularShadow {
      anchors.fill: pill
      radius: 30
      offset: Qt.vector2d(0, 26)
      blur: 64
      spread: -8
      color: Palette.a("#000000", 0.6)
    }

    Rectangle {
      id: pill
      width: parent.width
      height: 8 + header.height + (look.expanded ? 2 + (chips.visible ? chips.height + 8 : 0) + body.height : 0) + 8
      radius: 30
      color: look.ink
      Behavior on height {
        enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
      }

      Item {
        id: header
        z: 2
        x: 8
        y: 8
        width: parent.width - 16
        height: 44

        // Listening.
        Rectangle {
          id: dot
          x: 14
          anchors.verticalCenter: parent.verticalCenter
          width: 8
          height: 8
          radius: 4
          color: look.pal.accent
          RectangularShadow {
            anchors.fill: parent
            radius: 4
            blur: 8
            color: look.pal.accent
            z: -1
          }
        }

        StyleToken {
          id: token
          ui: look.ui
          what: look.idle ? "scope" : (look.ui && look.ui.mode !== "all" && look.ui.scope === "" ? "mode" : "scope")
          x: dot.x + dot.width + 12
          anchors.verticalCenter: parent.verticalCenter
          fontFamily: look.sans
          size: 13
          textColor: look.bright
          fill: look.lift
          hoverFill: Palette.mix(look.lift, "#ffffff", 0.08)
        }

        StyleInput {
          id: input
          ui: look.ui
          namesView: false
          x: token.visible ? token.x + token.width + 8 : dot.x + dot.width + 12
          anchors.verticalCenter: parent.verticalCenter
          width: trailing.x - x - 10
          height: 30
          color: look.bright
          font.family: look.sans
          font.pixelSize: 16
          placeholder: "Search"
          placeholderColor: look.dim
          cursorColor: look.pal.accent
          cursorHeight: 20
          completionColor: look.dim
          actionColor: look.dim
          actionSize: 13
        }

        Row {
          id: trailing
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: look.typed && look.ui && look.ui.mode === "all"
            text: look.ui ? String(look.ui.resultCount) : ""
            textFormat: Text.PlainText
            color: look.dim
            font.family: look.mono
            font.pixelSize: 11
          }

          StyleViewMenu {
            anchors.verticalCenter: parent.verticalCenter
            ui: look.ui
            fontFamily: look.sans
            color: look.dim
            hoverFill: look.lift
            menuFill: look.ink
            menuBorder: look.lift
            menuText: look.bright
            menuFaint: look.dim
            menuRadius: 16
          }

          Repeater {
            model: look.idle ? look.modes : []
            Rectangle {
              id: modeButton
              required property var modelData
              required property int index
              anchors.verticalCenter: parent.verticalCenter
              width: 30
              height: 30
              radius: 15
              color: buttonMouse.containsMouse ? Palette.mix(look.lift, "#ffffff", 0.1) : look.lift
              scale: 0.5
              opacity: 0
              Component.onCompleted: appear.start()
              ParallelAnimation {
                id: appear
                PauseAnimation { duration: 80 + modeButton.index * 40 }
                NumberAnimation { target: modeButton; property: "opacity"; to: 1; duration: 160 }
                NumberAnimation { target: modeButton; property: "scale"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2 }
              }
              Icon {
                anchors.centerIn: parent
                width: 15
                height: 15
                name: modeButton.modelData.icon
                color: look.soft
                weight: 1.9
              }
              MouseArea {
                id: buttonMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: look.hoverMode(modeButton.modelData.id, containsMouse)
                onClicked: look.pickMode(modeButton.modelData.id)
              }
            }
          }
        }
      }

      StyleChips {
        id: chips
        ui: look.ui
        x: 20
        y: header.y + header.height + 4
        width: parent.width - 40
        visible: look.expanded && shown
        fontFamily: look.sans
        size: 12
        itemHeight: 24
        itemPadding: 11
        radius: 12
        fill: look.lift
        hoverFill: Palette.mix(look.lift, "#ffffff", 0.08)
        activeFill: look.pal.accent
        textColor: look.soft
        activeTextColor: look.pal.onAccent
        onPicked: function(id) { look.ui.pickChip(id) }
      }

      StyleBody {
        id: body
        ui: look.ui
        x: 8
        y: header.y + header.height + 2 + (chips.visible ? chips.height + 8 : 0)
        width: parent.width - 16
        height: Math.min(look.maxBody, contentHeight)
        visible: look.expanded
        spacing: 2
        emptyFont: look.sans
        emptyColor: look.dim

        rowDelegate: Component {
          StyleRow {
            ui: look.ui
            fontFamily: look.sans
            rowHeight: 44
            selectedRowHeight: 52
            radius: 22
            padding: 12
            gap: 12
            iconSize: 28
            selectedIconSize: 32
            roundIcons: true
            titleSize: 14
            selectedTitleWeight: Font.Medium
            subtitleSize: 12
            subtitleMode: "inline"
            titleColor: look.soft
            selectedTitleColor: look.bright
            subtitleColor: look.dim
            selectedSubtitleColor: look.dim
            selectedFill: look.lift
            hint: "↵"
            hintStyle: "circle"
            hintSize: 13
            hintFill: look.bright
            hintColor: look.ink
            controlFill: look.lift
            controlHover: Palette.mix(look.lift, "#ffffff", 0.1)
          }
        }

        tileDelegate: Component {
          StyleTile {
            ui: look.ui
            fontFamily: look.sans
            radius: 20
            iconSize: 44
            roundIcons: true
            titleSize: 11
            lines: look.ui && look.ui.mode === "files" ? 2 : 1
            titleColor: look.soft
            selectedTitleColor: look.bright
            selectedFill: look.lift
          }
        }

        sectionDelegate: Component {
          StyleSection {
            ui: look.ui
            fontFamily: look.sans
            size: 11
            color: look.dim
            inset: 16
            sectionHeight: 28
          }
        }

        gridHeader: Component {
          StyleGridHeader {
            ui: look.ui
            fontFamily: look.sans
            size: 11
            color: look.dim
            rule: look.lift
          }
        }

        welcome: Component {
          StyleWelcome {
            ui: look.ui
            fontFamily: look.sans
            titleSize: 16
            textSize: 13
            titleColor: look.bright
            textColor: look.soft
            faintColor: look.dim
            keyFill: look.lift
            keyBorder: look.lift
            keyText: look.soft
            keyRadius: 11
            buttonFill: look.bright
            buttonHover: look.soft
            buttonText: look.ink
            sidePadding: 16
          }
        }
      }
    }

    StyleToast {
      id: toast
      anchors.horizontalCenter: pill.horizontalCenter
      y: pill.height + 10
      fontFamily: look.sans
      color: look.ink
      textColor: look.bright
    }
  }
}
