"""Tests for duo-fold-cost. No Mac, Xcode or simulator needed.

The XML below follows what `xctrace export` (Xcode 27.1) wrote for real traces
of an app folding on the iPhone Duo simulator: values written once with an id
and later as ref="id", a table with the same schema as the one before it
without a schema element, and process and thread names like
"FoldProbe (62983)" and "Main Thread (0x1a68c48) (FoldProbe, pid: 62983)".
"""

import io
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "scripts"))

import duo_fold_cost as fc  # noqa: E402

APP = "FoldProbe"
PID = 62983
MS = 1_000_000


class Export:
    """Builds an xctrace export with ids and refs, the way xctrace writes them."""

    def __init__(self):
        self.next_id = 1
        self.seen = {}
        self.nodes = []

    def value(self, tag, text, fmt=None, inner=""):
        key = (tag, text, fmt, inner)
        if key in self.seen:
            return '<%s ref="%d"/>' % (tag, self.seen[key])
        ident = self.next_id
        self.next_id += 1
        self.seen[key] = ident
        f = ' fmt="%s"' % fmt if fmt is not None else ""
        return '<%s id="%d"%s>%s%s</%s>' % (tag, ident, f, inner, text, tag)

    def process(self, name=APP, pid=PID):
        return self.value("process", "", "%s (%d)" % (name, pid),
                          self.value("pid", str(pid), str(pid)))

    def thread(self, main=True, name=APP, pid=PID):
        label = ("Main Thread (0x1) (%s, pid: %d)" if main else "Thread 0x2 (%s, pid: %d)") % (name, pid)
        return self.value("thread", "", label, self.value("tid", "1", "0x1") + self.process(name, pid))

    def node(self, columns, rows, with_schema=True):
        schema = ""
        if with_schema:
            schema = '<schema name="x">%s</schema>' % "".join(
                "<col><mnemonic>%s</mnemonic></col>" % c for c in columns)
        self.nodes.append("<node>%s%s</node>" % (schema, "".join("<row>%s</row>" % "".join(r) for r in rows)))

    def xml(self):
        return '<?xml version="1.0"?><trace-query-result>%s</trace-query-result>' % "".join(self.nodes)


RUNLOOP_COLS = ["timestamp", "interval-type", "event-type", "thread"]
SIGNPOST_COLS = ["time", "thread", "process", "event-type", "identifier", "name", "subsystem", "category"]
HANG_COLS = ["start", "duration", "hang-type", "thread", "process"]


def runloop(stretches, main=True, split_tables=False):
    """Run-loop events for main-thread stretches [(start ms, end ms)]: wake at start, sleep at end."""
    x = Export()
    rows = []
    for start, end in stretches:
        for t, kind in ((start, "END"), (end, "START")):
            rows.append([x.value("event-time", str(int(t * MS))),
                         x.value("short-string", "waiting_for_events", "waiting_for_events"),
                         x.value("kdebug-func", "1" if kind == "START" else "2", kind),
                         x.thread(main)])
    if split_tables:
        half = len(rows) // 2
        x.node(RUNLOOP_COLS, rows[:half])
        x.node(RUNLOOP_COLS, rows[half:], with_schema=False)
    else:
        x.node(RUNLOOP_COLS, rows)
    return x.xml()


def signposts(items, process=APP):
    """items: (begin ms, end ms or None for an event, subsystem, category, name)."""
    x = Export()
    rows = []
    for n, (begin, end, sub, cat, name) in enumerate(items):
        ident = str(1000 + n)
        common = [x.thread(True, process), x.process(process)]
        tail = [x.value("os-signpost-identifier", ident, ident), x.value("signpost-name", name, name),
                x.value("subsystem", sub, sub), x.value("category", cat, cat)]
        if end is None:
            rows.append([x.value("event-time", str(int(begin * MS)))] + common
                        + [x.value("event-type", "Event", "Event")] + tail)
            continue
        rows.append([x.value("event-time", str(int(begin * MS)))] + common
                    + [x.value("event-type", "Begin", "Begin")] + tail)
        rows.append([x.value("event-time", str(int(end * MS)))] + common
                    + [x.value("event-type", "End", "End")] + tail)
    x.node(SIGNPOST_COLS, rows)
    return x.xml()


def hang_table(items):
    x = Export()
    rows = [[x.value("start-time", str(int(s * MS))), x.value("duration", str(int((e - s) * MS))),
             x.value("hang-type", kind, kind), x.thread(True), x.process()] for s, e, kind in items]
    x.node(HANG_COLS, rows)
    return x.xml()


PROFILE_COLS = ["time", "thread", "process", "weight", "stack"]


def profile(samples):
    """Time Profiler rows: (ms, [(function, binary)] innermost first). Frames and backtraces repeat by ref."""
    x = Export()
    rows = []
    for at, frames in samples:
        inner = "".join(frame_xml(x, name, binary) for name, binary in frames)
        rows.append([x.value("sample-time", str(int(at * MS))), x.thread(True), x.process(),
                     x.value("weight", "1000000", "1.00 ms"), x.value("tagged-backtrace", "", None, inner)])
    x.node(PROFILE_COLS, rows)
    return x.xml()


def frame_xml(x, name, binary):
    key = ("frame", name, binary)
    if key in x.seen:
        return '<frame ref="%d"/>' % x.seen[key]
    ident = x.next_id
    x.next_id += 1
    x.seen[key] = ident
    bkey = ("binary", binary)
    if bkey in x.seen:
        b = '<binary ref="%d"/>' % x.seen[bkey]
    else:
        x.seen[bkey] = x.next_id
        b = '<binary id="%d" name="%s"/>' % (x.next_id, binary)
        x.next_id += 1
    return '<frame id="%d" name="%s" addr="0x1">%s</frame>' % (ident, name, b)


def resize(at_ms, dur=0.2):
    return (at_ms, at_ms + dur, "com.apple.UIKit", "Window", "UpdateSceneMetrics")


def stall(at_ms, dur):
    return (at_ms, at_ms + dur, "com.apple.UIKit", "UpdateCycle.Stalls", "UpdateSequence")


def ax_call(at_ms):
    return (at_ms, at_ms + 0.1, "com.apple.Accessibility", "AXUIA", "Automation")


TOC = "<trace-toc><run number=\"1\"><info><summary><start-date>2026-11-06T02:04:31.000+01:00</start-date>" \
      "</summary></info><data><table schema=\"runloop-events\"/><table schema=\"os-signpost\" " \
      "target-pid=\"SINGLE\"/><table schema=\"potential-hangs\"/></data></run></trace-toc>"
START = fc.trace_start(TOC)


def two_folds():
    """An open at 7.3 s (three resizes, slow) and a close at 24.1 s, like the measured probe."""
    return {
        "toc": TOC,
        "runloop": runloop([(7250, 7258), (7290, 7650), (7700, 7710), (24110, 24250), (30000, 30001)]),
        "signposts": signposts([resize(7289), resize(7360), resize(7368, 28), stall(7293, 349),
                                resize(24054), resize(24112, 36), (7315, None, "com.example", "Fold", "Resize")]),
        "hangs": hang_table([(7290, 7650, "Microhang"), (24110, 24250, "Brief Unresponsiveness")]),
    }


class ReadingExports(unittest.TestCase):
    def test_refs_resolve_across_tables_without_their_own_schema(self):
        xml = runloop([(10, 20), (30, 45), (50, 52), (60, 90)], split_tables=True)
        self.assertEqual(fc.main_thread_stretches(xml, APP),
                         [(10 * MS, 20 * MS), (30 * MS, 45 * MS), (50 * MS, 52 * MS), (60 * MS, 90 * MS)])

    def test_other_threads_and_processes_are_ignored(self):
        self.assertEqual(fc.main_thread_stretches(runloop([(10, 20)], main=False), APP), [])
        self.assertEqual(fc.main_thread_stretches(runloop([(10, 20)]), "Other"), [])

    def test_a_name_that_starts_another_name_is_not_a_match(self):
        xml = signposts([resize(100)], process="FoldProbeHelper")
        self.assertEqual(fc.signpost_intervals(xml, APP), [])

    def test_signposts_pair_begin_and_end(self):
        found = fc.signpost_intervals(signposts([resize(100, 5), (200, None, "s", "c", "E")]), APP)
        self.assertEqual(found, [(100 * MS, 105 * MS, "com.apple.UIKit", "Window", "UpdateSceneMetrics"),
                                 (200 * MS, 200 * MS, "s", "c", "E")])

    def test_hangs_on_the_main_thread(self):
        self.assertEqual(fc.hangs(hang_table([(5, 260, "Microhang")]), APP), [(5 * MS, 260 * MS, "Microhang")])

    def test_trace_start_reads_the_offset(self):
        self.assertAlmostEqual(START, 1793927071.0, places=3)
        self.assertIsNone(fc.trace_start("<trace-toc/>"))


class Folds(unittest.TestCase):
    def test_resizes_close_together_are_one_fold(self):
        sp = fc.signpost_intervals(signposts([resize(7289), resize(7360), resize(7368, 28), resize(24054)]), APP)
        folds = fc.find_folds(sp)
        self.assertEqual(len(folds), 2)
        self.assertEqual(folds[0][0], int((7289 - fc.LEAD_S * 1000) * MS))
        self.assertEqual(folds[0][1], int((7396 + fc.TAIL_S * 1000) * MS))

    def test_measure(self):
        report = fc.analyze(two_folds(), APP)
        opening, closing = report["folds"]
        self.assertEqual(opening["longest_ms"], 360.0)
        self.assertEqual(opening["busy_ms"], 378.0)      # 8 + 360 + 10
        self.assertEqual(opening["over_frame"], 2)       # 360 and 10 are longer than 8.3 ms
        self.assertEqual((opening["stalls"], opening["stall_longest_ms"]), (1, 349.0))
        self.assertEqual((opening["hangs"], opening["hang_longest_ms"]), (1, 360.0))
        self.assertEqual(closing["longest_ms"], 140.0)
        self.assertEqual(closing["hangs"], 1)

    def test_work_long_after_the_fold_is_not_counted(self):
        report = fc.analyze(two_folds(), APP)
        self.assertNotIn(1.0, [f["longest_ms"] for f in report["folds"]])

    def test_stretches_with_accessibility_reads_are_left_out(self):
        exports = two_folds()
        exports["signposts"] = signposts([resize(7289), ax_call(7252)])
        fold = fc.analyze(exports, APP)["folds"][0]
        self.assertEqual(fold["skipped"], 1)
        self.assertEqual(fold["busy_ms"], 370.0)

    def test_folds_take_the_name_of_the_pose_command(self):
        commands = [{"pose": "open", "from": "closed", "started": START + 3.0},
                    {"pose": "closed", "from": "open", "started": START + 18.0}]
        report = fc.analyze(two_folds(), APP, commands)
        self.assertEqual([fc.fold_name(f) for f in report["folds"]], ["closed -> open", "open -> closed"])
        self.assertEqual([s["fold"] for s in report["summary"]], ["closed -> open", "open -> closed"])

    def test_bursts_of_one_command_merge(self):
        exports = two_folds()
        exports["signposts"] = signposts([resize(7289), stall(7293, 20), resize(9000), stall(9001, 30)])
        exports["runloop"] = runloop([(7290, 7300), (9000, 9040)])
        commands = [{"pose": "closed", "from": "tabletop", "started": START + 3.0}]
        report = fc.analyze(exports, APP, commands)
        self.assertEqual(len(report["folds"]), 1)
        fold = report["folds"][0]
        self.assertEqual((fold["bursts"], fold["stalls"], fold["longest_ms"], fold["busy_ms"]), (2, 2, 40.0, 50.0))

    def test_without_a_pose_log_each_fold_keeps_its_own_row(self):
        report = fc.analyze(two_folds(), APP)
        self.assertEqual([s["fold"] for s in report["summary"]], ["fold 1", "fold 2"])

    def test_summary_takes_medians(self):
        folds = [dict(f, **{"from": "closed", "to": "open"}) for f in (
            {"longest_ms": 70.0, "busy_ms": 150.0, "stalls": 2, "hangs": 0},
            {"longest_ms": 20.0, "busy_ms": 70.0, "stalls": 1, "hangs": 0},
            {"longest_ms": 30.0, "busy_ms": 72.0, "stalls": 1, "hangs": 1})]
        (s,) = fc.summarize(folds)
        self.assertEqual((s["count"], s["longest_ms"], s["busy_ms"], s["stalls"], s["hangs"]), (3, 30.0, 72.0, 1, 0))


class TimeProfiler(unittest.TestCase):
    SORT = [("closure #1 in slowSorted(_:)", APP), ("specialized MutableCollection.sort", "libswiftCore.dylib"),
            ("RootView.body.getter", APP), ("static FoldProbeApp.$main()", APP)]
    SYSTEM = [("CA::Transaction::commit()", "QuartzCore"), ("static FoldProbeApp.$main()", APP)]

    def test_samples_keep_app_frames_without_the_entry_point(self):
        samples = fc.main_thread_samples(profile([(7300, self.SORT), (7301, self.SYSTEM)]), APP)
        self.assertEqual(samples, [(7300 * MS, ["closure #1 in slowSorted(_:)", "RootView.body.getter"]),
                                   (7301 * MS, [])])

    def test_the_longest_stretch_names_the_code_in_it(self):
        exports = two_folds()
        exports["profile"] = profile([(7300 + i, self.SORT) for i in range(8)]
                                     + [(7400 + i, self.SYSTEM) for i in range(2)]
                                     + [(9000, self.SORT)])   # outside the stretch
        fold = fc.analyze(exports, APP)["folds"][0]
        self.assertEqual(fold["in_longest"], [{"name": "closure #1 in slowSorted(_:)", "share": 0.8},
                                              {"name": "(system)", "share": 0.2}])

    def test_without_samples_nothing_is_named(self):
        self.assertEqual(fc.analyze(two_folds(), APP)["folds"][0]["in_longest"], [])


class Compare(unittest.TestCase):
    saved = {"summary": [{"fold": "closed -> open", "longest_ms": 29.0, "busy_ms": 71.0}]}

    def test_measured_noise_is_not_slower(self):
        now = [{"fold": "closed -> open", "longest_ms": 30.0, "busy_ms": 72.0}]
        self.assertEqual(fc.compare(now, self.saved), [])

    def test_a_large_growth_is_slower(self):
        now = [{"fold": "closed -> open", "longest_ms": 486.0, "busy_ms": 517.0}]
        self.assertEqual(fc.compare(now, self.saved), [("closed -> open", "longest_ms", 29.0, 486.0),
                                                      ("closed -> open", "busy_ms", 71.0, 517.0)])

    def test_it_needs_both_the_share_and_the_ms(self):
        small = {"summary": [{"fold": "a -> b", "longest_ms": 4.0, "busy_ms": 200.0}]}
        now = [{"fold": "a -> b", "longest_ms": 12.0, "busy_ms": 235.0}]
        self.assertEqual(fc.compare(now, small), [])   # +8 ms is under 20 ms; +35 ms is under 25 %

    def test_faster(self):
        before = {"summary": [{"fold": "closed -> open", "longest_ms": 2913.0, "busy_ms": 4370.0}]}
        now = [{"fold": "closed -> open", "longest_ms": 86.0, "busy_ms": 115.0}]
        self.assertEqual(fc.compare(now, before), [])
        self.assertEqual(fc.compare(now, before, faster=True),
                         [("closed -> open", "longest_ms", 2913.0, 86.0), ("closed -> open", "busy_ms", 4370.0, 115.0)])

    def test_a_fold_missing_from_the_saved_run_is_skipped(self):
        self.assertEqual(fc.compare([{"fold": "x -> y", "longest_ms": 900.0, "busy_ms": 900.0}], self.saved), [])


class FakeRunner:
    """Answers the commands duo-fold-cost runs; records them."""

    def __init__(self, exports, pose_now="closed", installed=True, booted=True, pose_fails=None,
                 launch_fails=False):
        self.exports = exports
        self.pose_now = pose_now
        self.installed = installed
        self.booted = booted
        self.pose_fails = pose_fails
        self.launch_fails = launch_fails
        self.calls = []
        self.clock = START + 1.0
        self.stopped = False
        self.app_dir = tempfile.mkdtemp(suffix=".app")
        with open(os.path.join(self.app_dir, "Info.plist"), "wb") as fh:
            import plistlib
            plistlib.dump({"CFBundleExecutable": APP}, fh)

    def run(self, argv, timeout=120):
        self.calls.append(argv)
        if argv[:3] == ["xcrun", "simctl", "list"]:
            state = "Booted" if self.booted else "Shutdown"
            return 0, json.dumps({"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
                {"name": "iPhone 17", "udid": "OTHER", "state": "Booted",
                 "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17"},
                {"name": "iPhone Duo", "udid": "DUO", "state": state, "deviceTypeIdentifier": fc.DUO_TYPE}]}}), ""
        if argv[:3] == ["xcrun", "simctl", "get_app_container"]:
            return (0, self.app_dir + "\n", "") if self.installed else (2, "", "No such app")
        if argv[:3] == ["xcrun", "simctl", "launch"]:
            return (1, "", "launch failed") if self.launch_fails else (0, "com.example: 4242\n", "")
        if argv[0] == fc.DUO_POSE and argv[1] == "status":
            return 0, json.dumps({"state": {"pose": self.pose_now}}), ""
        if argv[0] == fc.DUO_POSE and argv[1] == "set":
            if self.pose_fails == argv[2]:
                return 3, json.dumps({"ok": False, "code": 3, "error": "not allowed to use Accessibility"}), ""
            self.clock += 1.0
            return 0, json.dumps({"ok": True}), ""
        if argv[:3] == ["xcrun", "xctrace", "export"]:
            if "--toc" in argv:
                return 0, self.exports["toc"], ""
            xpath = argv[argv.index("--xpath") + 1]
            for schema, key in (("runloop-events", "runloop"), ("os-signpost", "signposts"),
                                ("potential-hangs", "hangs")):
                if '"%s"' % schema in xpath:
                    return 0, self.exports[key], ""
        return 1, "", "unexpected: %s" % " ".join(argv)

    def start(self, argv, log_path):
        self.calls.append(argv)
        self.trace = argv[argv.index("--output") + 1]
        os.makedirs(self.trace)
        return {"log": log_path}

    def wait_for_text(self, handle, text, timeout):
        return True

    def stop(self, handle, timeout):
        self.stopped = True
        return 0

    def read_log(self, handle):
        return ""

    def sleep(self, seconds):
        self.clock += seconds

    def now(self):
        return self.clock

    def note(self, text):
        pass


class Run(unittest.TestCase):
    def setUp(self):
        self.out_dir = tempfile.mkdtemp()
        self.duo_pose = fc.DUO_POSE
        fc.DUO_POSE = __file__   # any file that exists

    def tearDown(self):
        fc.DUO_POSE = self.duo_pose

    def main(self, argv, runner):
        out, err = io.StringIO(), io.StringIO()
        code = fc.main(argv, runner=runner, out=out, err=err)
        return code, out.getvalue(), err.getvalue()

    def test_run_folds_records_and_reports(self):
        runner = FakeRunner(two_folds())
        code, out, err = self.main(["run", "com.example.app", "--cycles", "1", "--out", self.out_dir,
                                    "--json", "--", "-slow"], runner)
        self.assertEqual(code, fc.EXIT_OK, err)
        report = json.loads(out)
        self.assertEqual(len(report["folds"]), 2)
        self.assertTrue(runner.stopped)
        record = next(c for c in runner.calls if c[:3] == ["xcrun", "xctrace", "record"])
        self.assertIn("--attach", record)
        self.assertEqual(record[record.index("--attach") + 1], APP)
        self.assertEqual(record.count("--instrument"), 2)
        launch = next(c for c in runner.calls if c[:3] == ["xcrun", "simctl", "launch"])
        self.assertEqual(launch[-2:], ["com.example.app", "-slow"])
        sets = [c[2] for c in runner.calls if c[0] == fc.DUO_POSE and c[1] == "set"]
        self.assertEqual(sets, ["closed", "open", "closed"])   # start pose, then the cycle
        self.assertTrue(os.path.exists(runner.trace + ".poses.json"))

    def test_the_pose_found_is_put_back(self):
        runner = FakeRunner(two_folds(), pose_now="open or book")
        code, _, err = self.main(["run", "com.example.app", "--cycles", "1", "--out", self.out_dir], runner)
        self.assertEqual(code, fc.EXIT_OK, err)
        sets = [c[2] for c in runner.calls if c[0] == fc.DUO_POSE and c[1] == "set"]
        self.assertEqual(sets[-1], "open")

    def sets(self, runner):
        return [c[2] for c in runner.calls if c[0] == fc.DUO_POSE and c[1] == "set"]

    def test_a_failed_pose_change_still_puts_the_phone_back(self):
        runner = FakeRunner(two_folds(), pose_now="closed", pose_fails="open")
        code, _, _ = self.main(["run", "com.example.app", "--out", self.out_dir], runner)
        self.assertEqual(code, fc.EXIT_POSE)
        self.assertEqual(self.sets(runner), ["closed", "open", "closed"])   # tried open, then back

    def test_a_failed_launch_puts_the_phone_back(self):
        runner = FakeRunner(two_folds(), pose_now="open or book", launch_fails=True)
        code, _, _ = self.main(["run", "com.example.app", "--out", self.out_dir], runner)
        self.assertEqual(code, fc.EXIT_NO_APP)
        self.assertEqual(self.sets(runner), ["closed", "open"])
        self.assertFalse(runner.stopped)   # nothing was recording yet

    def test_tabletop_is_put_back_as_tabletop(self):
        runner = FakeRunner(two_folds(), pose_now="tabletop (or open, held tall)")
        self.main(["run", "com.example.app", "--cycles", "1", "--out", self.out_dir], runner)
        self.assertEqual(self.sets(runner)[-1], "tabletop")

    def test_a_broken_pose_log_is_a_usage_error(self):
        trace = os.path.join(self.out_dir, "y.trace")
        os.makedirs(trace)
        with open(trace + ".poses.json", "w") as fh:
            fh.write("{not json")
        code, _, err = self.main(["read", trace, "--process", APP], FakeRunner(two_folds()))
        self.assertEqual(code, fc.EXIT_USAGE)
        self.assertIn("pose log", err)

    def test_an_export_that_is_not_xml_is_a_trace_error(self):
        trace = os.path.join(self.out_dir, "z.trace")
        os.makedirs(trace)
        exports = dict(two_folds(), runloop="<trace-query-result><node>")
        code, _, _ = self.main(["read", trace, "--process", APP], FakeRunner(exports))
        self.assertEqual(code, fc.EXIT_TRACE)

    def test_compare_exits_1_when_slower(self):
        saved = os.path.join(self.out_dir, "before.json")
        with open(saved, "w") as fh:
            json.dump({"summary": [{"fold": "closed -> open", "longest_ms": 29.0, "busy_ms": 71.0}]}, fh)
        code, out, _ = self.main(["run", "com.example.app", "--cycles", "1", "--out", self.out_dir,
                                  "--compare", saved], FakeRunner(two_folds()))
        self.assertEqual(code, fc.EXIT_SLOWER)
        self.assertIn("slower closed -> open: longest 29 ms -> 360 ms", out)

    def test_save_writes_a_report_compare_can_read(self):
        saved = os.path.join(self.out_dir, "run.json")
        self.main(["run", "com.example.app", "--cycles", "1", "--out", self.out_dir, "--save", saved],
                  FakeRunner(two_folds()))
        code, _, _ = self.main(["run", "com.example.app", "--cycles", "1", "--out", self.out_dir,
                                "--compare", saved], FakeRunner(two_folds()))
        self.assertEqual(code, fc.EXIT_OK)

    def test_no_booted_duo(self):
        code, _, err = self.main(["run", "com.example.app", "--out", self.out_dir], FakeRunner(two_folds(), booted=False))
        self.assertEqual(code, fc.EXIT_NO_SIMULATOR)
        self.assertIn("never creates one", err)

    def test_app_not_installed(self):
        code, _, _ = self.main(["run", "com.example.app", "--out", self.out_dir], FakeRunner(two_folds(), installed=False))
        self.assertEqual(code, fc.EXIT_NO_APP)

    def test_duo_pose_failure_stops_the_recording(self):
        runner = FakeRunner(two_folds(), pose_fails="open")
        code, out, _ = self.main(["run", "com.example.app", "--out", self.out_dir, "--json"], runner)
        self.assertEqual(code, fc.EXIT_POSE)
        self.assertTrue(runner.stopped)
        self.assertIn("not allowed to use Accessibility", json.loads(out)["error"]["message"])

    def test_no_fold_in_the_trace(self):
        exports = dict(two_folds(), signposts=signposts([]))
        code, _, _ = self.main(["run", "com.example.app", "--out", self.out_dir], FakeRunner(exports))
        self.assertEqual(code, fc.EXIT_NO_FOLD)

    def test_read_uses_the_pose_log_beside_the_trace(self):
        trace = os.path.join(self.out_dir, "x.trace")
        os.makedirs(trace)
        with open(trace + ".poses.json", "w") as fh:
            json.dump([{"pose": "open", "from": "closed", "started": START + 3.0}], fh)
        code, out, _ = self.main(["read", trace, "--process", APP], FakeRunner(two_folds()))
        self.assertEqual(code, fc.EXIT_OK)
        self.assertIn("closed -> open", out)

    def test_bad_arguments(self):
        for argv in (["run", "x", "--poses", "open"], ["run", "x", "--poses", "open,flat"],
                     ["run", "x", "--cycles", "0"], ["read", "t", "--process", "P", "--", "-slow"]):
            with self.assertRaises(SystemExit) as caught:
                fc.parse_args(argv)
            self.assertEqual(caught.exception.code, fc.EXIT_USAGE)


if __name__ == "__main__":
    unittest.main()
