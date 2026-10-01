import QtQuick
import QtQuick.Shapes
import ".."
import "../Palette.js" as Palette

// Terminal (designs 1a and 2a): fzf in a box-drawn frame, all monospace. A
// "❯" prompt and a block cursor; the kinds found as a filter line; rows as
// columns (a marker, what it is, the name and where it's from); the keys
// along the bottom. With nothing typed, the views as bracketed keys.
StyleBase {
  id: look
  field: input
  card: card

  readonly property bool typed: !!ui && ui.query.trim() !== ""
  readonly property bool expanded: !!ui && (ui.hasRows || ui.emptyShown || ui.showOnboarding || ui.slashFilter)
  readonly property bool idle: !!ui && ui.collapsedMain && !ui.showOnboarding
  readonly property real maxBody: 400

  // Short words, the way a terminal would put them.
  function kindWord(r) {
    if (r.kind === "answer") return r.detail === "Calculator" ? "calc" : "conv"
    if (r.kind === "web") return "web"
    if (r.source === "app") return "app"
    if (r.source === "omarchy" || r.source === "panel") return "set"
    if (r.source === "theme") return "theme"
    if (r.source === "clipboard") return "clip"
    if (r.source === "file") {
      var words = { folders: "dir", documents: "doc", pdf: "pdf", spreadsheets: "sheet", presentations: "slide",
        images: "img", movies: "video", music: "audio", developer: "dev", archives: "zip" }
      return words[r.section] || "file"
    }
    return "item"
  }
  readonly property var filterWords: ({
    apps: "apps", omarchy: "omarchy", themes: "themes", folders: "folders", documents: "docs", pdf: "pdf",
    spreadsheets: "sheets", presentations: "slides", images: "images", movies: "movies", music: "music",
    developer: "dev", archives: "archives", other: "other"
  })
  // "all" and the kinds found; Applications' categories; nothing otherwise.
  readonly property var filters: {
    if (!ui || !ui.engine) return []
    if (ui.mode === "apps") return [{ id: "", title: "all" }].concat(ui.engine.appCategories.map(function(c) { return { id: c.id, title: c.title.toLowerCase() } }))
    if (ui.mode !== "all" || !typed || ui.slashFilter) return ui.slashFilter ? ui.chipItems.map(function(k) { return { id: k.id, title: look.filterWords[k.id] || k.title.toLowerCase() } }) : []
    var kinds = ui.engine.kinds
    if (kinds.length < 2 && ui.scope === "") return []
    return [{ id: "", title: "all" }].concat(kinds.map(function(k) { return { id: k.id, title: look.filterWords[k.id] || k.title.toLowerCase() } }))
  }
  readonly property string activeFilter: !ui ? "" : ui.mode === "apps" && ui.engine ? ui.engine.appCategory : ui.scope
  function pickFilter(id) {
    if (ui.mode === "apps") ui.engine.setAppCategory(id)
    else if (id === "") ui.engine.setScope("")
    else ui.pickScope(id)
    ui.field.forceActiveFocus()
  }

  // What Return does to the selected row, lowercase.
  readonly property string enterWord: {
    if (!ui || ui.selectedIndex < 0 || ui.selectedIndex >= ui.resultsModel.count) return "open"
    ui.resultCount
    return String(ui.resultsModel.get(ui.selectedIndex).action || "Open").toLowerCase()
  }

  function reveal(index) { body.reveal(index) }
  function flashCopied() { toast.flash() }

  // A dashed rule, box-drawing style.
  component Dashes: Shape {
    id: dashes
    property color color: "gray"
    height: 1
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: dashes.color
      strokeWidth: 1
      strokeStyle: ShapePath.DashLine
      dashPattern: [4, 3]
      startX: 0
      startY: 0.5
      PathLine { x: dashes.width; y: 0.5 }
    }
  }

  StyleCard {
    id: card
    ui: look.ui
    width: 620
    height: frame.height
    tallest: 60 + 24 + look.maxBody + 32
    entrance: "fade"

    Rectangle {
      id: frame
      width: parent.width
      height: prompt.height + (look.expanded ? filterRow.height + body.height + 16 + footer.height : modeRow.height)
      color: look.pal.bg
      border.width: 1
      border.color: look.pal.accent

      // ┤ launch ├ and the count, over the top border.
      Rectangle {
        x: 16
        y: -9
        width: title.implicitWidth + 12
        height: 18
        color: look.pal.bg
        Text {
          id: title
          anchors.centerIn: parent
          text: "┤ launch ├"
          textFormat: Text.PlainText
          color: look.pal.accent
          font.family: look.mono
          font.pixelSize: 12
        }
      }
      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: -9
        visible: look.typed && !!look.ui && look.ui.mode === "all"
        width: count.implicitWidth + 12
        height: 18
        color: look.pal.bg
        Text {
          id: count
          anchors.centerIn: parent
          text: look.ui ? look.ui.resultCount + "/" + look.ui.indexedCount : ""
          textFormat: Text.PlainText
          color: look.pal.muted
          font.family: look.mono
          font.pixelSize: 12
        }
      }

      // ❯ the prompt.
      Item {
        id: prompt
        z: 2
        width: parent.width
        height: 48
        Text {
          id: chevron
          x: 16
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: 3
          text: look.ui && look.ui.mode !== "all" ? look.shortLabel(look.ui.mode).toLowerCase() + " ❯" : "❯"
          textFormat: Text.PlainText
          color: look.pal.accent2
          font.family: look.mono
          font.pixelSize: 16
          MouseArea {
            anchors.fill: parent
            enabled: !!look.ui && look.ui.mode !== "all"
            cursorShape: Qt.PointingHandCursor
            onClicked: look.pickMode("all")
          }
        }
        StyleToken {
          id: token
          ui: look.ui
          x: chevron.x + chevron.implicitWidth + 10
          anchors.verticalCenter: chevron.verticalCenter
          fontFamily: look.mono
          size: 13
          radius: 0
          textColor: look.pal.onAccent
          fill: look.pal.accent
          hoverFill: look.pal.accentDeep
        }
        StyleInput {
          id: input
          ui: look.ui
          namesView: false
          x: token.visible ? token.x + token.width + 10 : chevron.x + chevron.implicitWidth + 10
          anchors.verticalCenter: chevron.verticalCenter
          width: trailing.x - x - 12
          height: 24
          color: look.pal.text
          font.family: look.mono
          font.pixelSize: 16
          cursorStyle: "block"
          cursorColor: look.pal.text
          cursorHeight: 18
          placeholder: "type to search"
          placeholderColor: look.pal.faint
          completionColor: look.pal.faint
          actionColor: look.pal.faint
          actionSize: 13
          selectionColor: Palette.a(look.pal.accent, 0.35)
        }
        Row {
          id: trailing
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: chevron.verticalCenter
          // [grid] isn't a terminal's; Applications and Files list here.
        }
      }

      // ---- nothing typed: the views, as keys ----
      Item {
        id: modeRow
        y: prompt.height
        width: parent.width
        height: look.expanded ? 0 : 40
        visible: !look.expanded
        Dashes { x: 1; width: parent.width - 2; color: look.pal.borderStrong }
        Row {
          x: 16
          anchors.verticalCenter: parent.verticalCenter
          spacing: 20
          Repeater {
            model: look.modes
            Item {
              id: modeKey
              required property var modelData
              width: keyRow.implicitWidth
              height: keyRow.implicitHeight
              Row {
                id: keyRow
                Text {
                  text: "[" + modeKey.modelData.key + "]"
                  textFormat: Text.PlainText
                  color: keyMouse.containsMouse ? look.pal.accent2 : look.pal.accent
                  font.family: look.mono
                  font.pixelSize: 13
                }
                Text {
                  text: look.shortLabel(modeKey.modelData.id).toLowerCase()
                  textFormat: Text.PlainText
                  color: keyMouse.containsMouse ? look.pal.text : look.pal.textSoft
                  font.family: look.mono
                  font.pixelSize: 13
                }
              }
              MouseArea {
                id: keyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: look.hoverMode(modeKey.modelData.id, containsMouse)
                onClicked: look.pickMode(modeKey.modelData.id)
              }
            }
          }
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          text: "ctrl+key"
          textFormat: Text.PlainText
          color: look.pal.faint
          font.family: look.mono
          font.pixelSize: 13
        }
      }

      // ---- the filter line ----
      Item {
        id: filterRow
        y: prompt.height
        width: parent.width
        height: look.expanded ? (look.filters.length > 0 ? 28 : 6) : 0
        visible: look.expanded
        Row {
          x: 16
          y: 2
          spacing: 14
          Repeater {
            model: look.filters
            Rectangle {
              id: filter
              required property var modelData
              readonly property bool on: look.activeFilter === modelData.id
              width: filterText.implicitWidth + (on ? 12 : 0)
              height: 18
              color: on ? look.pal.accent : "transparent"
              Text {
                id: filterText
                anchors.centerIn: parent
                text: filter.modelData.title
                textFormat: Text.PlainText
                color: filter.on ? look.pal.onAccent : filterMouse.containsMouse ? look.pal.text : look.pal.muted
                font.family: look.mono
                font.pixelSize: 12
              }
              MouseArea {
                id: filterMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: look.pickFilter(filter.modelData.id)
              }
            }
          }
        }
        Dashes { x: 1; anchors.bottom: parent.bottom; width: parent.width - 2; color: look.pal.borderStrong }
      }

      StyleBody {
        id: body
        ui: look.ui
        x: 1
        y: filterRow.y + filterRow.height + 8
        width: parent.width - 2
        height: Math.min(look.maxBody, contentHeight)
        visible: look.expanded
        spacing: 0
        emptyFont: look.mono
        emptySize: 13
        emptyColor: look.pal.muted

        rowDelegate: Component {
          Item {
            id: termRow
            required property int index
            required property string kind
            required property string source
            required property string section
            required property string title
            required property string subtitle
            required property string folder
            required property string path
            required property string detail
            required property bool checked
            required property bool copyable
            required property string action
            readonly property bool selected: !!look.ui && look.ui.selectedIndex === index
            readonly property string where: look.ui && look.ui.showPaths && path !== "" ? path
              : subtitle + (subtitle !== "" && folder !== "" ? " · " : "") + folder
            width: ListView.view ? ListView.view.width : 0
            height: kind === "answer" ? 34 : 26

            Rectangle {
              anchors.fill: parent
              color: termRow.selected ? look.pal.surface : "transparent"
            }
            Text {
              x: 8
              anchors.verticalCenter: parent.verticalCenter
              visible: termRow.selected
              text: "▌"
              textFormat: Text.PlainText
              color: look.pal.accent
              font.family: look.mono
              font.pixelSize: 13
            }
            Text {
              x: 24
              width: 64
              anchors.verticalCenter: parent.verticalCenter
              text: look.kindWord(termRow)
              textFormat: Text.PlainText
              color: termRow.selected ? look.pal.accent : look.pal.faint
              font.family: look.mono
              font.pixelSize: 13
              elide: Text.ElideRight
            }
            Row {
              x: 88
              width: hint.x - x - 12
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8
              clip: true
              Text {
                id: name
                width: Math.min(implicitWidth, parent.width)
                text: (termRow.kind === "answer" ? "= " : "") + termRow.title
                textFormat: Text.PlainText
                color: termRow.selected ? look.pal.text : look.pal.textDim
                font.family: look.mono
                font.pixelSize: termRow.kind === "answer" ? 16 : 13
                font.weight: termRow.selected ? Font.Bold : Font.Normal
                elide: Text.ElideRight
              }
              Text {
                anchors.baseline: name.baseline
                width: Math.max(0, parent.width - name.width - 8)
                visible: width > 20 && text !== ""
                text: termRow.where + (termRow.checked ? "  ✓" : "")
                textFormat: Text.PlainText
                color: look.pal.faint
                font.family: look.mono
                font.pixelSize: 13
                elide: Text.ElideRight
              }
            }
            Text {
              id: hint
              anchors.right: parent.right
              anchors.rightMargin: 16
              anchors.verticalCenter: parent.verticalCenter
              text: termRow.selected ? "↵ " + termRow.action.toLowerCase() : termRow.detail !== "" ? termRow.detail.toLowerCase() : ""
              textFormat: Text.PlainText
              color: termRow.selected ? look.pal.muted : look.pal.faint
              font.family: look.mono
              font.pixelSize: 13
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: function(mouse) {
                var at = mapToItem(null, mouse.x, mouse.y)
                look.ui.pointerMoved(termRow.index, at.x, at.y)
              }
              onClicked: function(mouse) {
                look.ui.selectedIndex = termRow.index
                look.ui.activateSelected(mouse.modifiers & Qt.ControlModifier ? "reveal" : "open")
              }
            }
          }
        }

        sectionDelegate: Component {
          StyleSection {
            ui: look.ui
            fontFamily: look.mono
            size: 12
            weight: Font.Normal
            color: look.pal.faint
            inset: 16
            sectionHeight: 26
            upper: false
          }
        }

        welcome: Component {
          StyleWelcome {
            ui: look.ui
            fontFamily: look.mono
            keyFont: look.mono
            titleSize: 14
            textSize: 13
            smallSize: 11
            titleColor: look.pal.text
            textColor: look.pal.textSoft
            faintColor: look.pal.faint
            keyFill: "transparent"
            keyBorder: look.pal.borderStrong
            keyText: look.pal.accent
            keyRadius: 0
            buttonFill: "transparent"
            buttonHover: look.pal.surface
            buttonText: look.pal.accent
            buttonRadius: 0
            showIcons: false
            bullet: "›"
            sidePadding: 16
          }
        }
      }

      // ---- the keys ----
      Item {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        height: look.expanded ? 30 : 0
        visible: look.expanded
        Dashes { x: 1; width: parent.width - 2; color: look.pal.borderStrong }
        Row {
          x: 16
          anchors.verticalCenter: parent.verticalCenter
          spacing: 18
          Repeater {
            model: ["↵ " + look.enterWord, "^↵ reveal", "^c copy", "^1-4 views", "esc " + (look.ui && (look.ui.mode !== "all" || look.ui.scope !== "") ? "back" : "quit")]
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
      anchors.horizontalCenter: frame.horizontalCenter
      y: 58
      radius: 0
      fontFamily: look.mono
      color: look.pal.accent
      textColor: look.pal.onAccent
    }
  }
}
