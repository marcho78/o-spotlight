import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui
import "Settings.js" as Settings
import "Web.js" as Web
import "Styles.js" as Styles
import "Palette.js" as Palette
import "styles" as Looks

// What the O-Spotlight settings window shows: a live preview of the search in
// the current settings, a page list, and the pages. SettingsWindow.qml puts
// it in a window.
Item {
  id: root

  property var service: null
  property string page: "general"

  readonly property bool ready: !!service && !!service.settings
  readonly property var settings: ready ? service.settings : ({})
  readonly property bool customized: ready && Object.keys(service.user || {}).length > 0

  function set(key, value) {
    if (ready) service.setSetting(key, value)
  }

  function toggle(key) {
    set(key, settings[key] === false)
  }

  property bool resetConfirmOpen: false
  property bool clearConfirmOpen: false

  readonly property var pages: [
    { id: "general", label: "General", glyph: "󰒓" },
    { id: "results", label: "Search Results", glyph: "󰍉" },
    { id: "look", label: "Appearance", glyph: "󰏘" },
    { id: "privacy", label: "Privacy", glyph: "󰒃" }
  ]

  readonly property var highlightChoices: [
    { value: "accent", label: "Theme", color: Color.accent },
    { value: "blue", label: "Blue", color: "#0a84ff" },
    { value: "purple", label: "Purple", color: "#bf5af2" },
    { value: "pink", label: "Pink", color: "#ff375f" },
    { value: "red", label: "Red", color: "#ff453a" },
    { value: "orange", label: "Orange", color: "#ff9f0a" },
    { value: "yellow", label: "Yellow", color: "#ffd60a" },
    { value: "green", label: "Green", color: "#32d74b" },
    { value: "graphite", label: "Graphite", color: "#98989d" }
  ]

  readonly property var engineChoices: Object.keys(Web.ENGINES).map(function(id) {
    return { value: id, label: Web.ENGINES[id].name }
  })

  // ---- the style, and its colors ----
  readonly property string styleId: Styles.info(settings.style).id
  readonly property var styleInfo: Styles.info(styleId)
  readonly property var stylePalette: ready ? service.stylePalette : Palette.build({})
  readonly property bool followTheme: settings.colors !== "custom"
  onFollowThemeChanged: if (followTheme) closePicker()
  onPageChanged: closePicker()
  onStyleIdChanged: if (styleId === "tahoe") closePicker()
  readonly property var colorRoles: [
    { key: "customBackground", label: "Background", role: "bg" },
    { key: "customSurface", label: "Surface", role: "surface" },
    { key: "customText", label: "Text", role: "text" },
    { key: "customMuted", label: "Secondary text", role: "muted" },
    { key: "customAccent", label: "Accent", role: "accent" }
  ]

  // Your own colors start from your theme's, not from the designs'.
  function setFollowTheme(on) {
    if (on) {
      set("colors", "theme")
      return
    }
    var user = service.user || {}
    var picked = colorRoles.some(function(c) { return user[c.key] !== undefined })
    if (!picked) copyThemeColors()
    set("colors", "custom")
  }
  function copyThemeColors() {
    var theme = service.themePalette
    colorRoles.forEach(function(c) { set(c.key, theme[c.role]) })
  }

  // ---- the color picker, open for one color at a time ----
  property string pickerKey: ""
  readonly property var pickerSwatches: [
    { label: "From your theme", colors: ready ? colorRoles.map(function(c) { return service.themePalette[c.role] }) : [] },
    { label: "More", colors: ["#0a84ff", "#bf5af2", "#ff375f", "#ff453a", "#ff9f0a", "#ffd60a", "#32d74b", "#98989d",
      "#7aa2f7", "#bb9af7", "#1a1b26", "#24283b", "#c0caf5", "#000000", "#ffffff"] }
  ]

  function togglePicker(key, label, chip) {
    if (pickerKey === key) {
      closePicker()
      return
    }
    pickerKey = key
    colorPicker.title = label
    colorPicker.show(settings[key])
    // Beside the chip, level with it as far as the window allows, so the
    // chip and the other colors stay in view.
    var at = chip.mapToItem(root, chip.width + 12, chip.height / 2)
    colorPicker.x = Math.max(8, Math.min(root.width - colorPicker.width - 8, at.x))
    colorPicker.y = Math.max(8, Math.min(root.height - colorPicker.height - 8, at.y - colorPicker.height / 2))
  }

  function closePicker() {
    pickerKey = ""
    colorPicker.visible = false
  }

  function shortcutProblem(text) {
    return Settings.shortcutProblem(String(text))
  }

  // "~/Work/secret" or "/home/you/Work/secret" → an absolute path, or "".
  function folderPath(text) {
    var value = String(text || "").trim()
    if (value.indexOf("~/") === 0 || value === "~") value = service.home + value.slice(1)
    var cleaned = Settings.cleanPaths([value])
    return cleaned && cleaned.length === 1 ? cleaned[0] : ""
  }

  component SectionLabel: PanelSectionHeader {
    width: parent ? parent.width : 0
    topPadding: 10
    foreground: Color.foreground
    fontFamily: Style.font.family
  }

  component Caption: Text {
    width: parent ? parent.width : 0
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: Color.foreground
    opacity: 0.55
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }

  component SettingToggle: Toggle {
    property string key: ""
    width: parent ? parent.width : 0
    checked: root.settings[key] !== false
    onClicked: root.toggle(key)
  }

  // ---- live preview: the search bar and a result, in the current settings.
  Item {
    id: hero
    width: parent.width
    height: 190
    clip: true

    readonly property bool dark: root.ready ? root.service.dark : true
    readonly property color highlight: root.ready ? root.service.highlight : Color.accent
    readonly property string uiFont: root.ready ? root.service.uiFont : Style.font.family
    readonly property real highlightLuma: 0.2126 * highlight.r + 0.7152 * highlight.g + 0.0722 * highlight.b
    readonly property color primary: dark ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(0, 0, 0, 0.86)
    readonly property color secondary: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)

    Item {
      id: heroBackdrop
      anchors.fill: parent
      Image {
        id: heroWallpaper
        anchors.fill: parent
        source: root.ready ? root.service.wallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1200
        asynchronous: true
      }
    }

    MultiEffect {
      id: heroBlurred
      anchors.fill: parent
      source: heroWallpaper
      visible: false
      blurEnabled: true
      blurMax: 64
      blur: 1
      saturation: 0.18
    }

    ShaderEffectSource {
      id: heroGlass
      sourceItem: heroBlurred
      live: true
      mipmap: true
      hideSource: false
      visible: false
    }

    // Another style: a drawing of it, in its colors.
    Looks.StylePreview {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 14
      width: 300
      height: 162
      visible: root.styleId !== "tahoe"
      backdrop: false
      styleId: root.styleId
      pal: root.stylePalette
    }

    // One piece of glass: the field, and the Top Hit under it.
    Glass {
      id: heroPanel
      visible: root.styleId === "tahoe"
      anchors.horizontalCenter: parent.horizontalCenter
      y: 30
      width: Math.min(460, parent.width - 60)
      height: 110
      radius: 20
      style: root.settings.glass || "liquid"
      dark: hero.dark
      backdrop: heroGlass
      backdropSpace: hero
      frost: 0.7
      refraction: 8

      readonly property bool accentSelection: root.settings.selection === "accent"
      // Chromium (Omarchy's browser) as the example, with its own icon, or a
      // globe where it isn't installed.
      readonly property string browserIcon: Quickshell.iconPath("chromium", true) || ""

      Icon {
        x: 14
        y: 11
        width: 17
        height: 17
        name: "search"
        color: hero.secondary
        weight: 2
      }
      Text {
        id: heroTyped
        x: 42
        y: 7
        text: "chr"
        textFormat: Text.PlainText
        color: hero.primary
        font.family: hero.uiFont
        font.pixelSize: 19
      }
      Rectangle {
        x: heroTyped.x + heroTyped.contentWidth - 2
        anchors.verticalCenter: heroTyped.verticalCenter
        width: heroRest.implicitWidth + heroOpen.implicitWidth + 12
        height: 25
        radius: 7
        color: hero.dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.72)
        Text {
          id: heroRest
          x: 2
          anchors.verticalCenter: parent.verticalCenter
          text: "omium"
          textFormat: Text.PlainText
          color: hero.primary
          font: heroTyped.font
        }
        Text {
          id: heroOpen
          x: heroRest.x + heroRest.implicitWidth
          y: heroRest.y + heroRest.baselineOffset - baselineOffset
          text: " — Open"
          textFormat: Text.PlainText
          color: hero.secondary
          font.family: hero.uiFont
          font.pixelSize: 14
        }
      }
      ResultIcon {
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 8
        width: 22
        height: 22
        iconType: heroPanel.browserIcon ? "image" : "badge"
        iconSource: heroPanel.browserIcon
        badge: "#0a84ff"
        symbol: "globe"
      }
      Rectangle {
        x: 14
        y: 39
        width: parent.width - 28
        height: 1
        color: hero.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
      }
      Rectangle {
        x: 7
        y: 48
        width: parent.width - 14
        height: 52
        radius: 13
        color: heroPanel.accentSelection ? hero.highlight : (hero.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10))
        readonly property color text: heroPanel.accentSelection ? (hero.highlightLuma > 0.6 ? Qt.rgba(0, 0, 0, 0.88) : "white") : hero.primary
        readonly property color subtext: heroPanel.accentSelection ? (hero.highlightLuma > 0.6 ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(1, 1, 1, 0.78)) : hero.secondary
        ResultIcon {
          x: 9
          anchors.verticalCenter: parent.verticalCenter
          width: 30
          height: 30
          iconType: heroPanel.browserIcon ? "image" : "badge"
          iconSource: heroPanel.browserIcon
          badge: "#0a84ff"
          symbol: "globe"
        }
        Column {
          x: 50
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: "Chromium"
            textFormat: Text.PlainText
            color: parent.parent.text
            font.family: hero.uiFont
            font.pixelSize: 14
          }
          Text {
            text: "Web Browser"
            textFormat: Text.PlainText
            color: parent.parent.subtext
            font.family: hero.uiFont
            font.pixelSize: 12
          }
        }
      }
    }

    Button {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 10
      bordered: true
      background: Qt.rgba(0, 0, 0, 0.45)
      foreground: "white"
      iconText: "󰍉"
      text: "Try it"
      enabled: root.ready
      onClicked: root.service.show({})
    }
  }

  // ---- navigation, and reset.
  Column {
    id: nav
    anchors.top: hero.bottom
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.margins: 14
    width: 180
    spacing: 4

    Repeater {
      model: root.pages
      Button {
        required property var modelData
        width: nav.width
        leftAlign: true
        iconText: modelData.glyph
        text: modelData.label
        selected: root.page === modelData.id
        onClicked: root.page = modelData.id
      }
    }
  }

  Button {
    anchors.left: nav.left
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 14
    width: nav.width
    bordered: true
    iconText: "󰑓"
    text: "Reset to default"
    enabled: root.customized
    opacity: enabled ? 1 : 0.4
    onClicked: root.resetConfirmOpen = true
  }

  Rectangle {
    anchors.top: hero.bottom
    anchors.bottom: parent.bottom
    anchors.left: nav.right
    anchors.leftMargin: 14
    width: 1
    color: Color.foreground
    opacity: 0.1
  }

  Flickable {
    id: content
    anchors.top: hero.bottom
    anchors.bottom: parent.bottom
    anchors.left: nav.right
    anchors.right: parent.right
    anchors.leftMargin: 29
    anchors.rightMargin: 22
    anchors.topMargin: 12
    anchors.bottomMargin: 12
    contentHeight: pageColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: pageColumn
      width: content.width - 12
      spacing: 10

      // Problems registering with Hyprland.
      Rectangle {
        readonly property string problem: root.ready && root.service.hyprStatus !== "" && root.service.hyprStatus !== "ok" ? root.service.hyprStatus : ""
        visible: problem !== ""
        width: parent.width
        height: problemText.implicitHeight + 20
        color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.1)
        border.width: 1
        border.color: Color.urgent
        Text {
          id: problemText
          x: 10
          y: 10
          width: parent.width - 20
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: "Hyprland didn't take O-Spotlight's shortcut: " + parent.problem.slice(0, 400)
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }

      // ---- General
      Column {
        visible: root.page === "general"
        width: parent.width
        spacing: 10

        SectionLabel { text: "Keyboard shortcut"; topPadding: 0 }
        Caption { text: "Opens and closes the search from anywhere. Your Hyprland config is never edited: O-Spotlight adds the shortcut while it runs." }
        Row {
          spacing: 8
          TextField {
            id: keysField
            width: Math.min(280, pageColumn.width - 110)
            placeholderText: "None"
            text: root.settings.shortcut || ""
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            onEditingFinished: {
              if (root.shortcutProblem(text) === "") root.set("shortcut", text.trim())
            }
          }
          Button {
            anchors.verticalCenter: parent.verticalCenter
            bordered: true
            text: "Default"
            enabled: root.ready && root.settings.shortcut !== root.service.defaults.shortcut
            opacity: enabled ? 1 : 0.4
            onClicked: root.set("shortcut", root.service.defaults.shortcut)
          }
        }
        Caption {
          visible: text !== ""
          text: root.shortcutProblem(keysField.text)
          color: Color.urgent
          opacity: 1
        }
        Repeater {
          model: root.ready ? root.service.takenBinds : []
          Caption {
            required property var modelData
            text: modelData.unknown
              ? modelData.keys + " isn't bound: O-Spotlight couldn't read Hyprland's bindings to check that it's free."
              : modelData.keys + " is already " + (modelData.usedBy ? "used for “" + modelData.usedBy + "”" : "taken") + ", so O-Spotlight didn't bind it. Pick another shortcut, or free this one in ~/.config/hypr/bindings.lua."
            color: Color.urgent
            opacity: 1
          }
        }

        SettingToggle {
          key: "barIcon"
          label: "Show O-Spotlight in the top bar"
          description: "A magnifying glass, like the one in the macOS menu bar: click to search, right-click for these settings. Turned off, the icon takes no space and O-Spotlight keeps running."
        }

        SectionLabel { text: "Position" }
        Caption { text: "Drag the search bar anywhere; it opens there next time." }
        Button {
          bordered: true
          iconText: "󰘕"
          text: "Put it back in the middle"
          enabled: root.ready && ((root.settings.offsetX || 0) !== 0 || (root.settings.offsetY || 0) !== 0)
          opacity: enabled ? 1 : 0.4
          onClicked: {
            root.set("offsetX", 0)
            root.set("offsetY", 0)
          }
        }

        SectionLabel { text: "While you search" }
        Caption {
          text: "↑ ↓ (or Tab) pick a result · Return opens it · Ctrl+Return shows a file in Files · Ctrl+C copies it · Ctrl+B searches the web · → accepts the completion · hold Ctrl to see where files are · ↑ in an empty field brings back your last searches · Esc backs out, clears, then closes.\n"
            + "Ctrl+1 Applications · Ctrl+2 Files · Ctrl+3 Actions · Ctrl+4 Clipboard · Ctrl+, these settings."
        }

        SectionLabel { text: "From a terminal or your own bindings" }
        Caption {
          text: "omarchy-shell o-spotlight toggle\n"
            + "omarchy-shell o-spotlight search \"text\"\n"
            + "omarchy-shell o-spotlight browse apps      (files, actions, clipboard)\n"
            + "omarchy-shell o-spotlight settings"
          font.family: "monospace"
        }
      }

      // ---- Search results
      Column {
        visible: root.page === "results"
        width: parent.width
        spacing: 10

        Caption { text: "What O-Spotlight searches, like the Search Results list in macOS's Spotlight settings." }

        SettingToggle { key: "apps"; label: "Applications"; description: "Every app in the Omarchy launcher." }
        SettingToggle { key: "omarchy"; label: "Omarchy"; description: "Everything in the Omarchy menu (Style, Setup, Install, Trigger, System…) and the top bar's panels: Wi-Fi, Bluetooth, Sound." }
        SettingToggle { key: "themes"; label: "Themes"; description: "Your Omarchy themes, with their previews. Type “theme” to see them all." }
        SettingToggle { key: "calculator"; label: "Calculator and conversions"; description: "2+2, 15% of 80, sqrt 2, 10 km to mi, 72°F, 1 gb in mib, 255 to hex." }
        SettingToggle { key: "files"; label: "Files and folders"; description: "Names of everything in your home folder, except hidden and git-ignored files." }
        SettingToggle {
          key: "contents"
          label: "File contents"
          description: root.ready && !root.service.engine.localSearchAvailable
            ? "LocalSearch, GNOME's file indexer, isn't running, so only names are searched."
            : "Documents that contain what you type, from LocalSearch (GNOME's file indexer, which Files uses too)."
          enabled: root.settings.files !== false
          opacity: enabled ? 1 : 0.5
        }
        SettingToggle { key: "web"; label: "Search the web"; description: "The last row sends what you typed to your web browser. An address like github.com opens directly." }
        Dropdown {
          width: 240
          label: "Search engine"
          options: root.engineChoices
          value: root.settings.webEngine || "google"
          enabled: root.settings.web !== false
          opacity: enabled ? 1 : 0.5
          onChanged: function(v) { root.set("webEngine", v) }
        }
        SettingToggle { key: "clipboard"; label: "Clipboard"; description: "The Clipboard view (Ctrl+4) lists the Omarchy clipboard's history; Return pastes into the window you came from." }
      }

      // ---- Appearance
      Column {
        visible: root.page === "look"
        width: parent.width
        spacing: 10

        SectionLabel { text: "Style"; topPadding: 0 }
        Caption { text: "How the search looks. Every style searches the same things and has the same keys and views." }
        Flow {
          width: parent.width
          spacing: 10
          Repeater {
            model: Styles.STYLES
            Rectangle {
              id: styleCard
              required property var modelData
              readonly property bool chosen: root.styleId === modelData.id
              width: Math.floor((pageColumn.width - 30) / 4)
              height: width * 0.64 + 26
              radius: 10
              color: cardMouse.containsMouse && !chosen ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06) : "transparent"
              border.width: chosen ? 2 : 1
              border.color: chosen ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
              Looks.StylePreview {
                x: 5
                y: 5
                width: parent.width - 10
                height: width * 0.64
                styleId: styleCard.modelData.id
                pal: root.stylePalette
                highlight: root.ready ? root.service.highlight : Color.accent
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                text: styleCard.modelData.name
                textFormat: Text.PlainText
                color: Color.foreground
                opacity: styleCard.chosen ? 1 : 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.set("style", styleCard.modelData.id)
              }
            }
          }
        }
        Caption { text: root.styleInfo.name + ": " + root.styleInfo.note }

        // ---- Colors, for every style but Tahoe ----
        Column {
          visible: root.styleId !== "tahoe"
          width: parent.width
          spacing: 10

          SectionLabel { text: "Colors" }
          Toggle {
            width: parent.width
            label: "Follow my Omarchy theme"
            description: "Background, text and accent come from your theme, and the shades between are mixed from them, so the style changes with your theme. Turn this off to pick your own."
            checked: root.followTheme
            onClicked: root.setFollowTheme(!root.followTheme)
          }

          Repeater {
            model: root.followTheme ? [] : root.colorRoles
            Item {
              id: colorRow
              required property var modelData
              readonly property string value: root.settings[modelData.key] || "#000000"
              readonly property bool picking: root.pickerKey === modelData.key
              width: parent.width
              height: 36
              // Picked in the color picker: the hex follows.
              onValueChanged: if (!hexField.activeFocus) hexField.text = value

              // The color, as a chip: a click opens the color picker.
              Rectangle {
                id: chip
                objectName: "colorChip:" + colorRow.modelData.key
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: 28
                radius: 14
                color: colorRow.value
                border.width: colorRow.picking ? 2 : 1
                border.color: colorRow.picking ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, chipMouse.containsMouse ? 0.6 : 0.3)
                Text {
                  anchors.centerIn: parent
                  text: "󰈊"
                  textFormat: Text.PlainText
                  color: Palette.luminance(colorRow.value) > 0.35 ? Qt.rgba(0, 0, 0, 0.72) : Qt.rgba(1, 1, 1, 0.85)
                  opacity: chipMouse.containsMouse || colorRow.picking ? 1 : 0.7
                  font.family: Style.font.family
                  font.pixelSize: 14
                }
                MouseArea {
                  id: chipMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.togglePicker(colorRow.modelData.key, colorRow.modelData.label, chip)
                }
              }
              Text {
                x: 58
                anchors.verticalCenter: parent.verticalCenter
                text: colorRow.modelData.label
                textFormat: Text.PlainText
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.togglePicker(colorRow.modelData.key, colorRow.modelData.label, chip)
                }
              }
              TextField {
                id: hexField
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 110
                text: colorRow.value
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                onEditingFinished: {
                  var v = String(text).trim()
                  if (v.charAt(0) !== "#") v = "#" + v
                  if (/^#[0-9a-fA-F]{6}$/.test(v)) root.set(colorRow.modelData.key, v.toLowerCase())
                  else text = colorRow.value
                }
              }
            }
          }
          Row {
            visible: !root.followTheme
            spacing: 8
            Button {
              bordered: true
              iconText: "󰏘"
              text: "Copy my theme's colors"
              enabled: root.ready
              onClicked: root.copyThemeColors()
            }
          }
          Caption {
            visible: !root.followTheme
            text: "Click a color to pick it, or type it as #rrggbb. Surface is for the selected row, tiles and fields; secondary text is for the line under a name. The Island stays black; its accent is yours."
          }
        }

        // ---- Tahoe's glass ----
        Column {
          visible: root.styleId === "tahoe"
          width: parent.width
          spacing: 10

          SectionLabel { text: "Glass" }
          ButtonGroup {
            options: [{ value: "liquid", label: "Liquid" }, { value: "frosted", label: "Frosted" }, { value: "solid", label: "Solid" }]
            value: root.settings.glass || "liquid"
            onChanged: function(v) { root.set("glass", v) }
          }
          Caption { text: "Liquid shows what's behind it and bends it at the edges, like macOS Tahoe. Frosted is flatter and more tinted, easier to read over busy windows. Solid is plain and lightest on the GPU." }

          SectionLabel { text: "Appearance" }
          ButtonGroup {
            options: [{ value: "auto", label: "Match the theme" }, { value: "light", label: "Light" }, { value: "dark", label: "Dark" }]
            value: root.settings.appearance || "auto"
            onChanged: function(v) { root.set("appearance", v) }
          }

          SectionLabel { text: "Selection" }
          ButtonGroup {
            options: [{ value: "glass", label: "Glass, like Tahoe" }, { value: "accent", label: "Highlight color" }]
            value: root.settings.selection || "glass"
            onChanged: function(v) { root.set("selection", v) }
          }

          SectionLabel { text: "Highlight color" }
          Caption { text: "The text cursor, the chips you pick, and the selection if you chose the highlight color for it." }
          Flow {
            width: parent.width
            spacing: 10
            Repeater {
              model: root.highlightChoices
              Column {
                required property var modelData
                spacing: 4
                readonly property bool chosen: (root.settings.highlight || "accent") === modelData.value
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: 26
                  height: 26
                  radius: 13
                  color: parent.modelData.color
                  border.width: parent.chosen ? 3 : 1
                  border.color: parent.chosen ? Color.foreground : Qt.rgba(0, 0, 0, 0.3)
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.set("highlight", parent.parent.modelData.value)
                  }
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: parent.modelData.label
                  textFormat: Text.PlainText
                  color: Color.foreground
                  opacity: parent.chosen ? 1 : 0.6
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }

        SectionLabel { text: "Motion" }
        Toggle {
          width: parent.width
          label: "Reduce motion"
          description: "The search fades in and out instead of scaling, and results don't slide."
          checked: root.settings.reduceMotion === true
          onClicked: root.set("reduceMotion", root.settings.reduceMotion !== true)
        }
      }

      // ---- Privacy
      Column {
        visible: root.page === "privacy"
        width: parent.width
        spacing: 10

        SettingToggle {
          key: "learn"
          label: "Learn from what I open"
          description: "Results you pick move up, and what you picked for a word comes first when you type it again. Kept only on this computer, in ~/.local/state/marcho78.o-spotlight/history.json."
        }
        Button {
          bordered: true
          iconText: "󰆴"
          text: "Clear history"
          enabled: root.ready
          onClicked: root.clearConfirmOpen = true
        }

        SectionLabel { text: "Folders O-Spotlight doesn't search" }
        Caption { text: "Nothing inside these folders shows up in results. Hidden folders (like ~/.ssh) and files your git projects ignore are never searched." }

        Repeater {
          model: root.settings.excluded || []
          Item {
            required property string modelData
            width: pageColumn.width
            height: 30
            Text {
              anchors.left: parent.left
              anchors.right: removeButton.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: root.ready ? modelData.replace(root.service.home, "~") : modelData
              textFormat: Text.PlainText
              elide: Text.ElideMiddle
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            Button {
              id: removeButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              bordered: true
              text: "Remove"
              onClicked: root.set("excluded", (root.settings.excluded || []).filter(function(p) { return p !== modelData }))
            }
          }
        }

        Row {
          spacing: 8
          TextField {
            id: folderField
            width: Math.min(320, pageColumn.width - 90)
            placeholderText: "~/Folder/to/leave/out"
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            onAccepted: addButton.clicked()
          }
          Button {
            id: addButton
            anchors.verticalCenter: parent.verticalCenter
            bordered: true
            text: "Add"
            enabled: root.folderPath(folderField.text) !== ""
            opacity: enabled ? 1 : 0.4
            onClicked: {
              var path = root.folderPath(folderField.text)
              if (!path) return
              var list = (root.settings.excluded || []).slice()
              if (list.indexOf(path) < 0) list.push(path)
              root.set("excluded", list)
              folderField.text = ""
            }
          }
        }
      }
    }
  }

  // A click (or a scroll) anywhere but the picker closes it.
  MouseArea {
    anchors.fill: parent
    z: 8
    visible: root.pickerKey !== ""
    onPressed: root.closePicker()
    onWheel: function(wheel) { root.closePicker() }
  }

  ColorPicker {
    id: colorPicker
    z: 9
    swatches: root.pickerSwatches
    onPicked: function(color) { if (root.pickerKey !== "") root.set(root.pickerKey, color) }
    onDone: root.closePicker()
  }

  ConfirmDialog {
    anchors.fill: parent
    z: 10
    opened: root.resetConfirmOpen
    message: "Reset O-Spotlight to its default settings?"
    confirmText: "Reset"
    onCanceled: root.resetConfirmOpen = false
    onConfirmed: {
      root.resetConfirmOpen = false
      if (root.ready) root.service.resetSettings()
    }
  }

  ConfirmDialog {
    anchors.fill: parent
    z: 10
    opened: root.clearConfirmOpen
    message: "Forget everything O-Spotlight has learned from what you open?"
    confirmText: "Clear"
    onCanceled: root.clearConfirmOpen = false
    onConfirmed: {
      root.clearConfirmOpen = false
      if (root.ready) root.service.engine.clearHistory()
    }
  }
}
