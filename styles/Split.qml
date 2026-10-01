import QtQuick
import QtQuick.Effects
import ".."
import "../Palette.js" as Palette

// Split preview (designs 1c and 2d): the results on the left, the selected
// one on the right with what it is, where, when you last opened it, and
// what you can do with it (each with its key). The views sit on top of the
// window as folder tabs.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool typed: !!ui && ui.query.trim() !== ""
  readonly property real windowHeight: 440

  // The selected row, as the model has it now.
  readonly property var current: {
    if (!ui) return null
    ui.resultCount
    var i = ui.selectedIndex
    return i >= 0 && i < ui.resultsModel.count ? ui.resultsModel.get(i) : null
  }

  // What the preview says about a result: [label, value] pairs.
  function details(r) {
    if (!r) return []
    var parts = String(r.subtitle || "").split(" · ")
    var out = []
    if (r.kind === "answer") {
      out.push(["Type", r.detail || "Calculator"])
      out.push(["Expression", String(r.subtitle).replace(/ =$/, "")])
    } else if (r.kind === "web") {
      out.push(["Type", "Web search"])
      out.push(["With", r.subtitle])
    } else if (r.source === "app") {
      out.push(["Type", "Application"])
    } else if (r.source === "omarchy") {
      out.push(["Type", "Omarchy action"])
      if (parts.length > 1) out.push(["Menu", parts.slice(1).join(" · ")])
    } else if (r.source === "panel") {
      out.push(["Type", "Top bar panel"])
    } else if (r.source === "theme") {
      out.push(["Type", "Omarchy theme"])
      if (r.checked) out.push(["Now", "Current theme"])
    } else if (r.source === "file") {
      out.push(["Kind", parts[0] || "File"])
      if (parts.length > 2) {
        out.push(["Size", parts[1]])
        out.push(["Modified", parts[2]])
      } else if (parts.length > 1) {
        out.push(["Modified", parts[1]])
      }
      if (r.path) out.push(["Where", r.path])
    } else if (r.source === "clipboard") {
      out.push(["Type", parts[0] || "Clipboard"])
      if (parts.length > 1) out.push(["", parts.slice(1).join(" · ")])
    }
    var when = ui && ui.engine && r.key ? ui.engine.lastOpened(r.key) : 0
    if (when > 0) out.push(["Last opened", ui.engine.whenText(when)])
    return out
  }

  // What you can do with it, and the keys.
  function actions(r) {
    if (!r) return []
    var out = [{ label: r.action || "Open", key: "↵", how: "open" }]
    if (r.source === "file") out.push({ label: "Show in Files", key: "ctrl ↵", how: "reveal" })
    if (r.source === "file") out.push({ label: "Copy path", key: "ctrl c", how: "copy" })
    else if (r.kind === "answer" || r.source === "clipboard") { if (r.action !== "Copy") out.push({ label: "Copy", key: "ctrl c", how: "copy" }) }
    else if (r.kind !== "web") out.push({ label: "Copy name", key: "ctrl c", how: "copy" })
    if (ui && ui.mode === "all" && typed && r.kind !== "web") out.push({ label: "Search the web", key: "ctrl b", how: "web" })
    return out
  }
  function run(how) {
    if (how === "web") {
      if (ui.service && ui.service.searchWeb(ui.field.text)) ui.requestClose()
      return
    }
    ui.activateSelected(how)
  }

  // The tabs: everything, and the views.
  readonly property var tabs: !ui ? [] : [{ id: "all", title: "All" }].concat(ui.modes.map(function(m) { return { id: m.id, title: look.shortLabel(m.id) } }))

  function reveal(index) { body.reveal(index) }
  function flashCopied() { toast.flash() }

  StyleCard {
    id: card
    ui: look.ui
    width: 760
    height: tabsRow.height + windowFrame.height
    tallest: 34 + look.windowHeight
    entrance: "rise"

    // ---- the folder tabs ----
    Row {
      id: tabsRow
      x: 12
      height: 34
      spacing: 2
      Repeater {
        model: look.tabs
        Rectangle {
          id: tab
          required property var modelData
          readonly property bool on: !!look.ui && look.ui.mode === modelData.id
          width: tabText.implicitWidth + 32
          height: tabsRow.height
          radius: 8
          color: on ? look.pal.bg : tabMouse.containsMouse ? look.pal.surfaceLow : look.pal.bgDeep
          // Square at the bottom, so it joins the window.
          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 8
            color: parent.color
          }
          Rectangle {
            width: parent.width
            height: 2
            radius: 1
            color: look.pal.accent
            visible: tab.on
          }
          Text {
            id: tabText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            text: tab.modelData.title
            textFormat: Text.PlainText
            color: tab.on ? look.pal.text : look.pal.muted
            font.family: look.sans
            font.pixelSize: 13
            font.weight: tab.on ? Font.Medium : Font.Normal
          }
          MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (tab.modelData.id !== "all") look.hoverMode(tab.modelData.id, containsMouse)
            onClicked: {
              if (look.ui.scope !== "") look.ui.engine.setScope("")
              look.ui.engine.setMode(tab.modelData.id)
              look.ui.field.forceActiveFocus()
            }
          }
        }
      }
    }

    RectangularShadow {
      anchors.fill: windowFrame
      radius: 6
      offset: Qt.vector2d(0, 30)
      blur: 60
      spread: -10
      color: Palette.a("#000000", look.pal.dark ? 0.5 : 0.22)
    }

    Rectangle {
      id: windowFrame
      y: tabsRow.height
      width: parent.width
      height: look.expanded ? look.windowHeight : header.height + 2
      radius: 8
      color: look.pal.bg
      border.width: 1
      border.color: look.pal.border
      Behavior on height {
        enabled: !!look.ui && look.ui.revealed && !look.ui.reduceMotion
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }

      Item {
        id: header
        z: 2
        x: 1
        y: 1
        width: parent.width - 2
        height: 58

        Rectangle {
          id: ring
          x: 20
          anchors.verticalCenter: parent.verticalCenter
          width: 12
          height: 12
          radius: 6
          color: "transparent"
          border.width: 2
          border.color: look.pal.muted
        }
        StyleToken {
          id: token
          ui: look.ui
          x: ring.x + ring.width + 12
          anchors.verticalCenter: parent.verticalCenter
          fontFamily: look.sans
          size: 14
          textColor: look.pal.onAccent
          fill: look.pal.accent
          hoverFill: look.pal.accentDeep
        }
        StyleInput {
          id: input
          ui: look.ui
          x: token.visible ? token.x + token.width + 8 : ring.x + ring.width + 12
          anchors.verticalCenter: parent.verticalCenter
          width: trailing.x - x - 16
          height: 30
          color: look.pal.text
          font.family: look.sans
          font.pixelSize: 18
          placeholder: "Search everything"
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
          StyleChips {
            anchors.verticalCenter: parent.verticalCenter
            ui: look.ui
            width: Math.min(implicitWidth, 300)
            fontFamily: look.sans
            size: 12
            itemHeight: 22
            itemPadding: 8
            spacing: 2
            radius: 4
            hoverFill: look.pal.surface
            activeFill: look.pal.surface
            textColor: look.pal.muted
            activeTextColor: look.pal.accent
            onPicked: function(id) { look.ui.pickChip(id) }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !look.typed && !!look.ui && look.ui.mode === "all"
            text: "ctrl 1–4 switch"
            textFormat: Text.PlainText
            color: look.pal.muted
            font.family: look.mono
            font.pixelSize: 11
          }
        }
      }

      Rectangle {
        x: 1
        y: header.y + header.height
        width: parent.width - 2
        height: 1
        color: look.pal.border
        visible: look.expanded
      }

      // ---- the list ----
      StyleBody {
        id: body
        ui: look.ui
        x: 9
        y: header.y + header.height + 9
        width: look.ui && look.ui.showOnboarding ? parent.width - 18 : 312
        height: parent.height - y - 9
        visible: look.expanded
        spacing: 2
        emptyFont: look.sans
        emptyColor: look.pal.muted

        rowDelegate: Component {
          StyleRow {
            ui: look.ui
            fontFamily: look.sans
            rowHeight: 42
            radius: 4
            padding: 10
            gap: 10
            iconSize: 26
            titleSize: 14
            selectedTitleWeight: Font.DemiBold
            subtitleMode: "none"
            titleColor: look.pal.textDim
            selectedTitleColor: look.pal.onAccent
            subtitleColor: look.pal.muted
            selectedSubtitleColor: look.pal.onAccent
            selectedFill: look.pal.accent
            controlFill: look.pal.surface
            controlHover: look.pal.surfaceLow
          }
        }

        sectionDelegate: Component {
          StyleSection {
            ui: look.ui
            fontFamily: look.sans
            size: 11
            color: look.pal.faint
            upper: true
            tracking: 0.8
            inset: 10
            sectionHeight: 28
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
            keyRadius: 3
            buttonFill: look.pal.accent
            buttonHover: look.pal.accentDeep
            buttonText: look.pal.onAccent
            buttonRadius: 4
            sidePadding: 18
          }
        }
      }

      Rectangle {
        x: 329
        y: header.y + header.height + 1
        width: 1
        height: parent.height - y - 1
        color: look.pal.border
        visible: look.expanded && !look.ui.showOnboarding
      }

      // Nothing picked yet (a view opens with nothing selected).
      Column {
        x: 330 + (parent.width - 330 - width) / 2
        y: header.y + header.height + (parent.height - header.height - height) / 2
        width: 260
        spacing: 10
        visible: look.expanded && !look.ui.showOnboarding && !look.current && look.ui.hasRows
        Icon {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 40
          height: 40
          name: look.ui && look.ui.modeInfo(look.ui.mode) ? look.ui.modeInfo(look.ui.mode).icon : "search"
          color: look.pal.faint
          weight: 1.6
        }
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: "↑ ↓ to look through them; the one you pick shows here."
          textFormat: Text.PlainText
          color: look.pal.muted
          font.family: look.sans
          font.pixelSize: 13
        }
      }

      // ---- the preview ----
      Item {
        id: preview
        x: 330
        y: header.y + header.height + 1
        width: parent.width - x - 1
        height: parent.height - y - 1
        visible: look.expanded && !look.ui.showOnboarding && !!look.current

        Row {
          id: identity
          x: 28
          y: 28
          width: parent.width - 56
          spacing: 16
          ResultIcon {
            width: 64
            height: 64
            iconType: look.current ? look.current.iconType : ""
            iconSource: look.current ? look.current.iconSource : ""
            glyph: look.current ? look.current.glyph : ""
            glyphFont: look.current ? look.current.glyphFont : ""
            badge: look.current ? look.current.badge : "#8e8e93"
            symbol: look.current ? look.current.symbol : ""
            thumbs: look.current ? look.current.thumbs : ""
            fallbackFont: look.ui ? look.ui.glyphFont : ""
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: identity.width - 80
            spacing: 2
            Text {
              width: parent.width
              text: look.current ? look.current.title : ""
              textFormat: Text.PlainText
              color: look.pal.text
              font.family: look.sans
              font.pixelSize: 22
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              visible: text !== ""
              text: look.current ? (look.current.source === "file" ? look.current.folder : look.current.source === "app" ? "Application" : "") : ""
              textFormat: Text.PlainText
              color: look.pal.muted
              font.family: look.mono
              font.pixelSize: 13
              elide: Text.ElideMiddle
            }
          }
        }

        Grid {
          id: facts
          x: 28
          y: identity.y + identity.height + 22
          columns: 2
          columnSpacing: 12
          rowSpacing: 8
          Repeater {
            model: look.details(look.current).reduce(function(all, pair) { return all.concat(pair) }, [])
            Text {
              required property string modelData
              required property int index
              width: index % 2 === 0 ? 100 : preview.width - 56 - 112
              text: modelData
              textFormat: Text.PlainText
              color: index % 2 === 0 ? look.pal.faint : look.pal.textDim
              font.family: look.sans
              font.pixelSize: 13
              elide: Text.ElideMiddle
            }
          }
        }

        Column {
          x: 28
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 20
          width: parent.width - 56
          Rectangle { width: parent.width; height: 1; color: look.pal.border }
          Repeater {
            model: look.actions(look.current)
            Rectangle {
              id: actionRow
              required property var modelData
              width: parent.width
              height: 37
              color: actionMouse.containsMouse ? look.pal.surfaceLow : "transparent"
              Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: look.pal.border }
              Text {
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                text: actionRow.modelData.label
                textFormat: Text.PlainText
                color: look.pal.text
                font.family: look.sans
                font.pixelSize: 13
              }
              Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: keyText.implicitWidth + 12
                height: 20
                radius: 3
                color: look.pal.surface
                Text {
                  id: keyText
                  anchors.centerIn: parent
                  text: actionRow.modelData.key
                  textFormat: Text.PlainText
                  color: look.pal.muted
                  font.family: look.mono
                  font.pixelSize: 11
                }
              }
              MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: look.run(actionRow.modelData.how)
              }
            }
          }
        }
      }
    }

    StyleToast {
      id: toast
      anchors.horizontalCenter: windowFrame.horizontalCenter
      y: tabsRow.height + 70
      radius: 4
      fontFamily: look.sans
      color: look.pal.accent
      textColor: look.pal.onAccent
    }
  }
}
