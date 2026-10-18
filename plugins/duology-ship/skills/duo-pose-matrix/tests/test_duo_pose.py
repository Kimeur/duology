#!/usr/bin/env python3
"""Tests for duo-pose. They need no Mac, Xcode or simulator (FakeMac stands in).

Run from the repo root:
  python3 -m unittest discover plugins/duology-ship/skills/duo-pose-matrix/tests -v

One test builds the Swift helper; it runs only on a Mac with DUO_POSE_SWIFT=1.
"""

import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import duo_pose_fakes as fakes  # noqa: E402

# Keep the tests' lock files and helper builds out of the user's cache folder.
_CACHE = tempfile.mkdtemp(prefix="duo-pose-test-cache-")
os.environ["DUOLOGY_CACHE_DIR"] = _CACHE


def tearDownModule():
    shutil.rmtree(_CACHE, ignore_errors=True)

_spec = importlib.util.spec_from_file_location("duo_pose", os.path.join(fakes.SCRIPTS, "duo_pose.py"))
dp = importlib.util.module_from_spec(_spec)
sys.modules["duo_pose"] = dp
_spec.loader.exec_module(dp)

SIM = {"name": "iPhone Duo", "udid": fakes.UDID, "state": "Booted", "runtime": "iOS 27.1"}
FAST = dict(fold_wait=5.0, rotate_wait=1.5, settle=1.5, timeout=20.0, poll=1.0)


def run_main(argv, mac):
    out, err = io.StringIO(), io.StringIO()
    with mock.patch.object(dp, "ensure_helper", return_value=fakes.HELPER):
        code = dp.main(argv, system=mac, out=out, err=err)
    return code, out.getvalue(), err.getvalue()


class SimulatorTests(unittest.TestCase):
    def test_runtime_label(self):
        self.assertEqual(dp.runtime_label("com.apple.CoreSimulator.SimRuntime.iOS-27-1"), "iOS 27.1")
        self.assertEqual(dp.runtime_label("weird"), "weird")

    def test_picks_the_booted_iphone_duo(self):
        sim = dp.pick_simulator(fakes.fixture_json("simctl-devices.json"))
        self.assertEqual(sim["udid"], fakes.UDID)
        self.assertEqual(sim["runtime"], "iOS 27.1")

    def test_picks_by_udid(self):
        sim = dp.pick_simulator(fakes.fixture_json("simctl-devices.json"), "00000000-0000-4000-8000-000000000002")
        self.assertEqual(sim["name"], "Duo spare")

    def test_refuses_a_udid_that_is_not_a_duo(self):
        with self.assertRaises(dp.PoseError) as ctx:
            dp.pick_simulator(fakes.fixture_json("simctl-devices.json"), "00000000-0000-4000-8000-000000000017")
        self.assertEqual(ctx.exception.code, dp.EXIT_NO_SIMULATOR)

    def test_never_offers_to_create_a_simulator(self):
        with self.assertRaises(dp.PoseError) as ctx:
            dp.pick_simulator({"devices": {}})
        self.assertEqual(ctx.exception.code, dp.EXIT_NO_SIMULATOR)
        self.assertIn("never creates", ctx.exception.hint)

    def test_shutdown_simulator_is_an_error(self):
        mac = fakes.FakeMac()
        with self.assertRaises(dp.PoseError) as ctx:
            dp.find_simulator(mac, "00000000-0000-4000-8000-000000000002")
        self.assertIn("not booted", ctx.exception.message)

    def test_parse_busy_looks_at_the_program(self):
        ps = "\n".join([
            "  123 /Applications/Xcode-27.1.app/Contents/Developer/usr/bin/xcodebuild test -scheme App",
            "  124 /usr/bin/xcrun xcodebuild test-without-building -project A.xcodeproj",
            "  125 /usr/bin/xcodebuild build-for-testing -scheme App",
            "  126 /bin/zsh -c for i in 1 2; do pgrep -f \"xctrunner|xcodebuild.*test\"; done",
            "  127 /Users/me/Library/Developer/CoreSimulator/Devices/X/data/Containers/Bundle/Application/Y/"
            "AppUITests-Runner.app/AppUITests-Runner",
            "    2 /usr/bin/xcodebuild test -scheme Mine",
            "noise",
        ])
        busy = dp.parse_busy(ps, ignore={2})
        self.assertEqual([b["pid"] for b in busy], [123, 124, 127])

    def test_parse_launchctl(self):
        apps = dp.parse_launchctl(fakes.fixture("launchctl-list.txt"))
        self.assertEqual(apps["com.example.other"], 70169)
        self.assertIsNone(apps[fakes.BUNDLE])

    def test_parse_launchctl_prefers_the_running_copy(self):
        # A relaunch leaves the old job listed, with no process, next to the new one (seen on 18 October).
        out = "PID\tStatus\tLabel\n8220\t0\tUIKitApplication:a.b[922c][rb-legacy]\n" \
              "-\t0\tUIKitApplication:a.b[1f2e][rb-legacy]\n"
        self.assertEqual(dp.parse_launchctl(out), {"a.b": 8220})

    def test_lock_is_released(self):
        mac = fakes.FakeMac()
        dp.SimulatorLock(fakes.UDID).acquire(mac).release()
        dp.SimulatorLock(fakes.UDID).acquire(mac).release()
        held = dp.SimulatorLock(fakes.UDID).acquire(mac)
        self.addCleanup(held.release)
        code, _, err = run_main(["set", "open"], mac)
        self.assertEqual(code, dp.EXIT_BUSY)
        self.assertIn("another duo-pose", err)

    def test_ui_test_runner_in_the_simulator_counts_as_busy(self):
        busy = dp.busy_processes(fakes.FakeMac(runner=True), SIM)
        self.assertEqual([b["pid"] for b in busy], [78061])
        self.assertIn("xctrunner", busy[0]["command"])
        self.assertEqual(dp.busy_processes(fakes.FakeMac(), SIM), [])


class DisplayStateTests(unittest.TestCase):
    def test_real_closed_capture(self):
        state = dp.DisplayState.from_devicectl(fakes.fixture_json("devicectl-displays-closed.json"),
                                               fakes.fixture_json("devicectl-orientation-portrait.json"))
        self.assertEqual(state.active, "outer")
        self.assertEqual(state.orientation, "portrait")
        self.assertEqual(state.held, "portrait")
        self.assertEqual(state.shot_display(), "primary")
        self.assertEqual(state.shot_size(), (1398, 2034))
        self.assertEqual(state.pose_guess(), "closed")

    def test_open_held_wide(self):
        state = dp.DisplayState.from_devicectl(fakes.displays_json("inner", 0), fakes.orientation_json(0))
        self.assertEqual((state.active, state.held, state.shot_display()), ("inner", "portrait", "primary-1"))
        self.assertEqual(state.shot_size(), (2853, 2007))
        self.assertEqual(state.pose_guess(), "open or book")

    def test_tabletop_held_tall(self):
        state = dp.DisplayState.from_devicectl(fakes.displays_json("inner", 1), fakes.orientation_json(1))
        self.assertEqual(state.held, "landscape")
        self.assertEqual(state.shot_size(), (2007, 2853))
        self.assertTrue(state.pose_guess().startswith("tabletop"))

    def test_device_orientation_wins_over_the_screen(self):
        # A portrait-only app keeps the outer display at rot0 while the device is turned (seen on 18 October).
        state = dp.DisplayState.from_devicectl(fakes.displays_json("outer", 0), fakes.orientation_json(1))
        self.assertEqual(state.display_turns, 0)
        self.assertEqual(state.held, "landscape")
        self.assertEqual(state.pose_guess(), "closed, turned")
        self.assertTrue(dp.check_pose(state, "closed"))

    def test_falls_back_to_the_screen_without_device_orientation(self):
        state = dp.DisplayState.from_devicectl(fakes.displays_json("inner", 1), None)
        self.assertIsNone(state.orientation)
        self.assertEqual(state.held, "landscape")

    def test_mid_switch(self):
        state = dp.DisplayState.from_devicectl(fakes.displays_json(None, 0), fakes.orientation_json(0))
        self.assertIsNone(state.active)
        self.assertIsNone(state.shot_size())
        self.assertTrue(dp.check_pose(state, "open"))

    def test_no_displays_is_an_error(self):
        with self.assertRaises(dp.PoseError):
            dp.DisplayState.from_devicectl({"result": {}})

    def test_check_pose(self):
        def st(active, turns):
            return dp.DisplayState.from_devicectl(fakes.displays_json(active, turns), fakes.orientation_json(turns))
        closed, wide, tall = st("outer", 0), st("inner", 0), st("inner", 1)
        self.assertEqual(dp.check_pose(closed, "closed"), [])
        self.assertEqual(dp.check_pose(wide, "open"), [])
        self.assertEqual(dp.check_pose(wide, "book"), [])  # the same from outside the app
        self.assertEqual(dp.check_pose(tall, "tabletop"), [])
        self.assertEqual(dp.check_pose(st("inner", 3), "tabletop"), [])  # the other landscape is held tall too
        self.assertTrue(dp.check_pose(closed, "book"))
        self.assertTrue(dp.check_pose(wide, "tabletop"))
        self.assertTrue(dp.check_pose(tall, "closed"))
        self.assertTrue(dp.check_pose(st("inner", 2), "open"))

    def test_png_size(self):
        folder = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, folder)
        path = os.path.join(folder, "a.png")
        fakes.write_png_header(path, 2853, 2007)
        self.assertEqual(dp.png_size(path), (2853, 2007))
        with open(os.path.join(folder, "b.png"), "wb") as fh:
            fh.write(b"not a png at all, sorry")
        self.assertIsNone(dp.png_size(os.path.join(folder, "b.png")))
        self.assertIsNone(dp.png_size(os.path.join(folder, "missing.png")))

    def test_hinge_from_value(self):
        self.assertEqual(dp.hinge_from_value("hinge=partiallyOpen|fold=active"), "partiallyOpen")
        self.assertEqual(dp.hinge_from_value("FULLYOPEN"), "fullyOpen")
        self.assertEqual(dp.hinge_from_value("closed"), "closed")
        self.assertIsNone(dp.hinge_from_value("nothing here"))
        self.assertEqual(dp.hinge_from_value("fold=active"), "partiallyOpen")
        self.assertEqual(dp.hinge_from_value("fold=inactive"), "fullyOpen")  # "inactive" contains "active"
        self.assertEqual(dp.hinge_from_value("fold=none"), "closed")


class ArgumentTests(unittest.TestCase):
    def test_set_needs_a_known_pose(self):
        self.assertEqual(dp.parse_args(["set", "book"]).pose, "book")
        with mock.patch("sys.stderr", io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                dp.parse_args(["set", "tent"])
        self.assertEqual(ctx.exception.code, 2)

    def test_needs_a_command(self):
        with mock.patch("sys.stderr", io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                dp.parse_args([])
        self.assertEqual(ctx.exception.code, 2)

    def test_options(self):
        args = dp.parse_args(["set", "tabletop", "--udid", "X", "--json", "--force", "--readout-id", "duo.pose",
                              "--wait", "3", "--no-bring-forward"])
        self.assertEqual((args.udid, args.json, args.force, args.readout_id, args.wait, args.no_bring_forward),
                         ("X", True, True, "duo.pose", 3.0, True))
        self.assertTrue(dp.parse_args(["status", "--bring-forward"]).bring_forward)

    def test_negative_wait_is_refused(self):
        with mock.patch("sys.stderr", io.StringIO()):
            with self.assertRaises(SystemExit):
                dp.parse_args(["set", "open", "--wait", "-1"])


class SetPoseTests(unittest.TestCase):
    def hub(self, mac):
        with mock.patch.object(dp, "ensure_helper", return_value=fakes.HELPER):
            return dp.connect(mac, SIM)

    def test_closed_to_tabletop(self):
        mac = fakes.FakeMac()
        result = dp.set_pose(mac, SIM, "tabletop", self.hub(mac), timing=dp.Timing(**FAST))
        self.assertTrue(result["ok"], result["problems"])
        self.assertEqual(result["pressed"], ["Partially Open", "Rotate Right"])
        self.assertEqual(result["after"]["screenshotSize"], [2007, 2853])
        self.assertIn("screenshot size", result["verified"])
        self.assertEqual(result["fold"]["status"], "not checked")

    def test_tabletop_to_closed_turns_back_first(self):
        mac = fakes.FakeMac(fold="Partially Open", turns=1)
        result = dp.set_pose(mac, SIM, "closed", self.hub(mac), timing=dp.Timing(**FAST))
        self.assertTrue(result["ok"], result["problems"])
        self.assertEqual(result["pressed"], ["Rotate Right"] * 3 + ["Closed"])
        self.assertEqual(result["after"]["active"], "outer")

    def test_waits_for_a_slow_close(self):
        mac = fakes.FakeMac(fold="Open", switch_delay=9.0)
        result = dp.set_pose(mac, SIM, "closed", self.hub(mac), timing=dp.Timing(**FAST))
        self.assertTrue(result["ok"], result["problems"])

    def test_reports_a_pose_that_did_not_take(self):
        mac = fakes.FakeMac(broken_button="Open")
        result = dp.set_pose(mac, SIM, "open", self.hub(mac), timing=dp.Timing(**FAST))
        self.assertFalse(result["ok"])
        self.assertTrue(result["problems"])

    def test_readout_tells_book_from_open(self):
        names = {"Closed": "closed", "Open": "fullyOpen", "Partially Open": "partiallyOpen"}
        mac = fakes.FakeMac(readout=lambda fold: "hinge=%s" % names[fold])
        hub = self.hub(mac)
        result = dp.set_pose(mac, SIM, "book", hub, timing=dp.Timing(**FAST), readout_id="duo.pose")
        self.assertEqual(result["fold"]["status"], "pass")
        self.assertIn("app readout", result["verified"])
        mac.broken_button = "Partially Open"  # stays open: the app says fullyOpen
        mac.fold = "Open"
        result = dp.set_pose(mac, SIM, "book", hub, timing=dp.Timing(**FAST), readout_id="duo.pose")
        self.assertEqual(result["fold"]["status"], "fail")
        self.assertFalse(result["ok"])

    def test_missing_rotate_button_makes_tabletop_unreachable(self):
        mac = fakes.FakeMac(buttons=["Closed", "Partially Open", "Open"])
        hub = self.hub(mac)
        self.assertEqual(hub.reachable(), ["closed", "open", "book"])
        with self.assertRaises(dp.PoseError) as ctx:
            dp.set_pose(mac, SIM, "tabletop", hub, timing=dp.Timing(**FAST))
        self.assertEqual(ctx.exception.code, dp.EXIT_DEVICE_HUB)

    def test_restore_plan(self):
        closed = dp.DisplayState.from_devicectl(fakes.displays_json("outer", 0), fakes.orientation_json(0))
        wide = dp.DisplayState.from_devicectl(fakes.displays_json("inner", 0), fakes.orientation_json(0))
        turned = dp.DisplayState.from_devicectl(fakes.displays_json("outer", 0), fakes.orientation_json(3))
        fold, active, ok, note = dp.restore_plan(closed)
        self.assertEqual((fold, active, note), ("Closed", "outer", ""))
        self.assertTrue(ok(closed))
        fold, active, ok, note = dp.restore_plan(wide)
        self.assertEqual((fold, active), ("Open", "inner"))
        self.assertIn("doesn't say which", note)
        _, _, ok, _ = dp.restore_plan(turned)
        self.assertTrue(ok(turned))
        self.assertFalse(ok(closed))

    def test_turns_back_a_device_hidden_by_a_portrait_only_app(self):
        mac = fakes.FakeMac(turns=1, portrait_front=True)
        result = dp.set_pose(mac, SIM, "closed", self.hub(mac), timing=dp.Timing(**FAST))
        self.assertTrue(result["ok"], result["problems"])
        self.assertEqual(result["pressed"], ["Closed", "Rotate Right", "Rotate Right", "Rotate Right"])
        self.assertEqual(result["after"]["orientation"], "portrait")


class CommandLineTests(unittest.TestCase):
    def test_set_json(self):
        code, out, _ = run_main(["set", "book", "--json"], fakes.FakeMac())
        self.assertEqual(code, dp.EXIT_OK)
        data = json.loads(out)
        self.assertEqual(data["pressed"], ["Partially Open"])
        self.assertTrue(data["ok"])

    def test_set_text(self):
        code, out, _ = run_main(["set", "open"], fakes.FakeMac())
        self.assertEqual(code, 0)
        self.assertIn("Pressed: Open", out)
        self.assertIn("Done: the simulator is in open.", out)

    def test_not_trusted_says_how_to_allow_and_presses_nothing(self):
        mac = fakes.FakeMac(trusted=False)
        code, _, err = run_main(["set", "book"], mac)
        self.assertEqual(code, dp.EXIT_NOT_TRUSTED)
        self.assertIn("System Settings > Privacy & Security > Accessibility", err)
        self.assertIn("never changes", err)
        self.assertNotIn("press", mac.helper_commands())
        self.assertEqual(mac.pressed, [])

    def test_refuses_while_ui_tests_run(self):
        mac = fakes.FakeMac(busy="4242 /Applications/Xcode-27.1.app/.../xcodebuild test -scheme X\n")
        code, _, err = run_main(["set", "open"], mac)
        self.assertEqual(code, dp.EXIT_BUSY)
        self.assertIn("4242", err)
        self.assertEqual(mac.pressed, [])
        code, _, _ = run_main(["set", "open", "--force"], mac)
        self.assertEqual(code, dp.EXIT_OK)

    def test_status_ready(self):
        code, out, _ = run_main(["status"], fakes.FakeMac())
        self.assertEqual(code, 0)
        self.assertIn("Accessibility:  allowed", out)
        self.assertIn("Poses it can set: closed, open, book, tabletop", out)
        self.assertIn("Ready:", out)

    def test_status_not_ready_while_tests_run(self):
        code, out, _ = run_main(["status"], fakes.FakeMac(runner=True))
        self.assertEqual(code, dp.EXIT_BUSY)
        self.assertIn("Not ready: UI tests are running", out)

    def test_status_changes_nothing(self):
        mac = fakes.FakeMac(window=False)
        code, out, _ = run_main(["status", "--json"], mac)
        self.assertEqual(code, dp.EXIT_DEVICE_HUB)
        data = json.loads(out)
        self.assertFalse(data["ready"])
        self.assertEqual(data["problem"]["code"], dp.EXIT_DEVICE_HUB)
        self.assertEqual(mac.pressed, [])
        self.assertEqual(mac.opened, [])

    def test_set_brings_device_hub_forward_when_needed(self):
        mac = fakes.FakeMac(window=False)
        code, _, _ = run_main(["set", "open"], mac)
        self.assertEqual(code, 0)
        self.assertEqual(len(mac.opened), 1)
        self.assertTrue(mac.opened[0][-1].endswith("DeviceHub.app"))

    def test_set_without_bring_forward_explains(self):
        code, _, err = run_main(["set", "open", "--no-bring-forward"], fakes.FakeMac(window=False))
        self.assertEqual(code, dp.EXIT_DEVICE_HUB)
        self.assertIn("no window", err)
        self.assertIn("by hand", err)

    def test_no_pose_buttons_lists_what_it_sees(self):
        code, _, err = run_main(["list"], fakes.FakeMac(buttons=[]))
        self.assertEqual(code, dp.EXIT_DEVICE_HUB)
        self.assertIn("Home, Screenshot", err)

    def test_list(self):
        code, out, _ = run_main(["list", "--json"], fakes.FakeMac())
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["reachable"], ["closed", "open", "book", "tabletop"])

    def test_failed_pose_exits_1(self):
        code, out, _ = run_main(["set", "open"], fakes.FakeMac(broken_button="Open"))
        self.assertEqual(code, dp.EXIT_FAILED)
        self.assertIn("did not take", out)


class SafetyTests(unittest.TestCase):
    """duo-pose must never ask for, open or change a permission."""

    def read(self, name):
        with open(os.path.join(fakes.SCRIPTS, name), encoding="utf-8") as fh:
            return fh.read()

    def test_helper_checks_trust_without_a_prompt(self):
        src = self.read("duo-pose-ax.swift")
        self.assertIn("kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false", src)
        code = "\n".join(line for line in src.splitlines() if not line.lstrip().startswith("//"))
        self.assertNotIn("AXIsProcessTrusted()", code)
        for banned in ("tccutil", "x-apple.systempreferences", "Privacy_Accessibility", "sudo",
                       "NSWorkspace.shared.open", "AXMakeProcessTrusted"):
            self.assertNotIn(banned, code)

    def test_python_never_touches_permissions(self):
        for name in ("duo_pose.py", "duo_pose_matrix.py"):
            src = self.read(name)
            for banned in ("tccutil", "x-apple.systempreferences", "sudo ", "xcode-select", "simctl create",
                           "simctl clone", "simctl delete", "rmtree(args", "rmtree(out"):
                self.assertNotIn(banned, src, "%s contains %r" % (name, banned))

    def test_helper_cache_key_follows_the_source(self):
        folder = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, folder)
        a = os.path.join(folder, "a.swift")
        with open(a, "w") as fh:
            fh.write("print(1)\n")
        first = dp.helper_path(a)
        with open(a, "w") as fh:
            fh.write("print(2)\n")
        self.assertNotEqual(first, dp.helper_path(a))

    def test_helper_needs_macos(self):
        mac = fakes.FakeMac()
        mac.platform = lambda: "linux"
        with self.assertRaises(dp.PoseError) as ctx:
            dp.ensure_helper(mac)
        self.assertEqual(ctx.exception.code, dp.EXIT_NO_HELPER)


@unittest.skipUnless(os.environ.get("DUO_POSE_SWIFT") == "1" and sys.platform == "darwin" and shutil.which("xcrun"),
                     "builds the Swift helper; set DUO_POSE_SWIFT=1 on a Mac with Xcode")
class SwiftHelperTests(unittest.TestCase):
    def test_helper_builds_and_answers_trust(self):
        folder = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, folder)
        binary = os.path.join(folder, "duo-pose-ax")
        env = dict(os.environ)
        env.setdefault("DEVELOPER_DIR", dp.DEFAULT_DEVELOPER_DIR)
        subprocess.run(["xcrun", "--sdk", "macosx", "swiftc", "-O", "-o", binary, dp.HELPER_SOURCE],
                       check=True, env=env)
        out = subprocess.run([binary, "trust"], stdout=subprocess.PIPE, universal_newlines=True).stdout
        self.assertIn("trusted", json.loads(out))
        usage = subprocess.run([binary], stdout=subprocess.PIPE, universal_newlines=True)
        self.assertEqual(usage.returncode, 2)


if __name__ == "__main__":
    unittest.main()
