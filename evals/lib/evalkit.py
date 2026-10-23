#!/usr/bin/env python3
"""Helpers for evals/run.sh: task files, transcripts, lint results and summaries.

Python 3.9 or later, standard library only. run.sh calls one subcommand at a time:

  evalkit.py list <tasks-dir>                     one task file path per line
  evalkit.py validate <task.md>...                exit 1 and print problems if a task is malformed
  evalkit.py field <task.md> <key> [default]      a front-matter value
  evalkit.py prompt <task.md>                     the prompt text
  evalkit.py checks <task.md> <out-dir>           write each check to <out-dir>/<id>.sh, print the ids
  evalkit.py transcript <transcript.jsonl> <what> final | bash | skills | json
  evalkit.py lint-summary <lint.json> <work-dir>  JSON: findings, errors, warnings, unexplained silences
  evalkit.py checklist <task.md> <out.json>       write a pending checklist for the task's rules
  evalkit.py result <trial-dir>                   combine the trial's files into result.json
  evalkit.py summarize <run-dir>                  write summary.json and summary.md for a run
  evalkit.py pick-sim                             print the UDID of an iPhone Duo simulator
  evalkit.py allowed-tools <task.md> <developer-dir|-> [plugin-root]
                                                  the agent's --allowedTools rules, one per line;
                                                  exit 1 if any rule is too broad
  evalkit.py allowed-tools --summary <task.md> <developer-dir|->
                                                  one line naming the shared Bash commands (for the preamble)
  evalkit.py denied-tools                         the agent's --disallowedTools rules, one per line
  evalkit.py check-rule <rule>...                 exit 1 and say why if a rule is too broad
"""
import json
import os
import re
import subprocess
import sys

RULES = {
    "R1": "No letterboxing",
    "R2": "State survives fold and unfold",
    "R3": "No size from the main screen",
    "R4": "Nothing interactive in the fold",
    "R5": "Even grids",
    "R6": "Side controls, symbols and titles",
    "R7": "Tabletop and book layouts",
    "R8": "Split View and PiP work",
    "R9": "Camera preview upright",
    "R10": "Same features on the outer display",
    "R11": "Multiple windows",
    "R12": "Smooth transitions",
    "R13": "Touch targets of 44 pt",
    "R14": "Hardware keyboard",
    "R15": "Drag and drop",
}
VERDICTS = ("pending", "pass", "fail", "n/a")
REQUIRED_KEYS = ("id", "skill", "title", "fixture", "build", "lint", "status")
FENCE = re.compile(r"^```[A-Za-z0-9_-]*\s+(prompt|check)(?:\s+([A-Za-z0-9_.-]+))?\s*$")


# ------------------------------------------------------------- permissions
#
# The agent never gets blanket Bash, the Agent tool or web tools. It gets the
# rules below, plus the task's own `tools:` rules, plus (in the run with Duology)
# exact paths to the plugin's own scripts. Both arms get the same rules apart
# from those plugin paths. rule_problem() refuses anything broader.

BASE_TOOLS = [
    "Read", "Edit", "Write", "Glob", "Grep", "Skill",
    "Bash(xcodebuild:*)", "Bash(xcrun simctl:*)",
    "Bash(git diff:*)", "Bash(git status:*)",
    "Bash(ls:*)", "Bash(head:*)", "Bash(tail:*)", "Bash(cd:*)",
]

# Skills write commands like `DEVELOPER_DIR=<Xcode 27.1> xcodebuild ...`; allow
# that exact prefix too, for the Xcode the run uses.
DEVELOPER_DIR_TOOLS = ["Bash(DEVELOPER_DIR=%s xcodebuild:*)", "Bash(DEVELOPER_DIR=%s xcrun simctl:*)"]

# simctl subcommands the agent never needs: delete and erase can wipe simulators
# that aren't the eval's (`simctl delete all`), spawn runs any program in a
# simulator as your macOS user, and create and clone add a simulator (about
# 4-6 GB of disk each) when the run already names one to reuse. Deny rules win
# over the `xcrun simctl` allow rules.
SIMCTL_DENIED = ("create", "clone", "delete", "erase", "spawn")

DENIED_TOOLS = [
    "Agent", "WebFetch", "WebSearch",
    # Keep the agent from granting itself more through a settings file mid-run.
    "Edit(./.claude/**)", "Write(./.claude/**)", "Edit(~/.claude/**)", "Write(~/.claude/**)",
] + [r % sub for sub in SIMCTL_DENIED
     for r in ("Bash(xcrun simctl %s:*)", "Bash(DEVELOPER_DIR=* xcrun simctl %s *)")]

# Scripts inside the Duology plugins that its skills and commands tell the agent
# to run, relative to the plugin folder. Only the run with Duology gets them.
PLUGIN_SCRIPTS = [
    "duology-ship/skills/duo-lint/scripts/duo-lint",
    "duology-ship/skills/duo-app-store/scripts/duo-shots",
    "duology-recipes/skills/recipe-two-player-game/scripts/new-project.sh",
    "duology-recipes/skills/recipe-finance-dashboard/scripts/new-project.sh",
    "duology-recipes/skills/recipe-media-player/scripts/new-project.sh",
    "duology-recipes/skills/recipe-reader/scripts/new-project.sh",
    "duology-recipes/skills/recipe-shop/scripts/new-project.sh",
    "duology/bin/duo-doctor",
]
PLUGIN_PYTHON = ["duology-ship/skills/duo-lint/scripts/duo-lint.py"]

SAFE_TOOLS = {"Read", "Edit", "Write", "Glob", "Grep", "Skill", "TodoWrite"}
NEVER_COMMANDS = {
    "sudo", "su", "doas", "rm", "rmdir", "mv", "ln", "dd", "chown", "curl", "wget", "ssh", "scp",
    "sftp", "rsync", "nc", "ncat", "telnet", "ftp", "open", "osascript", "launchctl", "security",
    "eval", "exec", "xargs", "env", "nohup", "kill", "killall", "pkill", "diskutil", "crontab",
    "networksetup", "systemsetup", "spctl", "csrutil", "tccutil", "pmset", "softwareupdate",
    "installer", "brew", "npm", "npx", "pip", "pip3", "gem", "claude",
    # Commands that run another command given to them, so a prefix rule on them
    # allows anything: `nice rm -rf ~`, `find . -exec ...`, `awk 'BEGIN{system(...)}'`.
    "arch", "caffeinate", "nice", "time", "timeout", "gtimeout", "command", "builtin", "source",
    ".", "find", "awk", "gawk", "nawk", "script", "sandbox-exec", "chroot", "watch", "at",
    "batch", "screen", "tmux", "expect", "lldb", "gdb",
}
INTERPRETERS = {"sh", "bash", "zsh", "dash", "ksh", "fish", "python", "python3", "perl", "ruby",
                "node", "swift", "php", "lua", "tclsh"}
# git is an allow list: only subcommands that read.
GIT_OK = {"diff", "status", "log", "show"}
XCRUN_OK = {"simctl", "swiftc", "--find", "-f", "--show-sdk-version", "--show-sdk-path",
            "--show-sdk-platform-path"}
XCODE_SELECT_OK = {"xcode-select -p", "xcode-select --print-path", "xcode-select -v",
                   "xcode-select --version"}
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
# A wildcard path must start with a folder inside the project: Tools/* or ./Tools/*,
# never /bin/*, ../* or ./* (any program in the current folder).
DIR_PREFIX = re.compile(r"^(\./)?[A-Za-z0-9_][A-Za-z0-9_.-]*/")


def _wild_path_problem(path):
    """Why a path with a * in it is too broad, or None."""
    if not DIR_PREFIX.match(path) or ".." in path.split("/"):
        return "a wildcard path needs a project folder before it, like Tools/*, not / or .."
    return None


def _word(w):
    """A command word without quotes or a trailing :* (the prefix-rule marker)."""
    w = w.strip("\"'")
    return w[:-2] if w.endswith(":*") else w


def rule_problem(rule):
    """Why an --allowedTools rule is too broad for an eval run, or None if it is fine."""
    rule = rule.strip()
    if not rule:
        return "empty rule"
    if "," in rule:
        return "a rule can't contain a comma: %s" % rule
    m = re.match(r"^([A-Za-z_]+)(?:\((.*)\))?$", rule)
    if not m:
        return "not a tool rule: %s" % rule
    tool, inner = m.group(1), m.group(2)
    if tool != "Bash":
        if inner is not None:
            return "only Bash rules take a pattern here: %s" % rule
        if tool in SAFE_TOOLS:
            return None
        return "tool not allowed in an eval run: %s" % rule
    if inner is None:
        return "blanket Bash is never allowed; name the commands, like Bash(xcodebuild:*)"
    inner = inner.strip()
    if not inner or inner[0] in "*:":
        return "too broad: %s" % rule
    words = inner.split()
    while words and ASSIGNMENT.match(words[0]):
        if not words[0].startswith("DEVELOPER_DIR="):
            return "only DEVELOPER_DIR may come before the command: %s" % rule
        words = words[1:]
    if not words:
        return "no command in %s" % rule
    first = _word(words[0])
    if not first or first[0] in "*:-":
        return "too broad: %s" % rule
    if "*" in first and _wild_path_problem(first):
        return "%s: %s" % (_wild_path_problem(first), rule)
    if ".." in first.split("/"):
        return "a command path can't climb out with ..: %s" % rule
    name = os.path.basename(first)
    if not name:
        return "a rule must name a command, not a folder: %s" % rule
    rest = [_word(w) for w in words[1:]]
    if name in NEVER_COMMANDS:
        return "command never allowed in an eval run: %s" % rule
    if name == "git" and (not rest or rest[0] not in GIT_OK):
        return "git rules must name a read-only subcommand (%s) right after git: %s" % (
            ", ".join(sorted(GIT_OK)), rule)
    if name == "defaults" and (not rest or rest[0] != "read"):
        return "defaults may only read: %s" % rule
    if name == "xcode-select" and " ".join([name] + rest) not in XCODE_SELECT_OK:
        return "xcode-select may only print its path or version: %s" % rule
    if name == "xcrun":
        for w in rest:
            if w in XCRUN_OK:
                break
            if "*" in w:
                return "xcrun rules must name the tool before any wildcard, like xcrun simctl: %s" % rule
        else:
            return "xcrun may only run simctl, swiftc or its --find/--show-sdk options: %s" % rule
    if name in INTERPRETERS:
        if not rest:
            return "an interpreter rule must name the script it runs: %s" % rule
        script = rest[0]
        if not script or script[0] in "*:-":
            return "an interpreter rule must name the script it runs: %s" % rule
        if "*" in script and _wild_path_problem(script):
            return "%s: %s" % (_wild_path_problem(script), rule)
        if ".." in script.split("/"):
            return "a script path can't climb out with ..: %s" % rule
    return None


def task_tools(meta):
    return [t.strip() for t in meta.get("tools", "").split(",") if t.strip()]


def plugin_rules(plugin_root):
    rules = []
    for rel in PLUGIN_SCRIPTS:
        path = os.path.join(plugin_root, rel)
        if os.path.exists(path):
            rules += ["Bash(%s:*)" % path, 'Bash("%s" *)' % path]
    for rel in PLUGIN_PYTHON:
        path = os.path.join(plugin_root, rel)
        if os.path.exists(path):
            rules += ["Bash(python3 %s:*)" % path, 'Bash(python3 "%s" *)' % path]
    # Each plugin puts its bin/ on PATH, and the skills offer the bare command.
    for rel, rule in (("duology/bin/duo-doctor", "Bash(duo-doctor:*)"),
                      ("duology-ship/bin/duo-lint", "Bash(duo-lint:*)")):
        if os.path.exists(os.path.join(plugin_root, rel)):
            rules.append(rule)
    return rules


def allowed_rules(meta, developer_dir, plugin_root=None):
    rules = list(BASE_TOOLS)
    if developer_dir and not re.search(r"\s", developer_dir):
        rules += [r % developer_dir for r in DEVELOPER_DIR_TOOLS]
    rules += task_tools(meta)
    if plugin_root:
        rules += plugin_rules(plugin_root)
    seen, out = set(), []
    for r in rules:
        if r not in seen:
            seen.add(r)
            out.append(r)
    return out


def bash_summary(rules):
    """'xcodebuild, xcrun simctl, ...' for the preamble: the shared Bash commands."""
    names = []
    for r in rules:
        m = re.match(r"^Bash\((.*)\)$", r)
        if not m or m.group(1).startswith("DEVELOPER_DIR="):
            continue
        cmd = m.group(1)
        cmd = cmd[:-2] if cmd.endswith(":*") else cmd
        cmd = cmd[:-2] if cmd.endswith(" *") else cmd
        if cmd not in names:
            names.append(cmd)
    return ", ".join(names)


# ---------------------------------------------------------------- task files

def parse_task(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    meta = {}
    body = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end < 0:
            raise ValueError("%s: front matter has no closing ---" % path)
        for line in text[4:end].splitlines():
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if ":" not in line:
                raise ValueError("%s: bad front-matter line: %r" % (path, line))
            key, value = line.split(":", 1)
            meta[key.strip()] = value.strip().strip('"')
        body = text[end + 5:]
    prompt = None
    checks = []
    lines = body.splitlines()
    i = 0
    while i < len(lines):
        m = FENCE.match(lines[i])
        if not m:
            i += 1
            continue
        kind, ident = m.group(1), m.group(2)
        j = i + 1
        block = []
        while j < len(lines) and lines[j].rstrip() != "```":
            block.append(lines[j])
            j += 1
        if j >= len(lines):
            raise ValueError("%s: unclosed %s block" % (path, kind))
        if kind == "prompt":
            if prompt is not None:
                raise ValueError("%s: more than one prompt block" % path)
            prompt = "\n".join(block).strip() + "\n"
        else:
            checks.append((ident, "\n".join(block) + "\n"))
        i = j + 1
    return meta, prompt, checks


def validate(path, evals_dir):
    problems = []
    try:
        meta, prompt, checks = parse_task(path)
    except ValueError as e:
        return [str(e)]
    for key in REQUIRED_KEYS:
        if key not in meta:
            problems.append("missing front-matter key: %s" % key)
    rel = os.path.relpath(path, os.path.join(evals_dir, "tasks"))
    expected_id = rel[:-3] if rel.endswith(".md") else rel
    if meta.get("id") and meta["id"] != expected_id:
        problems.append("id %r does not match the file path (%s)" % (meta.get("id"), expected_id))
    if not prompt or not prompt.strip():
        problems.append("no prompt block")
    fixture = meta.get("fixture", "")
    if fixture and fixture != "empty" and not os.path.isdir(os.path.join(evals_dir, "fixtures", fixture)):
        problems.append("fixture not found: fixtures/%s" % fixture)
    for key in ("build", "lint"):
        if meta.get(key) not in (None, "yes", "no"):
            problems.append("%s must be yes or no" % key)
    if meta.get("status") not in (None, "ready", "planned"):
        problems.append("status must be ready or planned")
    ids = [c[0] for c in checks]
    if any(i is None for i in ids):
        problems.append("every check block needs an id: ```sh check <id>")
    if len(set(ids)) != len(ids):
        problems.append("duplicate check ids: %s" % ids)
    for rule in meta.get("checklist", "").split():
        if rule not in RULES:
            problems.append("unknown checklist rule: %s" % rule)
    if not checks and meta.get("build") != "yes" and meta.get("lint") != "yes":
        problems.append("task has no automatic check at all")
    for rule in task_tools(meta):
        why = rule_problem(rule)
        if why:
            problems.append("tools: " + why)
    if meta.get("developer_dir") not in (None, "set", "unset"):
        problems.append("developer_dir must be set or unset")
    if meta.get("developer_dir") == "unset" and meta.get("preamble") != "minimal":
        problems.append("developer_dir: unset needs preamble: minimal (the full preamble says DEVELOPER_DIR is set)")
    if meta.get("preamble") not in (None, "full", "minimal"):
        problems.append("preamble must be full or minimal")
    return problems


# --------------------------------------------------------------- transcripts

def read_events(path):
    events = []
    if not os.path.exists(path):
        return events
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                events.append(json.loads(line))
            except ValueError:
                continue
    return events


def tool_uses(events, with_ids=False):
    for ev in events:
        if ev.get("type") != "assistant":
            continue
        content = (ev.get("message") or {}).get("content") or []
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                if with_ids:
                    yield block.get("id"), block.get("name") or "", block.get("input") or {}
                else:
                    yield block.get("name") or "", block.get("input") or {}


REFUSAL = re.compile(r"permission|haven't granted|not allowed|denied", re.IGNORECASE)


def _describe(name, inp):
    detail = inp.get("command") or inp.get("file_path") or inp.get("skill") or ""
    return ("%s: %s" % (name, detail))[:200]


def permission_denials(events, result):
    """Tool calls the permission rules refused.

    Uses the result event's permission_denials list when there is one. Otherwise
    it falls back to tool results that are errors and talk about permission.
    Neither format has been checked against a paid run yet (see evals/README.md).
    """
    listed = result.get("permission_denials")
    if isinstance(listed, list):
        out = []
        for d in listed:
            if isinstance(d, dict):
                out.append(_describe(d.get("tool_name") or "?", d.get("tool_input") or {}))
            else:
                out.append(str(d)[:200])
        return out
    calls = {i: (n, inp) for i, n, inp in tool_uses(events, with_ids=True) if i}
    out = []
    for ev in events:
        if ev.get("type") != "user":
            continue
        content = (ev.get("message") or {}).get("content") or []
        if not isinstance(content, list):
            continue
        for block in content:
            if not (isinstance(block, dict) and block.get("type") == "tool_result" and block.get("is_error")):
                continue
            text = block.get("content")
            if isinstance(text, list):
                text = " ".join(str(c.get("text", "")) for c in text if isinstance(c, dict))
            if REFUSAL.search(str(text or "")):
                name, inp = calls.get(block.get("tool_use_id"), ("?", {}))
                out.append(_describe(name, inp))
    return out


def transcript_info(path):
    events = read_events(path)
    init = next((e for e in events if e.get("type") == "system" and e.get("subtype") == "init"), {})
    result = next((e for e in reversed(events) if e.get("type") == "result"), {})
    bash, skills, reads, counts = [], [], [], {}
    for name, inp in tool_uses(events):
        counts[name] = counts.get(name, 0) + 1
        if name == "Bash":
            bash.append(str(inp.get("command", "")))
        elif name == "Skill":
            skills.append(str(inp.get("skill") or inp.get("command") or inp.get("name") or "?"))
        elif name == "Read":
            reads.append(str(inp.get("file_path", "")))
    usage = result.get("usage") or {}
    return {
        "model": init.get("model"),
        "claude_code_version": init.get("claude_code_version"),
        "plugins": [p.get("name") if isinstance(p, dict) else p for p in (init.get("plugins") or [])],
        "result": result.get("result"),
        "is_error": result.get("is_error"),
        "subtype": result.get("subtype"),
        "cost_usd": result.get("total_cost_usd"),
        "turns": result.get("num_turns"),
        "duration_ms": result.get("duration_ms"),
        "output_tokens": usage.get("output_tokens"),
        "tool_counts": counts,
        "skills_loaded": skills,
        "bash_commands": bash,
        "files_read": reads,
        "permission_denials": permission_denials(events, result),
    }


# Signs that the run without Duology saw Duology anyway.
CONTAMINATION = re.compile(r"duology|duo-lint\.py|/plugins/duology", re.IGNORECASE)


def contamination(info):
    hits = []
    for cmd in info["bash_commands"]:
        if CONTAMINATION.search(cmd):
            hits.append("bash: " + cmd[:200])
    for path in info["files_read"]:
        if CONTAMINATION.search(path):
            hits.append("read: " + path)
    for skill in info["skills_loaded"]:
        if skill.startswith(("duo-", "duology", "recipe-")) or ":duo-" in skill:
            hits.append("skill: " + skill)
    for plugin in info["plugins"]:
        if plugin and "duology" in str(plugin).lower():
            hits.append("plugin: %s" % plugin)
    return hits


# ---------------------------------------------------------------------- lint

SILENCE = re.compile(r"duo-lint:disable(?:-next-line|-line|-file)?\b(.*)")


def lint_summary(lint_path, work_dir):
    out = {"findings": None, "errors": None, "warnings": None, "rules": {},
           "silences": 0, "unexplained_silences": [], "passed": False}
    try:
        with open(lint_path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        out["error"] = "could not read lint output: %s" % e
        return out
    findings = data.get("findings", data) if isinstance(data, dict) else data
    if not isinstance(findings, list):
        out["error"] = "unexpected lint output"
        return out
    out["findings"] = len(findings)
    out["errors"] = sum(1 for f in findings if f.get("severity") == "error")
    out["warnings"] = sum(1 for f in findings if f.get("severity") == "warning")
    for f in findings:
        out["rules"][f.get("rule", "?")] = out["rules"].get(f.get("rule", "?"), 0) + 1
    skip = {".git", "DerivedData", "build", ".build", "Pods", "Carthage", "SourcePackages"}
    for root, dirs, files in os.walk(work_dir):
        dirs[:] = [d for d in dirs if d not in skip and not d.endswith((".xcresult", ".app"))]
        for name in files:
            if not name.endswith((".swift", ".m", ".mm", ".h", ".plist", ".xcconfig", ".pbxproj")):
                continue
            path = os.path.join(root, name)
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    for n, line in enumerate(f, 1):
                        m = SILENCE.search(line)
                        if not m:
                            continue
                        out["silences"] += 1
                        if "--" not in m.group(1):
                            out["unexplained_silences"].append(
                                "%s:%d" % (os.path.relpath(path, work_dir), n))
            except OSError:
                pass
    out["passed"] = out["findings"] == 0 and not out["unexplained_silences"]
    return out


# ----------------------------------------------------------------- checklist

def write_checklist(task_path, out_path):
    meta, _, _ = parse_task(task_path)
    rules = meta.get("checklist", "").split()
    data = {
        "task": meta.get("id"),
        "how": "Set each rule to pass, fail or n/a after looking at the app on the iPhone Duo "
               "simulator. See evals/rubric.md. Then run: evals/run.sh --summarize <run-dir>",
        "reviewer": "",
        "frames": [],
        "rules": {r: "pending" for r in rules},
        "rule_names": {r: RULES[r] for r in rules},
        "notes": "",
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


# -------------------------------------------------------------------- result

def load_json(path, default=None):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def trial_result(trial_dir):
    meta = load_json(os.path.join(trial_dir, "meta.json"), {})
    res = {
        "task": meta.get("task"),
        "arm": meta.get("arm"),
        "trial": meta.get("trial"),
        "dry_run": bool(meta.get("dry_run")),
        "work_dir": meta.get("work_dir"),
        "agent": {"exit_code": meta.get("agent_exit"), "timed_out": meta.get("timed_out", False)},
    }
    t = os.path.join(trial_dir, "transcript.jsonl")
    if os.path.exists(t):
        info = transcript_info(t)
        res["agent"].update({k: info[k] for k in (
            "model", "claude_code_version", "is_error", "subtype", "cost_usd", "turns",
            "duration_ms", "output_tokens", "tool_counts", "skills_loaded")})
        res["agent"]["bash_command_count"] = len(info["bash_commands"])
        res["agent"]["permission_denials"] = len(info["permission_denials"])
        res["agent"]["permission_denial_samples"] = info["permission_denials"][:10]
        res["agent"]["contamination"] = contamination(info) if meta.get("arm") == "without" else []
    build_required = meta.get("build") == "yes"
    res["build"] = {"required": build_required}
    if build_required:
        b = load_json(os.path.join(trial_dir, "build.json"), {})
        res["build"].update(b)
        res["build"].setdefault("passed", False)
    lint_required = meta.get("lint") == "yes"
    res["lint"] = {"required": lint_required}
    if lint_required:
        res["lint"].update(load_json(os.path.join(trial_dir, "lint-summary.json"), {"passed": False}))
    checks = []
    cdir = os.path.join(trial_dir, "checks")
    for ident in meta.get("check_ids", []):
        code_path = os.path.join(cdir, ident + ".exit")
        try:
            with open(code_path) as f:
                code = int(f.read().strip() or "1")
        except (OSError, ValueError):
            code = None
        checks.append({"id": ident, "passed": code == 0, "exit": code,
                       "log": os.path.join("checks", ident + ".log")})
    res["checks"] = checks
    cl = load_json(os.path.join(trial_dir, "checklist.json"), None)
    if cl and cl.get("rules"):
        verdicts = cl["rules"]
        bad = {k: v for k, v in verdicts.items() if v not in VERDICTS}
        state = "pending"
        if bad:
            state = "invalid"
        elif any(v == "fail" for v in verdicts.values()):
            state = "fail"
        elif all(v in ("pass", "n/a") for v in verdicts.values()):
            state = "pass"
        res["checklist"] = {"state": state, "rules": verdicts, "reviewer": cl.get("reviewer", "")}
    else:
        res["checklist"] = {"state": "none"}

    if res["dry_run"]:
        status = "dry-run"
    elif meta.get("agent_exit") is None and not meta.get("score_only"):
        status = "error"
    elif meta.get("scored") is not True:
        status = "unscored"  # run with --no-score: nothing was checked, so it is not a pass
    else:
        auto_ok = True
        if build_required and not res["build"].get("passed"):
            auto_ok = False
        if lint_required and not res["lint"].get("passed"):
            auto_ok = False
        if any(not c["passed"] for c in checks):
            auto_ok = False
        cstate = res["checklist"]["state"]
        if not auto_ok or cstate in ("fail", "invalid"):
            status = "fail"
        elif cstate == "pending":
            status = "pending-review"
        else:
            status = "pass"
    res["automatic_passed"] = status in ("pass", "pending-review")
    if res["agent"].get("contamination"):
        status = "contaminated"  # the run without Duology saw Duology: rerun it
    res["status"] = status
    return res


# ------------------------------------------------------------------- summary

ARMS = ("with", "without", "fixture", "score")
TRIAL_DIR = re.compile(r"^trial-[0-9]+$")


def trial_dirs(run_dir):
    """The trial folders of a run, as (path, task, arm).

    A trial folder is <skill>/<task>/<arm>/trial-N with a meta.json in it. Nothing
    inside a trial folder is searched, so a meta.json that the agent left in its
    work folder (copied to final-tree/) never counts as a trial.
    """
    found = []
    for root, dirs, files in os.walk(run_dir):
        dirs.sort()
        parts = os.path.relpath(root, run_dir).split(os.sep)
        if len(parts) == 4 and parts[2] in ARMS and TRIAL_DIR.match(parts[3]):
            dirs[:] = []
            if "meta.json" in files:
                found.append((root, "/".join(parts[:2]), parts[2]))
        elif len(parts) >= 4:
            dirs[:] = []  # deeper than any trial folder
    return found


def summarize(run_dir):
    run_meta = load_json(os.path.join(run_dir, "run.json"), {})
    tasks = {}
    for root, path_task, path_arm in trial_dirs(run_dir):
        res = trial_result(root)
        # The folder decides where a trial counts, not what its meta.json says.
        res["task"], res["arm"] = path_task, path_arm
        with open(os.path.join(root, "result.json"), "w", encoding="utf-8") as f:
            json.dump(res, f, indent=2)
            f.write("\n")
        res["_dir"] = root
        tasks.setdefault(path_task, {}).setdefault(path_arm, []).append(res)
    task_meta = run_meta.get("tasks", {})
    out_tasks = []
    totals = {}
    for task in sorted(tasks):
        arms = {}
        for arm, trials in sorted(tasks[task].items()):
            trials.sort(key=lambda r: r.get("trial") or 0)
            counts = {s: sum(1 for r in trials if r["status"] == s)
                      for s in ("pass", "pending-review", "fail", "error", "contaminated", "dry-run",
                                "unscored")}
            cost = sum((r["agent"].get("cost_usd") or 0) for r in trials)
            denials = sum((r["agent"].get("permission_denials") or 0) for r in trials)
            arms[arm] = {
                "trials": len(trials),
                "counts": counts,
                "automatic_passed": sum(1 for r in trials if r["automatic_passed"]),
                "cost_usd": round(cost, 4),
                "permission_denials": denials,
                "results": [os.path.relpath(os.path.join(r["_dir"], "result.json"), run_dir)
                            for r in trials],
            }
            t = totals.setdefault(arm, {"trials": 0, "pass": 0, "pending-review": 0, "fail": 0,
                                        "error": 0, "contaminated": 0, "dry-run": 0, "unscored": 0,
                                        "cost_usd": 0.0, "permission_denials": 0})
            t["trials"] += len(trials)
            for s, n in counts.items():
                t[s] += n
            t["cost_usd"] = round(t["cost_usd"] + cost, 4)
            t["permission_denials"] += denials
        tm = task_meta.get(task, {})
        out_tasks.append({"id": task, "title": tm.get("title"), "readme": tm.get("readme"), "arms": arms})
    summary = {
        "run_id": run_meta.get("run_id"),
        "created": run_meta.get("created"),
        "dry_run": run_meta.get("dry_run", False),
        "claude_version": run_meta.get("claude_version"),
        "model": run_meta.get("model"),
        "duology_commit": run_meta.get("duology_commit"),
        "xcode": run_meta.get("xcode"),
        "simulator": run_meta.get("simulator"),
        "tasks": out_tasks,
        "totals": totals,
    }
    with open(os.path.join(run_dir, "summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    def cell(arm):
        if not arm:
            return "not run"
        c = arm["counts"]
        n = arm["trials"]
        if c["dry-run"]:
            return "dry run"
        text = "%d/%d pass" % (c["pass"], n)
        if c["pending-review"]:
            text += ", %d awaiting review" % c["pending-review"]
        if c["unscored"]:
            text += ", %d not scored" % c["unscored"]
        if c["contaminated"]:
            text += ", %d contaminated" % c["contaminated"]
        return text

    lines = ["# Eval run %s" % summary["run_id"], "",
             "Claude Code %s, model %s, Duology %s, %s." % (
                 summary["claude_version"] or "?", summary["model"] or "default",
                 summary["duology_commit"] or "?", summary["xcode"] or "Xcode ?"), "",
             "| Task | Without Duology | With Duology |", "|---|---|---|"]
    for t in out_tasks:
        title = t["title"] or t["id"]
        lines.append("| %s | %s | %s |" % (title, cell(t["arms"].get("without")), cell(t["arms"].get("with"))))
    lines.append("")
    if any(t.get("permission_denials") for t in totals.values()):
        lines.append("Tool calls refused by the allow list: %s. Read `permission_denial_samples` in each "
                     "result.json; many refusals mean the task's `tools:` list is too tight." % ", ".join(
                         "%s %d" % (arm, t["permission_denials"]) for arm, t in sorted(totals.items())))
        lines.append("")
    lines.append("A trial passes when it builds for the iPhone Duo simulator, duo-lint reports nothing, "
                 "every task check passes and every checklist rule is pass or n/a. "
                 "See [evals/README.md](https://github.com/Kimeur/duology/blob/main/evals/README.md).")
    with open(os.path.join(run_dir, "summary.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return summary


# ----------------------------------------------------------------- simulator

def pick_sim():
    dev = os.environ.get("DEVELOPER_DIR")
    env = dict(os.environ)
    if dev:
        env["DEVELOPER_DIR"] = dev
    raw = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "-j"],
                         capture_output=True, text=True, env=env, check=True).stdout
    data = json.loads(raw)
    found = []
    for runtime, devices in data.get("devices", {}).items():
        if "iOS-27" not in runtime:
            continue
        for d in devices:
            if "iPhone-Duo" not in d.get("deviceTypeIdentifier", ""):
                continue
            score = (d.get("name") == "iPhone Duo", d.get("state") == "Booted")
            found.append((score, runtime, d))
    if not found:
        return None
    found.sort(key=lambda x: x[0], reverse=True)
    return found[0][2]["udid"]


# ---------------------------------------------------------------------- main

def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, args = argv[1], argv[2:]
    evals_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if cmd == "list":
        tasks_dir = args[0] if args else os.path.join(evals_dir, "tasks")
        for root, dirs, files in os.walk(tasks_dir):
            dirs.sort()
            for name in sorted(files):
                if name.endswith(".md") and name != "README.md":
                    print(os.path.join(root, name))
        return 0
    if cmd == "validate":
        bad = 0
        for path in args:
            for p in validate(path, evals_dir):
                print("%s: %s" % (path, p))
                bad += 1
        return 1 if bad else 0
    if cmd == "field":
        meta, _, _ = parse_task(args[0])
        value = meta.get(args[1], args[2] if len(args) > 2 else "")
        print(value)
        return 0
    if cmd == "prompt":
        _, prompt, _ = parse_task(args[0])
        sys.stdout.write(prompt or "")
        return 0
    if cmd == "checks":
        _, _, checks = parse_task(args[0])
        os.makedirs(args[1], exist_ok=True)
        for ident, code in checks:
            with open(os.path.join(args[1], ident + ".sh"), "w", encoding="utf-8") as f:
                f.write(code)
            print(ident)
        return 0
    if cmd == "transcript":
        info = transcript_info(args[0])
        what = args[1]
        if what == "final":
            sys.stdout.write((info["result"] or "") + "\n")
        elif what == "bash":
            for c in info["bash_commands"]:
                print(c)
        elif what == "skills":
            for s in info["skills_loaded"]:
                print(s)
        else:
            json.dump(info, sys.stdout, indent=2)
            print()
        return 0
    if cmd == "lint-summary":
        json.dump(lint_summary(args[0], args[1]), sys.stdout, indent=2)
        print()
        return 0
    if cmd == "checklist":
        write_checklist(args[0], args[1])
        return 0
    if cmd == "result":
        json.dump(trial_result(args[0]), sys.stdout, indent=2)
        print()
        return 0
    if cmd == "summarize":
        s = summarize(args[0])
        json.dump(s["totals"], sys.stdout, indent=2)
        print()
        return 0
    if cmd == "pick-sim":
        udid = pick_sim()
        if not udid:
            return 1
        print(udid)
        return 0
    if cmd == "allowed-tools":
        summary = bool(args) and args[0] == "--summary"
        if summary:
            args = args[1:]
        if len(args) < 2:
            print("usage: evalkit.py allowed-tools [--summary] <task.md> <developer-dir|-> [plugin-root]",
                  file=sys.stderr)
            return 2
        meta, _, _ = parse_task(args[0])
        developer_dir = "" if args[1] == "-" else args[1]
        plugin_root = args[2] if len(args) > 2 and not summary else None
        rules = allowed_rules(meta, developer_dir, plugin_root)
        bad = [p for p in (rule_problem(r) for r in rules) if p]
        if bad:
            for p in bad:
                print("refusing to run: %s" % p, file=sys.stderr)
            return 1
        if summary:
            print(bash_summary(rules))
        else:
            for r in rules:
                print(r)
        return 0
    if cmd == "denied-tools":
        for r in DENIED_TOOLS:
            print(r)
        return 0
    if cmd == "check-rule":
        bad = 0
        for r in args:
            why = rule_problem(r)
            print("%-60s %s" % (r, why or "ok"))
            bad += 1 if why else 0
        return 1 if bad else 0
    print("unknown command: %s" % cmd, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
