import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Frosted (design 3a, "Frosted glass"): heavy blur tinted with the palette's
// surface, an inner highlight along the top, and a soft glow under the
// selected row. With nothing typed, the four views wait as round buttons at
// the end of the field.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool idle: !!ui && ui.opened && ui.collapsedMain && !ui.showOnboarding
  readonly property real maxBody: 430
  readonly property color glassText: pal.textBright
  readonly property color glassSoft: Palette.a(pal.text, 0.6)

  gridColumns: 5
  gridGap: 4
  gridTileWidth: (body.width - gridGap * (gridColumns - 1)) / gridColumns
  gridTileHeight: ui && ui.mode === "files" ? 116 : 100
  gridHeaderHeight: 32

  function reveal(index) { body.reveal(index) }
  function flashCopied() { toast.flash() }

  StyleCard {
    id: card
    ui: look.ui
    width: 580
    height: panel.height
    tallest: 20 + 56 + 6 + 34 + look.maxBody
    entrance: "rise"

    RectangularShadow {
      anchors.fill: panel
      radius: panel.radius
      offset: Qt.vector2d(0, 34)
      blur: 70
      spread: -12
      color: Palette.a("#000000", look.pal.dark ? 0.5 : 0.25)
    }

    Glass {
      id: panel
      width: parent.width
      height: 10 + header.height + (look.expanded ? 6 + (chips.shown ? chips.height + 8 : 0) + body.height : 0) + 10
      radius: 24
      style: "frosted"
      dark: look.pal.dark
      shadow: false
      backdrop: look.ui ? look.ui.backdrop : null
      backdropSpace: look.ui ? look.ui.stageItem : null
      frost: 1.6
      tintColor: look.pal.surface
      tintAlpha: look.pal.dark ? 0.5 : 0.72
      rimStrength: 0.4
      paneColor: look.pal.surface
      paneAlpha: 0.96

      Behavior on height {
        enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }

      // A hairline ring around the glass.
      Rectangle {
        anchors.fill: parent
        radius: panel.radius
        color: "transparent"
        border.width: 1
        border.color: Palette.a(look.pal.dark ? "#ffffff" : "#000000", 0.07)
      }

      Item {
        anchors.fill: parent

        Item {
          id: header
          z: 2
          x: 10
          y: 10
          width: parent.width - 20
          height: 56

          // A ring for "search", or the view you're in (a click goes back).
          Item {
            id: leading
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            readonly property var info: look.ui ? look.ui.modeInfo(look.ui.mode) : null
            Rectangle {
              anchors.centerIn: parent
              visible: !leading.info
              width: 14
              height: 14
              radius: 7
              color: "transparent"
              border.width: 2
              border.color: Palette.a(look.pal.text, 0.6)
            }
            Icon {
              anchors.centerIn: parent
              visible: !!leading.info
              width: 20
              height: 20
              name: leading.info ? leading.info.icon : "search"
              color: look.glassText
              weight: 1.9
            }
            MouseArea {
              anchors.fill: parent
              enabled: !!leading.info
              cursorShape: Qt.PointingHandCursor
              onClicked: look.pickMode("all")
            }
          }

          StyleToken {
            id: token
            ui: look.ui
            x: leading.x + leading.width + 12
            anchors.verticalCenter: parent.verticalCenter
            fontFamily: look.sans
            size: 16
            textColor: look.glassText
            fill: Palette.a(look.pal.text, 0.14)
            hoverFill: Palette.a(look.pal.text, 0.22)
          }

          StyleInput {
            id: input
            ui: look.ui
            x: token.visible ? token.x + token.width + 8 : leading.x + leading.width + 14
            anchors.verticalCenter: parent.verticalCenter
            width: trailing.x - x - 10
            height: 34
            color: look.glassText
            font.family: look.sans
            font.pixelSize: 22
            font.weight: Font.Light
            placeholder: "Search"
            placeholderColor: Palette.a(look.pal.text, 0.45)
            cursorColor: look.pal.accent
            cursorHeight: 26
            completionColor: Palette.a(look.pal.text, 0.42)
            actionColor: Palette.a(look.pal.text, 0.42)
            actionSize: 15
          }

          Row {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            StyleViewMenu {
              anchors.verticalCenter: parent.verticalCenter
              ui: look.ui
              fontFamily: look.sans
              color: look.glassSoft
              hoverFill: Palette.a(look.pal.text, 0.12)
              menuFill: Palette.a(look.pal.bg, 0.98)
              menuBorder: Palette.a(look.pal.text, 0.14)
              menuText: look.pal.text
              menuFaint: look.pal.muted
            }

            // The views, while nothing's typed.
            Repeater {
              model: look.idle ? look.modes : []
              Rectangle {
                id: modeButton
                required property var modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 17
                color: buttonMouse.containsMouse ? Palette.a(look.pal.text, 0.16) : Palette.a(look.pal.text, 0.07)
                border.width: 1
                border.color: Palette.a("#ffffff", 0.08)
                opacity: 0
                scale: 0.7
                Component.onCompleted: appear.start()
                ParallelAnimation {
                  id: appear
                  PauseAnimation { duration: modeButton.index * 30 }
                  NumberAnimation { target: modeButton; property: "opacity"; to: 1; duration: 160 }
                  NumberAnimation { target: modeButton; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                }
                Icon {
                  anchors.centerIn: parent
                  width: 18
                  height: 18
                  name: modeButton.modelData.icon
                  color: look.glassSoft
                  weight: 1.8
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

        Rectangle {
          x: 10
          y: header.y + header.height
          width: parent.width - 20
          height: 1
          color: Palette.a(look.pal.dark ? "#ffffff" : "#000000", 0.07)
          visible: look.expanded
        }

        StyleChips {
          id: chips
          ui: look.ui
          x: 16
          y: header.y + header.height + 8
          width: parent.width - 32
          visible: look.expanded && shown
          fontFamily: look.sans
          size: 12
          itemHeight: 26
          itemPadding: 12
          radius: 13
          fill: Palette.a(look.pal.text, 0.07)
          hoverFill: Palette.a(look.pal.text, 0.14)
          activeFill: Palette.a(look.pal.accent, 0.3)
          textColor: look.glassSoft
          activeTextColor: look.pal.textStrong
          onPicked: function(id) { look.ui.pickChip(id) }
        }

        StyleBody {
          id: body
          ui: look.ui
          x: 10
          y: header.y + header.height + 6 + (chips.visible ? chips.height + 8 : 0)
          width: parent.width - 20
          height: Math.min(look.maxBody, contentHeight)
          visible: look.expanded
          spacing: 4
          listBottomMargin: 0
          emptyFont: look.sans
          emptyColor: look.glassSoft

          rowDelegate: Component {
            StyleRow {
              ui: look.ui
              fontFamily: look.sans
              rowHeight: 48
              selectedRowHeight: 54
              radius: 14
              padding: 12
              iconSize: 30
              selectedIconSize: 34
              titleSize: 14
              selectedTitleSize: 15
              selectedTitleWeight: Font.Medium
              subtitleSize: 12
              titleColor: look.pal.textBright
              selectedTitleColor: look.pal.textStrong
              subtitleColor: Palette.a(look.pal.text, 0.58)
              selectedSubtitleColor: Palette.a(look.pal.textStrong, 0.62)
              selectedFill: Palette.a(look.pal.accent, 0.22)
              highlightColor: Palette.a("#ffffff", 0.12)
              glowColor: Palette.a(look.pal.accent, 0.25)
              glowSize: 28
              hint: action + " ↵"
              hintColor: Palette.a(look.pal.textStrong, 0.6)
              hintSize: 12
            }
          }

          tileDelegate: Component {
            StyleTile {
              ui: look.ui
              fontFamily: look.sans
              radius: 14
              iconSize: 48
              titleSize: 12
              lines: look.ui && look.ui.mode === "files" ? 2 : 1
              titleColor: look.pal.textBright
              selectedTitleColor: look.pal.textStrong
              selectedFill: Palette.a(look.pal.accent, 0.22)
              glowColor: Palette.a(look.pal.accent, 0.2)
            }
          }

          sectionDelegate: Component {
            StyleSection {
              ui: look.ui
              fontFamily: look.sans
              size: 12
              color: look.glassSoft
              rule: Palette.a(look.pal.dark ? "#ffffff" : "#000000", 0.07)
              sectionHeight: 32
            }
          }

          gridHeader: Component {
            StyleGridHeader {
              ui: look.ui
              fontFamily: look.sans
              size: 12
              color: look.glassSoft
              rule: Palette.a(look.pal.dark ? "#ffffff" : "#000000", 0.07)
            }
          }

          welcome: Component {
            StyleWelcome {
              ui: look.ui
              fontFamily: look.sans
              titleColor: look.pal.textBright
              textColor: look.glassSoft
              faintColor: Palette.a(look.pal.text, 0.45)
              keyFill: Palette.a(look.pal.text, 0.08)
              keyBorder: Palette.a(look.pal.text, 0.12)
              buttonFill: Palette.a(look.pal.accent, 0.22)
              buttonHover: Palette.a(look.pal.accent, 0.32)
              buttonText: look.pal.textStrong
              sidePadding: 16
            }
          }
        }
      }
    }

    StyleToast {
      id: toast
      anchors.horizontalCenter: panel.horizontalCenter
      y: header.height + 30
      fontFamily: look.sans
      color: Palette.a(look.pal.bgInner, 0.9)
      textColor: look.pal.textStrong
    }
  }
}
