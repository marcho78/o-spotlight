import QtQuick
import Quickshell
import Quickshell.Io

// Runs one command from an argument list, by absolute path and never through
// a shell, then reports once: finished(ok, output).
//
// The command runs as the leader of its own process group (setsid), so a
// deadline, an output overrun or cancel() ends it together with anything it
// started, and so does O-Spotlight unloading while it runs. Output is counted
// in bytes as it arrives, stdout and stderr together, and nothing past the
// budget is kept. On failure, `output` says why: the budget or deadline it
// broke, or what the command printed on stderr.
//
// Output arrives in pieces as the command writes it, and each piece is turned
// into text on its own, so a character whose bytes land in two pieces would
// be garbled. Commands that print ASCII only (the file helper, which hands
// files over as escaped JSON text) can be read as they come; for the rest, `splitMarker`
// cuts stdout into whole records (fd's NUL-ended paths, `stat`'s lines)
// before they're turned into text. A record is at most a path long, and it's
// counted against the budget as soon as it's complete.
//
// replace(argv) is for searches that follow your typing: it stops the command
// in flight (its result is never reported) and starts the new one.
//
// start(argv, input) hands the command `input` on stdin and closes it.
// `environment` changes variables for the command (null unsets one); with
// `clearEnvironment`, the command gets those variables only (null then
// takes the value O-Spotlight has).
Item {
  id: run

  property int timeoutMs: 5000
  property int maxBytes: 64 * 1024
  // Exit codes that still count as success (find and stat use 1 for "some
  // paths were missing").
  property var okCodes: [0]
  property var environment: ({})
  property bool clearEnvironment: false
  // "" (pieces as they come), "\n" or "\u0000" (whole records; see above).
  property string splitMarker: ""
  readonly property bool running: proc.running

  signal finished(bool ok, string output)

  property string _out: ""
  property string _err: ""
  property int _seen: 0
  property string _failed: ""
  property bool _cancelled: false
  property var _pending: null
  property string _input: ""
  property bool _hasInput: false

  function start(argv, input) {
    if (proc.running) return false
    _begin(argv, input)
    return true
  }

  function replace(argv) {
    if (proc.running) {
      _pending = argv
      _stop()
    } else {
      _pending = null
      _begin(argv)
    }
  }

  function cancel() {
    _pending = null
    _stop()
  }

  function _begin(argv, input) {
    _out = ""
    _err = ""
    _seen = 0
    _failed = ""
    _cancelled = false
    _hasInput = input !== undefined && input !== null
    _input = _hasInput ? String(input) : ""
    proc.stdinEnabled = _hasInput
    proc.command = ["/usr/bin/setsid", "--wait"].concat(argv)
    proc.running = true
    deadline.restart()
  }

  // What replace() asked for, if nothing has called it off since.
  function _startPending() {
    var next = _pending
    _pending = null
    if (next && !proc.running) _begin(next)
  }

  function _kill() {
    if (proc.processId > 0) Quickshell.execDetached(["/usr/bin/kill", "-KILL", "--", "-" + proc.processId])
  }

  function _stop() {
    if (!proc.running || _cancelled) return
    _cancelled = true
    _kill()
  }

  function _fail(reason) {
    if (_failed) return
    _failed = reason
    _kill()
  }

  // The UTF-8 bytes `text` came from.
  function _bytes(text) {
    if (!/[^\u0000-\u007f]/.test(text)) return text.length
    var n = text.length
    for (var i = 0; i < text.length; i++) {
      var c = text.charCodeAt(i)
      if (c >= 0x80) n += c >= 0x800 && (c < 0xd800 || c > 0xdfff) ? 2 : 1
    }
    return n
  }

  function _take(data, isError) {
    if (_failed || _cancelled) return
    // A record comes without its marker; put it back, so the output reads
    // as the command wrote it.
    if (!isError && splitMarker) data += splitMarker
    _seen += _bytes(data)
    if (_seen > maxBytes) {
      _fail("printed more than " + maxBytes + " bytes")
      return
    }
    if (isError) {
      if (_err.length < 2000) _err += data
    } else {
      _out += data
    }
  }

  Component.onDestruction: if (proc.running) _kill()

  Timer {
    id: deadline
    interval: run.timeoutMs
    onTriggered: run._fail("took longer than " + run.timeoutMs + "ms")
  }

  Process {
    id: proc
    environment: run.environment
    clearEnvironment: run.clearEnvironment
    onStarted: {
      if (!run._hasInput) return
      write(run._input)
      run._input = ""
      // Closes stdin: the command sees the end of its input.
      stdinEnabled = false
    }
    stdout: SplitParser {
      splitMarker: run.splitMarker
      onRead: function(data) { run._take(data, false) }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(data) { run._take(data, true) }
    }
    onExited: function(exitCode) {
      deadline.stop()
      if (run._cancelled) {
        run._cancelled = false
        run._out = ""
        run._err = ""
        if (run._pending) Qt.callLater(run._startPending)
        return
      }
      var ok = run.okCodes.indexOf(exitCode) >= 0 && !run._failed
      var out = ok ? run._out : (run._failed || (run._err.trim() + (run._out ? "\n" + run._out : "")).trim() || ("exited with " + exitCode))
      run._out = ""
      run._err = ""
      run.finished(ok, out)
    }
  }
}
