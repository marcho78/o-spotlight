import QtQuick
import Quickshell
import Quickshell.Wayland

// "Launching Firefox…" on the Omarchy OSD when an app takes a while, as the
// Omarchy launcher does: shown if no new window has appeared two seconds
// after launching, gone as soon as one does (or after fifteen seconds).
Item {
  id: feedback

  property int serial: 0
  property int windowCount: 0
  property var activeWindow: null
  property bool osdOpen: false
  property string message: ""

  function count() {
    try { return ToplevelManager.toplevels.values.length } catch (e) { return 0 }
  }

  function begin(name) {
    serial++
    windowCount = count()
    activeWindow = ToplevelManager.activeToplevel
    message = "Launching " + String(name || "application").slice(0, 80) + "…"
    delay.restart()
    timeout.restart()
  }

  function finish() {
    delay.stop()
    timeout.stop()
    if (osdOpen) {
      Quickshell.execDetached(["/usr/bin/omarchy-shell", "-q", "osd", "close"])
      osdOpen = false
    }
  }

  function check() {
    if (!delay.running && !timeout.running && !osdOpen) return
    if (count() <= windowCount && ToplevelManager.activeToplevel === activeWindow) return
    finish()
  }

  Timer {
    id: delay
    interval: 2000
    onTriggered: {
      if (feedback.count() > feedback.windowCount || ToplevelManager.activeToplevel !== feedback.activeWindow) return
      feedback.osdOpen = true
      Quickshell.execDetached(["/usr/bin/omarchy-shell", "-q", "osd", "show", JSON.stringify({ icon: "󱓞", message: feedback.message, duration: 0 })])
    }
  }

  Timer {
    id: timeout
    interval: 15000
    onTriggered: feedback.finish()
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { feedback.check() }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { feedback.check() }
  }
}
