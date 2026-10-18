#!/usr/bin/env python3
"""Tests for duo-pose-matrix: arguments, summary output and a full run on FakeMac.

Run from the repo root:
  python3 -m unittest discover plugins/duology-ship/skills/duo-pose-matrix/tests -v
"""

import importlib.util
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import duo_pose_fakes as fakes  # noqa: E402

sys.path.insert(0, fakes.SCRIPTS)
_spec = importlib.util.spec_from_file_location("duo_pose_matrix", os.path.join(fakes.SCRIPTS, "duo_pose_matrix.py"))
dm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dm)
dp = dm.dp


class Run:
    """Runs duo-pose-matrix on a FakeMac with a temporary output folder."""

    def __init__(self, test):
        self.out = tempfile.mkdtemp(prefix="duo-poses-test-")
        test.addCleanup(shutil.rmtree, self.out, True)

    def __call__(self, argv, mac):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(dp, "ensure_helper", return_value=fakes.HELPER):
            code = dm.main([fakes.BUNDLE, "--out", self.out] + argv, system=mac, out=out, err=err)
        self.stdout, self.stderr = out.getvalue(), err.getvalue()
        return code

    def summary(self):
        with open(os.path.join(self.out, "summary.json"), encoding="utf-8") as fh:
            return json.load(fh)

    def markdown(self):
        with open(os.path.join(self.out, "summary.md"), encoding="utf-8") as fh:
            return fh.read()

    def pngs(self):
        return sorted(n for n in os.listdir(self.out) if n.endswith(".png"))


CASES = ["--case", "listDetail=-pattern listDetail", "--case", "twoPage=-pattern twoPage"]


class ArgumentTests(unittest.TestCase):
    def test_parse_case(self):
        self.assertEqual(dm.parse_case("listDetail=-pattern listDetail -select 1"),
                         {"name": "listDetail", "args": ["-pattern", "listDetail", "-select", "1"]})
        self.assertEqual(dm.parse_case("two words=-a 'b c'"), {"name": "two-words", "args": ["-a", "b c"]})
        for bad in ("noequals", "=-pattern x", "x=-a 'unclosed"):
            with self.assertRaises(Exception):
                dm.parse_case(bad)

    def test_safe_name(self):
        self.assertEqual(dm.safe_name("../../etc/passwd"), "etc-passwd")
        self.assertEqual(dm.safe_name("***"), "case")

    def test_parse_poses(self):
        self.assertEqual(dm.parse_poses("all"), list(dp.POSES))
        self.assertEqual(dm.parse_poses("book, open,book"), ["book", "open"])
        for bad in ("tent", "", " , "):
            with self.assertRaises(Exception):
                dm.parse_poses(bad)

    def test_split_argv(self):
        self.assertEqual(dm.split_argv(["a", "--", "-pattern", "x", "--", "y"]), (["a"], ["-pattern", "x", "--", "y"]))
        self.assertEqual(dm.split_argv(["a"]), (["a"], []))

    def test_defaults(self):
        args = dm.parse_args([fakes.BUNDLE, "--", "-showsRegions", "YES"])
        self.assertEqual(args.poses, ["closed", "open", "book", "tabletop"])
        self.assertEqual(args.cases, [{"name": "app", "args": ["-showsRegions", "YES"]}])
        self.assertTrue(os.path.isabs(args.out))
        self.assertIn("duo-poses", args.out)
        self.assertEqual(args.wait, 4.0)

    def test_cases_get_the_common_arguments(self):
        args = dm.parse_args([fakes.BUNDLE] + CASES + ["--", "-showsRegions", "YES"])
        self.assertEqual(args.cases[1], {"name": "twoPage", "args": ["-pattern", "twoPage", "-showsRegions", "YES"]})

    def test_bad_combinations(self):
        for argv in ([fakes.BUNDLE, "--manual", "book", "--poses", "open"],
                     [fakes.BUNDLE, "--case", "a=-x", "--case", "a=-y"],
                     [fakes.BUNDLE, "--wait", "-2"],
                     [fakes.BUNDLE, "--manual", "tent"],
                     []):
            with mock.patch("sys.stderr", io.StringIO()):
                with self.assertRaises(SystemExit) as ctx:
                    dm.parse_args(argv)
            self.assertEqual(ctx.exception.code, 2, argv)

    def test_manual_captures_one_pose(self):
        self.assertEqual(dm.parse_args([fakes.BUNDLE, "--manual", "tabletop"]).poses, ["tabletop"])


class ParsingTests(unittest.TestCase):
    def test_parse_launchctl(self):
        apps = dm.parse_launchctl(fakes.fixture("launchctl-list.txt"))
        self.assertEqual(apps["com.example.other"], 70169)
        self.assertIsNone(apps[fakes.BUNDLE])
        self.assertNotIn("com.apple.progressd", apps)

    def test_new_foreign_apps(self):
        before = {"com.example.other": None, "com.apple.Spotlight": 1, fakes.BUNDLE: 10}
        after = {"com.example.other": 77, "com.apple.Spotlight": 2, fakes.BUNDLE: 11, "com.example.same": 5}
        self.assertEqual(dm.new_foreign_apps(before, after, fakes.BUNDLE), ["com.example.other", "com.example.same"])
        self.assertEqual(dm.new_foreign_apps(None, after, fakes.BUNDLE), [])


def shot(case, pose, status="ok", fold="not checked", notes=()):
    return {"case": case, "args": [], "pose": pose, "file": "%s-%s.png" % (case, pose), "display": "primary-1",
            "size": [2853, 2007], "expectedSize": [2853, 2007], "checks": {}, "fold": fold, "foldNote": "",
            "status": status, "notes": list(notes), "review": [], "takenAt": ""}


class SummaryTests(unittest.TestCase):
    def summary(self):
        args = dm.parse_args([fakes.BUNDLE] + CASES)
        sim = {"name": "iPhone Duo", "udid": fakes.UDID, "runtime": "iOS 27.1"}
        return dm.new_summary(args, sim, "automatic")

    def test_merge_replaces_the_same_case_and_pose(self):
        s = self.summary()
        dm.merge_shot(s, shot("twoPage", "book", status="failed"))
        dm.merge_shot(s, shot("listDetail", "closed"))
        dm.merge_shot(s, shot("twoPage", "book"))
        self.assertEqual(len(s["shots"]), 2)
        self.assertEqual([c["name"] for c in s["cases"]], ["twoPage", "listDetail"])
        self.assertEqual([x["status"] for x in s["shots"] if x["pose"] == "book"], ["ok"])

    def test_markdown(self):
        s = self.summary()
        dm.merge_shot(s, shot("listDetail", "book"))
        dm.merge_shot(s, shot("listDetail", "closed", fold="n/a"))
        dm.merge_shot(s, shot("listDetail", "tabletop", status="failed", notes=["app | crashed"]))
        s["startPose"], s["endPose"] = "closed", "closed"
        md = dm.summary_markdown(s)
        self.assertIn("# Pose matrix: dev.duology.gallery", md)
        self.assertIn("3 screenshots: 2 ok, 0 to check, 1 failed.", md)
        rows = [line for line in md.splitlines() if line.startswith("| listDetail")]
        self.assertEqual([r.split("|")[2].strip() for r in rows], ["closed", "book", "tabletop"])
        self.assertIn("[listDetail-book.png](listDetail-book.png)", md)
        self.assertIn("app \\| crashed", md)
        self.assertIn("- **book**: R4 Nothing interactive in the fold, R5 Even grids, R7 Tabletop and book layouts", md)
        self.assertNotIn("- **open**", md)
        self.assertIn("Open and book look the same to the tool", md)
        self.assertIn("doesn't prove R2", md)
        self.assertIn("Pose at the start: closed. Pose at the end: closed.", md)

    def test_review_rules_name_real_checklist_rules(self):
        names = {"R1": "No letterboxing", "R3": "No size from the main screen", "R4": "Nothing interactive in the fold",
                 "R5": "Even grids", "R6": "Side controls, symbols and titles", "R7": "Tabletop and book layouts",
                 "R10": "Same features on the outer display", "R13": "Touch targets of 44 pt"}
        for pose, rules in dm.REVIEW.items():
            for rule, name in rules:
                self.assertEqual(names[rule], name, (pose, rule))

    def test_load_summary_ignores_another_app(self):
        folder = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, folder)
        s = self.summary()
        dm.write_summary(folder, s)
        path = os.path.join(folder, "summary.json")
        self.assertIsNotNone(dm.load_summary(path, fakes.BUNDLE))
        self.assertIsNone(dm.load_summary(path, "com.example.other"))
        self.assertIsNone(dm.load_summary(os.path.join(folder, "missing.json"), fakes.BUNDLE))

    def test_manual_command(self):
        args = dm.parse_args([fakes.BUNDLE, "--out", "/tmp/o"] + CASES + ["--", "-showsRegions", "YES"])
        cmd = dm.manual_command(args, "book")
        self.assertEqual(cmd, "duo-pose-matrix dev.duology.gallery --out /tmp/o --manual book "
                              "--case 'listDetail=-pattern listDetail' --case 'twoPage=-pattern twoPage' "
                              "-- -showsRegions YES")
        self.assertEqual(dm.parse_args(__import__("shlex").split(cmd)[1:]).cases, args.cases)


class RunTests(unittest.TestCase):
    def test_full_matrix(self):
        run, mac = Run(self), fakes.FakeMac()
        code = run(CASES + ["--", "-showsRegions", "YES"], mac)
        self.assertEqual(code, 0, run.stderr)
        self.assertEqual(run.pngs(), sorted("%s-%s.png" % (c, p) for c in ("listDetail", "twoPage") for p in dp.POSES))
        s = run.summary()
        self.assertEqual(len(s["shots"]), 8)
        self.assertTrue(all(x["status"] == "ok" for x in s["shots"]), s["shots"])
        sizes = {x["pose"]: x["size"] for x in s["shots"]}
        self.assertEqual(sizes, {"closed": [1398, 2034], "open": [2853, 2007], "book": [2853, 2007],
                                 "tabletop": [2007, 2853]})
        self.assertEqual(mac.launches[0], ["-pattern", "listDetail", "-showsRegions", "YES"])
        self.assertEqual(len(mac.launches), 8)
        # Each pose presses its own fold button; tabletop adds Rotate Right. Then back to closed, portrait.
        self.assertEqual(mac.pressed, ["Closed", "Open", "Partially Open", "Partially Open", "Rotate Right",
                                       "Rotate Right", "Rotate Right", "Rotate Right", "Closed"])
        self.assertEqual((s["startPose"], s["endPose"]), ("closed", "closed"))
        self.assertIsNone(mac.app_pid)  # quit at the end
        self.assertIn("Saved 8 screenshots", run.stdout)
        md = run.markdown()
        self.assertIn("8 screenshots: 8 ok", md)

    def test_no_relaunch_keeps_the_app_running(self):
        run, mac = Run(self), fakes.FakeMac()
        code = run(CASES + ["--no-relaunch", "--poses", "closed,open"], mac)
        self.assertEqual(code, 0, run.stderr)
        self.assertEqual(len(mac.launches), 2)
        self.assertEqual(len(run.summary()["shots"]), 4)
        self.assertIn("also show R2", run.markdown())

    def test_restores_an_open_start(self):
        run, mac = Run(self), fakes.FakeMac(fold="Partially Open")
        code = run(["--poses", "closed"], mac)
        self.assertEqual(code, 0, run.stderr)
        self.assertEqual(mac.pressed, ["Closed", "Open"])
        self.assertIn("doesn't say which", run.summary()["restoreNote"])

    def test_no_restore(self):
        run, mac = Run(self), fakes.FakeMac()
        run(["--poses", "open", "--no-restore", "--keep-running"], mac)
        self.assertEqual(mac.pressed, ["Open"])
        self.assertIsNotNone(mac.app_pid)

    def test_refuses_while_ui_tests_run(self):
        run, mac = Run(self), fakes.FakeMac(busy="99 FooUITests-Runner.xctrunner\n")
        self.assertEqual(run([], mac), dp.EXIT_BUSY)
        self.assertEqual(mac.pressed, [])
        self.assertEqual(run.pngs(), [])
        self.assertIn("--force", run.stderr)

    def test_app_not_installed(self):
        run, mac = Run(self), fakes.FakeMac(installed=False)
        self.assertEqual(run([], mac), dm.EXIT_NO_APP)
        self.assertIn("not installed", run.stderr)
        self.assertEqual(mac.pressed, [])

    def test_not_trusted_prints_the_manual_route(self):
        run, mac = Run(self), fakes.FakeMac(trusted=False)
        self.assertEqual(run(CASES, mac), dp.EXIT_NOT_TRUSTED)
        self.assertIn("System Settings > Privacy & Security > Accessibility", run.stderr)
        self.assertIn("--manual closed", run.stderr)
        self.assertIn("--manual tabletop", run.stderr)
        self.assertEqual(mac.pressed, [])

    def test_manual_runs_add_up(self):
        run, mac = Run(self), fakes.FakeMac(trusted=False)
        self.assertEqual(run(["--manual", "closed"], mac), 0, run.stderr)
        mac.fold = mac.shown_fold = "Partially Open"
        mac.turns = 1
        self.assertEqual(run(["--manual", "tabletop"], mac), 0, run.stderr)
        s = run.summary()
        self.assertEqual(sorted(x["pose"] for x in s["shots"]), ["closed", "tabletop"])
        self.assertEqual(s["mode"], "manual")
        self.assertEqual(mac.pressed, [])
        self.assertNotIn("press", mac.helper_commands())

    def test_manual_run_in_the_wrong_pose_fails(self):
        run, mac = Run(self), fakes.FakeMac()
        self.assertEqual(run(["--manual", "book"], mac), dp.EXIT_FAILED)
        self.assertEqual(run.summary()["shots"][0]["status"], "failed")

    def test_a_crash_fails_the_shot(self):
        run, mac = Run(self), fakes.FakeMac(crash_in="Partially Open")
        self.assertEqual(run([], mac), dp.EXIT_FAILED)
        status = {x["pose"]: x["status"] for x in run.summary()["shots"]}
        self.assertEqual(status, {"closed": "ok", "open": "ok", "book": "failed", "tabletop": "failed"})

    def test_another_app_taking_the_screen_is_flagged(self):
        run, mac = Run(self), fakes.FakeMac(foreign_in="Open")
        self.assertEqual(run(["--poses", "closed,open"], mac), 0)
        status = {x["pose"]: x["status"] for x in run.summary()["shots"]}
        self.assertEqual(status, {"closed": "ok", "open": "check"})

    def test_skips_a_pose_without_its_button(self):
        run, mac = Run(self), fakes.FakeMac(buttons=["Closed", "Partially Open", "Open"])
        self.assertEqual(run([], mac), 0)
        s = run.summary()
        self.assertEqual(s["skipped"], [{"pose": "tabletop", "reason": "Device Hub shows no button for it"}])
        self.assertIn("Skipped:", run.markdown())

    def test_json_output(self):
        run, mac = Run(self), fakes.FakeMac()
        self.assertEqual(run(["--poses", "book", "--json"], mac), 0)
        data = json.loads(run.stdout)
        self.assertEqual(data["shots"][0]["pose"], "book")
        self.assertEqual(run.stderr, "")


if __name__ == "__main__":
    unittest.main()
