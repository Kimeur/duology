"""A pretend iPhone Duo simulator and Device Hub for the duo-pose tests.

No Mac, Xcode or simulator needed: FakeMac answers the commands duo-pose runs
(simctl, devicectl, pgrep, the Accessibility helper) from a small model of the
phone that reacts to button presses. The display data comes from a real
`devicectl device info displays` capture (tests/fixtures).
"""

import copy
import json
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(HERE, "fixtures")
SKILL = os.path.dirname(HERE)
SCRIPTS = os.path.join(SKILL, "scripts")

UDID = "00000000-0000-4000-8000-000000000001"
HELPER = "/fake/cache/duo-pose-ax"
BUNDLE = "dev.duology.gallery"


def fixture(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as fh:
        return fh.read()


def fixture_json(name):
    return json.loads(fixture(name))


def displays_json(active, turns):
    """devicectl output for a phone with `active` ("outer", "inner" or None) display, turned `turns` times."""
    data = fixture_json("devicectl-displays-closed.json")
    for d in data["result"]["displays"]:
        if d["primary"]:
            d["active"] = active == "outer"
            d["currentOrientation"] = "rot%d" % ((turns * 90) % 360)
        else:
            d["active"] = active == "inner"
            d["currentOrientation"] = "rot%d" % ((90 + turns * 90) % 360)
    return data


def write_png_header(path, width, height, bytes_per_pixel=None):
    """A PNG with only its header chunks: enough for duo-pose's size reader.

    With bytes_per_pixel, the file is padded (sparsely, so nothing is written)
    to the size a real screenshot of that busyness would have.
    """
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        fh.write(chunk(b"IEND", b""))
        if bytes_per_pixel:
            fh.truncate(int(width * height * bytes_per_pixel))


class FakeMac:
    """Answers duo-pose's commands. Button presses change the fold and the rotation."""

    def __init__(self, fold="Closed", turns=0, trusted=True, window=True, buttons=None, busy="",
                 installed=True, switch_delay=2.0, broken_button=None, readout=None, crash_in=None,
                 foreign_in=None, busy_after=0, runner=False, blank_in=None, steal_in=None, move_in=None):
        self.fold = fold                  # "Closed", "Open" or "Partially Open"
        self.turns = turns
        self.shown_fold = fold            # what the displays show (lags after a press)
        self.switch_at = 0.0
        self.trusted = trusted
        self.window = window
        self.buttons = list(buttons) if buttons is not None else ["Rotate Right", "Closed", "Partially Open", "Open"]
        self.busy = busy                     # extra `ps -axo pid=,args=` lines
        self.busy_after = busy_after         # the busy lines appear after this many presses
        self.runner = runner                 # a UI test runner app is running in the simulator
        self.blank_in = blank_in             # fold in which screenshots come out blank
        self.steal_in = steal_in             # fold in which someone else relaunches the app mid-capture
        self.move_in = move_in               # fold in which someone else presses Rotate Right mid-capture
        self.shots = 0
        self.installed = installed
        self.switch_delay = switch_delay
        self.broken_button = broken_button   # a button whose press reports success but does nothing
        self.readout = readout               # callable(fold) -> value string, or None for no element
        self.crash_in = crash_in             # pose-ish fold name in which the app is not running
        self.foreign_in = foreign_in         # fold in which another app starts during the capture
        self.developer_dir = "/fake/Xcode-27.1.app/Contents/Developer"
        self.time = 0.0
        self.calls = []
        self.pressed = []
        self.launches = []
        self.opened = []
        self.app_pid = None
        self.foreign_pid = None
        self.notes = []

    # -- the model -------------------------------------------------------

    def active(self):
        """The active display now. Between closed and open, no display is active until the switch ends."""
        if self.time >= self.switch_at:
            self.shown_fold = self.fold
        if self.shown_fold != self.fold and (self.shown_fold == "Closed") != (self.fold == "Closed"):
            return None
        return "outer" if self.shown_fold == "Closed" else "inner"

    # -- the System interface ---------------------------------------------

    def run(self, argv, timeout=120):
        argv = [str(a) for a in argv]
        self.calls.append(argv)
        if argv[:4] == ["xcrun", "simctl", "list", "-j"]:
            return 0, fixture("simctl-devices.json"), ""
        if argv[:2] == ["ps", "-axo"]:
            busy = self.busy if len(self.pressed) >= self.busy_after else ""
            return 0, "    1 /sbin/launchd\n   57 /usr/libexec/logd\n" + busy, ""
        if argv[:2] == ["pgrep", "-x"]:
            return 0, "88720\n", ""
        if argv[0] == "open":
            self.opened.append(argv)
            self.window = True
            return 0, "", ""
        if argv[0] == HELPER:
            return self._helper(argv[1:])
        if argv[:3] == ["xcrun", "simctl", "io"] and argv[4] == "screenshot":
            return self._screenshot(argv)
        if argv[:3] == ["xcrun", "simctl", "launch"]:
            self.launches.append(argv[6:])
            self.app_pid = 5000 + len(self.launches)
            return 0, "%s: %d\n" % (BUNDLE, self.app_pid), ""
        if argv[:3] == ["xcrun", "simctl", "get_app_container"]:
            return (0, "/fake/container\n", "") if self.installed else (2, "", "No such app")
        if argv[:3] == ["xcrun", "simctl", "spawn"]:
            return 0, self._launchctl(), ""
        if argv[:3] == ["xcrun", "simctl", "terminate"]:
            self.app_pid = None
            return 0, "", ""
        return 127, "", "unexpected command: %s" % argv

    def devicectl_json(self, args, timeout=60):
        self.calls.append(["xcrun", "devicectl"] + list(args))
        return displays_json(self.active(), self.turns)

    def sleep(self, seconds):
        self.time += max(seconds, 0)

    def monotonic(self):
        return self.time

    def own_pids(self):
        return {1, 2}

    def platform(self):
        return "darwin"

    def note(self, text):
        self.notes.append(text)

    # -- pieces -------------------------------------------------------------

    def _helper(self, args):
        cmd = args[0]
        if cmd == "trust":
            return 0, json.dumps({"trusted": self.trusted}), ""
        if not self.trusted:
            return 3, json.dumps({"trusted": False, "error": "not trusted for Accessibility"}), ""
        if not self.window:
            return 5, json.dumps({"trusted": True, "window": None, "windows": [],
                                  "error": "no Device Hub window shows this simulator"}), ""
        if cmd == "buttons":
            if not self.buttons:
                return 1, json.dumps({"trusted": True, "window": "iPhone Duo", "buttons": [],
                                      "otherButtons": ["Home", "Screenshot"]}), ""
            listed = [{"label": b, "enabled": True, "value": "", "selected": ""} for b in self.buttons]
            return 0, json.dumps({"trusted": True, "window": "iPhone Duo", "match": "selected-row",
                                  "buttons": listed}), ""
        if cmd == "press":
            label = args[3]
            if label not in self.buttons:
                return 1, json.dumps({"pressed": False, "error": "no %s button in Device Hub" % label}), ""
            self.pressed.append(label)
            if label != self.broken_button:
                if label == "Rotate Right":
                    self.turns = (self.turns + 1) % 4
                else:
                    self.active()
                    self.fold = label
                    self.switch_at = self.time + self.switch_delay
            return 0, json.dumps({"pressed": True, "label": label, "axError": 0}), ""
        if cmd == "readout":
            value = self.readout(self.fold) if self.readout else None
            if value is None:
                return 1, json.dumps({"found": False}), ""
            return 0, json.dumps({"found": True, "value": value, "label": "", "title": ""}), ""
        return 2, json.dumps({"error": "unknown command"}), ""

    def _screenshot(self, argv):
        display = argv[5].split("=", 1)[1]
        path = argv[6]
        native = (1398, 2034) if display == "primary" else (2007, 2853)
        rot = (self.turns * 90) % 360 if display == "primary" else (90 + self.turns * 90) % 360
        w, h = (native[1], native[0]) if rot in (90, 270) else native
        self.shots += 1
        write_png_header(path, w, h, None if self.fold == self.blank_in else 0.2)
        if self.fold == self.steal_in and self.app_pid:
            self.app_pid += 1000
        if self.fold == self.move_in:
            self.turns = (self.turns + 1) % 4
        return 0, "Wrote screenshot to: %s\n" % path, ""

    def _launchctl(self):
        lines = ["PID\tStatus\tLabel", "93419\t0\tUIKitApplication:com.apple.Spotlight[013a][rb-legacy]"]
        lines.append("%s\t0\tUIKitApplication:com.example.app.uitests.xctrunner[b392][rb-legacy]"
                     % ("78061" if self.runner else "-"))
        running = self.app_pid is not None and self.fold != self.crash_in
        lines.append("%s\t0\tUIKitApplication:%s[1f2e][rb-legacy]" % (self.app_pid if running else "-", BUNDLE))
        if self.foreign_in == self.fold:
            # Another session's app appears between the before and after snapshots of a capture.
            self.foreign_pid = (self.foreign_pid or 7000) + 1
            lines.append("%d\t0\tUIKitApplication:com.example.other[79a3][rb-legacy]" % self.foreign_pid)
        return "\n".join(lines) + "\n"

    def helper_commands(self):
        return [c[1] for c in self.calls if c and c[0] == HELPER]


def copy_state(data):
    return copy.deepcopy(data)
