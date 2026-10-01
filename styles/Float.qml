import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Float (designs 1e and 2e): no panel. The field is a pill with an accent
// ring; each result floats on its own under it, fading as the list goes
// down; the kinds found wait as keys at the bottom of the screen. With
// nothing typed, the views are keys inside the pill.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool idle: !!ui && ui.opened && ui.collapsedMain && !ui.showOnboarding
  readonly property bool typed: !!ui && ui.query.trim() !== ""
  readonly property real maxBody: 440

  gridColumns: 5
  gridGap: 8
  gridTileWidth: (body.width - gridGap * (gridColumns - 1)) / gridColumns
  gridTileHeight: ui && ui.mode === "files" ? 116 : 104
  gridHeaderHeight: 34

  function reveal(index) { body.reveal(index) }
  function flashCopied() { toast.flash() }

  StyleCard {
    id: card
    ui: look.ui
    width: look.idle ? 640 : 560
    height: pill.height + (look.expanded ? 18 + body.height : 0)
    tallest: 64 + 18 + look.maxBody
    entrance: "rise"
    Behavior on width {
      enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
      NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    RectangularShadow {
      anchors.fill: pill
      radius: pill.radius
      offset: Qt.vector2d(0, 20)
      blur: 40
      spread: -6
      color: Palette.a("#000000", look.pal.dark ? 0.5 : 0.22)
    }

    Rectangle {
      id: pill
      z: 2
      width: parent.width
      height: look.idle ? 64 : 60
      radius: height / 2
      color: look.pal.bg
      border.width: look.idle ? 1 : 2
      border.color: look.idle ? look.pal.borderStrong : look.pal.accent

      StyleToken {
        id: token
        ui: look.ui
        what: look.ui && look.ui.mode !== "all" && look.ui.scope === "" ? "mode" : "scope"
        x: 22
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
        namesView: false
        x: token.visible ? token.x + token.width + 10 : 26
        anchors.verticalCenter: parent.verticalCenter
        width: trailing.x - x - 12
        height: 32
        color: look.pal.text
        font.family: look.sans
        font.pixelSize: look.idle ? 20 : 22
        placeholder: "Search"
        placeholderColor: look.pal.faint
        cursorColor: look.pal.accent
        cursorHeight: 24
        completionColor: look.pal.faint
        actionColor: look.pal.faint
        actionSize: 15
      }
      Row {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        StyleViewMenu {
          anchors.verticalCenter: parent.verticalCenter
          ui: look.ui
          fontFamily: look.sans
          color: look.pal.muted
          hoverFill: look.pal.surface
          menuFill: look.pal.bg
          menuBorder: look.pal.borderStrong
          menuText: look.pal.text
          menuFaint: look.pal.muted
          menuRadius: 14
        }

        // The views, as keys in the pill.
        Repeater {
          model: look.idle ? look.modes : []
          Rectangle {
            id: keycap
            required property var modelData
            required property int index
            anchors.verticalCenter: parent.verticalCenter
            width: capRow.implicitWidth + 24
            height: 44
            radius: 22
            color: capMouse.containsMouse ? Palette.mix(look.pal.surface, look.pal.text, 0.06) : look.pal.surface
            opacity: 0
            Component.onCompleted: appear.start()
            SequentialAnimation {
              id: appear
              PauseAnimation { duration: keycap.index * 35 }
              NumberAnimation { target: keycap; property: "opacity"; to: 1; duration: 180 }
            }
            // The key's lower edge.
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - 16
              height: 2
              radius: 1
              color: look.pal.bgDeep
            }
            Row {
              id: capRow
              anchors.centerIn: parent
              spacing: 6
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "⌃" + keycap.modelData.key
                textFormat: Text.PlainText
                color: look.pal.accent
                font.family: look.mono
                font.pixelSize: 10
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: keycap.modelData.id === "clipboard" ? "Clip" : look.shortLabel(keycap.modelData.id)
                textFormat: Text.PlainText
                color: look.pal.text
                font.family: look.sans
                font.pixelSize: 13
              }
            }
            MouseArea {
              id: capMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: look.hoverMode(keycap.modelData.id, containsMouse)
              onClicked: look.pickMode(keycap.modelData.id)
            }
          }
        }
      }
    }

    StyleBody {
      id: body
      ui: look.ui
      y: pill.height + 18
      width: parent.width
      height: Math.min(look.maxBody, contentHeight)
      visible: look.expanded
      spacing: 8
      emptyFont: look.sans
      emptyColor: look.pal.muted

      rowDelegate: Component {
        StyleRow {
          ui: look.ui
          fontFamily: look.sans
          rowHeight: 44
          selectedRowHeight: 48
          radius: height / 2
          padding: 8
          gap: 12
          iconSize: 28
          selectedIconSize: 32
          roundIcons: true
          titleSize: 14
          selectedTitleSize: 15
          selectedTitleWeight: Font.DemiBold
          subtitleSize: 12
          subtitleMode: "inline"
          titleColor: look.pal.text
          subtitleColor: look.pal.muted
          fill: Palette.a(look.pal.bg, 0.92)
          selectedFill: look.pal.surface
          // Search results fade down the list (from the one selected);
          // a browse view's long list doesn't.
          rowOpacity: selected || !look.ui || look.ui.mode !== "all" ? 1
            : Math.max(0.35, 1 - Math.max(0, index - look.ui.selectedIndex) * 0.13)
          hint: "↵"
          hintStyle: "pill"
          hintFont: look.mono
          hintSize: 11
          hintFill: look.pal.accent
          hintColor: look.pal.onAccent
          controlFill: look.pal.surface
          controlHover: look.pal.border
        }
      }

      tileDelegate: Component {
        StyleTile {
          ui: look.ui
          fontFamily: look.sans
          radius: 22
          iconSize: 48
          titleSize: 12
          lines: look.ui && look.ui.mode === "files" ? 2 : 1
          titleColor: look.pal.text
          fill: Palette.a(look.pal.bg, 0.92)
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
          color: look.pal.textSoft
          inset: 18
          sectionHeight: 30
        }
      }

      gridHeader: Component {
        StyleGridHeader {
          ui: look.ui
          fontFamily: look.mono
          size: 11
          weight: Font.Normal
          color: look.pal.textSoft
          rule: "transparent"
          inset: 18
        }
      }

      welcome: Component {
        Rectangle {
          width: body.width
          implicitHeight: welcomeText.implicitHeight
          radius: 24
          color: Palette.a(look.pal.bg, 0.94)
          StyleWelcome {
            id: welcomeText
            width: parent.width
            ui: look.ui
            fontFamily: look.sans
            keyFont: look.mono
            titleColor: look.pal.text
            textColor: look.pal.textSoft
            faintColor: look.pal.faint
            keyFill: look.pal.surface
            keyBorder: look.pal.borderStrong
            keyText: look.pal.accent
            keyRadius: 4
            buttonFill: look.pal.accent
            buttonHover: look.pal.accentDeep
            buttonText: look.pal.onAccent
            sidePadding: 24
            topPadding: 18
            bottomPadding: 18
          }
        }
      }
    }

    StyleToast {
      id: toast
      anchors.horizontalCenter: pill.horizontalCenter
      y: pill.height + 12
      fontFamily: look.sans
      color: look.pal.accent
      textColor: look.pal.onAccent
    }
  }

  // The kinds found, as keys at the bottom of the screen.
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 24
    spacing: 8
    visible: opacity > 0.01
    opacity: !!look.ui && look.ui.revealed && look.expanded && look.ui.mode === "all" ? look.ui.progress : 0
    Repeater {
      model: look.ui ? look.ui.chipItems : []
      Rectangle {
        id: kindKey
        required property var modelData
        width: kindText.implicitWidth + 16
        height: 22
        radius: 4
        color: kindMouse.containsMouse ? look.pal.surface : Palette.a(look.pal.bg, 0.85)
        border.width: 1
        border.color: look.pal.borderStrong
        Text {
          id: kindText
          anchors.centerIn: parent
          text: kindKey.modelData.title.toLowerCase()
          textFormat: Text.PlainText
          color: kindMouse.containsMouse ? look.pal.text : look.pal.muted
          font.family: look.mono
          font.pixelSize: 11
        }
        MouseArea {
          id: kindMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: look.ui.pickChip(kindKey.modelData.id)
        }
      }
    }
  }
}
