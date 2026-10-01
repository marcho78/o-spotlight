import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Tiles (designs 1d and 2f): icon first. The Top Hit as a card in the
// accent, the other results as tiles beside it, the kinds found as pills
// underneath. With nothing typed, the views are big tiles, gone once you
// type.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool idle: !!ui && ui.opened && ui.collapsedMain && !ui.showOnboarding
  readonly property bool typed: !!ui && ui.query.trim() !== ""
  readonly property bool heroMode: !!ui && ui.mode === "all" && typed
  readonly property bool hasTop: !!ui && !!ui.topInfo
  readonly property real maxBody: 400
  readonly property var hit: ui ? ui.topInfo : null

  gridGap: 10
  gridColumns: heroMode ? 3 : 4
  heroWidth: 200
  heroHeight: 236
  gridTileWidth: (body.width - (heroMode && hasTop ? heroWidth + gridGap : 0) - gridGap * (gridColumns - 1)) / gridColumns
  gridTileHeight: heroMode ? 108 : ui && ui.mode === "files" ? 116 : 104
  gridHeaderHeight: 34

  function reveal(index) { body.reveal(index) }
  function flashCopied() { toast.flash() }

  StyleCard {
    id: card
    ui: look.ui
    width: 660
    height: panel.height
    tallest: 20 + 50 + 18 + look.maxBody + 18 + 30 + 20
    entrance: "rise"

    RectangularShadow {
      anchors.fill: panel
      radius: 18
      offset: Qt.vector2d(0, 30)
      blur: 60
      spread: -10
      color: Palette.a("#000000", look.pal.dark ? 0.5 : 0.22)
    }

    Rectangle {
      id: panel
      width: parent.width
      height: 20 + fieldBox.height
        + (look.idle ? 16 + scopeTiles.height : 0)
        + (look.expanded ? 18 + body.height + (pills.visible ? 18 + pills.height : 0) : 0)
        + 20
      radius: 18
      color: look.pal.bg
      Behavior on height {
        enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }

      Rectangle {
        id: fieldBox
        z: 2
        x: 20
        y: 20
        width: parent.width - 40
        height: 52
        radius: 12
        color: look.pal.surface

        StyleToken {
          id: modeToken
          ui: look.ui
          what: "mode"
          x: 14
          anchors.verticalCenter: parent.verticalCenter
          fontFamily: look.sans
          size: 14
          textColor: look.pal.onAccent
          fill: look.pal.accent
          hoverFill: look.pal.accentDeep
        }
        StyleToken {
          id: token
          ui: look.ui
          x: modeToken.visible ? modeToken.x + modeToken.width + 6 : 14
          anchors.verticalCenter: parent.verticalCenter
          fontFamily: look.sans
          size: 14
          textColor: look.pal.bg
          fill: look.pal.text
          hoverFill: look.pal.textDim
        }
        StyleInput {
          id: input
          ui: look.ui
          namesView: false
          x: token.visible ? token.x + token.width + 8 : modeToken.visible ? modeToken.x + modeToken.width + 8 : 18
          anchors.verticalCenter: parent.verticalCenter
          width: trailing.x - x - 12
          height: 28
          color: look.pal.text
          font.family: look.sans
          font.pixelSize: 18
          placeholder: "Search"
          placeholderColor: look.pal.faint
          cursorColor: look.pal.accent
          cursorHeight: 22
          completionColor: look.pal.faint
          actionColor: look.pal.faint
          actionSize: 14
        }
        Row {
          id: trailing
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: look.heroMode
            text: look.ui ? look.ui.resultCount + (look.ui.resultCount === 1 ? " result" : " results") : ""
            textFormat: Text.PlainText
            color: look.pal.muted
            font.family: look.mono
            font.pixelSize: 12
          }
          StyleViewMenu {
            anchors.verticalCenter: parent.verticalCenter
            ui: look.ui
            fontFamily: look.sans
            color: look.pal.muted
            hoverFill: look.pal.surfaceLow
            menuFill: look.pal.bg
            menuBorder: look.pal.borderStrong
            menuText: look.pal.text
            menuFaint: look.pal.muted
            menuRadius: 12
          }
        }
      }

      // ---- nothing typed: the views as big tiles ----
      Row {
        id: scopeTiles
        x: 20
        y: fieldBox.y + fieldBox.height + 16
        width: parent.width - 40
        height: 76
        spacing: 10
        visible: look.idle
        Repeater {
          model: look.idle ? look.modes : []
          Rectangle {
            id: scopeTile
            required property var modelData
            required property int index
            width: (scopeTiles.width - scopeTiles.spacing * (look.modes.length - 1)) / look.modes.length
            height: scopeTiles.height
            radius: 10
            color: tileMouse.containsMouse ? look.pal.surfaceLow : "transparent"
            border.width: 1
            border.color: tileMouse.containsMouse ? look.pal.accent : look.pal.border
            opacity: 0
            Component.onCompleted: appear.start()
            SequentialAnimation {
              id: appear
              PauseAnimation { duration: scopeTile.index * 35 }
              NumberAnimation { target: scopeTile; property: "opacity"; to: 1; duration: 180 }
            }
            Text {
              x: 12
              y: 12
              text: "⌃" + scopeTile.modelData.key
              textFormat: Text.PlainText
              color: tileMouse.containsMouse ? look.pal.accent : look.pal.muted
              font.family: look.mono
              font.pixelSize: 11
            }
            Text {
              x: 12
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 12
              text: scopeTile.modelData.label
              textFormat: Text.PlainText
              color: look.pal.text
              font.family: look.sans
              font.pixelSize: 14
              font.weight: Font.Medium
            }
            MouseArea {
              id: tileMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: look.hoverMode(scopeTile.modelData.id, containsMouse)
              onClicked: look.pickMode(scopeTile.modelData.id)
            }
          }
        }
      }

      // Applications' categories, above the grid.
      StyleChips {
        id: categories
        ui: look.ui
        x: 20
        y: fieldBox.y + fieldBox.height + 14
        width: parent.width - 40
        visible: look.expanded && shown && !!look.ui && look.ui.mode === "apps"
        fontFamily: look.sans
        size: 12
        itemHeight: 28
        itemPadding: 12
        radius: 14
        borderWidth: 1
        border: look.pal.borderStrong
        activeBorder: look.pal.text
        hoverFill: look.pal.surfaceLow
        activeFill: look.pal.text
        textColor: look.pal.textSoft
        activeTextColor: look.pal.bg
        onPicked: function(id) { look.ui.pickChip(id) }
      }

      StyleBody {
        id: body
        ui: look.ui
        x: 20
        y: fieldBox.y + fieldBox.height + 18 + (categories.visible ? categories.height + 12 : 0)
        width: parent.width - 40
        height: Math.min(look.maxBody, contentHeight)
        visible: look.expanded
        spacing: 4
        emptyFont: look.sans
        emptyColor: look.pal.muted

        rowDelegate: Component {
          StyleRow {
            ui: look.ui
            fontFamily: look.sans
            rowHeight: 48
            radius: 10
            padding: 12
            iconSize: 30
            titleSize: 14
            selectedTitleWeight: Font.Medium
            subtitleSize: 12
            titleColor: look.pal.text
            subtitleColor: look.pal.muted
            fill: look.pal.surfaceLow
            selectedFill: look.pal.surface
            barColor: look.pal.accent
            barWidth: 3
            hint: action + " ↵"
            hintFont: look.mono
            hintSize: 11
            hintColor: look.pal.accent
            controlFill: look.pal.surface
            controlHover: look.pal.border
          }
        }

        tileDelegate: Component {
          StyleTile {
            ui: look.ui
            layout: "card"
            fontFamily: look.sans
            radius: 12
            padding: 12
            iconSize: 34
            titleSize: 13
            titleWeight: Font.Medium
            subtitleSize: 11
            titleColor: look.pal.text
            subtitleColor: look.pal.muted
            fill: look.pal.surfaceLow
            selectedFill: look.pal.surface
            borderWidth: 1.5
            border: "transparent"
            selectedBorder: look.pal.accent
          }
        }

        sectionDelegate: Component {
          StyleSection {
            ui: look.ui
            fontFamily: look.sans
            size: 12
            color: look.pal.muted
            inset: 2
            sectionHeight: 30
          }
        }

        gridHeader: Component {
          StyleGridHeader {
            ui: look.ui
            fontFamily: look.sans
            size: 12
            color: look.pal.muted
            rule: look.pal.border
            inset: 2
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
            keyText: look.pal.textSoft
            buttonFill: look.pal.accent
            buttonHover: look.pal.accentDeep
            buttonText: look.pal.onAccent
            buttonRadius: 14
            sidePadding: 4
          }
        }

        // The Top Hit's card, where the grid left room for it.
        Rectangle {
          id: hero
          parent: body.grid.contentItem
          readonly property var place: look.ui && look.ui.tilePositions[0] && look.ui.tilePositions[0].hero ? look.ui.tilePositions[0] : null
          readonly property bool selected: !!look.ui && look.ui.selectedIndex === 0
          visible: !!place && look.ui.gridView
          x: place ? place.x : 0
          y: place ? place.y : 0
          width: place ? place.w : 0
          height: place ? place.h : 0
          radius: 14
          color: look.pal.accent
          border.width: selected ? 0 : 0
          opacity: selected ? 1 : 0.8

          Column {
            x: 18
            y: 18
            width: parent.width - 36
            spacing: 26
            Text {
              text: "TOP HIT"
              textFormat: Text.PlainText
              color: look.pal.onAccent
              font.family: look.sans
              font.pixelSize: 11
              font.weight: Font.DemiBold
              font.letterSpacing: 0.9
            }
            Rectangle {
              width: 56
              height: 56
              radius: 14
              color: look.pal.bg
              ResultIcon {
                anchors.centerIn: parent
                width: 38
                height: 38
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
          }
          Column {
            x: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: parent.width - 36
            Text {
              width: parent.width
              text: look.hit ? look.hit.title : ""
              textFormat: Text.PlainText
              color: look.pal.onAccent
              font.family: look.sans
              font.pixelSize: 20
              font.weight: Font.DemiBold
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: "Press ↵ to " + (look.hit ? String(look.hit.action).toLowerCase() : "open")
              textFormat: Text.PlainText
              color: look.pal.onAccent
              font.family: look.sans
              font.pixelSize: 12
            }
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) {
              var at = mapToItem(null, mouse.x, mouse.y)
              look.ui.pointerMoved(0, at.x, at.y)
            }
            onClicked: {
              look.ui.selectedIndex = 0
              look.ui.activateSelected("open")
            }
          }
        }
      }

      // The kinds found, as pills.
      StyleChips {
        id: pills
        ui: look.ui
        x: 20
        y: body.y + body.height + 18
        width: parent.width - 40
        visible: look.expanded && shown && !!look.ui && look.ui.mode === "all"
        fontFamily: look.sans
        size: 12
        itemHeight: 28
        itemPadding: 12
        radius: 14
        borderWidth: 1
        border: look.pal.borderStrong
        activeBorder: look.pal.text
        hoverFill: look.pal.surfaceLow
        activeFill: look.pal.text
        textColor: look.pal.textSoft
        activeTextColor: look.pal.bg
        onPicked: function(id) { look.ui.pickChip(id) }
      }
    }

    StyleToast {
      id: toast
      anchors.horizontalCenter: panel.horizontalCenter
      y: 90
      fontFamily: look.sans
      color: look.pal.text
      textColor: look.pal.bg
    }
  }
}
