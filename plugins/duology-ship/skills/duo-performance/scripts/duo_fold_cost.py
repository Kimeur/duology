#!/usr/bin/env python3
"""duo-fold-cost: what each fold costs your app's main thread, on the iPhone Duo simulator.

  duo-fold-cost run <bundle-id> [options] [-- launch arguments]
  duo-fold-cost read <file.trace> --process <name> [options]

`run` launches the installed app, starts Instruments (xctrace) with the Hangs
and os_signpost instruments attached to it, folds and unfolds the phone with
duo-pose, stops the recording and reads it. `read` reads a trace you recorded
before, with the same instruments.

For every fold it reports:
  longest   the longest time the main thread ran without going back to its run
            loop: the app can't commit a new frame before it ends
  busy      the main thread's total running time during the fold
  stalls    UIKit's own count of update cycles that stalled, and the longest
  hangs     what the Hangs instrument reported (100 ms and longer)

With --time-profiler it also names the app's functions the main thread was in
during each fold's longest stretch, and says whether that time went to your code
or to SwiftUI and UIKit laying out views.

It finds each fold from UIKit's own scene-resize signposts, so the app needs no
changes. The simulator runs on the Mac's CPU and draws at 60 Hz: compare runs
of your app on the same Mac (--save, then --compare), and test smoothness on a
device. A phone at 120 Hz has 8.3 ms per frame.

It uses an existing iPhone Duo simulator and never creates one. Poses are set
with duo-pose (the duo-pose-matrix skill, in the same plugin), which needs the
Accessibility permission for the app that runs it, and puts the phone back in
the pose it found.

Exit codes: 0 done; 1 a fold is slower than the saved run (--compare); 2 bad
arguments; 3 Instruments failed (xctrace); 4 duo-pose failed; 5 no booted
iPhone Duo simulator; 6 no fold found in the trace; 8 the app is not installed
on the simulator, or didn't launch.

Part of Duology (MIT license). https://github.com/Kimeur/duology
"""

import argparse
import datetime
import json
import os
import plistlib
import re
import signal
import statistics
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

VERSION = "0.5.0"
HERE = os.path.dirname(os.path.realpath(__file__))
DUO_POSE_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "duo-pose-matrix", "scripts"))
DUO_POSE = os.path.join(DUO_POSE_DIR, "duo-pose")
DEFAULT_DEVELOPER_DIR = "/Applications/Xcode-27.1.app/Contents/Developer"
DUO_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"
POSES = ("closed", "open", "book", "tabletop")
INSTRUMENTS = ("Hangs", "os_signpost")

EXIT_OK = 0
EXIT_SLOWER = 1
EXIT_USAGE = 2
EXIT_TRACE = 3
EXIT_POSE = 4
EXIT_NO_SIMULATOR = 5
EXIT_NO_FOLD = 6
EXIT_NO_APP = 8

FRAME_MS_120 = 1000.0 / 120
# The app's main function is under every sample; it says nothing about the fold.
ENTRY_POINT = re.compile(r"^main$|\$main\(\)$")
# A fold is one burst of scene resizes. Resizes further apart than this start a new fold.
FOLD_GAP_S = 1.0
# The window read around a burst: work just before the first resize (the app hears
# the hinge first) and the frames after the last one.
LEAD_S = 0.15
TAIL_S = 0.5
# --compare: a fold is slower when a median grew by both this share and this many ms.
SLOWER_SHARE = 0.25
SLOWER_MS = 20.0


class CostError(Exception):
    """A problem with a plain-words message, a hint and an exit code."""

    def __init__(self, code, message, hint=""):
        super().__init__(message)
        self.code = code
        self.message = message
        self.hint = hint


# --------------------------------------------------------------------------
# Reading xctrace exports
# --------------------------------------------------------------------------

def export_rows(xml_text, ids=None):
    """Rows of an `xctrace export --xpath` result, as {column mnemonic: element}.

    Values are written once with an id and later as ref="id", across every table
    in the export; a table with the same schema as the one before has no schema
    element of its own. The XML comes from xctrace on this Mac.
    """
    root = ET.fromstring(xml_text)
    ids = {} if ids is None else ids
    cols = []
    for node in root.iter("node"):
        schema = node.find("schema")
        if schema is not None:
            cols = [c.findtext("mnemonic") for c in schema.findall("col")]
        for row in node.findall("row"):
            values = []
            for el in row:
                for sub in el.iter():
                    if "id" in sub.attrib:
                        ids[sub.attrib["id"]] = sub
                if "ref" in el.attrib:
                    el = ids.get(el.attrib["ref"], el)
                values.append(el)
            yield dict(zip(cols, values))


def fmt(row, column):
    el = row.get(column)
    if el is None:
        return ""
    return el.attrib.get("fmt", el.text or "")


def number(row, column):
    el = row.get(column)
    try:
        return int(el.text)
    except (AttributeError, TypeError, ValueError):
        return None


def in_process(row, process, column="process"):
    """True when the row comes from `process`, written "Name (pid)" by xctrace."""
    return fmt(row, column).startswith(process + " (")


def on_main_thread(row, process):
    text = fmt(row, "thread")
    return text.startswith("Main Thread") and ("(%s, pid:" % process) in text


def main_thread_stretches(runloop_xml, process):
    """[(start ns, end ns)]: each time the main thread woke from its run loop until it slept again."""
    out = []
    woke = None
    for row in export_rows(runloop_xml):
        if fmt(row, "interval-type") != "waiting_for_events" or not on_main_thread(row, process):
            continue
        t = number(row, "timestamp")
        kind = fmt(row, "event-type")
        if kind == "END":
            woke = t
        elif kind == "START" and woke is not None:
            out.append((woke, t))
            woke = None
    return out


def signpost_intervals(signpost_xml, process):
    """[(begin ns, end ns, subsystem, category, name)] for the app's signposts; events have begin == end."""
    open_ = {}
    out = []
    for row in export_rows(signpost_xml):
        if not in_process(row, process):
            continue
        sub, cat, name = fmt(row, "subsystem"), fmt(row, "category"), fmt(row, "name")
        t = number(row, "time")
        kind = fmt(row, "event-type")
        key = (sub, cat, name, fmt(row, "identifier"))
        if kind == "Begin":
            open_[key] = t
        elif kind == "End" and key in open_:
            out.append((open_.pop(key), t, sub, cat, name))
        elif kind == "Event":
            out.append((t, t, sub, cat, name))
    out.sort()
    return out


def hangs(hangs_xml, process):
    """[(start ns, end ns, type)] the Hangs instrument found on the app's main thread."""
    out = []
    for row in export_rows(hangs_xml):
        if not on_main_thread(row, process):
            continue
        start, duration = number(row, "start"), number(row, "duration")
        if start is not None and duration is not None:
            out.append((start, start + duration, fmt(row, "hang-type")))
    return out


def resolved(el, ids):
    return ids.get(el.attrib["ref"], el) if el is not None and "ref" in el.attrib else el


def main_thread_samples(profile_xml, process):
    """[(time ns, [function names])] for Time Profiler samples on the main thread.

    The names are the app's own frames, innermost first: frames whose binary is the
    app's executable, without its entry point. Instruments names them from the app
    binary's symbols; a stripped binary gives addresses.
    """
    ids = {}
    out = []
    for row in export_rows(profile_xml, ids):
        if not on_main_thread(row, process):
            continue
        names = []
        for frame in list(row.get("stack") if row.get("stack") is not None else []):
            frame = resolved(frame, ids)
            binary = resolved(frame.find("binary"), ids)
            name = frame.attrib.get("name", "?")
            if binary is not None and binary.attrib.get("name") == process and not ENTRY_POINT.search(name):
                names.append(name)
        out.append((number(row, "time"), names))
    return out


def trace_start(toc_xml):
    """The recording's start as a Unix time, from the table of contents."""
    m = re.search(r"<start-date>([^<]+)</start-date>", toc_xml)
    if not m:
        return None
    try:
        return datetime.datetime.fromisoformat(m.group(1)).timestamp()
    except ValueError:
        return None


# --------------------------------------------------------------------------
# Folds
# --------------------------------------------------------------------------

def is_resize(sp):
    return sp[2] == "com.apple.UIKit" and sp[3] == "Window" and sp[4] == "UpdateSceneMetrics"


def is_stall(sp):
    return sp[2] == "com.apple.UIKit" and sp[3] == "UpdateCycle.Stalls"


def is_accessibility(sp):
    return sp[2] == "com.apple.Accessibility"


def find_folds(signposts):
    """[(start ns, end ns)] windows around each burst of scene resizes."""
    bursts = []
    for begin, end, *_ in (sp for sp in signposts if is_resize(sp)):
        if bursts and begin - bursts[-1][1] <= FOLD_GAP_S * 1e9:
            bursts[-1][1] = max(bursts[-1][1], end)
        else:
            bursts.append([begin, end])
    return [(int(b - LEAD_S * 1e9), int(e + TAIL_S * 1e9)) for b, e in bursts]


def in_your_code(samples, start, end, top=3):
    """The app functions the main thread was in during [start, end]: [{"name", "share"}].

    Each sample counts for its innermost app frame; samples with no app frame (SwiftUI,
    UIKit and other system code) count as "(system)", so the shares add up to the stretch.
    """
    counts = {}
    total = 0
    for t, names in samples:
        if t is None or not start <= t <= end:
            continue
        total += 1
        key = names[0] if names else "(system)"
        counts[key] = counts.get(key, 0) + 1
    ranked = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:top]
    return [{"name": name, "share": round(n / total, 2)} for name, n in ranked] if total else []


def measure_fold(window, stretches, signposts, hang_rows, samples=None):
    """The costs inside one fold window. Times are in ms.

    A stretch with an Accessibility call in it is left out: that is a tool such
    as duo-pose reading the screen through Device Hub, not the app's own work.
    """
    lo, hi = window
    ax_times = [sp[0] for sp in signposts if is_accessibility(sp) and lo <= sp[0] < hi]
    inside, skipped = [], 0
    for s, e in stretches:
        if not lo <= s < hi:
            continue
        if any(s <= t <= e for t in ax_times):
            skipped += 1
        else:
            inside.append((s, e))
    stalls = [(sp[0], sp[1]) for sp in signposts if is_stall(sp) and lo <= sp[0] < hi]
    found = [(s, e, kind) for s, e, kind in hang_rows if lo <= s < hi]
    longest = max(inside, key=lambda se: se[1] - se[0], default=None)
    return {
        "in_longest": in_your_code(samples, *longest) if samples and longest else [],
        "start_s": round(lo / 1e9 + LEAD_S, 3),
        "longest_ms": round(max((e - s for s, e in inside), default=0) / 1e6, 1),
        "busy_ms": round(sum(e - s for s, e in inside) / 1e6, 1),
        "over_frame": sum(1 for s, e in inside if (e - s) / 1e6 > FRAME_MS_120),
        "stalls": len(stalls),
        "stall_longest_ms": round(max((e - s for s, e in stalls), default=0) / 1e6, 1),
        "hangs": len(found),
        "hang_longest_ms": round(max((e - s for s, e, _ in found), default=0) / 1e6, 1),
        "skipped": skipped,
    }


def label_folds(folds, commands, start_unix):
    """Name each fold after the pose command running when it began.

    commands: [{"pose", "from", "started"}] with Unix times. A fold that began
    before any command (or with no command log) is called "unknown".
    """
    for fold in folds:
        fold["from"] = fold["to"] = "unknown"
        fold["command"] = None
        if start_unix is None:
            continue
        at = start_unix + fold["start_s"]
        for index, cmd in enumerate(commands):
            if cmd["started"] <= at:
                fold["from"], fold["to"], fold["command"] = cmd["from"], cmd["pose"], index
    return folds


def merge_by_command(folds):
    """One result per pose change: some changes resize the app in several bursts."""
    merged = []
    for fold in folds:
        last = merged[-1] if merged else None
        if last and fold["command"] is not None and fold["command"] == last["command"]:
            if fold["longest_ms"] > last["longest_ms"]:
                last["in_longest"] = fold["in_longest"]
            last["longest_ms"] = max(last["longest_ms"], fold["longest_ms"])
            last["stall_longest_ms"] = max(last["stall_longest_ms"], fold["stall_longest_ms"])
            last["hang_longest_ms"] = max(last["hang_longest_ms"], fold["hang_longest_ms"])
            for key in ("busy_ms", "over_frame", "stalls", "hangs", "skipped"):
                last[key] = round(last[key] + fold[key], 1)
            last["bursts"] += 1
        else:
            merged.append(dict(fold, bursts=1))
    return merged


def fold_name(fold):
    return "%s -> %s" % (fold["from"], fold["to"])


def summarize(folds):
    """Medians per change of pose ("closed -> open"), in the order first seen."""
    groups = {}
    for index, fold in enumerate(folds, 1):
        name = fold_name(fold) if fold["to"] != "unknown" else "fold %d" % index
        groups.setdefault(name, []).append(fold)
    summary = []
    for name, items in groups.items():
        summary.append({
            "fold": name,
            "count": len(items),
            "longest_ms": round(statistics.median(f["longest_ms"] for f in items), 1),
            "busy_ms": round(statistics.median(f["busy_ms"] for f in items), 1),
            "stalls": round(statistics.median(f["stalls"] for f in items), 1),
            "hangs": round(statistics.median(f["hangs"] for f in items), 1),
        })
    return summary


def compare(summary, saved, faster=False):
    """[(fold, column, before, now)] for each median that grew past the limit, or shrank past it."""
    before = {s["fold"]: s for s in saved.get("summary", [])}
    changed = []
    for now in summary:
        old = before.get(now["fold"])
        if not old:
            continue
        for column in ("longest_ms", "busy_ms"):
            a, b = (now[column], old[column]) if faster else (old[column], now[column])
            if b - a >= SLOWER_MS and b >= a * (1 + SLOWER_SHARE):
                changed.append((now["fold"], column, old[column], now[column]))
    return changed


def analyze(exports, process, commands=(), start_unix=None):
    """exports: {"toc", "runloop", "signposts", "hangs"} XML text. Returns the report without paths."""
    stretches = main_thread_stretches(exports["runloop"], process)
    signposts = signpost_intervals(exports["signposts"], process)
    hang_rows = hangs(exports["hangs"], process) if exports.get("hangs") else []
    samples = main_thread_samples(exports["profile"], process) if exports.get("profile") else None
    if start_unix is None and exports.get("toc"):
        start_unix = trace_start(exports["toc"])
    folds = [measure_fold(w, stretches, signposts, hang_rows, samples) for w in find_folds(signposts)]
    label_folds(folds, list(commands), start_unix)
    folds = merge_by_command(folds)
    return {"process": process, "folds": folds, "summary": summarize(folds),
            "stretches_seen": len(stretches)}


# --------------------------------------------------------------------------
# The Mac: every command goes through Runner, so tests can fake it
# --------------------------------------------------------------------------

def pick_developer_dir():
    env = os.environ.get("DEVELOPER_DIR")
    if env:
        return env
    if os.path.isdir(DEFAULT_DEVELOPER_DIR):
        return DEFAULT_DEVELOPER_DIR
    return None


class Runner:
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

    def start(self, argv, log_path):
        """Start a long command with its output in log_path. Returns a handle for wait_for_text and stop."""
        fh = open(log_path, "w", encoding="utf-8")
        proc = subprocess.Popen(argv, stdout=fh, stderr=subprocess.STDOUT, env=self.env())
        return {"proc": proc, "log": log_path, "fh": fh}

    def wait_for_text(self, handle, text, timeout):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if handle["proc"].poll() is not None:
                return False
            try:
                with open(handle["log"], encoding="utf-8", errors="replace") as fh:
                    if text in fh.read():
                        return True
            except OSError:
                pass
            time.sleep(0.5)
        return False

    def stop(self, handle, timeout):
        """Ask the command to stop as Ctrl-C would, wait for it, return its exit code."""
        proc = handle["proc"]
        if proc.poll() is None:
            proc.send_signal(signal.SIGINT)
        try:
            code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            code = proc.wait()
        handle["fh"].close()
        return code

    def read_log(self, handle):
        try:
            with open(handle["log"], encoding="utf-8", errors="replace") as fh:
                return fh.read()
        except OSError:
            return ""

    def sleep(self, seconds):
        if seconds > 0:
            time.sleep(seconds)

    def now(self):
        return time.time()

    def note(self, text):
        if self.log:
            self.log(text)


# --------------------------------------------------------------------------
# Simulator, app and Instruments
# --------------------------------------------------------------------------

def find_simulator(runner, udid=None):
    """The booted iPhone Duo (or the one with this UDID). Never creates or boots one."""
    code, out, err = runner.run(["xcrun", "simctl", "list", "-j", "devices"])
    if code != 0:
        raise CostError(EXIT_NO_SIMULATOR, "simctl could not list the simulators", (err or out).strip()[-300:])
    try:
        devices = json.loads(out).get("devices") or {}
    except ValueError:
        raise CostError(EXIT_NO_SIMULATOR, "simctl printed something that isn't JSON")
    found = []
    for runtime, items in sorted(devices.items()):
        for d in items or []:
            if d.get("deviceTypeIdentifier") != DUO_TYPE:
                continue
            if udid and d.get("udid", "").lower() != udid.lower():
                continue
            found.append(dict(d, runtime=runtime))
    if udid and not found:
        raise CostError(EXIT_NO_SIMULATOR, "no iPhone Duo simulator has the UDID %s" % udid,
                        "List them with: xcrun simctl list devices")
    booted = [d for d in found if d.get("state") == "Booted"]
    if not booted:
        raise CostError(EXIT_NO_SIMULATOR, "no booted iPhone Duo simulator",
                        "Boot yours with `xcrun simctl boot <udid>` and open it in Device Hub. "
                        "duo-fold-cost never creates one.")
    booted.sort(key=lambda d: d.get("name") != "iPhone Duo")
    return booted[0]


def app_process(runner, udid, bundle_id):
    """The app's executable name, which Instruments uses to attach."""
    code, out, err = runner.run(["xcrun", "simctl", "get_app_container", udid, bundle_id, "app"])
    if code != 0 or not out.strip():
        raise CostError(EXIT_NO_APP, "%s is not installed on the simulator" % bundle_id,
                        "Build and install it first: xcrun simctl install %s <path to .app>" % udid)
    try:
        with open(os.path.join(out.strip(), "Info.plist"), "rb") as fh:
            name = plistlib.load(fh).get("CFBundleExecutable")
    except (OSError, ValueError, plistlib.InvalidFileException):
        name = None
    return name or os.path.splitext(os.path.basename(out.strip()))[0]


def duo_pose(runner, udid, pose, force):
    argv = [DUO_POSE, "set", pose, "--udid", udid, "--json"] + (["--force"] if force else [])
    code, out, err = runner.run(argv, timeout=180)
    if code != 0:
        try:
            detail = json.loads(out.strip().splitlines()[-1]).get("error") or ""
        except (ValueError, IndexError, AttributeError):
            detail = (err or out).strip()[-300:]
        raise CostError(EXIT_POSE, "duo-pose could not set %s (exit %d)%s" % (
            pose, code, ": " + detail if detail else ""),
            "Run `duo-pose status` (duo-pose-matrix skill). It needs Device Hub showing the phone "
            "and the Accessibility permission for the app that runs it.")


def duo_pose_now(runner, udid):
    """The pose duo-pose reads now, or None."""
    code, out, _ = runner.run([DUO_POSE, "status", "--udid", udid, "--json"], timeout=60)
    try:
        pose = (json.loads(out).get("state") or {}).get("pose") or ""
    except (ValueError, AttributeError):
        return None
    if pose in POSES:
        return pose
    # duo-pose's guesses: "tabletop (or open, held tall)", "open or book". Take the
    # first pose named; for "open or book", flat is the safe way back.
    first = re.match(r"(closed|open|book|tabletop)\b", pose)
    return first.group(1) if first else None


def export(runner, trace, xpath=None):
    argv = ["xcrun", "xctrace", "export", "--input", trace] + (["--xpath", xpath] if xpath else ["--toc"])
    code, out, err = runner.run(argv, timeout=600)
    if code != 0:
        raise CostError(EXIT_TRACE, "xctrace could not read %s" % trace, (err or out).strip()[-300:])
    return out


def table(schema, extra=""):
    return '/trace-toc/run[@number="1"]/data/table[@schema="%s"%s]' % (schema, extra)


def read_trace(runner, trace):
    """The four exports duo-fold-cost reads from a trace."""
    toc = export(runner, trace)
    for schema in ("runloop-events", "os-signpost"):
        if 'schema="%s"' % schema not in toc:
            raise CostError(EXIT_TRACE, "%s has no %s table" % (trace, schema),
                            "Record with the Hangs and os_signpost instruments: "
                            "xctrace record --instrument Hangs --instrument os_signpost ...")
    return {
        "toc": toc,
        "runloop": export(runner, trace, table("runloop-events")),
        # The app's own signposts: the table without a category filter, for the one target process.
        "signposts": export(runner, trace, table("os-signpost", ' and @target-pid="SINGLE" and not(@category)')),
        "hangs": export(runner, trace, table("potential-hangs")) if 'schema="potential-hangs"' in toc else "",
        "profile": export(runner, trace, table("time-profile")) if 'schema="time-profile"' in toc else "",
    }



def analyze_trace(runner, trace, process, commands):
    try:
        return analyze(read_trace(runner, trace), process, commands)
    except ET.ParseError as exc:
        raise CostError(EXIT_TRACE, "could not read what xctrace exported from %s: %s" % (trace, exc))


def record(runner, sim, bundle_id, process, args):
    """Launch, record while folding, stop. Returns (trace path, pose commands)."""
    udid = sim["udid"]
    os.makedirs(args.out, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    trace = os.path.join(args.out, "fold-cost-%s.trace" % stamp)
    n = 1
    while os.path.exists(trace):    # xctrace won't write over a trace
        n += 1
        trace = os.path.join(args.out, "fold-cost-%s-%d.trace" % (stamp, n))
    poses = args.poses
    start_pose = poses[-1]
    found_pose = duo_pose_now(runner, udid)
    # The pose the phone is in now; None after a pose change failed, when nobody knows.
    state = {"pose": found_pose}

    def set_pose(pose):
        state["pose"] = None
        duo_pose(runner, udid, pose, args.force)
        state["pose"] = pose

    instruments = list(INSTRUMENTS) + (["Time Profiler"] if args.time_profiler else [])
    limit = int(args.cycles * len(poses) * 60 + 60)
    argv = ["xcrun", "xctrace", "record", "--device", udid, "--attach", process, "--output", trace,
            "--time-limit", "%ds" % limit, "--no-prompt"]
    for name in instruments:
        argv += ["--instrument", name]
    handle = None
    code = None
    commands = []
    try:
        runner.note("Putting the phone in %s before launching." % start_pose)
        set_pose(start_pose)
        code, out, err = runner.run(["xcrun", "simctl", "launch", "--terminate-running-process", udid,
                                     bundle_id] + list(args.launch_args))
        if code != 0:
            raise CostError(EXIT_NO_APP, "the app did not launch", (err or out).strip()[-300:])
        runner.sleep(args.settle)

        runner.note("Recording %s with %s." % (process, ", ".join(instruments)))
        handle = runner.start(argv, trace + ".log")
        if not runner.wait_for_text(handle, "Starting recording", 60):
            raise CostError(EXIT_TRACE, "Instruments did not start recording",
                            runner.read_log(handle).strip()[-400:])
        runner.sleep(2)
        current = start_pose
        for cycle in range(1, args.cycles + 1):
            for pose in poses:
                runner.note("Cycle %d of %d: %s -> %s" % (cycle, args.cycles, current, pose))
                commands.append({"pose": pose, "from": current, "cycle": cycle, "started": runner.now()})
                set_pose(pose)
                current = pose
                runner.sleep(args.settle)
    finally:
        # Runs on errors and Ctrl-C too: stop the recording, then put the phone back.
        if handle is not None:
            code = runner.stop(handle, timeout=300)
        if found_pose and state["pose"] != found_pose:
            try:
                duo_pose(runner, udid, found_pose, args.force)
            except CostError as exc:
                runner.note("Could not put the phone back in %s: %s" % (found_pose, exc.message))
    if not os.path.isdir(trace):
        raise CostError(EXIT_TRACE, "Instruments saved no trace (exit %d)" % code,
                        runner.read_log(handle).strip()[-400:])
    with open(trace + ".poses.json", "w", encoding="utf-8") as fh:
        json.dump(commands, fh, indent=1)
    return trace, commands


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

def hint(in_longest):
    """One line on what to look at, from where the longest stretch spent its time."""
    system = sum(i["share"] for i in in_longest if i["name"] == "(system)")
    if system >= 0.5:
        return ("mostly SwiftUI and UIKit: too many views laid out or rebuilt. Look for stacks that "
                "aren't lazy, a GeometryReader per row, and .id or if/else that rebuild on resize.")
    return "mostly your code: move that work out of body, or after the fold."


def print_report(report, out):
    out.write("duo-fold-cost: %s, %d fold%s%s\n\n" % (
        report["process"], len(report["folds"]), "" if len(report["folds"]) == 1 else "s",
        (" on " + report["simulator"]) if report.get("simulator") else ""))
    out.write("%-22s %8s %8s %8s %7s %6s\n" % ("Fold (median)", "longest", "busy", ">8.3ms", "stalls", "hangs"))
    for s in report["summary"]:
        folds = [f for i, f in enumerate(report["folds"], 1)
                 if (fold_name(f) if f["to"] != "unknown" else "fold %d" % i) == s["fold"]]
        over = statistics.median(f["over_frame"] for f in folds) if folds else 0
        out.write("%-22s %6.0f ms %5.0f ms %8g %7g %6g   (%d run%s)\n" % (
            s["fold"], s["longest_ms"], s["busy_ms"], over, s["stalls"], s["hangs"],
            s["count"], "" if s["count"] == 1 else "s"))
    out.write("\nEach fold:\n")
    for f in report["folds"]:
        note = ""
        if f["skipped"]:
            note = "  (%d stretch%s left out: Accessibility reads by a tool)" % (
                f["skipped"], "" if f["skipped"] == 1 else "es")
        out.write("  %8.2f s  %-9s -> %-9s longest %5.0f ms, busy %5.0f ms, %d stall%s, %d hang%s%s\n" % (
            f["start_s"], f["from"], f["to"], f["longest_ms"], f["busy_ms"],
            f["stalls"], "" if f["stalls"] == 1 else "s", f["hangs"], "" if f["hangs"] == 1 else "s", note))
        if f.get("in_longest"):
            out.write("             in the longest: %s\n" % ", ".join(
                "%s %d %%" % (item["name"], round(item["share"] * 100)) for item in f["in_longest"]))
            out.write("             %s\n" % hint(f["in_longest"]))
    out.write("\nlongest: the longest the main thread ran without a break; the app commits no frame until it ends.\n"
              "busy: main-thread running time in the fold. >8.3ms: stretches longer than a 120 Hz frame.\n"
              "These come from the simulator, on this Mac's CPU at 60 Hz. Compare them with another run on\n"
              "this Mac (--save, then --compare). They are not device timings.\n")
    if report.get("trace"):
        out.write("Trace: %s (open it in Instruments; the times above are from its start)\n" % report["trace"])


def print_comparison(slower, faster, saved_path, out):
    out.write("\nCompared with %s: %s.\n" % (saved_path, "slower" if slower else "no fold is slower"))
    for label, items in (("slower", slower), ("faster", faster)):
        for fold, column, a, b in items:
            out.write("  %s %s: %s %.0f ms -> %.0f ms\n" % (label, fold, column.replace("_ms", ""), a, b))


def emit_error(exc, as_json, out, err):
    if as_json:
        out.write(json.dumps({"ok": False, "error": {"code": exc.code, "message": exc.message,
                                                     "hint": exc.hint}}, sort_keys=True) + "\n")
    else:
        err.write("duo-fold-cost: %s\n" % exc.message)
        if exc.hint:
            err.write("  %s\n" % exc.hint)
    return exc.code


def build_parser():
    parser = argparse.ArgumentParser(
        prog="duo-fold-cost",
        description="What each fold costs your app's main thread, on the iPhone Duo simulator.")
    parser.add_argument("--version", action="version", version="duo-fold-cost " + VERSION)
    sub = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--json", action="store_true", help="print one JSON object")
    common.add_argument("--save", metavar="FILE", help="write the report as JSON, for a later --compare")
    common.add_argument("--compare", metavar="FILE", help="a report saved with --save; exit 1 if a fold got slower")

    r = sub.add_parser("run", parents=[common], help="launch the app, fold it while Instruments records, report")
    r.add_argument("bundle_id")
    r.add_argument("--udid", help="the simulator (default: the booted iPhone Duo)")
    r.add_argument("--poses", default="open,closed",
                   help="the poses to go through in each cycle, comma-separated (default: open,closed)")
    r.add_argument("--cycles", type=int, default=3, help="how many times to go through them (default: 3)")
    r.add_argument("--settle", type=float, default=2.0, metavar="SECONDS",
                   help="wait after launching and after each pose (default: 2)")
    r.add_argument("--time-profiler", action="store_true",
                   help="also record Time Profiler, to see in Instruments which code ran (a bigger trace)")
    r.add_argument("--out", default="fold-cost", help="folder for the trace (default: ./fold-cost)")
    r.add_argument("--force", action="store_true", help="passed to duo-pose: go on while UI tests run")

    rd = sub.add_parser("read", parents=[common], help="read a trace recorded before")
    rd.add_argument("trace")
    rd.add_argument("--process", required=True, help="the app's process name, as Instruments shows it")
    rd.add_argument("--poses-log", metavar="FILE",
                    help="the .poses.json that `run` wrote beside the trace (default: look for it)")
    return parser


def parse_args(argv):
    """Everything after `--` goes to the app, untouched."""
    argv = list(argv)
    launch_args = []
    if "--" in argv:
        cut = argv.index("--")
        argv, launch_args = argv[:cut], argv[cut + 1:]
    parser = build_parser()
    args = parser.parse_args(argv)
    args.launch_args = launch_args
    if launch_args and args.command != "run":
        parser.error("only `run` takes launch arguments after --")
    if args.command == "run":
        poses = [p.strip() for p in args.poses.split(",") if p.strip()]
        bad = [p for p in poses if p not in POSES]
        if not poses or bad:
            parser.error("--poses takes %s, comma-separated" % ", ".join(POSES))
        if len(set(poses)) < 2:
            parser.error("--poses needs at least two different poses, or the phone never folds")
        if args.cycles < 1:
            parser.error("--cycles must be 1 or more")
        args.poses = poses
    return args


def main(argv=None, runner=None, out=None, err=None):
    out = out or sys.stdout
    err = err or sys.stderr
    args = parse_args(sys.argv[1:] if argv is None else argv)
    runner = runner or Runner(log=None if args.json else (lambda t: err.write(t + "\n")))
    saved = None
    try:
        if args.compare:
            try:
                with open(args.compare, encoding="utf-8") as fh:
                    saved = json.load(fh)
            except (OSError, ValueError) as exc:
                raise CostError(EXIT_USAGE, "could not read %s: %s" % (args.compare, exc))

        if args.command == "run":
            if not os.path.exists(DUO_POSE):
                raise CostError(EXIT_POSE, "duo-pose is missing (%s)" % DUO_POSE,
                                "duo-fold-cost uses duo-pose from the duo-pose-matrix skill. "
                                "Install the whole duology-ship plugin.")
            sim = find_simulator(runner, args.udid)
            process = app_process(runner, sim["udid"], args.bundle_id)
            trace, commands = record(runner, sim, args.bundle_id, process, args)
            report = analyze_trace(runner, trace, process, commands)
            report["simulator"] = "%s (%s)" % (sim.get("name", "?"), sim["udid"])
        else:
            if not os.path.isdir(args.trace):
                raise CostError(EXIT_USAGE, "%s is not a trace" % args.trace)
            trace = args.trace
            log = args.poses_log or trace + ".poses.json"
            commands = []
            if os.path.exists(log):
                try:
                    with open(log, encoding="utf-8") as fh:
                        commands = json.load(fh)
                except (OSError, ValueError) as exc:
                    raise CostError(EXIT_USAGE, "could not read the pose log %s: %s" % (log, exc))
            report = analyze_trace(runner, trace, args.process, commands)
        report["trace"] = trace
        if not report["folds"]:
            raise CostError(EXIT_NO_FOLD, "no fold in the trace: UIKit never resized %s's scene" % report["process"],
                            "Check that the app was in front while the phone folded, and that the "
                            "trace has the os_signpost instrument.")
        slower = compare(report["summary"], saved) if saved else []
        faster = compare(report["summary"], saved, faster=True) if saved else []
        report["slower"] = [{"fold": f, "column": c, "before": a, "now": b} for f, c, a, b in slower]
        report["faster"] = [{"fold": f, "column": c, "before": a, "now": b} for f, c, a, b in faster]
        if args.save:
            try:
                with open(args.save, "w", encoding="utf-8") as fh:
                    json.dump(report, fh, indent=1, sort_keys=True)
            except OSError as exc:
                raise CostError(EXIT_USAGE, "could not write %s: %s" % (args.save, exc))
    except CostError as exc:
        return emit_error(exc, args.json, out, err)

    if args.json:
        out.write(json.dumps(dict(report, ok=True), sort_keys=True) + "\n")
    else:
        print_report(report, out)
        if saved is not None:
            print_comparison(slower, faster, args.compare, out)
    return EXIT_SLOWER if slower else EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
