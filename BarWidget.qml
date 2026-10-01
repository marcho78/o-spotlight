import QtQuick
import qs.Ui
import "Settings.js" as Settings

// O-Spotlight's magnifying glass in the Omarchy bar, where Spotlight sits in
// the macOS menu bar. Click it to search; right-click for the settings.
//
// For Omarchy this icon is also O-Spotlight's on switch: a third-party plugin
// is on while its entry is in the bar. To keep O-Spotlight but lose the icon,
// turn off "Show O-Spotlight in the top bar" in its settings; the icon then
// takes no space.
BarWidget {
  id: root
  moduleName: "marcho78.o-spotlight"

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("marcho78.o-spotlight") : null
  readonly property bool wanted: !service || !service.settings || service.settings.barIcon !== false
  readonly property string shortcut: service && service.settings ? Settings.shortcutLabel(service.settings.shortcut) : ""

  visible: wanted
  implicitWidth: wanted ? button.implicitWidth : 0
  implicitHeight: wanted ? button.implicitHeight : 0

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Material Design "magnify".
    text: String.fromCodePoint(0xf0349)
    tooltipText: "O-Spotlight" + (root.shortcut ? " · " + root.shortcut : "") + " · right-click for settings"
    onPressed: function(button) {
      if (!root.service) return
      if (button === Qt.RightButton) root.service.openSettings("")
      // From the bar, the browse buttons are out right away (as from the
      // magnifying glass in the macOS menu bar).
      else root.service.toggle({ buttons: true })
    }
  }
}
