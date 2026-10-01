import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Layered (design 3d): the field and the results float as separate sheets,
// the field a light sheet on dark (dark on light), the results frosted
// under it. The selected row lifts off the results in the field's color.
// "All ▾" in the field picks a view, or narrows the results to one kind.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool typed: !!ui && ui.query.trim() !== ""
  readonly property real maxBody: 420
  readonly property color onSheet: pal.onInverse
  readonly property color onSheetSoft: Palette.mix(pal.onInverse, pal.inverse, 0.45)

  // "All", the view, or the kind the results are narrowed to.
  readonly property string scopeLabel: !ui ? "All"
    : ui.scope !== "" && ui.engine ? ui.engine.scopeTitle
    : ui.mode !== "all" ? shortLabel(ui.mode) : "All"

  // The scope menu: the views, then (while you search) the kinds found.
  readonly property var scopeItems: {
    if (!ui) return []
    var out = [{ id: "mode:all", title: "All", on: ui.mode === "all" && ui.scope === "" }]
    ui.modes.forEach(function(m) { out.push({ id: "mode:" + m.id, title: m.label, on: ui.mode === m.id }) })
    if (ui.mode === "all" && typed && ui.engine) {
      ui.engine.kinds.forEach(function(k) { out.push({ id: "kind:" + k.id, title: k.title, on: ui.scope === k.id, kind: true }) })
    }
    return out
  }
  function pickScopeItem(id) {
    ui.popup = ""
    if (id.indexOf("mode:") === 0) {
      var mode = id.slice(5)
      if (ui.scope !== "") ui.engine.setScope("")
      ui.engine.setMode(mode)
    } else {
      ui.pickScope(id.slice(5))
    }
    ui.field.forceActiveFocus()
  }

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
    width: 540
    height: fieldSheet.height + (look.expanded ? 12 + sheet.height : 0)
    tallest: 62 + 12 + look.maxBody + 20
    entrance: "rise"

    // ---- the field's sheet ----
    RectangularShadow {
      anchors.fill: fieldSheet
      radius: 18
      offset: Qt.vector2d(0, 20)
      blur: 40
      spread: -6
      color: Palette.a("#000000", look.pal.dark ? 0.4 : 0.18)
    }
    Rectangle {
      id: fieldSheet
      z: 3
      width: parent.width
      height: 62
      radius: 18
      color: look.pal.inverse

      StyleToken {
        id: token
        ui: look.ui
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        fontFamily: look.sans
        size: 15
        textColor: look.onSheet
        fill: Palette.a(look.onSheet, 0.08)
        hoverFill: Palette.a(look.onSheet, 0.14)
      }

      StyleInput {
        id: input
        ui: look.ui
        x: token.visible ? token.x + token.width + 8 : 22
        anchors.verticalCenter: parent.verticalCenter
        width: trailing.x - x - 12
        height: 34
        color: look.onSheet
        font.family: look.sans
        font.pixelSize: 21
        font.weight: Font.Medium
        placeholder: "Search"
        placeholderColor: Palette.a(look.onSheet, 0.4)
        cursorColor: look.pal.accentDeep
        cursorHeight: 24
        completionColor: Palette.a(look.onSheet, 0.4)
        actionColor: Palette.a(look.onSheet, 0.4)
        actionSize: 15
        selectionColor: Palette.a(look.pal.accentDeep, 0.3)
      }

      Row {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        StyleViewMenu {
          anchors.verticalCenter: parent.verticalCenter
          ui: look.ui
          fontFamily: look.sans
          color: look.onSheetSoft
          hoverFill: Palette.a(look.onSheet, 0.08)
          menuFill: look.pal.inverse
          menuBorder: Palette.a(look.onSheet, 0.12)
          menuText: look.onSheet
          menuFaint: look.onSheetSoft
          menuRadius: 12
        }

        // "All ▾": the scope menu.
        Rectangle {
          id: scopeButton
          anchors.verticalCenter: parent.verticalCenter
          width: scopeText.implicitWidth + 16
          height: 24
          radius: 6
          color: scopeMouse.containsMouse || (look.ui && look.ui.popup === "scope") ? Palette.a(look.onSheet, 0.14) : Palette.a(look.onSheet, 0.08)
          Text {
            id: scopeText
            anchors.centerIn: parent
            text: look.scopeLabel + " ▾"
            textFormat: Text.PlainText
            color: look.onSheet
            font.family: look.mono
            font.pixelSize: 11
          }
          MouseArea {
            id: scopeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: look.ui.popup = look.ui.popup === "scope" ? "" : "scope"
          }

          Rectangle {
            visible: !!look.ui && look.ui.popup === "scope"
            anchors.right: parent.right
            anchors.top: parent.bottom
            anchors.topMargin: 10
            width: 200
            height: menu.implicitHeight + 12
            radius: 12
            color: look.pal.inverse
            border.width: 1
            border.color: Palette.a(look.onSheet, 0.12)
            MouseArea { anchors.fill: parent }
            Column {
              id: menu
              x: 6
              y: 6
              width: parent.width - 12
              Repeater {
                model: look.scopeItems
                Rectangle {
                  required property var modelData
                  required property int index
                  width: menu.width
                  height: modelData.kind && index > 0 && !look.scopeItems[index - 1].kind ? 37 : 28
                  radius: 6
                  color: "transparent"
                  Rectangle {
                    visible: parent.height > 28
                    x: 8
                    y: 4
                    width: parent.width - 16
                    height: 1
                    color: Palette.a(look.onSheet, 0.12)
                  }
                  Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 28
                    radius: 6
                    color: itemMouse.containsMouse ? Palette.a(look.onSheet, 0.08) : "transparent"
                    Icon {
                      x: 8
                      anchors.verticalCenter: parent.verticalCenter
                      width: 13
                      height: 13
                      visible: parent.parent.modelData.on
                      name: "check"
                      color: look.onSheet
                      weight: 2.4
                    }
                    Text {
                      x: 28
                      anchors.verticalCenter: parent.verticalCenter
                      text: (parent.parent.modelData.kind ? "Only " : "") + parent.parent.modelData.title
                      textFormat: Text.PlainText
                      color: look.onSheet
                      font.family: look.sans
                      font.pixelSize: 14
                    }
                    MouseArea {
                      id: itemMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: look.pickScopeItem(parent.parent.modelData.id)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // ---- the results' sheet ----
    RectangularShadow {
      anchors.fill: sheet
      radius: 18
      offset: Qt.vector2d(0, 30)
      blur: 60
      spread: -10
      color: Palette.a("#000000", look.pal.dark ? 0.45 : 0.2)
      opacity: sheet.opacity
    }
    Glass {
      id: sheet
      y: fieldSheet.height + 12 + (look.expanded ? 0 : -10)
      width: parent.width
      height: 8 + (chips.visible ? chips.height + 8 : 0) + body.height + 8
      visible: opacity > 0.01
      opacity: look.expanded ? 1 : 0
      radius: 18
      style: "frosted"
      dark: look.pal.dark
      shadow: false
      backdrop: look.ui ? look.ui.backdrop : null
      backdropSpace: look.ui ? look.ui.stageItem : null
      frost: 1.2
      tintColor: look.pal.bg
      tintAlpha: 0.85
      rimStrength: 0.25
      paneColor: look.pal.bg
      paneAlpha: 0.97
      Behavior on opacity {
        enabled: !!look.ui && !look.ui.reduceMotion
        NumberAnimation { duration: 160 }
      }
      Behavior on y {
        enabled: !!look.ui && !look.ui.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }
      Behavior on height {
        enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }

      Rectangle {
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.width: 1
        border.color: Palette.a(look.pal.dark ? "#ffffff" : "#000000", 0.06)
      }

      StyleChips {
        id: chips
        ui: look.ui
        x: 14
        y: 12
        width: parent.width - 28
        visible: shown && look.ui && look.ui.mode === "apps"
        fontFamily: look.sans
        size: 12
        itemHeight: 26
        radius: 13
        fill: Palette.a(look.pal.text, 0.07)
        hoverFill: Palette.a(look.pal.text, 0.14)
        activeFill: look.pal.inverse
        textColor: look.pal.muted
        activeTextColor: look.onSheet
        onPicked: function(id) { look.ui.pickChip(id) }
      }

      StyleBody {
        id: body
        ui: look.ui
        x: 8
        y: 8 + (chips.visible ? chips.height + 8 : 0)
        width: parent.width - 16
        height: Math.min(look.maxBody, contentHeight)
        spacing: 2
        emptyFont: look.sans
        emptyColor: look.pal.muted

        rowDelegate: Component {
          StyleRow {
            ui: look.ui
            fontFamily: look.sans
            rowHeight: 48
            selectedRowHeight: 52
            radius: 12
            padding: 12
            iconSize: 30
            selectedIconSize: 32
            titleSize: 14
            selectedTitleSize: 15
            selectedTitleWeight: Font.DemiBold
            subtitleSize: 12
            subtitleMode: "trailing"
            titleColor: look.pal.textBright
            selectedTitleColor: look.onSheet
            subtitleColor: look.pal.muted
            selectedSubtitleColor: look.onSheetSoft
            selectedFill: look.pal.inverse
            selectedScale: 1.02
            shadowColor: Palette.a("#000000", 0.35)
            controlFill: Palette.a(look.pal.text, 0.1)
            controlHover: Palette.a(look.pal.text, 0.18)
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
            selectedTitleColor: look.onSheet
            selectedFill: look.pal.inverse
            selectedScale: 1.03
          }
        }

        sectionDelegate: Component {
          StyleSection {
            ui: look.ui
            fontFamily: look.sans
            size: 12
            color: look.pal.muted
            rule: Palette.a(look.pal.text, 0.1)
            sectionHeight: 32
          }
        }

        gridHeader: Component {
          StyleGridHeader {
            ui: look.ui
            fontFamily: look.sans
            size: 12
            color: look.pal.muted
            rule: Palette.a(look.pal.text, 0.1)
          }
        }

        welcome: Component {
          StyleWelcome {
            ui: look.ui
            fontFamily: look.sans
            titleColor: look.pal.textBright
            textColor: look.pal.muted
            faintColor: look.pal.faint
            keyFill: Palette.a(look.pal.text, 0.07)
            keyBorder: Palette.a(look.pal.text, 0.12)
            buttonFill: look.pal.inverse
            buttonHover: Palette.mix(look.pal.inverse, look.onSheet, 0.1)
            buttonText: look.onSheet
            sidePadding: 14
          }
        }
      }
    }

    StyleToast {
      id: toast
      anchors.horizontalCenter: parent.horizontalCenter
      y: fieldSheet.height + 24
      z: 5
      fontFamily: look.sans
      color: look.pal.inverse
      textColor: look.onSheet
    }
  }
}
