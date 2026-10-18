#!/usr/bin/env python3
"""duo-pose-matrix: screenshot an installed app in every iPhone Duo pose.

  duo-pose-matrix <bundle-id> [options] [-- launch arguments]

For each pose (closed, open, book, tabletop) it presses Device Hub's buttons
with duo-pose, launches the app, saves a screenshot of the active display with
`xcrun simctl io <udid> screenshot`, checks the pose, and at the end puts the
simulator back in the pose it found. It writes the PNGs, summary.json and
summary.md to the output folder.

It uses an existing iPhone Duo simulator and never creates one. The pose is
shared by everything on that simulator, so it refuses to start while UI tests
(xctrunner, xcodebuild test) run, unless you pass --force.

When it can't press the buttons (no Accessibility permission, Device Hub not
showing the phone), run it once per pose with --manual <pose> after someone
sets that pose in Device Hub. Each run adds to the same summary.

Exit codes: 0 every screenshot taken and checked; 1 some screenshots failed
their checks (see summary.md); 2 bad arguments; 3 not allowed to use
Accessibility; 4 Device Hub not ready; 5 no booted iPhone Duo simulator;
6 UI tests are running; 7 the helper could not be built; 8 the app is not
installed on the simulator.

Part of Duology (MIT license). https://github.com/Kimeur/duology
"""

import argparse
import json
import os
import re
import shlex
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import duo_pose as dp  # noqa: E402

VERSION = dp.VERSION
EXIT_NO_APP = 8
SUMMARY_VERSION = 1

# What to check in each pose with the duo-design-review checklist (rule ids and names from that skill).
REVIEW = {
    "closed": [("R1", "No letterboxing"), ("R6", "Side controls, symbols and titles"),
               ("R10", "Same features on the outer display"), ("R13", "Touch targets of 44 pt")],
    "open": [("R1", "No letterboxing"), ("R3", "No size from the main screen"), ("R5", "Even grids"),
             ("R6", "Side controls, symbols and titles"), ("R13", "Touch targets of 44 pt")],
    "book": [("R4", "Nothing interactive in the fold"), ("R5", "Even grids"), ("R7", "Tabletop and book layouts")],
    "tabletop": [("R4", "Nothing interactive in the fold"), ("R7", "Tabletop and book layouts")],
}
NOT_COVERED = [
    "Closed and turned sideways, and open held tall but flat (the matrix doesn't take these)",
    "Split View and Picture in Picture (R8)",
    "The fold and unfold animation (R12): record it with `xcrun simctl io <udid> recordVideo`",
    "Hinge angles other than the three buttons (Option-drag the slider in Device Hub)",
]


# --------------------------------------------------------------------------
# Arguments
# --------------------------------------------------------------------------

def safe_name(text):
    """A file-name-safe case name: letters, digits, dot, dash and underscore."""
    return re.sub(r"[^A-Za-z0-9._-]+", "-", text).strip("-.") or "case"


def parse_case(text):
    name, sep, rest = text.partition("=")
    if not sep or not name.strip():
        raise argparse.ArgumentTypeError(
            "use NAME=ARGS, for example --case \"listDetail=-pattern listDetail\" (got %r)" % text)
    try:
        args = shlex.split(rest)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("can't split the arguments of case %r: %s" % (name, exc))
    return {"name": safe_name(name.strip()), "args": args}


def parse_poses(text):
    if text.strip() == "all":
        return list(dp.POSES)
    poses = []
    for part in text.split(","):
        part = part.strip().lower()
        if not part:
            continue
        if part not in dp.POSES:
            raise argparse.ArgumentTypeError("unknown pose %r; use %s, or all" % (part, ", ".join(dp.POSES)))
        if part not in poses:
            poses.append(part)
    if not poses:
        raise argparse.ArgumentTypeError("name at least one pose")
    return poses


def split_argv(argv):
    """Split at the first `--`: duo-pose-matrix's own options, then the app's launch arguments."""
    if "--" in argv:
        i = argv.index("--")
        return argv[:i], argv[i + 1:]
    return list(argv), []


def default_out(bundle_id, now=None):
    stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime(now))
    return os.path.join(tempfile.gettempdir(), "duo-poses", "%s-%s" % (safe_name(bundle_id), stamp))


def build_parser():
    p = argparse.ArgumentParser(
        prog="duo-pose-matrix",
        usage="duo-pose-matrix <bundle-id> [options] [-- launch arguments]",
        description="Screenshot an installed app in every iPhone Duo pose. Arguments after -- go to the app "
                    "on every launch.",
        epilog="Exit codes: 0 all screenshots checked, 1 some failed their checks, 2 bad arguments, "
               "3 not allowed to use Accessibility, 4 Device Hub not ready, 5 no booted iPhone Duo "
               "simulator, 6 UI tests running (use --force), 7 helper could not be built, 8 app not installed.")
    p.add_argument("bundle_id", help="the app's bundle identifier, for example dev.duology.gallery")
    p.add_argument("--version", action="version", version="duo-pose-matrix " + VERSION)
    p.add_argument("--udid", help="the simulator to use (default: the booted iPhone Duo)")
    p.add_argument("--out", help="output folder (default: a new folder under $TMPDIR/duo-poses)")
    p.add_argument("--poses", type=parse_poses, default=None, metavar="LIST",
                   help="comma-separated poses, in order (default: closed,open,book,tabletop)")
    p.add_argument("--case", dest="cases", action="append", default=[], type=parse_case, metavar="NAME=ARGS",
                   help="one screen to capture, with its own launch arguments; repeat for more")
    p.add_argument("--wait", type=float, default=4.0, metavar="SECONDS",
                   help="seconds between launching the app and the screenshot (default 4)")
    p.add_argument("--no-relaunch", action="store_true",
                   help="launch each case once and keep it running while the poses change, "
                        "so the screenshots show what survives a fold")
    p.add_argument("--manual", choices=dp.POSES, metavar="POSE",
                   help="don't press anything: capture this one pose, which someone set by hand")
    p.add_argument("--readout-id", metavar="ID",
                   help="accessibility identifier of the app's pose readout, to tell open from book")
    p.add_argument("--force", action="store_true", help="go on even while UI tests run on this Mac")
    p.add_argument("--busy-wait", type=float, default=120.0, metavar="SECONDS",
                   help="how long to wait between poses when UI tests start mid-run (default 120)")
    p.add_argument("--no-restore", action="store_true", help="leave the simulator in the last pose")
    p.add_argument("--no-bring-forward", action="store_true",
                   help="fail instead of bringing Device Hub's window to the front")
    p.add_argument("--keep-running", action="store_true", help="don't quit the app at the end")
    p.add_argument("--json", action="store_true", help="print summary.json to stdout as well")
    return p


def parse_args(argv):
    own, launch = split_argv(argv)
    parser = build_parser()
    args = parser.parse_args(own)
    if args.manual and args.poses and args.poses != [args.manual]:
        parser.error("--manual captures one pose; leave out --poses")
    if args.wait < 0 or args.busy_wait < 0:
        parser.error("--wait and --busy-wait must be 0 or more")
    args.poses = [args.manual] if args.manual else (args.poses or list(dp.POSES))
    args.launch_args = launch
    if args.cases:
        args.cases = [{"name": c["name"], "args": c["args"] + launch} for c in args.cases]
    else:
        args.cases = [{"name": "app", "args": launch}]
    names = [c["name"] for c in args.cases]
    dupes = sorted({n for n in names if names.count(n) > 1})
    if dupes:
        parser.error("two cases share the name %s" % ", ".join(dupes))
    args.out = os.path.abspath(args.out or default_out(args.bundle_id))
    return args


# --------------------------------------------------------------------------
# The app on the simulator
# --------------------------------------------------------------------------

parse_launchctl = dp.parse_launchctl


def running_apps(system, sim):
    code, out, _ = system.run(["xcrun", "simctl", "spawn", sim["udid"], "launchctl", "list"])
    return parse_launchctl(out) if code == 0 else None


def new_foreign_apps(before, after, bundle_id):
    """Third-party apps that started between two launchctl snapshots (another session taking the screen)."""
    if before is None or after is None:
        return []
    found = []
    for bundle, pid in sorted(after.items()):
        if pid is None or bundle == bundle_id or bundle.startswith("com.apple."):
            continue
        if before.get(bundle) != pid:
            found.append(bundle)
    return found


def app_installed(system, sim, bundle_id):
    code, _, _ = system.run(["xcrun", "simctl", "get_app_container", sim["udid"], bundle_id])
    return code == 0


def launch(system, sim, bundle_id, args):
    code, out, err = system.run(["xcrun", "simctl", "launch", "--terminate-running-process",
                                 sim["udid"], bundle_id] + list(args))
    return code == 0, (err or out).strip()


# --------------------------------------------------------------------------
# One screenshot
# --------------------------------------------------------------------------

def capture(system, sim, args, case, pose, state, hub, relaunch=True):
    """Launch (or keep) the app, take the screenshot and check it. Returns one shot record."""
    notes = []
    before = running_apps(system, sim)
    if relaunch:
        ok, message = launch(system, sim, args.bundle_id, case["args"])
        if not ok:
            notes.append("launch failed: %s" % (message[-200:] or "no output"))
    system.sleep(args.wait)
    file_name = "%s-%s.png" % (case["name"], pose)
    path = os.path.join(args.out, file_name)
    display = state.shot_display() if state.active else ("primary" if pose == "closed" else "primary-1")
    ok, message = dp.screenshot(system, sim, display, path)
    size = dp.png_size(path) if ok else None
    expected = state.shot_size()
    after = running_apps(system, sim)

    checks = {}
    problems = dp.check_pose(state, pose)
    checks["pose"] = "fail" if problems else "pass"
    notes.extend(problems)
    if size is None:
        checks["size"] = "fail"
        notes.append("no screenshot: %s" % (message[-200:] or "simctl failed"))
    elif expected and tuple(size) != tuple(expected):
        checks["size"] = "fail"
        notes.append("screenshot is %d x %d px, expected %d x %d" % (tuple(size) + tuple(expected)))
    else:
        checks["size"] = "pass"
    if after is None:
        checks["appRunning"] = "not checked"
    elif after.get(args.bundle_id):
        checks["appRunning"] = "pass"
    else:
        checks["appRunning"] = "fail"
        notes.append("%s was not running when the screenshot was taken (did it crash?)" % args.bundle_id)
    foreign = new_foreign_apps(before, after, args.bundle_id)
    if foreign:
        notes.append("another app started during the capture (%s); it may be on screen instead" % ", ".join(foreign))
    fold = dp.check_fold(hub, pose, args.readout_id)
    if fold["status"] == "fail":
        notes.append(fold["note"])

    if "fail" in checks.values() or fold["status"] == "fail":
        status = "failed"
    elif foreign:
        status = "check"
    else:
        status = "ok"
    return {
        "case": case["name"], "args": case["args"], "pose": pose,
        "file": file_name if size else None, "display": display,
        "size": list(size) if size else None, "expectedSize": list(expected) if expected else None,
        "checks": checks, "fold": fold["status"], "foldNote": fold["note"],
        "status": status, "notes": notes, "review": [r for r, _ in REVIEW[pose]],
        "takenAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }


# --------------------------------------------------------------------------
# Summary files
# --------------------------------------------------------------------------

def new_summary(args, sim, mode):
    return {
        "tool": "duo-pose-matrix", "version": VERSION, "summaryVersion": SUMMARY_VERSION,
        "bundleId": args.bundle_id,
        "simulator": {"name": sim["name"], "udid": sim["udid"], "runtime": sim["runtime"]},
        "mode": mode, "startedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "finishedAt": None,
        "startPose": None, "endPose": None, "restoreNote": "",
        "cases": [], "shots": [], "skipped": [], "stopped": None,
    }


def load_summary(path, bundle_id):
    """An earlier summary.json in the same folder for the same app, or None."""
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict) or data.get("tool") != "duo-pose-matrix" or data.get("bundleId") != bundle_id:
        return None
    return data


def merge_shot(summary, shot):
    """Add a shot, replacing an earlier one for the same case and pose."""
    summary["shots"] = [s for s in summary["shots"] if (s["case"], s["pose"]) != (shot["case"], shot["pose"])]
    summary["shots"].append(shot)
    if shot["case"] not in [c["name"] for c in summary["cases"]]:
        summary["cases"].append({"name": shot["case"], "args": shot["args"]})


def ordered_shots(summary):
    case_order = [c["name"] for c in summary["cases"]]
    pose_order = list(dp.POSES)

    def key(s):
        ci = case_order.index(s["case"]) if s["case"] in case_order else len(case_order)
        return ci, pose_order.index(s["pose"]) if s["pose"] in pose_order else 9
    return sorted(summary["shots"], key=key)


def _cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def summary_markdown(summary):
    sim = summary["simulator"]
    shots = ordered_shots(summary)
    counts = {k: sum(1 for s in shots if s["status"] == k) for k in ("ok", "check", "failed")}
    mode = ("automatic: duo-pose pressed Device Hub's buttons" if summary["mode"] == "automatic"
            else "manual: someone set each pose in Device Hub")
    lines = [
        "# Pose matrix: %s" % summary["bundleId"],
        "",
        "%d screenshots: %d ok, %d to check, %d failed. Simulator: %s (%s), %s. Mode: %s." % (
            len(shots), counts["ok"], counts["check"], counts["failed"],
            sim["name"], sim["udid"], sim["runtime"], mode),
        "",
    ]
    if summary.get("startPose") or summary.get("endPose"):
        lines.append("Pose at the start: %s. Pose at the end: %s.%s" % (
            summary.get("startPose") or "not recorded", summary.get("endPose") or "not recorded",
            (" " + summary["restoreNote"]) if summary.get("restoreNote") else ""))
        lines.append("")
    if summary.get("stopped"):
        lines += ["**Stopped early:** %s" % summary["stopped"], ""]
    lines += ["| Case | Pose | Screenshot | Size (px) | Fold | Status | Notes |",
              "|---|---|---|---|---|---|---|"]
    for s in shots:
        shot = "[%s](%s)" % (s["file"], s["file"]) if s.get("file") else "none"
        size = "%d x %d" % tuple(s["size"]) if s.get("size") else "-"
        lines.append("| %s | %s | %s | %s | %s | %s | %s |" % (
            _cell(s["case"]), s["pose"], shot, size, _cell(s.get("fold", "")), s["status"],
            _cell("; ".join(s.get("notes") or [])) or ""))
    lines.append("")
    if summary.get("skipped"):
        lines.append("Skipped:")
        for sk in summary["skipped"]:
            lines.append("- %s: %s" % (sk["pose"], sk["reason"]))
        lines.append("")
    if any(s["pose"] in ("open", "book", "tabletop") and s.get("fold") == "not checked" for s in shots):
        lines += ["Open and book look the same to the tool: the inner display is active and held wide in both. "
                  "Confirm the fold from the screenshot (a region overlay helps) or pass `--readout-id`.", ""]
    lines += ["## Review next", "",
              "Load the duo-design-review skill and run its checklist on these frames. "
              "Start with these rules for each pose:", ""]
    present = [p for p in dp.POSES if any(s["pose"] == p for s in shots)]
    for pose in present:
        rules = ", ".join("%s %s" % r for r in REVIEW[pose])
        lines.append("- **%s**: %s" % (pose, rules))
    lines += ["", "Fold position, measured in Duology's gallery (duo-design-review step 2): "
              "x 455-495 pt (1365-1485 px) in book, y 455-495 pt (1365-1485 px) in tabletop, "
              "when the app fills the display.", ""]
    if summary["mode"] == "automatic" and summary.get("relaunch") is False:
        lines += ["The app kept running while the poses changed, so each case's screenshots also show "
                  "R2 (state survives fold and unfold).", ""]
    else:
        lines += ["Each screenshot is a fresh launch, so this matrix doesn't prove R2 (state survives fold "
                  "and unfold). Run it again with `--no-relaunch` for that.", ""]
    lines.append("Not in this matrix (mark the rules they prove as Check):")
    for item in NOT_COVERED:
        lines.append("- %s" % item)
    lines.append("")
    return "\n".join(lines)


def write_summary(out_dir, summary):
    with open(os.path.join(out_dir, "summary.json"), "w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=2, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(out_dir, "summary.md"), "w", encoding="utf-8") as fh:
        fh.write(summary_markdown(summary))


def manual_command(args, pose):
    parts = ["duo-pose-matrix", args.bundle_id, "--out", args.out, "--manual", pose]
    if args.udid:
        parts += ["--udid", args.udid]
    if args.readout_id:
        parts += ["--readout-id", args.readout_id]
    launch_only = args.launch_args
    for c in args.cases:
        own = c["args"][:len(c["args"]) - len(launch_only)] if launch_only else c["args"]
        if c["name"] != "app" or own:
            parts += ["--case", "%s=%s" % (c["name"], " ".join(shlex.quote(a) for a in own))]
    if launch_only:
        parts += ["--"] + launch_only
    return " ".join(shlex.quote(p) for p in parts)


# --------------------------------------------------------------------------
# The run
# --------------------------------------------------------------------------

def wait_until_free(system, sim, args):
    """Wait while UI tests run. Returns the busy list that remains (empty when free)."""
    if args.force:
        return []
    busy = dp.busy_processes(system, sim)
    deadline = system.monotonic() + args.busy_wait
    while busy and system.monotonic() < deadline:
        system.sleep(5)
        busy = dp.busy_processes(system, sim)
    return busy


def run_matrix(system, args, log=lambda text: None):
    sim = dp.find_simulator(system, args.udid)
    busy = [] if args.force else dp.busy_processes(system, sim)
    if busy:
        raise dp.PoseError(dp.EXIT_BUSY, "UI tests are running on this Mac (%s)" % ", ".join(
            "pid %d" % b["pid"] for b in busy),
            "The pose is shared by everything on the simulator. Wait until they finish, "
            "or pass --force if you know they use another simulator.")
    if not app_installed(system, sim, args.bundle_id):
        raise dp.PoseError(EXIT_NO_APP, "%s is not installed on %s" % (args.bundle_id, sim["name"]),
                           "Build it for the simulator, then: xcrun simctl install %s <path to .app>" % sim["udid"])
    os.makedirs(args.out, exist_ok=True)
    mode = "manual" if args.manual else "automatic"
    summary_path = os.path.join(args.out, "summary.json")
    summary = (load_summary(summary_path, args.bundle_id) if args.manual else None) or new_summary(args, sim, mode)
    if summary["mode"] != mode:
        summary["mode"] = "mixed"
    summary["relaunch"] = not args.no_relaunch
    start = dp.read_state(system, sim)
    if summary.get("startPose") is None or not args.manual:
        summary["startPose"] = start.pose_guess()

    hub = None
    if not args.manual:
        hub = dp.connect(system, sim, bring_forward=not args.no_bring_forward)
        reachable = hub.reachable()
    else:
        reachable = [args.manual]

    poses = []
    for pose in args.poses:
        if pose in reachable:
            poses.append(pose)
        else:
            summary["skipped"].append({"pose": pose, "reason": "Device Hub shows no button for it"})

    def put_in(pose):
        if args.manual:
            state = dp.read_state(system, sim)
            log("%s: set by hand; %s" % (pose, state.describe()))
            return state
        busy_now = wait_until_free(system, sim, args)
        if busy_now:
            raise StopRun("UI tests started on this Mac (%s); stopped before changing the pose again"
                          % ", ".join("pid %d" % b["pid"] for b in busy_now))
        log("%s: pressing Device Hub's buttons" % pose)
        dp.set_pose(system, sim, pose, hub, readout_id=None, check_screenshot=False)
        state = dp.read_state(system, sim)
        log("%s: %s" % (pose, state.describe()))
        return state

    try:
        if args.no_relaunch and not args.manual:
            for case in args.cases:
                for i, pose in enumerate(poses):
                    state = put_in(pose)
                    if i == 0:
                        launch_ok, message = launch(system, sim, args.bundle_id, case["args"])
                        if not launch_ok:
                            log("launch failed: %s" % message)
                    shot = capture(system, sim, args, case, pose, state, hub, relaunch=False)
                    merge_shot(summary, shot)
                    log("  %s-%s: %s" % (case["name"], pose, shot["status"]))
        else:
            for pose in poses:
                state = put_in(pose)
                for case in args.cases:
                    shot = capture(system, sim, args, case, pose, state, hub, relaunch=True)
                    merge_shot(summary, shot)
                    log("  %s-%s: %s" % (case["name"], pose, shot["status"]))
    except StopRun as stop:
        # UI tests started: don't move the pose under them again.
        summary["stopped"] = str(stop)
        restore = False
    except dp.PoseError as exc:
        summary["stopped"] = "%s. %s" % (exc.message, exc.hint)
        restore = hub is not None
    else:
        restore = True

    if restore and not args.manual and not args.no_restore:
        fold_label, want_active, turns, note = dp.restore_plan(start)
        try:
            log("restoring: pressing %s" % fold_label)
            dp.drive(system, sim, hub, fold_label, want_active, turns, dp.Timing())
            summary["restoreNote"] = note
        except dp.PoseError as exc:
            summary["restoreNote"] = "Could not put it back: %s." % exc.message
    if not args.keep_running:
        system.run(["xcrun", "simctl", "terminate", sim["udid"], args.bundle_id])
    try:
        summary["endPose"] = dp.read_state(system, sim).pose_guess()
    except dp.PoseError:
        summary["endPose"] = None
    summary["finishedAt"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    write_summary(args.out, summary)
    return summary


class StopRun(Exception):
    pass


def exit_code(summary):
    shots = summary["shots"]
    if summary.get("stopped") or not shots or any(s["status"] == "failed" for s in shots):
        return dp.EXIT_FAILED
    return dp.EXIT_OK


def main(argv=None, system=None, out=None, err=None):
    out = out or sys.stdout
    err = err or sys.stderr
    args = parse_args(sys.argv[1:] if argv is None else argv)

    def log(text):
        if not args.json:
            err.write(text + "\n")

    system = system or dp.System(log=log)
    try:
        summary = run_matrix(system, args, log)
    except dp.PoseError as exc:
        if args.json:
            out.write(json.dumps({"ok": False, "code": exc.code, "error": exc.message, "hint": exc.hint},
                                 sort_keys=True) + "\n")
        else:
            err.write("duo-pose-matrix: %s.\n" % exc.message)
            if exc.hint:
                err.write("  %s\n" % exc.hint)
            if exc.code in (dp.EXIT_NOT_TRUSTED, dp.EXIT_DEVICE_HUB) and not args.manual:
                err.write("Set the poses by hand instead. For each pose, have someone press it in Device Hub, "
                          "then run:\n")
                for pose in args.poses:
                    err.write("  %s\n" % manual_command(args, pose))
                err.write("Each run adds to summary.md in %s.\n" % args.out)
        return exc.code
    if args.json:
        out.write(json.dumps(summary, sort_keys=True) + "\n")
    else:
        shots = summary["shots"]
        saved = sum(1 for s in shots if s.get("file"))
        out.write("Saved %d screenshot%s, summary.md and summary.json in %s\n" % (
            saved, "" if saved == 1 else "s", args.out))
        for s in ordered_shots(summary):
            out.write("  %-28s %-7s %s\n" % (s["file"] or "%s-%s (none)" % (s["case"], s["pose"]), s["status"],
                                             "; ".join(s["notes"])))
        if summary.get("stopped"):
            out.write("Stopped early: %s\n" % summary["stopped"])
        if summary.get("restoreNote"):
            out.write("%s\n" % summary["restoreNote"])
        out.write("Pose at the end: %s\n" % (summary.get("endPose") or "unknown"))
    return exit_code(summary)


if __name__ == "__main__":
    sys.exit(main())
