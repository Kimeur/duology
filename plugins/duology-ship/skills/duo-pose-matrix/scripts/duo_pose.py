#!/usr/bin/env python3
"""duo-pose: set the iPhone Duo simulator's pose from the command line.

simctl and devicectl (Xcode 27.1) have no pose command. Device Hub has pose
buttons under the phone, and macOS lets a trusted process press them through
the Accessibility API. duo-pose presses them with a small Swift helper,
duo-pose-ax.swift, which it builds on first use into your cache folder.

  duo-pose status            what is ready, and the pose now (changes nothing)
  duo-pose list              the pose buttons Device Hub shows (changes nothing)
  duo-pose set <pose>        press the buttons for closed, open, book or tabletop

"book" and "tabletop" are Duology's words. Apple describes these ways of
holding the phone as "partially folded, like a book" and "seated on a table
like a laptop".

duo-pose never asks for, opens or changes a permission. The trust check passes
kAXTrustedCheckOptionPrompt = false, so macOS shows no prompt. If the app that
runs it is not allowed to use Accessibility, it says how you can allow it.

Exit codes: 0 done; 1 the pose did not take; 2 bad arguments; 3 not allowed to
use Accessibility; 4 Device Hub is not ready (not running, no window for the
simulator, or no pose buttons); 5 no booted iPhone Duo simulator; 6 tests are
running on the simulator (pass --force to go on); 7 the helper could not be built.

Part of Duology (MIT license). https://github.com/Kimeur/duology
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time

VERSION = "0.2.0"
HERE = os.path.dirname(os.path.realpath(__file__))
HELPER_SOURCE = os.path.join(HERE, "duo-pose-ax.swift")
DEFAULT_DEVELOPER_DIR = "/Applications/Xcode-27.1.app/Contents/Developer"
DUO_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"
PREFERRED_NAME = "iPhone Duo"

POSES = ("closed", "open", "book", "tabletop")
FOLD_BUTTON = {"closed": "Closed", "open": "Open", "book": "Partially Open", "tabletop": "Partially Open"}
# Rotate Right presses away from portrait. Tabletop is partly open and turned once.
TARGET_TURNS = {"closed": 0, "open": 0, "book": 0, "tabletop": 1}
# What a pose readout in the app should say for each pose (DeviceHinge.Status names).
HINGE_FOR_POSE = {"closed": "closed", "open": "fullyOpen", "book": "partiallyOpen", "tabletop": "partiallyOpen"}
ROTATE_RIGHT = "Rotate Right"
POSE_BUTTONS = ("Closed", "Partially Open", "Open")

# xcodebuild actions that run tests. build-for-testing only builds.
TEST_ACTIONS = ("test", "test-without-building")

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_USAGE = 2
EXIT_NOT_TRUSTED = 3
EXIT_DEVICE_HUB = 4
EXIT_NO_SIMULATOR = 5
EXIT_BUSY = 6
EXIT_NO_HELPER = 7

GRANT_HELP = (
    "Only you can allow this, and duo-pose never changes the setting. To allow it, open "
    "System Settings > Privacy & Security > Accessibility and turn on the app that runs this "
    "command (Terminal, iTerm or the Claude app). If it still says not allowed, quit and reopen that app."
)
MANUAL_HELP = (
    "You can also set the pose by hand: in Device Hub, press Closed, Partially Open or Open under "
    "the phone. For tabletop, press Partially Open, then Rotate Right once."
)


class PoseError(Exception):
    """A problem with a plain-words message, a hint and an exit code."""

    def __init__(self, code, message, hint=""):
        super().__init__(message)
        self.code = code
        self.message = message
        self.hint = hint


# --------------------------------------------------------------------------
# The Mac: every command duo-pose runs goes through System, so tests can fake it
# --------------------------------------------------------------------------

def pick_developer_dir():
    """DEVELOPER_DIR if set, else Xcode 27.1 at its usual path, else None (xcrun's default)."""
    env = os.environ.get("DEVELOPER_DIR")
    if env:
        return env
    if os.path.isdir(DEFAULT_DEVELOPER_DIR):
        return DEFAULT_DEVELOPER_DIR
    return None


class System:
    def __init__(self, developer_dir=None, log=None):
        self.developer_dir = developer_dir or pick_developer_dir()
        self.log = log

    def env(self):
        env = dict(os.environ)
        if self.developer_dir:
            env["DEVELOPER_DIR"] = self.developer_dir
        return env

    def run(self, argv, timeout=120):
        """Run a command. Returns (exit code, stdout, stderr); never raises."""
        try:
            proc = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  universal_newlines=True, env=self.env(), timeout=timeout)
            return proc.returncode, proc.stdout, proc.stderr
        except FileNotFoundError:
            return 127, "", "%s: command not found" % argv[0]
        except subprocess.TimeoutExpired:
            return 124, "", "%s timed out after %d s" % (" ".join(argv[:3]), timeout)

    def devicectl_json(self, args, timeout=60):
        """Run `xcrun devicectl <args> --json-output <file> -q` and return the parsed file, or None."""
        fd, path = tempfile.mkstemp(prefix="duo-pose-", suffix=".json")
        os.close(fd)
        try:
            code, _, _ = self.run(["xcrun", "devicectl"] + list(args) + ["--json-output", path, "-q"],
                                  timeout=timeout)
            if code != 0:
                return None
            with open(path, encoding="utf-8") as fh:
                return json.load(fh)
        except (OSError, ValueError):
            return None
        finally:
            try:
                os.remove(path)
            except OSError:
                pass

    def sleep(self, seconds):
        if seconds > 0:
            time.sleep(seconds)

    def monotonic(self):
        return time.monotonic()

    def own_pids(self):
        return {os.getpid(), os.getppid()}

    def platform(self):
        return sys.platform

    def note(self, text):
        if self.log:
            self.log(text)


# --------------------------------------------------------------------------
# Simulators
# --------------------------------------------------------------------------

def runtime_label(identifier):
    """com.apple.CoreSimulator.SimRuntime.iOS-27-1 -> iOS 27.1"""
    m = re.search(r"SimRuntime\.([A-Za-z]+)-(\d+(?:-\d+)*)$", identifier or "")
    if not m:
        return identifier or ""
    return "%s %s" % (m.group(1), m.group(2).replace("-", "."))


def pick_simulator(devices_json, udid=None):
    """Pick the simulator to use from `simctl list -j devices` output.

    With a UDID, that simulator (it must be an iPhone Duo). Otherwise the best
    iPhone Duo: booted first, then the one named "iPhone Duo". Never creates one.
    """
    candidates = []
    for runtime_id, devices in sorted((devices_json.get("devices") or {}).items()):
        for d in devices or []:
            candidates.append({
                "name": d.get("name", ""),
                "udid": d.get("udid", ""),
                "state": d.get("state", ""),
                "runtime": runtime_label(runtime_id),
                "isDuo": d.get("deviceTypeIdentifier") == DUO_TYPE,
                "available": d.get("isAvailable", True) is not False,
            })
    if udid:
        for c in candidates:
            if c["udid"].lower() == udid.lower():
                if not c["isDuo"]:
                    raise PoseError(EXIT_NO_SIMULATOR, "simulator %s (%s) is not an iPhone Duo" % (udid, c["name"]))
                return c
        raise PoseError(EXIT_NO_SIMULATOR, "no simulator has the UDID %s" % udid,
                        "List them with: xcrun simctl list devices")
    duos = [c for c in candidates if c["isDuo"] and c["available"]]
    if not duos:
        raise PoseError(EXIT_NO_SIMULATOR, "this Mac has no iPhone Duo simulator",
                        "duo-pose never creates one (each takes 4-6 GB). Run duo-doctor, or follow duo-setup.")

    def score(c):
        return (2 if c["name"] == PREFERRED_NAME else 0) + (4 if c["state"] == "Booted" else 0)

    best = duos[0]
    for c in duos[1:]:
        if score(c) > score(best):
            best = c
    return best


def find_simulator(system, udid=None, need_booted=True):
    code, out, err = system.run(["xcrun", "simctl", "list", "-j", "devices"])
    if code != 0:
        raise PoseError(EXIT_NO_SIMULATOR, "simctl could not list the simulators",
                        (err or out).strip()[-300:] or "Is Xcode 27.1 installed?")
    try:
        data = json.loads(out)
    except ValueError:
        raise PoseError(EXIT_NO_SIMULATOR, "simctl printed something that isn't JSON")
    sim = pick_simulator(data, udid)
    if need_booted and sim["state"] != "Booted":
        raise PoseError(EXIT_NO_SIMULATOR, "%s (%s) is not booted" % (sim["name"], sim["udid"]),
                        "Boot it with `xcrun simctl boot %s` and open it in Device Hub." % sim["udid"])
    return sim


def parse_busy(ps_output, ignore=()):
    """UI test processes in `ps -axo pid=,args=` output: [{"pid", "command"}].

    Looks at the program itself, not at any text in its arguments, so a shell
    script that merely mentions "xcodebuild test" (another agent's wait loop,
    for example) doesn't count:
    - xcodebuild (also through xcrun) running the test or test-without-building action;
    - a UI test runner app (a path with ".xctrunner" or "-Runner.app/").
    """
    busy = []
    for line in ps_output.splitlines():
        pid_text, _, command = line.strip().partition(" ")
        if not pid_text.isdigit() or int(pid_text) in ignore:
            continue
        command = command.strip()
        tokens = command.split()
        if not tokens:
            continue
        exe = tokens[0]
        if os.path.basename(exe) == "xcrun" and len(tokens) > 1:
            tokens = tokens[1:]
            exe = tokens[0]
        name = os.path.basename(exe)
        if (name == "xcodebuild" and any(t in TEST_ACTIONS for t in tokens[1:])) \
                or ".xctrunner" in exe or "-Runner.app/" in exe:
            busy.append({"pid": int(pid_text), "command": command})
    return busy


def parse_launchctl(output):
    """Running apps from `launchctl list` inside the simulator: {bundle id: pid or None}."""
    apps = {}
    for line in output.splitlines():
        parts = line.split("\t") if "\t" in line else line.split(None, 2)
        if len(parts) < 3:
            continue
        m = re.match(r"^UIKitApplication:([^\[\s]+)\[", parts[2].strip())
        if m:
            pid = parts[0].strip()
            apps[m.group(1)] = int(pid) if pid.isdigit() and int(pid) > 0 else None
    return apps


def busy_processes(system, sim=None):
    """UI tests running on this Mac, and UI test runners running in the simulator."""
    busy = []
    code, out, _ = system.run(["ps", "-axo", "pid=,args="])
    if code == 0:
        busy = parse_busy(out, ignore=system.own_pids())
    if sim is not None:
        code, out, _ = system.run(["xcrun", "simctl", "spawn", sim["udid"], "launchctl", "list"])
        if code == 0:
            for bundle, pid in sorted(parse_launchctl(out).items()):
                if pid and bundle.endswith(".xctrunner") and pid not in [b["pid"] for b in busy]:
                    busy.append({"pid": pid, "command": "%s (UI test runner in the simulator)" % bundle})
    return busy


# --------------------------------------------------------------------------
# What the simulator shows: active display and rotation, from devicectl
# --------------------------------------------------------------------------

def rotation_degrees(text):
    m = re.fullmatch(r"rot(\d+)", text or "")
    return int(m.group(1)) % 360 if m else None


def _size(display):
    native = display.get("nativeSize") or [0, 0]
    try:
        return int(round(float(native[0]))), int(round(float(native[1])))
    except (TypeError, ValueError, IndexError):
        return 0, 0


class DisplayState:
    """The simulator's displays as devicectl reports them.

    outer: the display marked primary (named LCD). Closed, it is active.
    inner: the other built-in display (LCD-1). Open or partly open, it is active.
    turns: Rotate Right presses away from portrait. Measured on Xcode 27.1:
    portrait shows the outer display at rot0 and the inner one at rot90 (held
    wide); one Rotate Right moves the inner display to rot180 (held tall).
    """

    def __init__(self, displays):
        self.outer = None
        self.inner = None
        for d in displays or []:
            if d.get("primary") and self.outer is None:
                self.outer = d
            elif not d.get("primary") and "integrated" in (d.get("type") or {}) and self.inner is None:
                self.inner = d
        self.active = None
        if self.outer is not None and self.outer.get("active"):
            self.active = "outer"
        elif self.inner is not None and self.inner.get("active"):
            self.active = "inner"

    @classmethod
    def from_devicectl(cls, data):
        displays = ((data or {}).get("result") or {}).get("displays")
        if not displays:
            raise PoseError(EXIT_FAILED, "devicectl returned no displays for the simulator")
        return cls(displays)

    def _display(self):
        return self.outer if self.active == "outer" else self.inner if self.active == "inner" else None

    @property
    def rotation(self):
        d = self._display()
        return rotation_degrees(d.get("currentOrientation")) if d else None

    @property
    def turns(self):
        rot = self.rotation
        if rot is None:
            return None
        return (rot // 90) % 4 if self.active == "outer" else ((rot - 90) // 90) % 4

    def shot_display(self):
        """The simctl screenshot --display value for the active display."""
        return "primary" if self.active == "outer" else "primary-1"

    def shot_size(self):
        """Expected screenshot size in pixels: the native size, turned with the display."""
        d = self._display()
        if d is None:
            return None
        w, h = _size(d)
        return (h, w) if self.rotation in (90, 270) else (w, h)

    def pose_guess(self):
        if self.active == "outer":
            return "closed" if self.turns == 0 else "closed, turned"
        if self.active == "inner":
            return {0: "open or book", 1: "tabletop (or open, held tall)"}.get(self.turns, "open, turned")
        return "changing (no display is active)"

    def describe(self):
        if self.active is None:
            return "no display is active (the phone may be moving)"
        held = {0: "portrait", 1: "turned once", 2: "turned twice", 3: "turned three times"}.get(self.turns, "?")
        if self.active == "inner":
            held = {0: "held wide", 1: "held tall"}.get(self.turns, held)
        size = self.shot_size()
        return "%s display active, %s, screenshots %d x %d px" % (
            self.active, held, size[0] if size else 0, size[1] if size else 0)

    def to_dict(self):
        size = self.shot_size()
        return {"active": self.active, "rotation": self.rotation, "turns": self.turns,
                "screenshotDisplay": self.shot_display() if self.active else None,
                "screenshotSize": list(size) if size else None, "pose": self.pose_guess()}


def read_state(system, sim):
    data = system.devicectl_json(["device", "info", "displays", "-d", sim["udid"]])
    if data is None:
        raise PoseError(EXIT_FAILED, "devicectl could not read the simulator's displays",
                        "Try: xcrun devicectl device info displays -d %s" % sim["udid"])
    return DisplayState.from_devicectl(data)


def check_pose(state, target):
    """Problems that show the simulator is not in `target`; empty when the displays fit it.

    Open and book look the same from here (inner display, held wide). Only the
    app can tell them apart (see --readout-id).
    """
    want_active = "outer" if target == "closed" else "inner"
    if state.active != want_active:
        return ["the %s display should be active for %s, but %s" % (
            want_active, target, "the %s one is" % state.active if state.active else "none is")]
    if state.turns != TARGET_TURNS[target]:
        return ["%s needs %d Rotate Right press(es) from portrait, but the phone is at %s" % (
            target, TARGET_TURNS[target], state.turns)]
    return []


def png_size(path):
    """(width, height) of a PNG file, or None."""
    try:
        with open(path, "rb") as fh:
            head = fh.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def screenshot(system, sim, display, path):
    code, out, err = system.run(["xcrun", "simctl", "io", sim["udid"], "screenshot",
                                 "--display=%s" % display, path])
    return code == 0 and os.path.exists(path), (err or out).strip()


def hinge_from_value(value):
    """Read the hinge from an app's readout value.

    Accepts a DeviceHinge.Status name (closed, partiallyOpen, fullyOpen) or the
    fold region's state: fold=none (closed), fold=inactive (flat), fold=active
    (partly folded).
    """
    low = (value or "").lower()
    m = re.search(r"fold=(active|inactive|none)\b", low)
    if m:
        return {"active": "partiallyOpen", "inactive": "fullyOpen", "none": "closed"}[m.group(1)]
    for name in ("partiallyOpen", "fullyOpen", "closed"):
        if name.lower() in low:
            return name
    return None


# --------------------------------------------------------------------------
# The Accessibility helper
# --------------------------------------------------------------------------

def cache_root():
    if os.environ.get("DUOLOGY_CACHE_DIR"):
        return os.environ["DUOLOGY_CACHE_DIR"]
    if sys.platform == "darwin":
        return os.path.join(os.path.expanduser("~"), "Library", "Caches", "duology")
    return os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache"),
                        "duology")


def helper_path(source=HELPER_SOURCE):
    """Where the built helper lives. The folder name changes with the source, so edits rebuild it."""
    with open(source, "rb") as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()[:16]
    return os.path.join(cache_root(), "duo-pose-ax-" + digest, "duo-pose-ax")


def ensure_helper(system):
    if system.platform() != "darwin":
        raise PoseError(EXIT_NO_HELPER, "duo-pose needs macOS: it drives Device Hub")
    if not os.path.isfile(HELPER_SOURCE):
        raise PoseError(EXIT_NO_HELPER, "duo-pose-ax.swift is missing next to duo-pose")
    path = helper_path()
    if os.access(path, os.X_OK):
        return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = "%s.tmp-%d" % (path, os.getpid())
    system.note("Building the Accessibility helper (first run only) into %s" % os.path.dirname(path))
    code, out, err = system.run(["xcrun", "--sdk", "macosx", "swiftc", "-O", "-o", tmp, HELPER_SOURCE],
                                timeout=600)
    if code != 0 or not os.path.isfile(tmp):
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise PoseError(EXIT_NO_HELPER, "could not build the Accessibility helper",
                        "It needs Xcode's Swift compiler (xcrun swiftc). Output: %s" % (err or out).strip()[-400:])
    os.replace(tmp, path)
    return path


def ax(system, helper, *args):
    """Run the helper. Returns (exit code, parsed JSON object)."""
    code, out, err = system.run([helper] + [str(a) for a in args], timeout=60)
    text = out.strip().splitlines()[-1] if out.strip() else ""
    try:
        data = json.loads(text) if text else {}
    except ValueError:
        data = {}
    if not isinstance(data, dict):
        data = {}
    if not data and (out or err).strip():
        data = {"error": (err or out).strip()[-300:]}
    return code, data


def device_hub_app(system):
    dev = system.developer_dir or DEFAULT_DEVELOPER_DIR
    return os.path.join(os.path.dirname(dev), "Applications", "DeviceHub.app")


def device_hub_pid(system):
    code, out, _ = system.run(["pgrep", "-x", "DeviceHub"])
    pids = [int(x) for x in out.split() if x.isdigit()]
    return pids[0] if code == 0 and pids else None


def is_trusted(system, helper):
    code, data = ax(system, helper, "trust")
    return code == 0 and data.get("trusted") is True


class Hub:
    """A connection to Device Hub's window for one simulator."""

    def __init__(self, system, sim, helper, pid, info):
        self.system = system
        self.sim = sim
        self.helper = helper
        self.pid = pid
        self.info = info

    @property
    def labels(self):
        return [b.get("label") for b in self.info.get("buttons", [])]

    def reachable(self):
        """Poses whose buttons Device Hub shows."""
        have = set(self.labels)
        return [p for p in POSES if FOLD_BUTTON[p] in have and (TARGET_TURNS[p] == 0 or ROTATE_RIGHT in have)]

    def press(self, label):
        code, data = ax(self.system, self.helper, "press", self.pid, self.sim["udid"], label, self.sim["name"])
        if code != 0 or not data.get("pressed"):
            raise PoseError(EXIT_FAILED, "pressing %s in Device Hub failed" % label,
                            data.get("error") or "Accessibility error %s" % data.get("axError"))

    def readout(self, identifier):
        code, data = ax(self.system, self.helper, "readout", self.pid, self.sim["udid"], identifier,
                        self.sim["name"])
        return data if code == 0 and data.get("found") else None


def connect(system, sim, bring_forward=False, wait=10.0):
    """Check trust, find Device Hub's window for `sim` and its pose buttons.

    With bring_forward, open Device Hub (`open -a`) when it isn't running or its
    window can't be seen. That brings its window to the front of your screen.
    """
    helper = ensure_helper(system)
    if not is_trusted(system, helper):
        raise PoseError(EXIT_NOT_TRUSTED, "the app that runs duo-pose is not allowed to use Accessibility",
                        GRANT_HELP + " " + MANUAL_HELP)
    pid = device_hub_pid(system)
    opened = False
    if pid is None:
        if not bring_forward:
            raise PoseError(EXIT_DEVICE_HUB, "Device Hub is not running",
                            "Open Device Hub on the iPhone Duo, or pass --bring-forward. " + MANUAL_HELP)
        system.run(["open", "-a", device_hub_app(system)])
        opened = True
        deadline = system.monotonic() + wait
        while pid is None and system.monotonic() < deadline:
            system.sleep(1)
            pid = device_hub_pid(system)
        if pid is None:
            raise PoseError(EXIT_DEVICE_HUB, "Device Hub did not start", MANUAL_HELP)
    code, data = ax(system, helper, "buttons", pid, sim["udid"], sim["name"])
    if code == 5 and bring_forward:
        if not opened:
            system.run(["open", "-a", device_hub_app(system)])
        deadline = system.monotonic() + wait
        while code == 5 and system.monotonic() < deadline:
            system.sleep(1)
            code, data = ax(system, helper, "buttons", pid, sim["udid"], sim["name"])
    if code == 3:
        raise PoseError(EXIT_NOT_TRUSTED, "the app that runs duo-pose is not allowed to use Accessibility",
                        GRANT_HELP + " " + MANUAL_HELP)
    if code == 5:
        raise PoseError(EXIT_DEVICE_HUB, "Device Hub has no window showing %s on this desktop" % sim["name"],
                        "Select the iPhone Duo in Device Hub and keep its window on the current desktop "
                        "(not minimized, not behind Mission Control), or pass --bring-forward. " + MANUAL_HELP)
    if code != 0 or not data.get("buttons"):
        seen = ", ".join(data.get("otherButtons") or []) or "none"
        raise PoseError(EXIT_DEVICE_HUB, "Device Hub's window shows no pose buttons",
                        "Device Hub may have changed in an Xcode update. Buttons it shows: %s. %s" % (seen, MANUAL_HELP))
    return Hub(system, sim, helper, pid, data)


# --------------------------------------------------------------------------
# Setting a pose
# --------------------------------------------------------------------------

class Timing:
    def __init__(self, fold_wait=5.0, rotate_wait=1.5, settle=1.5, timeout=20.0, poll=1.0):
        self.fold_wait = fold_wait      # Open and Partially Open settled in 4-6 s on Xcode 27.1
        self.rotate_wait = rotate_wait
        self.settle = settle
        self.timeout = timeout          # Closed once took 9 s
        self.poll = poll


def wait_for(system, sim, predicate, timeout, poll):
    deadline = system.monotonic() + timeout
    state = read_state(system, sim)
    while not predicate(state) and system.monotonic() < deadline:
        system.sleep(poll)
        state = read_state(system, sim)
    return state


def rotate_to(system, sim, hub, turns, timing, pressed):
    """Press Rotate Right until the phone is `turns` presses from portrait (at most four presses)."""
    state = read_state(system, sim)
    for _ in range(4):
        if state.turns == turns:
            return state
        if state.turns is None:
            state = wait_for(system, sim, lambda s: s.turns is not None, timing.timeout, timing.poll)
            continue
        before = state.turns
        hub.press(ROTATE_RIGHT)
        pressed.append(ROTATE_RIGHT)
        system.sleep(timing.rotate_wait)
        state = wait_for(system, sim, lambda s, b=before: s.turns is not None and s.turns != b,
                         timing.timeout / 2, timing.poll)
    return state


def drive(system, sim, hub, fold_label, want_active, turns, timing):
    """Press `fold_label`, then turn the phone. Returns (state, buttons pressed)."""
    pressed = []
    state = read_state(system, sim)
    # Closing a turned phone: turn it back first, while the inner display still shows.
    if want_active == "outer" and state.active == "inner" and state.turns not in (None, turns):
        state = rotate_to(system, sim, hub, turns, timing, pressed)
    hub.press(fold_label)
    pressed.append(fold_label)
    system.sleep(timing.fold_wait)
    state = wait_for(system, sim, lambda s: s.active == want_active, timing.timeout, timing.poll)
    if state.active == want_active and state.turns != turns:
        state = rotate_to(system, sim, hub, turns, timing, pressed)
    system.sleep(timing.settle)
    return read_state(system, sim), pressed


def set_pose(system, sim, target, hub, timing=None, readout_id=None, check_screenshot=True):
    """Put the simulator in `target` and check it. Returns a result dict; result["ok"] says if it took."""
    timing = timing or Timing()
    if target not in hub.reachable():
        raise PoseError(EXIT_DEVICE_HUB, "Device Hub shows no button for %s" % target,
                        "Buttons it shows: %s. %s" % (", ".join(hub.labels) or "none", MANUAL_HELP))
    before = read_state(system, sim)
    want_active = "outer" if target == "closed" else "inner"
    state, pressed = drive(system, sim, hub, FOLD_BUTTON[target], want_active, TARGET_TURNS[target], timing)
    problems = check_pose(state, target)
    verified = [] if problems else ["active display", "rotation"]
    shot = None
    if check_screenshot and not problems:
        folder = tempfile.mkdtemp(prefix="duo-pose-check-")
        path = os.path.join(folder, "check.png")
        try:
            ok, err = screenshot(system, sim, state.shot_display(), path)
            size = png_size(path) if ok else None
            shot = {"display": state.shot_display(), "size": list(size) if size else None,
                    "expected": list(state.shot_size() or ())}
            if size is None:
                problems.append("the screenshot failed: %s" % (err or "no file"))
            elif tuple(size) != state.shot_size():
                problems.append("the screenshot is %d x %d px, expected %d x %d" % (size + state.shot_size()))
            else:
                verified.append("screenshot size")
        finally:
            shutil.rmtree(folder, ignore_errors=True)
    fold = check_fold(hub, target, readout_id)
    if fold["status"] == "fail":
        problems.append(fold["note"])
    elif fold["status"] == "pass":
        verified.append("app readout")
    return {"pose": target, "ok": not problems, "pressed": pressed, "before": before.to_dict(),
            "after": state.to_dict(), "verified": verified, "problems": problems, "fold": fold,
            "screenshot": shot}


def check_fold(hub, target, readout_id):
    """Ask the app's pose readout (an accessibility element) whether the hinge matches."""
    if target == "closed":
        return {"status": "n/a", "note": "closed: no fold"}
    if not readout_id:
        return {"status": "not checked",
                "note": "open and book look the same from outside the app; use --readout-id or look at the screenshot"}
    if hub is None:
        return {"status": "not checked", "note": "the readout needs Device Hub and Accessibility access; "
                                                 "a --manual run can't read it"}
    data = hub.readout(readout_id)
    if data is None:
        return {"status": "not checked", "note": "no element with identifier %s in Device Hub's window" % readout_id}
    value = data.get("value") or data.get("label") or ""
    hinge = hinge_from_value(value)
    want = HINGE_FOR_POSE[target]
    if hinge == want:
        return {"status": "pass", "note": "app says %s" % value, "hinge": hinge}
    if hinge is None:
        return {"status": "not checked", "note": "the readout says %r, with no hinge status in it" % value}
    return {"status": "fail", "note": "the app says the hinge is %s, expected %s" % (hinge, want), "hinge": hinge}


def restore_plan(state):
    """How to put the simulator back where it started: (fold button, active display, turns, note)."""
    if state.active == "outer":
        return "Closed", "outer", state.turns or 0, ""
    if state.active == "inner":
        return ("Open", "inner", state.turns or 0,
                "It started open or partly open, and Device Hub doesn't say which, so it was left open (flat).")
    return "Closed", "outer", 0, "No display was active at the start, so it was left closed, in portrait."


# --------------------------------------------------------------------------
# Status and the command line
# --------------------------------------------------------------------------

def gather_status(system, udid=None, bring_forward=False):
    """Everything `duo-pose status` reports. Changes nothing unless bring_forward."""
    status = {"tool": "duo-pose", "version": VERSION, "ready": False, "problem": None}
    try:
        sim = find_simulator(system, udid)
        status["simulator"] = sim
        status["busy"] = busy_processes(system, sim)
        try:
            status["state"] = read_state(system, sim).to_dict()
        except PoseError as exc:
            status["state"] = {"error": exc.message}
        status["deviceHubPid"] = device_hub_pid(system)
        helper = ensure_helper(system)
        status["trusted"] = is_trusted(system, helper)
        hub = connect(system, sim, bring_forward=bring_forward)
        status["window"] = hub.info.get("window")
        status["buttons"] = hub.info.get("buttons")
        status["reachable"] = hub.reachable()
        if status["busy"]:
            raise PoseError(EXIT_BUSY, "UI tests are running, so `set` would refuse",
                            "Wait until they finish, or pass --force to `set` if they use another simulator.")
        status["ready"] = True
    except PoseError as exc:
        status["problem"] = {"code": exc.code, "message": exc.message, "hint": exc.hint}
    return status


def print_status(status, out):
    sim = status.get("simulator")
    lines = ["duo-pose %s" % status["version"]]
    if sim:
        lines.append("  Simulator:      %s (%s), %s, %s" % (sim["name"], sim["udid"], sim["runtime"], sim["state"].lower()))
    if "state" in status:
        st = status["state"]
        lines.append("  Pose now:       %s" % (st.get("pose") or st.get("error")))
    if "deviceHubPid" in status:
        pid = status["deviceHubPid"]
        lines.append("  Device Hub:     %s" % ("running (pid %d)" % pid if pid else "not running"))
    if "trusted" in status:
        lines.append("  Accessibility:  %s" % ("allowed for the app that runs this command" if status["trusted"]
                                              else "not allowed for the app that runs this command"))
    if status.get("window"):
        lines.append("  Window:         %s" % status["window"])
    if status.get("buttons"):
        lines.append("  Buttons:        %s" % ", ".join(b["label"] for b in status["buttons"]))
        lines.append("  Poses it can set: %s" % ", ".join(status.get("reachable") or []))
    if "busy" in status:
        busy = status["busy"]
        lines.append("  UI tests:       %s" % ("none running" if not busy else
                                              "; ".join("%d %s" % (b["pid"], b["command"][:80]) for b in busy)))
    if status["ready"]:
        lines.append("Ready: `duo-pose set <closed|open|book|tabletop>` can press Device Hub's buttons.")
    else:
        prob = status["problem"] or {}
        lines.append("Not ready: %s." % prob.get("message", "unknown problem"))
        if prob.get("hint"):
            lines.append("  %s" % prob["hint"])
    out.write("\n".join(lines) + "\n")


def build_parser():
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--udid", help="the simulator to use (default: the booted iPhone Duo)")
    common.add_argument("--json", action="store_true", help="print one JSON object")
    common.add_argument("--bring-forward", action="store_true",
                        help="open Device Hub and bring its window to the front if it can't be seen")
    p = argparse.ArgumentParser(
        prog="duo-pose",
        description="Set the iPhone Duo simulator's pose by pressing Device Hub's buttons "
                    "through the macOS Accessibility API.",
        epilog="Exit codes: 0 done, 1 the pose did not take, 2 bad arguments, 3 not allowed to use "
               "Accessibility, 4 Device Hub not ready, 5 no booted iPhone Duo simulator, "
               "6 UI tests running (use --force), 7 helper could not be built.")
    p.add_argument("--version", action="version", version="duo-pose " + VERSION)
    sub = p.add_subparsers(dest="command", metavar="command")
    sub.required = True
    sub.add_parser("status", parents=[common], help="what is ready, and the pose now (changes nothing)")
    sub.add_parser("list", parents=[common], help="the pose buttons Device Hub shows (changes nothing)")
    s = sub.add_parser("set", parents=[common], help="press the buttons for a pose, then check it")
    s.add_argument("pose", choices=POSES)
    s.add_argument("--force", action="store_true", help="go on even while UI tests run on this Mac")
    s.add_argument("--readout-id", metavar="ID",
                   help="accessibility identifier of the app's pose readout, to tell open from book")
    s.add_argument("--no-bring-forward", action="store_true",
                   help="fail instead of bringing Device Hub to the front")
    s.add_argument("--wait", type=float, default=5.0, metavar="SECONDS",
                   help="wait after pressing a fold button (default 5)")
    s.add_argument("--timeout", type=float, default=20.0, metavar="SECONDS",
                   help="how long to wait for the displays to switch (default 20)")
    return p


def parse_args(argv):
    args = build_parser().parse_args(argv)
    if getattr(args, "wait", 0) < 0 or getattr(args, "timeout", 1) <= 0:
        build_parser().error("--wait must be 0 or more and --timeout more than 0")
    return args


def emit_error(exc, as_json, out, err, extra=None):
    if as_json:
        payload = {"ok": False, "code": exc.code, "error": exc.message, "hint": exc.hint}
        payload.update(extra or {})
        out.write(json.dumps(payload, sort_keys=True) + "\n")
    else:
        err.write("duo-pose: %s.\n" % exc.message)
        if exc.hint:
            err.write("  %s\n" % exc.hint)
    return exc.code


def main(argv=None, system=None, out=None, err=None):
    out = out or sys.stdout
    err = err or sys.stderr
    args = parse_args(sys.argv[1:] if argv is None else argv)
    system = system or System(log=None if args.json else (lambda t: err.write(t + "\n")))

    if args.command == "status":
        status = gather_status(system, args.udid, args.bring_forward)
        if args.json:
            out.write(json.dumps(status, sort_keys=True) + "\n")
        else:
            print_status(status, out)
        return EXIT_OK if status["ready"] else status["problem"]["code"]

    try:
        sim = find_simulator(system, args.udid)
        if args.command == "list":
            hub = connect(system, sim, bring_forward=args.bring_forward)
            if args.json:
                out.write(json.dumps({"ok": True, "window": hub.info.get("window"), "buttons": hub.info["buttons"],
                                      "reachable": hub.reachable()}, sort_keys=True) + "\n")
            else:
                out.write("Device Hub window: %s\n" % hub.info.get("window"))
                for b in hub.info["buttons"]:
                    out.write("  %-15s %s\n" % (b["label"], "enabled" if b.get("enabled", True) else "disabled"))
                out.write("Poses it can set: %s\n" % ", ".join(hub.reachable()))
            return EXIT_OK

        busy = busy_processes(system, sim)
        if busy and not args.force:
            raise PoseError(EXIT_BUSY, "UI tests are running on this Mac (%s)" % ", ".join(
                "pid %d" % b["pid"] for b in busy),
                "The pose is shared by everything on the simulator. Wait until they finish, "
                "or pass --force if you know they use another simulator.")
        hub = connect(system, sim, bring_forward=not args.no_bring_forward)
        timing = Timing(fold_wait=args.wait, timeout=args.timeout)
        result = set_pose(system, sim, args.pose, hub, timing=timing, readout_id=args.readout_id)
    except PoseError as exc:
        return emit_error(exc, args.json, out, err)

    if args.json:
        out.write(json.dumps(result, sort_keys=True) + "\n")
    else:
        after = result["after"]
        out.write("Pressed: %s\n" % (", ".join(result["pressed"]) or "nothing"))
        out.write("Pose now: %s (%s display active, screenshots %s px)\n" % (
            after["pose"], after["active"] or "no",
            " x ".join(str(n) for n in after["screenshotSize"] or []) or "?"))
        if result["verified"]:
            out.write("Checked: %s\n" % ", ".join(result["verified"]))
        out.write("Fold: %s (%s)\n" % (result["fold"]["status"], result["fold"]["note"]))
        for problem in result["problems"]:
            out.write("Problem: %s\n" % problem)
        out.write(("Done: the simulator is in %s.\n" % args.pose) if result["ok"] else
                  "The pose did not take. Look at Device Hub, or set it by hand.\n")
    return EXIT_OK if result["ok"] else EXIT_FAILED


if __name__ == "__main__":
    sys.exit(main())
