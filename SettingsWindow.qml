import QtQuick
import Quickshell
import qs.Commons

// The O-Spotlight settings window. Open it with `omarchy-shell o-spotlight
// settings`, a right-click on the magnifying glass in the top bar, or Ctrl+,
// in the search. Settings live on O-Spotlight's entry in
// ~/.config/omarchy/shell.json (only what differs from Defaults.js) and apply
// as you change them.
FloatingWindow {
  id: window

  property var service: null
  property alias page: view.page

  title: "O-Spotlight Settings"
  color: Color.background
  implicitWidth: 760
  implicitHeight: 600
  minimumSize: Qt.size(680, 520)

  onVisibleChanged: if (!visible && service) service.settingsClosed()

  FocusScope {
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: window.visible = false

    SettingsView {
      id: view
      anchors.fill: parent
      service: window.service
    }
  }
}
