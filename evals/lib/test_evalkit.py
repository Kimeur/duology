#!/usr/bin/env python3
"""Tests for evalkit.py: the permission gate, task files, transcripts and verdicts.

Run: python3 -B evals/lib/test_evalkit.py
Standard library only, Python 3.9 or later. No Claude, no Xcode.
"""
import glob
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
EVALS = os.path.dirname(HERE)
REPO = os.path.dirname(EVALS)
sys.path.insert(0, HERE)
import evalkit  # noqa: E402

TASKS = sorted(glob.glob(os.path.join(EVALS, "tasks", "*", "*.md")))
XCODE = "/Applications/Xcode-27.1.app/Contents/Developer"


class RuleGate(unittest.TestCase):
    BROAD = [
        "Bash", "Bash()", "Bash(*)", "Bash(:*)", "Bash( * )",
        "Agent", "Task", "WebFetch", "WebSearch", "mcp__github__create_issue",
        "Bash(python3 *duo-lint*)", "Bash(python3:*)", "Bash(python3 -c:*)", "Bash(bash:*)",
        "Bash(bash *)", "Bash(sh -c:*)", "Bash(swift *)", "Bash(node:*)",
        "Bash(sudo xcodebuild:*)", "Bash(rm -rf:*)", "Bash(curl:*)", "Bash(env -i:*)",
        "Bash(xargs:*)", "Bash(osascript:*)", "Bash(open:*)", "Bash(claude:*)",
        "Bash(git:*)", "Bash(git push:*)", "Bash(git config:*)", "Bash(git *)",
        "Bash(xcrun:*)", "Bash(xcrun python3:*)", "Bash(xcrun * simctl:*)",
        "Bash(xcode-select -s:*)", "Bash(xcode-select:*)", "Bash(defaults write:*)",
        "Bash(FOO=1 xcodebuild:*)", "Bash(*/Tools/run.sh)", "Bash(*xcodebuild*)",
        "Read(./**)", "Edit(/etc/**)", "Bash(a,b)",
        # Wildcards outside a project folder: these cover /bin/rm, /usr/bin/curl and so on.
        "Bash(/bin/*)", "Bash(/usr/bin/*)", "Bash(../*)", "Bash(./*)", "Bash(Tools/../*)",
        "Bash(./:*)", "Bash(/:*)", "Bash(Tools/../../bin/rm:*)", "Bash(bash ../*)",
        "Bash(python3 /tmp/*)", "Bash(bash Tools/../x.sh)",
        # Commands that run other commands.
        "Bash(arch:*)", "Bash(caffeinate:*)", "Bash(source:*)", "Bash(.:*)", "Bash(find:*)",
        "Bash(time:*)", "Bash(nice:*)", "Bash(timeout:*)", "Bash(command:*)", "Bash(awk:*)",
        "Bash(/usr/bin/find:*)",
        # git that writes, or hides the subcommand behind an option.
        "Bash(git commit:*)", "Bash(git reset:*)", "Bash(git clean:*)", "Bash(git checkout:*)",
        "Bash(git -C . push:*)", "Bash(git -c x=y diff:*)", "Bash(git branch:*)",
    ]
    SCOPED = [
        "Read", "Edit", "Write", "Glob", "Grep", "Skill",
        "Bash(xcodebuild:*)", "Bash(xcrun simctl:*)", "Bash(git diff:*)", "Bash(git status:*)",
        "Bash(xcrun -sdk macosx swiftc:*)", "Bash(xcrun --find *)",
        "Bash(bash Tools/run-logic-tests.sh:*)", "Bash(bash Tools/*)", "Bash(Tools/*)", "Bash(./Tools/*)",
        "Bash(DEVELOPER_DIR=* xcodebuild *)", "Bash(DEVELOPER_DIR=%s xcrun simctl:*)" % XCODE,
        "Bash(xcode-select -p)", "Bash(swift test:*)", "Bash(defaults read *)",
        "Bash(python3 /tmp/x/plugins/duology-ship/skills/duo-lint/scripts/duo-lint.py:*)",
        'Bash("/tmp/x/plugins/duology-ship/skills/duo-lint/scripts/duo-lint" *)',
        "Bash(/tmp/x/plugins/duology/bin/duo-doctor:*)", "Bash(duo-doctor:*)",
        "Bash(git log:*)", "Bash(git show:*)", "Bash(Tools/run-logic-tests.sh:*)",
        "Bash(./Tools/run-logic-tests.sh:*)", "Bash(mdfind:*)", "Bash(chmod +x *)",
    ]

    def test_broad_rules_are_refused(self):
        for rule in self.BROAD:
            with self.subTest(rule=rule):
                self.assertIsNotNone(evalkit.rule_problem(rule))

    def test_scoped_rules_are_accepted(self):
        for rule in self.SCOPED:
            with self.subTest(rule=rule):
                self.assertIsNone(evalkit.rule_problem(rule))

    def test_base_list_is_scoped(self):
        for rule in evalkit.BASE_TOOLS:
            self.assertIsNone(evalkit.rule_problem(rule), rule)
        self.assertNotIn("Bash", evalkit.BASE_TOOLS)
        self.assertNotIn("Agent", evalkit.BASE_TOOLS)

    def test_agent_and_web_are_denied(self):
        for tool in ("Agent", "WebFetch", "WebSearch"):
            self.assertIn(tool, evalkit.DENIED_TOOLS)

    def test_destructive_simctl_is_denied(self):
        for sub in ("delete", "erase", "spawn"):
            self.assertIn("Bash(xcrun simctl %s:*)" % sub, evalkit.DENIED_TOOLS)
            self.assertIn("Bash(DEVELOPER_DIR=* xcrun simctl %s *)" % sub, evalkit.DENIED_TOOLS)


class TaskFiles(unittest.TestCase):
    def test_there_are_tasks_for_every_v01_skill(self):
        skills = {os.path.basename(os.path.dirname(t)) for t in TASKS}
        for s in ("duo-start", "duo-setup", "duo-layout", "duo-navigation", "duo-continuity",
                  "duo-patterns", "duo-shared-screen", "duo-design-review", "duo-testing",
                  "duo-lint", "recipe-two-player-game"):
            self.assertIn(s, skills)

    def test_every_task_is_valid(self):
        for path in TASKS:
            with self.subTest(task=os.path.relpath(path, EVALS)):
                self.assertEqual(evalkit.validate(path, EVALS), [])

    def test_four_readme_tasks(self):
        readme = [t for t in TASKS if evalkit.parse_task(t)[0].get("readme") == "yes"]
        self.assertEqual(len(readme), 4)

    def test_allowed_rules_for_every_task_and_arm_are_scoped(self):
        plugins = os.path.join(REPO, "plugins")
        for path in TASKS:
            meta, _, _ = evalkit.parse_task(path)
            dev = "" if meta.get("developer_dir") == "unset" else XCODE
            for root in (None, plugins):
                rules = evalkit.allowed_rules(meta, dev, root)
                with self.subTest(task=meta["id"], plugins=bool(root)):
                    self.assertEqual([r for r in rules if evalkit.rule_problem(r)], [])

    def test_arms_differ_only_by_plugin_rules(self):
        meta, _, _ = evalkit.parse_task(os.path.join(EVALS, "tasks", "duo-layout", "existing-list-app.md"))
        plugins = os.path.join(REPO, "plugins")
        without = evalkit.allowed_rules(meta, XCODE)
        with_ = evalkit.allowed_rules(meta, XCODE, plugins)
        self.assertEqual(with_[:len(without)], without)
        self.assertTrue(all(plugins in r or r == "Bash(duo-doctor:*)" for r in with_[len(without):]))

    def test_mac_check_starts_without_developer_dir(self):
        meta, _, _ = evalkit.parse_task(os.path.join(EVALS, "tasks", "duo-setup", "mac-check.md"))
        self.assertEqual(meta.get("developer_dir"), "unset")
        rules = evalkit.allowed_rules(meta, "")
        self.assertFalse(any(XCODE in r for r in rules))


def write_jsonl(path, events):
    with open(path, "w") as f:
        for e in events:
            f.write(json.dumps(e) + "\n")


class Transcripts(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dir)

    def test_denials_from_result_event(self):
        t = os.path.join(self.dir, "t.jsonl")
        write_jsonl(t, [{"type": "result", "result": "done", "permission_denials": [
            {"tool_name": "Bash", "tool_input": {"command": "rm -rf build"}}]}])
        self.assertEqual(evalkit.transcript_info(t)["permission_denials"], ["Bash: rm -rf build"])

    def test_denials_fallback_from_tool_results(self):
        t = os.path.join(self.dir, "t.jsonl")
        write_jsonl(t, [
            {"type": "assistant", "message": {"content": [
                {"type": "tool_use", "id": "a1", "name": "Bash", "input": {"command": "curl x"}},
                {"type": "tool_use", "id": "a2", "name": "Bash", "input": {"command": "xcodebuild"}}]}},
            {"type": "user", "message": {"content": [
                {"type": "tool_result", "tool_use_id": "a1", "is_error": True,
                 "content": "Claude requested permissions to use Bash, but you haven't granted it yet."},
                {"type": "tool_result", "tool_use_id": "a2", "is_error": True, "content": "build failed"}]}},
            {"type": "result", "result": "done"}])
        self.assertEqual(evalkit.transcript_info(t)["permission_denials"], ["Bash: curl x"])


class Verdicts(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dir)

    def meta(self, **kw):
        with open(os.path.join(self.dir, "meta.json"), "w") as f:
            json.dump(kw, f)

    def test_unscored_trial_is_not_a_pass(self):
        self.meta(task="t", arm="with", trial=1, agent_exit=0)
        self.assertEqual(evalkit.trial_result(self.dir)["status"], "unscored")

    def test_scored_trial_without_checklist_passes(self):
        self.meta(task="t", arm="with", trial=1, agent_exit=0, scored=True, check_ids=["c"])
        os.makedirs(os.path.join(self.dir, "checks"))
        with open(os.path.join(self.dir, "checks", "c.exit"), "w") as f:
            f.write("0\n")
        self.assertEqual(evalkit.trial_result(self.dir)["status"], "pass")

    def test_failed_check_fails(self):
        self.meta(task="t", arm="with", trial=1, agent_exit=0, scored=True, check_ids=["c"])
        os.makedirs(os.path.join(self.dir, "checks"))
        with open(os.path.join(self.dir, "checks", "c.exit"), "w") as f:
            f.write("1\n")
        self.assertEqual(evalkit.trial_result(self.dir)["status"], "fail")

    def test_contaminated_without_arm(self):
        self.meta(task="t", arm="without", trial=1, agent_exit=0, scored=True, check_ids=[])
        write_jsonl(os.path.join(self.dir, "transcript.jsonl"), [
            {"type": "assistant", "message": {"content": [
                {"type": "tool_use", "id": "a", "name": "Skill", "input": {"skill": "duo-layout"}}]}},
            {"type": "result", "result": "done"}])
        self.assertEqual(evalkit.trial_result(self.dir)["status"], "contaminated")


class Summary(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dir)

    def put(self, rel, data):
        path = os.path.join(self.dir, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(data if isinstance(data, str) else json.dumps(data))
        return path

    def test_only_trial_folders_count(self):
        trial = "duo-lint/lint-and-fix/with/trial-1"
        self.put("run.json", {"run_id": "x"})
        self.put(trial + "/meta.json", {"task": "duo-lint/lint-and-fix", "arm": "with", "trial": 1,
                                        "agent_exit": 0, "scored": True, "check_ids": ["c"]})
        self.put(trial + "/checks/c.exit", "1\n")
        fake = {"task": "duo-lint/lint-and-fix", "arm": "with", "trial": 2, "score_only": True,
                "scored": True}
        # A meta.json the agent wrote in its work folder, saved in final-tree/.
        self.put(trial + "/final-tree/Notes/meta.json", fake)
        self.put(trial + "/final-tree/a/b/with/trial-2/meta.json", fake)
        self.put(trial + "/checks/meta.json", fake)
        # Folders that don't have the trial shape.
        self.put("duo-lint/meta.json", fake)
        self.put("duo-lint/lint-and-fix/other/trial-1/meta.json", fake)
        summary = evalkit.summarize(self.dir)
        arms = summary["tasks"][0]["arms"]
        self.assertEqual(len(summary["tasks"]), 1)
        self.assertEqual(list(arms), ["with"])
        self.assertEqual(arms["with"]["trials"], 1)
        self.assertEqual(arms["with"]["counts"]["fail"], 1)
        self.assertEqual(arms["with"]["results"], [trial + "/result.json"])
        self.assertFalse(os.path.exists(os.path.join(self.dir, trial, "final-tree", "Notes", "result.json")))
        with open(os.path.join(self.dir, "summary.md")) as f:
            self.assertIn("0/1 pass", f.read())

    def test_folder_decides_task_and_arm(self):
        self.put("duo-setup/mac-check/without/trial-1/meta.json", {
            "task": "duo-lint/lint-and-fix", "arm": "with", "trial": 1, "agent_exit": 0,
            "scored": True, "check_ids": []})
        summary = evalkit.summarize(self.dir)
        self.assertEqual(summary["tasks"][0]["id"], "duo-setup/mac-check")
        self.assertEqual(list(summary["tasks"][0]["arms"]), ["without"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
