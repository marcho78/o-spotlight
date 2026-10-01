import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Bento (design 3e): an oversized query with the Top Hit's name completing
// it in a dim color, the Top Hit as a hero card in the accent (with what
// Return does, and a second action when there is one), the other results in
// a list beside it. With nothing typed, the views are four cards.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool idle: !!ui && ui.opened && ui.collapsedMain && !ui.showOnboarding
  readonly property var hit: ui ? ui.topInfo : null
  readonly property bool heroShown: !!ui && ui.mode === "all" && !!hit && ui.hasRows && !ui.showOnboarding && !ui.gridView
  readonly property real maxBody: 330
  readonly property real heroCardHeight: Math.max(236, Math.min(300, body.contentHeight))

  // A second thing the Top Hit can do: show a file in Files, or copy.
  readonly property var secondary: !hit ? null
    : hit.source === "file" ? { label: "Show in Files", how: "reveal" }
    : hit.copyable && hit.action !== "Copy" ? { label: "Copy", how: "copy" }
    : null

  gridColumns: 6
  gridGap: 8
  gridTileWidth: (body.width - gridGap * (gridColumns - 1)) / gridColumns
  gridTileHeight: ui && ui.mode === "files" ? 118 : 104
  gridHeaderHeight: 32

  function reveal(index) { if (!(heroShown && index === 0)) body.reveal(index) }
  function flashCopied() { toast.flash() }
  function activateTop(how) {
    ui.selectedIndex = 0
    ui.activateSelected(how)
  }

  StyleCard {
    id: card
    ui: look.ui
    width: 740
    height: panel.height
    tallest: 24 + 58 + 20 + 26 + 300 + 24
    entrance: "rise"

    RectangularShadow {
      anchors.fill: panel
      radius: 28
      offset: Qt.vector2d(0, 36)
      blur: 80
      spread: -14
      color: Palette.a("#000000", look.pal.dark ? 0.5 : 0.22)
    }

    Glass {
      id: panel
      width: parent.width
      height: 24 + queryRow.height
        + (look.idle ? 20 + modeCards.height : 0)
        + (look.expanded ? 20 + (chips.visible ? chips.height + 14 : 0) + Math.max(look.heroShown ? look.heroCardHeight : 0, body.height) : 0)
        + 24
      radius: 28
      style: "frosted"
      dark: look.pal.dark
      shadow: false
      backdrop: look.ui ? look.ui.backdrop : null
      backdropSpace: look.ui ? look.ui.stageItem : null
      frost: 1.4
      tintColor: look.pal.bgInner
      tintAlpha: look.pal.dark ? 0.8 : 0.85
      rimStrength: 0.3
      paneColor: look.pal.bgInner
      paneAlpha: 0.97
      Behavior on height {
        enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
      }

      Item {
        id: queryRow
        z: 2
        x: 24
        y: 24
        width: parent.width - 48
        height: 58

        StyleToken {
          id: modeToken
          ui: look.ui
          what: "mode"
          anchors.verticalCenter: parent.verticalCenter
          fontFamily: look.sans
          size: 18
          textColor: look.pal.textStrong
          fill: Palette.a(look.pal.text, 0.1)
          hoverFill: Palette.a(look.pal.text, 0.18)
        }
        StyleToken {
          id: token
          ui: look.ui
          x: modeToken.visible ? modeToken.width + 8 : 0
          anchors.verticalCenter: parent.verticalCenter
          fontFamily: look.sans
          size: 18
          textColor: look.pal.textStrong
          fill: Palette.a(look.pal.accent, 0.25)
          hoverFill: Palette.a(look.pal.accent, 0.35)
        }

        StyleInput {
          id: input
          ui: look.ui
          namesView: false
          x: token.visible ? token.x + token.width + 12 : modeToken.visible ? modeToken.width + 12 : 0
          anchors.verticalCenter: parent.verticalCenter
          width: trailing.x - x - 12
          height: 58
          color: look.pal.textStrong
          font.family: look.sans
          font.pixelSize: 44
          font.weight: Font.DemiBold
          font.letterSpacing: -0.9
          placeholder: "Search"
          placeholderColor: look.pal.borderStrong
          cursorColor: look.pal.accent
          cursorWidth: 3
          cursorHeight: 46
          completionColor: look.pal.borderStrong
          showAction: false
        }

        Row {
          id: trailing
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          StyleViewMenu {
            ui: look.ui
            fontFamily: look.sans
            color: look.pal.muted
            hoverFill: Palette.a(look.pal.text, 0.1)
            menuFill: look.pal.bgInner
            menuBorder: Palette.a(look.pal.text, 0.12)
            menuText: look.pal.text
            menuFaint: look.pal.muted
            menuRadius: 14
          }
        }
      }

      // ---- nothing typed: the views as cards ----
      Row {
        id: modeCards
        x: 24
        y: queryRow.y + queryRow.height + 20
        width: parent.width - 48
        height: 96
        spacing: 12
        visible: look.idle
        Repeater {
          model: look.idle ? look.modes : []
          Rectangle {
            id: modeCard
            required property var modelData
            required property int index
            width: (modeCards.width - modeCards.spacing * (look.modes.length - 1)) / look.modes.length
            height: modeCards.height
            radius: 18
            color: cardMouse.containsMouse ? Palette.a(look.pal.accent, 0.16) : Palette.a(look.pal.text, 0.05)
            border.width: 1
            border.color: cardMouse.containsMouse ? Palette.a(look.pal.accent, 0.45) : Palette.a(look.pal.text, 0.07)
            opacity: 0
            Component.onCompleted: appear.start()
            SequentialAnimation {
              id: appear
              PauseAnimation { duration: modeCard.index * 40 }
              NumberAnimation { target: modeCard; property: "opacity"; to: 1; duration: 200 }
            }
            Icon {
              x: 16
              y: 16
              width: 22
              height: 22
              name: modeCard.modelData.icon
              color: look.pal.accent
              weight: 1.9
            }
            Text {
              anchors.right: parent.right
              anchors.rightMargin: 14
              y: 17
              text: "⌃" + modeCard.modelData.key
              textFormat: Text.PlainText
              color: look.pal.faint
              font.family: look.mono
              font.pixelSize: 11
            }
            Text {
              x: 16
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 14
              text: modeCard.modelData.label
              textFormat: Text.PlainText
              color: look.pal.textBright
              font.family: look.sans
              font.pixelSize: 15
              font.weight: Font.Medium
            }
            MouseArea {
              id: cardMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: look.hoverMode(modeCard.modelData.id, containsMouse)
              onClicked: look.pickMode(modeCard.modelData.id)
            }
          }
        }
      }

      // ---- results ----
      StyleChips {
        id: chips
        ui: look.ui
        x: 24
        y: queryRow.y + queryRow.height + 20
        width: parent.width - 48
        visible: look.expanded && shown
        fontFamily: look.sans
        size: 12
        itemHeight: 26
        itemPadding: 13
        radius: 13
        fill: Palette.a(look.pal.text, 0.06)
        hoverFill: Palette.a(look.pal.text, 0.12)
        activeFill: look.pal.accent
        textColor: look.pal.textSoft
        activeTextColor: look.pal.onAccent
        onPicked: function(id) { look.ui.pickChip(id) }
      }

      // The Top Hit.
      Rectangle {
        id: hero
        x: 24
        y: chips.y + (chips.visible ? chips.height + 14 : 0)
        width: 240
        height: look.heroCardHeight
        visible: look.expanded && look.heroShown
        radius: 20
        border.width: 2
        border.color: look.ui && look.ui.selectedIndex === 0 ? Palette.a(look.pal.textStrong, 0.55) : "transparent"
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0; color: look.pal.accent }
          GradientStop { position: 1; color: look.pal.accentDeep }
        }

        RectangularShadow {
          anchors.fill: parent
          z: -1
          radius: 20
          offset: Qt.vector2d(0, 20)
          blur: 40
          spread: -8
          color: Palette.a(look.pal.accent, 0.25)
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPositionChanged: function(mouse) {
            var at = mapToItem(null, mouse.x, mouse.y)
            look.ui.pointerMoved(0, at.x, at.y)
          }
          onClicked: look.activateTop("open")
        }

        Rectangle {
          x: 20
          y: 20
          width: 60
          height: 60
          radius: 16
          color: Palette.a(look.pal.bgInner, 0.9)
          ResultIcon {
            anchors.centerIn: parent
            width: 40
            height: 40
            iconType: look.hit ? look.hit.iconType : ""
            iconSource: look.hit ? look.hit.iconSource : ""
            glyph: look.hit ? look.hit.glyph : ""
            glyphFont: look.hit ? look.hit.glyphFont : ""
            badge: look.hit ? look.hit.badge : "#8e8e93"
            symbol: look.hit ? look.hit.symbol : ""
            thumbs: look.hit ? look.hit.thumbs : ""
            fallbackFont: look.ui ? look.ui.glyphFont : ""
          }
        }

        Column {
          x: 20
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 20
          width: parent.width - 40
          spacing: 12
          Column {
            width: parent.width
            Text {
              width: parent.width
              text: look.hit ? look.hit.title : ""
              textFormat: Text.PlainText
              color: look.pal.onAccent
              font.family: look.sans
              font.pixelSize: look.hit && look.hit.kind === "answer" ? 30 : 24
              font.weight: Font.DemiBold
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: look.hit ? (look.hit.subtitle || (look.hit.source === "app" ? "Application" : "")) : ""
              textFormat: Text.PlainText
              color: look.pal.onAccent
              opacity: 0.85
              font.family: look.sans
              font.pixelSize: 13
              elide: Text.ElideRight
            }
          }
          Flow {
            width: parent.width
            spacing: 6
            Rectangle {
              width: openText.implicitWidth + 24
              height: 28
              radius: 14
              color: openMouse.containsMouse ? Palette.mix(look.pal.bgInner, "#ffffff", 0.08) : look.pal.bgInner
              Text {
                id: openText
                anchors.centerIn: parent
                text: (look.hit ? look.hit.action : "Open") + " ↵"
                textFormat: Text.PlainText
                color: look.pal.textStrong
                font.family: look.sans
                font.pixelSize: 12
              }
              MouseArea {
                id: openMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: look.activateTop("open")
              }
            }
            Rectangle {
              visible: !!look.secondary
              width: secondText.implicitWidth + 24
              height: 28
              radius: 14
              color: secondMouse.containsMouse ? Palette.a(look.pal.onAccent, 0.25) : Palette.a(look.pal.onAccent, 0.15)
              Text {
                id: secondText
                anchors.centerIn: parent
                text: look.secondary ? look.secondary.label : ""
                textFormat: Text.PlainText
                color: look.pal.onAccent
                font.family: look.sans
                font.pixelSize: 12
              }
              MouseArea {
                id: secondMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: look.activateTop(look.secondary.how)
              }
            }
          }
        }
      }

      StyleBody {
        id: body
        ui: look.ui
        x: look.heroShown ? 24 + 240 + 14 : 24
        y: chips.y + (chips.visible ? chips.height + 14 : 0)
        width: parent.width - 24 - x
        height: Math.min(look.maxBody, Math.max(contentHeight, look.heroShown ? look.heroCardHeight : 0))
        visible: look.expanded
        spacing: 3
        emptyFont: look.sans
        emptyColor: look.pal.muted

        rowDelegate: Component {
          StyleRow {
            ui: look.ui
            hidden: look.heroShown && index === 0
            fontFamily: look.sans
            rowHeight: 46
            radius: 12
            padding: 12
            gap: 12
            iconSize: 28
            titleSize: 14
            selectedTitleWeight: Font.Medium
            subtitleSize: 11
            titleColor: look.pal.textBright
            selectedTitleColor: look.pal.textStrong
            subtitleColor: look.pal.muted
            selectedSubtitleColor: look.pal.textSoft
            fill: Palette.a(look.pal.text, 0.03)
            selectedFill: Palette.a(look.pal.accent, 0.2)
            hint: "↵"
            hintSize: 12
            hintColor: look.pal.accent
          }
        }

        tileDelegate: Component {
          StyleTile {
            ui: look.ui
            fontFamily: look.sans
            radius: 16
            iconSize: 48
            titleSize: 12
            lines: look.ui && look.ui.mode === "files" ? 2 : 1
            fill: Palette.a(look.pal.text, 0.03)
            titleColor: look.pal.textBright
            selectedTitleColor: look.pal.onAccent
            selectedFill: look.pal.accent
          }
        }

        sectionDelegate: Component {
          StyleSection {
            ui: look.ui
            fontFamily: look.sans
            size: 12
            color: look.pal.muted
            inset: 4
            sectionHeight: 30
          }
        }

        gridHeader: Component {
          StyleGridHeader {
            ui: look.ui
            fontFamily: look.sans
            size: 12
            color: look.pal.muted
            rule: Palette.a(look.pal.text, 0.08)
            inset: 4
          }
        }

        welcome: Component {
          StyleWelcome {
            ui: look.ui
            fontFamily: look.sans
            titleSize: 20
            titleColor: look.pal.textStrong
            textColor: look.pal.textSoft
            faintColor: look.pal.faint
            keyFill: Palette.a(look.pal.text, 0.06)
            keyBorder: Palette.a(look.pal.text, 0.1)
            buttonFill: look.pal.accent
            buttonHover: look.pal.accentDeep
            buttonText: look.pal.onAccent
            sidePadding: 4
          }
        }
      }
    }

    StyleToast {
      id: toast
      anchors.horizontalCenter: panel.horizontalCenter
      y: 110
      fontFamily: look.sans
      color: look.pal.bgInner
      textColor: look.pal.textStrong
    }
  }
}
