#!/usr/bin/env python3
"""Tests for scripts/check-manifests.py. Run: python3 -m unittest discover -s scripts/tests -v"""

import contextlib
import importlib.util
import io
import json
import os
import shutil
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
REPO = os.path.dirname(SCRIPTS)

_spec = importlib.util.spec_from_file_location("check_manifests", os.path.join(SCRIPTS, "check-manifests.py"))
cm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cm)


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="check-manifests-")
        self.write_json(".claude-plugin/marketplace.json", {
            "name": "duology",
            "owner": {"name": "Kimeur"},
            "plugins": [{"name": "duology", "source": "./plugins/duology"}],
        })
        self.write_json("plugins/duology/.claude-plugin/plugin.json", {"name": "duology", "version": "0.1.0"})
        self.write("plugins/duology/hooks/lint-hook.sh", "#!/bin/sh\n")
        self.write_json("plugins/duology/hooks/hooks.json", {"hooks": {"PostToolUse": [{
            "matcher": "Edit|Write",
            "hooks": [{"type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/lint-hook.sh\"",
                       "timeout": 15}]}]}})

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)

    def write_json(self, rel, data):
        self.write(rel, json.dumps(data, indent=2))

    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = cm.main(["--root", self.root] + list(args))
        return code, out.getvalue()

    def test_good_setup_passes(self):
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn("3 JSON files checked · 0 errors · 0 warnings", out)

    def test_invalid_json_and_duplicate_keys(self):
        self.write("samples/App/Assets.xcassets/Contents.json", '{"info": {"version": 1,}}')
        self.write("other.json", '{"a": 1, "a": 2}')
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("invalid JSON at line 1", out)
        self.assertIn("duplicate key 'a'", out)

    def test_marketplace_source_rules(self):
        self.write_json(".claude-plugin/marketplace.json", {
            "name": "duology",
            "owner": {"name": "Kimeur"},
            "plugins": [
                {"name": "duology", "source": "./plugins/duology"},
                {"name": "duology", "source": "./plugins/duology"},
                {"name": "ghost", "source": "./plugins/ghost"},
                {"name": "up", "source": "./../elsewhere"},
                {"name": "bare", "source": "plugins/duology"},
                {"name": "bad name", "source": {"source": "github", "repo": "a/b"}},
            ],
        })
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("plugin 'duology' is listed twice", out)
        self.assertIn("source folder ./plugins/ghost doesn't exist", out)
        self.assertIn("can't use '..'", out)
        self.assertIn("must start with './'", out)
        self.assertIn("can't contain spaces", out)

    def test_plugin_root_bare_names(self):
        self.write_json(".claude-plugin/marketplace.json", {
            "name": "duology", "owner": {"name": "Kimeur"}, "metadata": {"pluginRoot": "./plugins"},
            "plugins": [{"name": "duology", "source": "duology"}]})
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_marketplace_required_fields(self):
        self.write_json(".claude-plugin/marketplace.json", {"name": "my market", "plugins": []})
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("may use only letters", out)
        self.assertIn("'owner' is required", out)
        self.assertIn("non-empty list", out)

    def test_unlisted_plugin_warns(self):
        self.write_json("plugins/duology-extra/.claude-plugin/plugin.json", {"name": "duology-extra"})
        code, out = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("plugins/duology-extra isn't listed", out)
        self.assertEqual(self.run_main("--strict")[0], 1)

    def test_plugin_manifest(self):
        self.write_json("plugins/duology/.claude-plugin/plugin.json",
                        {"name": "other", "version": "v1", "skills": "./missing-skills"})
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("differs from its folder", out)
        self.assertIn("should be semantic", out)
        self.assertIn("lists ./missing-skills, which doesn't exist", out)

    def test_hooks(self):
        self.write_json("plugins/duology/hooks/hooks.json", {"hooks": {"PostToolUse": [
            {"hooks": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/gone.sh"},
                       {"type": "command"},
                       {"command": "x"}]}]}})
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("${CLAUDE_PLUGIN_ROOT}/hooks/gone.sh, which doesn't exist", out)
        self.assertIn("a command hook needs a 'command'", out)
        self.assertIn("needs a 'type'", out)

    def test_hooks_need_wrapper(self):
        self.write_json("plugins/duology/hooks/hooks.json", {"PostToolUse": []})
        code, out = self.run_main()
        self.assertIn("top-level \"hooks\" object", out)

    def test_skips_research_and_git(self):
        self.write(".research/scratch/bad.json", "{")
        self.write(".git/bad.json", "{")
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_real_repo(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = cm.main(["--root", REPO])
        self.assertIn(code, (0, 1))
        self.assertIn("JSON files checked", out.getvalue())


if __name__ == "__main__":
    unittest.main()
