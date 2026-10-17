#!/usr/bin/env python3
"""Tests for scripts/validate-skills.py. Run: python3 -m unittest discover -s scripts/tests -v"""

import contextlib
import importlib.util
import io
import os
import shutil
import tempfile
import textwrap
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
REPO = os.path.dirname(SCRIPTS)

_spec = importlib.util.spec_from_file_location("validate_skills", os.path.join(SCRIPTS, "validate-skills.py"))
vs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vs)

try:
    import yaml  # only used to cross-check the parser when it happens to be installed
except ImportError:  # pragma: no cover
    yaml = None


def parse(text):
    lines = textwrap.dedent(text).strip("\n").split("\n")
    parser = vs.MiniYaml(lines, 2)
    return parser.parse(), parser.notes


GOOD_SKILL = """\
---
name: {name}
description: Does one thing for iPhone Duo. Use it when the fold gets in the way.
metadata:
  verified: "Xcode 27.1 (27A9275), iOS 27.1 simulator, device: no"
  sources: "reference/sources.md"
---

# {name}

Read [the rules](references/rules.md) first. Then open `references/rules.md` again.
"""


class MiniYamlTests(unittest.TestCase):
    def test_plain_quoted_and_nested(self):
        data, notes = parse("""
            name: duo-layout
            description: 'It''s for the fold'
            metadata:
              verified: "Xcode 27.1 (27A9275), device: no"
              sources: reference/sources.md
        """)
        self.assertEqual(data["name"], "duo-layout")
        self.assertEqual(data["description"], "It's for the fold")
        self.assertEqual(data["metadata"]["verified"], "Xcode 27.1 (27A9275), device: no")
        self.assertEqual(notes, [])

    def test_colon_space_in_plain_value_is_an_error(self):
        # The exact shape that broke duo-lint's description: real YAML parsers reject it.
        with self.assertRaises(vs.FrontMatterError) as ctx:
            parse("description: Catches .frame(width: 390) and fixed widths.\n")
        self.assertIn("put the whole value in quotes", ctx.exception.message)
        if yaml:
            with self.assertRaises(yaml.YAMLError):
                yaml.safe_load("description: Catches .frame(width: 390) and fixed widths.\n")

    def test_colon_without_space_is_fine(self):
        data, _ = parse("description: see https://developer.apple.com/x and a:b\n")
        self.assertEqual(data["description"], "see https://developer.apple.com/x and a:b")

    def test_space_hash_cuts_the_value_and_is_reported(self):
        # duo-testing's description lost everything after "@Test and" this way.
        data, notes = parse("description: Swift Testing with @Test and #expect, plus UI tests\n")
        self.assertEqual(data["description"], "Swift Testing with @Test and")
        self.assertEqual(notes[0][1:3], ("description", "comment-cut"))
        if yaml:
            self.assertEqual(yaml.safe_load("d: Swift Testing with @Test and #expect\n")["d"],
                             "Swift Testing with @Test and")

    def test_hash_without_space_stays(self):
        data, notes = parse("description: C# and issue#12 stay\n")
        self.assertEqual(data["description"], "C# and issue#12 stay")
        self.assertEqual(notes, [])

    def test_multiline_plain_value_folds(self):
        data, _ = parse("""
            description: first line
              second line

              after a blank line
            name: x
        """)
        self.assertEqual(data["description"], "first line second line\nafter a blank line")
        self.assertEqual(data["name"], "x")

    def test_block_scalars(self):
        data, _ = parse("""
            folded: >
              one
              two

              three
            literal: |
              a
                b
            stripped: >-
              tail
            kept: |+
              k

            last: end
        """)
        self.assertEqual(data["folded"], "one two\nthree\n")
        self.assertEqual(data["literal"], "a\n  b\n")
        self.assertEqual(data["stripped"], "tail")
        self.assertEqual(data["kept"], "k\n\n")
        self.assertEqual(data["last"], "end")

    def test_double_quoted_escapes_and_folding(self):
        data, _ = parse('d: "tab\\there \\"q\\" \\u00e9 \\\\ end"\n')
        self.assertEqual(data["d"], 'tab\there "q" \u00e9 \\ end')
        data, _ = parse('d: "one\n  two\n\n  three"\n')
        self.assertEqual(data["d"], "one two\nthree")

    def test_unknown_escape_is_an_error(self):
        with self.assertRaises(vs.FrontMatterError):
            parse('d: "C:\\Users"\n')

    def test_lists(self):
        data, _ = parse("""
            flow: [Read, "Grep", 'Bash(git:*)']
            block:
              - one
              - two
            same-indent:
            - a
            - b
            maps:
              - type: command
                command: run.sh
              - type: prompt
            after: done
        """)
        self.assertEqual(data["flow"], ["Read", "Grep", "Bash(git:*)"])
        self.assertEqual(data["block"], ["one", "two"])
        self.assertEqual(data["same-indent"], ["a", "b"])
        self.assertEqual(data["maps"], [{"type": "command", "command": "run.sh"}, {"type": "prompt"}])
        self.assertEqual(data["after"], "done")

    def test_types(self):
        data, notes = parse("""
            i: 12
            f: 1.0
            t: true
            n: null
            e:
            d: 2026-10-16
            s: "1.0"
            no: no
        """)
        self.assertEqual((data["i"], data["f"], data["t"], data["n"], data["e"]), (12, 1.0, True, None, None))
        self.assertIsInstance(data["d"], vs.YamlTimestamp)
        self.assertEqual(data["s"], "1.0")
        self.assertEqual(data["no"], "no")
        self.assertEqual(notes[0][2], "yaml11-bool")

    def test_errors(self):
        cases = {
            "tab": "a:\n\tb: c\n",
            "duplicate": "a: 1\na: 2\n",
            "unclosed": 'a: "open\nb: c\n',
            "anchor": "a: &x 1\n",
            "flow map": "a: {b: c}\n",
            "no space": "a:b\n",
            "item on key line": "a: - b\n",
            "bad indent": "a: 1\n  b: 2\n",
            "backtick": "a: `code`\n",
        }
        for label, text in cases.items():
            with self.subTest(label):
                with self.assertRaises(vs.FrontMatterError):
                    parse(text)

    def test_error_line_numbers_are_file_lines(self):
        with self.assertRaises(vs.FrontMatterError) as ctx:
            vs.parse_front_matter("---\nname: x\ndescription: a: b\n---\nbody\n")
        self.assertEqual(ctx.exception.line, 3)

    @unittest.skipUnless(yaml, "PyYAML not installed")
    def test_agrees_with_pyyaml(self):
        docs = [
            "name: duo-start\ndescription: Entry point. Use it first.\nmetadata:\n  verified: \"Xcode 27.1, device: no\"\n",
            "description: >-\n  folded text\n  over lines\n\n  and a paragraph\nname: x\n",
            "d: |\n  keep\n    indent\n\n  lines\n",
            "d: 'single ''quoted'' text'\nl:\n  - a\n  - 'b c'\n",
            "d: \"esc \\\" \\\\ \\n done\"\n",
            "d: plain\n  continued here\n  and here\n",
            "m:\n  - k: v\n    k2: v2\n  - k: w\n",
            "n: 42\nf: 2.5\nb: false\nz: ~\n",
        ]
        for doc in docs:
            with self.subTest(doc=doc):
                ours = vs.MiniYaml(doc.rstrip("\n").split("\n"), 1).parse()
                self.assertEqual(ours, yaml.safe_load(doc))

    @unittest.skipUnless(yaml, "PyYAML not installed")
    def test_real_skills_agree_with_pyyaml_or_both_fail(self):
        for dirpath, _, files in os.walk(os.path.join(REPO, "plugins")):
            if "SKILL.md" not in files:
                continue
            path = os.path.join(dirpath, "SKILL.md")
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
            with self.subTest(path=os.path.relpath(path, REPO)):
                lines, first, _, _ = vs.split_front_matter(text)
                block = "\n".join(lines)
                try:
                    theirs = yaml.safe_load(block)
                except yaml.YAMLError:
                    theirs = "error"
                try:
                    ours = vs.MiniYaml(lines, first).parse()
                except vs.FrontMatterError:
                    ours = "error"
                self.assertEqual(ours, theirs)


class MarkdownTests(unittest.TestCase):
    def test_links_skip_code_and_comments(self):
        lines = textwrap.dedent("""\
            See [a](a.md) and ![img](img/x.png "t") and [api](x(for:).md).
            `[not](code.md)`
            ```swift
            [not](fenced.md)
            ```
            <!-- [not](comment.md) -->
            [ref]: refs/def.md
            <img src="pic.svg" alt="">
        """).split("\n")
        masked, spans = vs.mask_markdown(lines)
        targets = [t for _, t in vs.find_links(masked)]
        self.assertEqual(targets, ["a.md", "img/x.png", "x(for:).md", "refs/def.md", "pic.svg"])
        self.assertEqual(spans, [(2, "[not](code.md)")])

    def test_slugify(self):
        self.assertEqual(vs.slugify("Rules on the Mac"), "rules-on-the-mac")
        self.assertEqual(vs.slugify("`ArrangementView` (split)"), "arrangementview-split")
        self.assertEqual(vs.slugify("Not in the SDK"), "not-in-the-sdk")


class RepoFixture(unittest.TestCase):
    """Builds a small fake repo in a temp folder."""

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="validate-skills-")
        os.makedirs(os.path.join(self.root, "reference"))
        self.write("reference/sources.md", "# Sources\n")

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        return path

    def skill(self, name="duo-demo", plugin="duology", text=None, refs=True):
        base = "plugins/%s/skills/%s" % (plugin, name)
        self.write(base + "/SKILL.md", GOOD_SKILL.format(name=name) if text is None else text)
        if refs:
            self.write(base + "/references/rules.md", "# Rules\n\n## Rules on the Mac\n")
        return base

    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = vs.main(["--root", self.root] + list(args))
        return code, out.getvalue()


class CheckerTests(RepoFixture):
    def test_good_skill_passes(self):
        self.skill()
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn("1 skill checked · 0 errors · 0 warnings", out)

    def test_missing_skill_md(self):
        os.makedirs(os.path.join(self.root, "plugins/duology/skills/duo-empty"))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("has no SKILL.md", out)

    def test_name_must_match_folder_and_rules(self):
        self.skill(name="duo-demo", text=GOOD_SKILL.format(name="Duo-Demo"))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("may use only a-z", out)
        self.assertIn("must match the folder name", out)

    def test_description_rules(self):
        long = "x" * 1025
        self.skill(text=GOOD_SKILL.format(name="duo-demo").replace(
            "Does one thing for iPhone Duo. Use it when the fold gets in the way.", long))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("1025 characters", out)

    def test_description_cut_by_comment_is_an_error(self):
        self.skill(text=GOOD_SKILL.format(name="duo-demo").replace(
            "Use it when the fold gets in the way.", "Use @Test and #expect."))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("YAML comment", out)

    def test_metadata_verified_required_and_shaped(self):
        text = GOOD_SKILL.format(name="duo-demo")
        self.skill(text=text.replace('  verified: "Xcode 27.1 (27A9275), iOS 27.1 simulator, device: no"\n', ""))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("no 'verified' line", out)
        self.skill(text=text.replace("device: no", "on my phone"))
        code, out = self.run_main()
        self.assertIn("must name the Xcode version", out)

    def test_metadata_values_must_be_strings(self):
        text = GOOD_SKILL.format(name="duo-demo").replace("metadata:\n", "metadata:\n  version: 1.0\n")
        self.skill(text=text)
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("metadata.version is float", out)

    def test_sources_path_must_exist(self):
        text = GOOD_SKILL.format(name="duo-demo").replace("reference/sources.md", "reference/missing.md")
        self.skill(text=text)
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("reference/missing.md, which doesn't exist", out)

    def test_line_limit(self):
        text = GOOD_SKILL.format(name="duo-demo") + "line\n" * 300
        self.skill(text=text)
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("keep it to 300 or fewer", out)
        code, out = self.run_main("--max-lines", "400")
        self.assertEqual(code, 0, out)

    def test_broken_link_and_case_mismatch(self):
        base = self.skill(text=GOOD_SKILL.format(name="duo-demo") + "\n[gone](references/gone.md)\n"
                          "[case](references/RULES.md)\n")
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("broken link: %s/references/gone.md doesn't exist" % base, out)
        if os.path.exists(os.path.join(self.root, base, "references", "RULES.md")):
            # Case-insensitive file system (macOS default): the case check must still fire.
            self.assertIn("different letter case", out)
        else:
            self.assertIn("references/RULES.md doesn't exist", out)

    def test_absolute_and_outside_links(self):
        self.skill(text=GOOD_SKILL.format(name="duo-demo") + "\n[abs](/reference/sources.md)\n"
                        "[up](../../../../../outside.md)\n[ok](../../../../reference/sources.md)\n")
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("starts with '/'", out)
        self.assertIn("points outside the repository", out)
        self.assertIn("note: 1 link leave", out)
        code, out = self.run_main("--portable")
        self.assertIn("leaves the skill folder", out)

    def test_anchor_warnings(self):
        self.skill(text=GOOD_SKILL.format(name="duo-demo") +
                   "\n[ok](references/rules.md#rules-on-the-mac)\n[bad](references/rules.md#nope)\n[self](#nowhere)\n")
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn("has no heading or anchor '#nope'", out)
        self.assertIn("link to #nowhere", out)
        code, _ = self.run_main("--strict")
        self.assertEqual(code, 1)

    def test_inline_code_mentions(self):
        self.skill(name="duo-other", text=GOOD_SKILL.format(name="duo-other"))
        self.write("plugins/duology/skills/duo-other/references/testing.md", "# Testing\n")
        self.skill(text=GOOD_SKILL.format(name="duo-demo") +
                   "\nSee `references/missing.md`.\n"
                   "See `duo-other`'s `references/testing.md`.\n"
                   "Glob `references/*.md` is skipped.\n")
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn("`references/missing.md` names a file that doesn't exist", out)
        self.assertNotIn("references/testing.md` names", out)

    def test_links_in_code_are_ignored(self):
        self.skill(text=GOOD_SKILL.format(name="duo-demo") + "\n```\n[x](nope.md)\n```\n`[y](nope.md)`\n")
        code, out = self.run_main()
        self.assertEqual(code, 0, out)

    def test_duplicate_skill_names_across_plugins(self):
        self.skill(plugin="duology")
        self.skill(plugin="duology-design")
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("used by more than one plugin", out)

    def test_misplaced_skill_md_warns(self):
        self.skill()
        self.write("plugins/duology/skills/duo-demo/nested/SKILL.md", GOOD_SKILL.format(name="nested"))
        code, out = self.run_main()
        self.assertIn("isn't at plugins/<plugin>/skills/<skill>/SKILL.md", out)

    def test_unknown_key_warns(self):
        self.skill(text=GOOD_SKILL.format(name="duo-demo").replace("metadata:", "colour: blue\nmetadata:"))
        code, out = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("unknown front matter key 'colour'", out)

    def test_no_front_matter(self):
        self.skill(text="# Just a heading\n")
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("must start with a '---' line", out)

    def test_command_front_matter(self):
        self.skill()
        self.write("plugins/duology/commands/duo-good.md",
                   "---\nname: duo-good\ndescription: \"Runs it: fast.\"\nallowed-tools:\n  - Read\n---\nBody\n")
        self.write("plugins/duology/commands/duo-bad.md", "---\ndescription: Runs it: fast.\n---\nBody\n")
        self.write("plugins/duology/agents/duo-agent.md", "---\nname: other\n---\nBody\n")
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("commands/duo-bad.md:2: error: front matter: description", out)
        self.assertNotIn("duo-good.md", out)
        self.assertIn("agents/duo-agent.md:2: warning: no 'description'", out)
        self.assertIn("differs from the file name", out)

    def test_github_format(self):
        self.skill(text=GOOD_SKILL.format(name="duo-demo") + "\n[gone](gone.md)\n")
        code, out = self.run_main("--format", "github")
        self.assertEqual(code, 1)
        self.assertIn("::error file=plugins/duology/skills/duo-demo/SKILL.md,line=", out)

    def test_paths_argument_limits_the_check(self):
        self.skill(name="duo-demo")
        self.skill(name="duo-broken", text="no front matter\n")
        code, out = self.run_main(os.path.join(self.root, "plugins/duology/skills/duo-demo"))
        self.assertEqual(code, 0, out)

    def test_path_to_skill_folder_without_skill_md(self):
        os.makedirs(os.path.join(self.root, "plugins/duology/skills/duo-wip/references"))
        code, out = self.run_main(os.path.join(self.root, "plugins/duology/skills/duo-wip"))
        self.assertEqual(code, 1)
        self.assertIn("has no SKILL.md", out)

    def test_bad_root(self):
        empty = tempfile.mkdtemp()
        try:
            with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(vs.main(["--root", empty]), 2)
        finally:
            shutil.rmtree(empty)


class RealRepoTest(unittest.TestCase):
    def test_script_runs_on_this_repo(self):
        """The script must finish on the real repo; failures in skills are reported, not crashes."""
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = vs.main(["--root", REPO, "-q"])
        self.assertIn(code, (0, 1))
        self.assertRegex(out.getvalue(), r"\d+ skills? checked")


if __name__ == "__main__":
    unittest.main()
