# Checks bin/o-spotlight-files: that it reads only through real, private
# directories and refuses symbolic links, hard links, foreign or
# others-writable files and folders, special files and files over their cap;
# and that it writes the history atomically, only where it should.
# Usage (from the plugin directory): python3 tests/files-helper.test.py
#
# Runs in a scratch folder in your runtime folder (/run/user/<uid>), which
# nobody else can write to, standing in for your home folder.

import importlib.machinery
import importlib.util
import os
import shutil
import stat
import sys
import tempfile

# Leaves no bytecode cache in the plugin's folder.
sys.dont_write_bytecode = True

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
loader = importlib.machinery.SourceFileLoader("helper", os.path.join(ROOT, "bin", "o-spotlight-files"))
spec = importlib.util.spec_from_loader("helper", loader)
helper = importlib.util.module_from_spec(spec)
loader.exec_module(helper)

passed = 0


def check(name, fn):
    global passed
    try:
        fn()
    except AssertionError as e:
        raise SystemExit("files-helper: FAILED %s: %s" % (name, e))
    passed += 1


def raises(kind, fn):
    try:
        fn()
    except kind:
        return
    raise AssertionError("expected %s" % kind.__name__)


runtime = "/run/user/%d" % os.getuid()
if not os.path.isdir(runtime):
    print("files-helper: skipped (no %s)" % runtime)
    sys.exit(0)

scratch = tempfile.mkdtemp(prefix="o-spotlight-test-", dir=runtime)
os.chmod(scratch, 0o700)
fake_home = os.path.join(scratch, "home")
os.mkdir(fake_home, 0o700)
helper.home = lambda: fake_home
helper.runtime_dir = lambda: runtime


def put(rel, data=b"x", mode=0o644):
    path = os.path.join(fake_home, rel)
    os.makedirs(os.path.dirname(path), mode=0o755, exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    os.chmod(path, mode)
    return path


try:
    menu = ".config/omarchy/extensions/omarchy-menu.jsonc"
    recent = ".local/share/recently-used.xbel"

    def reads_a_plain_file():
        put(menu, b'{"a": 1}')
        assert helper.read_named("user-menu") == b'{"a": 1}'
    check("reads a plain file", reads_a_plain_file)

    def reads_omarchys_own_files():
        assert len(helper.read_named("menu")) > 0, "the Omarchy menu, root's"
    check("reads Omarchy's own files", reads_omarchys_own_files)

    def missing_is_missing():
        raises(helper.Missing, lambda: helper.read_named("clipboard"))
    check("a missing file is missing", missing_is_missing)

    def refuses_a_symlinked_file():
        target = put("elsewhere.xbel", b"secret")
        os.makedirs(os.path.join(fake_home, ".local/share"), mode=0o755, exist_ok=True)
        os.symlink(target, os.path.join(fake_home, recent))
        raises(helper.Refused, lambda: helper.read_named("recent"))
        os.unlink(os.path.join(fake_home, recent))
    check("refuses a symbolic link", refuses_a_symlinked_file)

    def refuses_a_symlinked_folder():
        os.makedirs(os.path.join(fake_home, "real-state"), mode=0o755)
        put("real-state/theme.name", b"nord")
        os.makedirs(os.path.join(fake_home, ".local/state/omarchy"), mode=0o755)
        os.symlink(os.path.join(fake_home, "real-state"), os.path.join(fake_home, ".local/state/omarchy/current"))
        raises(helper.Refused, lambda: helper.read_named("theme-name"))
    check("refuses a symbolic link on the way", refuses_a_symlinked_folder)

    def refuses_a_hard_link():
        path = put(recent, b"<xbel/>")
        os.link(path, os.path.join(fake_home, "second-link"))
        raises(helper.Refused, lambda: helper.read_named("recent"))
        os.unlink(os.path.join(fake_home, "second-link"))
        assert helper.read_named("recent") == b"<xbel/>"
    check("refuses a file with two links", refuses_a_hard_link)

    def refuses_writable_by_others():
        path = put(recent, b"<xbel/>", mode=0o666)
        raises(helper.Refused, lambda: helper.read_named("recent"))
        os.chmod(path, 0o600)
        share = os.path.join(fake_home, ".local/share")
        os.chmod(share, 0o775)
        raises(helper.Refused, lambda: helper.read_named("recent"))
        os.chmod(share, 0o755)
        assert helper.read_named("recent") == b"<xbel/>"
    check("refuses files and folders others can write to", refuses_writable_by_others)

    def refuses_a_fifo_without_waiting():
        path = os.path.join(fake_home, ".local/state/omarchy/clipboard-history.json")
        os.mkfifo(path, 0o600)
        raises(helper.Refused, lambda: helper.read_named("clipboard"))
        os.unlink(path)
    check("refuses a FIFO without blocking", refuses_a_fifo_without_waiting)

    def refuses_over_the_cap():
        put(recent, b"x" * 2048)
        saved = helper.FILES["recent"]
        helper.FILES["recent"] = (saved[0], saved[1], 1024)
        try:
            raises(helper.Refused, lambda: helper.read_named("recent"))
        finally:
            helper.FILES["recent"] = saved
    check("refuses a file over its cap", refuses_over_the_cap)

    def unknown_names_are_refused():
        raises(helper.Refused, lambda: helper.read_named("../../etc/passwd"))
        raises(helper.Refused, lambda: helper.read_named("__proto__"))
    check("only the files it knows", unknown_names_are_refused)

    state = os.path.join(fake_home, ".local/state/marcho78.o-spotlight")

    def writes_the_history_atomically():
        helper.history_write(state, b'{"version": 1}\n')
        st = os.stat(state)
        assert stat.S_IMODE(st.st_mode) == 0o700, oct(st.st_mode)
        assert stat.S_IMODE(os.stat(os.path.join(state, "history.json")).st_mode) == 0o600
        assert helper.history_read(state) == b'{"version": 1}\n'
        helper.history_write(state, b'{"version": 1, "items": {}}\n')
        assert helper.history_read(state) == b'{"version": 1, "items": {}}\n'
        assert os.listdir(state) == ["history.json"], os.listdir(state)
    check("writes the history atomically", writes_the_history_atomically)

    def write_refusals():
        raises(helper.Refused, lambda: helper.history_write(state, b"not json"))
        raises(helper.Refused, lambda: helper.history_write(state, b"[1, 2]"))
        raises(helper.Refused, lambda: helper.history_write(state, b"{" + b" " * (helper.HISTORY_CAP + 1) + b"}"))
        raises(helper.Refused, lambda: helper.history_write("/var/tmp/o-spotlight", b"{}"))
        raises(helper.Refused, lambda: helper.history_write(state + "/../elsewhere", b"{}"))
        raises(helper.Refused, lambda: helper.history_write("relative/path", b"{}"))
        assert helper.history_read(state) == b'{"version": 1, "items": {}}\n', "untouched"
    check("refuses bad history and other places", write_refusals)

    def replaces_a_planted_link_not_its_target():
        target = put("victim.json", b"keep me")
        os.unlink(os.path.join(state, "history.json"))
        os.symlink(target, os.path.join(state, "history.json"))
        raises(helper.Refused, lambda: helper.history_read(state))
        helper.history_write(state, b"{}\n")
        assert open(target, "rb").read() == b"keep me", "the link's target is untouched"
        assert not os.path.islink(os.path.join(state, "history.json"))
    check("replaces a planted link, never writes through it", replaces_a_planted_link_not_its_target)

    def refuses_a_symlinked_state_folder():
        elsewhere = os.path.join(fake_home, "other-place")
        os.mkdir(elsewhere, 0o700)
        linked = os.path.join(fake_home, ".local/state/linked")
        os.symlink(elsewhere, linked)
        raises(helper.Refused, lambda: helper.history_write(linked + "/marcho78.o-spotlight", b"{}"))
        assert os.listdir(elsewhere) == []
    check("refuses a state folder reached through a link", refuses_a_symlinked_state_folder)

    def exit_codes():
        quiet, sys.stderr = sys.stderr, open(os.devnull, "w")
        try:
            assert helper.main(["x"]) == 2
            assert helper.main(["x", "read", "nope"]) == 4
            assert helper.main(["x", "read", "clipboard"]) == 3
        finally:
            sys.stderr.close()
            sys.stderr = quiet
    check("exit codes", exit_codes)
finally:
    shutil.rmtree(scratch, ignore_errors=True)

print("files-helper: %d checks passed" % passed)
