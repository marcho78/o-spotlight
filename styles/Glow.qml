import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import ".."
import "../Palette.js" as Palette

// Glow edge (design 3c): a rim lit in the accent, fading round to the second
// accent, a soft glow around the whole search, and the selected row lifted
// by a bar of light at its left. With nothing typed, the four views wait at
// the end of the field.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool idle: !!ui && ui.opened && ui.collapsedMain && !ui.showOnboarding
  readonly property real maxBody: 420

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
    height: rim.height
    tallest: 64 + 1 + 40 + look.maxBody + 20
    entrance: "rise"

    RectangularShadow {
      anchors.fill: rim
      radius: 18
      blur: 50
      spread: 0
      color: Palette.a(look.pal.accent, 0.25)
    }
    RectangularShadow {
      anchors.fill: rim
      radius: 18
      offset: Qt.vector2d(0, 40)
      blur: 80
      spread: -16
      color: Palette.a("#000000", look.pal.dark ? 0.5 : 0.22)
    }

    // The lit rim: the whole search in a gradient, the panel 1px inside it.
    ClippingRectangle {
      id: rim
      width: parent.width
      height: 2 + header.height + (look.expanded ? 1 + (chips.visible ? chips.height + 10 : 0) + body.height + 16 : 0)
      radius: 18
      color: "transparent"
      Behavior on height {
        enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }

      Rectangle {
        anchors.centerIn: parent
        width: Math.hypot(parent.width, parent.height) + 20
        height: width
        rotation: -20
        gradient: Gradient {
          GradientStop { position: 0.0; color: look.pal.accent }
          GradientStop { position: 0.40; color: Palette.a(look.pal.accent, 0.1) }
          GradientStop { position: 0.70; color: Palette.a(look.pal.accent2, 0.1) }
          GradientStop { position: 1.0; color: look.pal.accent2 }
        }
      }

      Rectangle {
        id: panel
        x: 1
        y: 1
        width: parent.width - 2
        height: parent.height - 2
        radius: 17
        color: look.pal.bgInner
        clip: false

        Item {
          id: header
          z: 2
          width: parent.width
          height: 64

          Rectangle {
            anchors.fill: parent
            anchors.topMargin: 0
            radius: 17
            gradient: Gradient {
              GradientStop { position: 0; color: Palette.a(look.pal.accent, 0.08) }
              GradientStop { position: 1; color: "transparent" }
            }
          }

          StyleToken {
            id: modeToken
            ui: look.ui
            what: "mode"
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            fontFamily: look.sans
            size: 15
            textColor: look.pal.accent
            fill: Palette.a(look.pal.accent, 0.12)
            hoverFill: Palette.a(look.pal.accent, 0.2)
          }
          StyleToken {
            id: token
            ui: look.ui
            x: modeToken.visible ? modeToken.x + modeToken.width + 6 : 22
            anchors.verticalCenter: parent.verticalCenter
            fontFamily: look.sans
            size: 15
            textColor: look.pal.accent
            fill: Palette.a(look.pal.accent, 0.12)
            hoverFill: Palette.a(look.pal.accent, 0.2)
          }

          StyleInput {
            id: input
            ui: look.ui
            namesView: false
            x: token.visible ? token.x + token.width + 10 : modeToken.visible ? modeToken.x + modeToken.width + 10 : 22
            anchors.verticalCenter: parent.verticalCenter
            width: trailing.x - x - 10
            height: 34
            color: look.pal.textStrong
            font.family: look.sans
            font.pixelSize: 22
            placeholder: "Search"
            placeholderColor: look.pal.faint
            cursorColor: look.pal.accent
            cursorHeight: 26
            cursorGlow: true
            completionColor: look.pal.faint
            actionColor: look.pal.faint
            actionSize: 15
          }

          Row {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            StyleViewMenu {
              anchors.verticalCenter: parent.verticalCenter
              ui: look.ui
              fontFamily: look.sans
              color: look.pal.muted
              hoverFill: Palette.a(look.pal.accent, 0.12)
              menuFill: look.pal.bgInner
              menuBorder: Palette.a(look.pal.accent, 0.5)
              menuText: look.pal.text
              menuFaint: look.pal.muted
            }

            Repeater {
              model: look.idle ? look.modes : []
              Rectangle {
                id: modeButton
                required property var modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 10
                color: buttonMouse.containsMouse ? Palette.a(look.pal.accent, 0.12) : "transparent"
                border.width: 1
                border.color: buttonMouse.containsMouse ? look.pal.accent : look.pal.border
                opacity: 0
                Component.onCompleted: appear.start()
                SequentialAnimation {
                  id: appear
                  PauseAnimation { duration: modeButton.index * 35 }
                  NumberAnimation { target: modeButton; property: "opacity"; to: 1; duration: 180 }
                }
                Icon {
                  anchors.centerIn: parent
                  width: 18
                  height: 18
                  name: modeButton.modelData.icon
                  color: buttonMouse.containsMouse ? look.pal.accent : look.pal.muted
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

        // A line of light under the field.
        Rectangle {
          y: header.height
          width: parent.width
          height: 1
          visible: look.expanded
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Palette.a(look.pal.accent, 0.5) }
            GradientStop { position: 1; color: "transparent" }
          }
        }

        StyleChips {
          id: chips
          ui: look.ui
          x: 16
          y: header.height + 11
          width: parent.width - 32
          visible: look.expanded && shown
          fontFamily: look.sans
          size: 12
          itemHeight: 24
          itemPadding: 11
          radius: 8
          borderWidth: 1
          border: look.pal.border
          activeBorder: look.pal.accent
          hoverFill: Palette.a(look.pal.accent, 0.08)
          activeFill: Palette.a(look.pal.accent, 0.14)
          textColor: look.pal.muted
          activeTextColor: look.pal.accent
          onPicked: function(id) { look.ui.pickChip(id) }
        }

        StyleBody {
          id: body
          ui: look.ui
          x: 8
          y: header.height + 1 + 8 + (chips.visible ? chips.height + 10 : 0)
          width: parent.width - 16
          height: Math.min(look.maxBody, contentHeight)
          visible: look.expanded
          spacing: 2
          emptyFont: look.sans
          emptyColor: look.pal.muted

          rowDelegate: Component {
            StyleRow {
              ui: look.ui
              fontFamily: look.sans
              rowHeight: 48
              selectedRowHeight: 52
              radius: 10
              padding: 14
              iconSize: 30
              selectedIconSize: 32
              titleSize: 14
              selectedTitleSize: 15
              selectedTitleWeight: Font.Medium
              subtitleSize: 12
              titleColor: look.pal.text
              selectedTitleColor: look.pal.textStrong
              subtitleColor: look.pal.faint
              selectedSubtitleColor: look.pal.muted
              selectedFill: Palette.mix(look.pal.bgInner, look.pal.accent, 0.07)
              barColor: look.pal.accent
              barWidth: 2
              glowColor: Palette.a(look.pal.accent, 0.3)
              glowSize: 14
              hint: "↵"
              hintFont: look.mono
              hintSize: 11
              hintColor: look.pal.accent
            }
          }

          tileDelegate: Component {
            StyleTile {
              ui: look.ui
              fontFamily: look.sans
              radius: 10
              iconSize: 48
              titleSize: 12
              lines: look.ui && look.ui.mode === "files" ? 2 : 1
              titleColor: look.pal.text
              selectedTitleColor: look.pal.textStrong
              selectedFill: Palette.mix(look.pal.bgInner, look.pal.accent, 0.08)
              borderWidth: 1
              selectedBorder: look.pal.accent
              glowColor: Palette.a(look.pal.accent, 0.3)
            }
          }

          sectionDelegate: Component {
            StyleSection {
              ui: look.ui
              fontFamily: look.sans
              size: 12
              color: look.pal.muted
              rule: look.pal.border
              inset: 14
              sectionHeight: 32
            }
          }

          gridHeader: Component {
            StyleGridHeader {
              ui: look.ui
              fontFamily: look.sans
              size: 12
              color: look.pal.muted
              rule: look.pal.border
            }
          }

          welcome: Component {
            StyleWelcome {
              ui: look.ui
              fontFamily: look.sans
              titleColor: look.pal.textStrong
              textColor: look.pal.muted
              faintColor: look.pal.faint
              keyFill: "transparent"
              keyBorder: look.pal.border
              keyText: look.pal.accent
              keyRadius: 5
              buttonFill: Palette.a(look.pal.accent, 0.12)
              buttonHover: Palette.a(look.pal.accent, 0.22)
              buttonText: look.pal.accent
              buttonRadius: 8
              sidePadding: 16
            }
          }
        }
      }
    }

    StyleToast {
      anchors.horizontalCenter: rim.horizontalCenter
      y: 80
      id: toast
      fontFamily: look.sans
      color: look.pal.bgInner
      border.width: 1
      border.color: look.pal.accent
      textColor: look.pal.accent
    }
  }
}
