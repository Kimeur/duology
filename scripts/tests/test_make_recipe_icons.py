#!/usr/bin/env python3
"""Tests for scripts/make-recipe-icons.py. Run: python3 -m unittest discover -s scripts/tests -v"""

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

_spec = importlib.util.spec_from_file_location("make_recipe_icons", os.path.join(SCRIPTS, "make-recipe-icons.py"))
mri = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mri)


def recipes():
    return sorted(d for d in os.listdir(mri.RECIPES) if d.startswith("recipe-"))


class RecipeIconTests(unittest.TestCase):
    def test_every_recipe_has_a_design(self):
        self.assertEqual(recipes(), sorted(mri.DESIGNS))

    def test_contents_json_names_the_icon(self):
        for recipe in recipes():
            path = os.path.join(mri.RECIPES, recipe, os.path.dirname(mri.ICON_PATH), "Contents.json")
            with open(path, encoding="utf-8") as fh:
                images = json.load(fh)["images"]
            self.assertEqual([(i.get("filename"), i.get("size")) for i in images], [("AppIcon.png", "1024x1024")],
                             recipe)

    def test_icons_are_1024_rgb_without_alpha(self):
        for recipe in recipes():
            width, height, depth, ctype, rows = mri.read_png(os.path.join(mri.RECIPES, recipe, mri.ICON_PATH))
            self.assertEqual((width, height, depth, ctype), (1024, 1024, 8, 2), recipe)
            self.assertEqual(len(rows), 1024)

    def test_committed_icons_match_the_script(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = mri.main(["--check"])
        self.assertEqual(code, 0, out.getvalue())

    def test_check_fails_on_a_changed_icon(self):
        recipe = "recipe-kids-learning"
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        copy = os.path.join(tmp, recipe, mri.ICON_PATH)
        os.makedirs(os.path.dirname(copy))
        rows = mri.draw(mri.DESIGNS[recipe])
        rows[0] = b"\x00\x00\x00" + rows[0][3:]
        with open(copy, "wb") as fh:
            fh.write(mri.png(rows))
        saved = (mri.RECIPES, mri.DESIGNS)
        mri.RECIPES, mri.DESIGNS = tmp, {recipe: mri.DESIGNS[recipe]}
        try:
            with contextlib.redirect_stdout(io.StringIO()) as out:
                code = mri.main(["--check"])
        finally:
            mri.RECIPES, mri.DESIGNS = saved
        self.assertEqual(code, 1)
        self.assertIn("differs", out.getvalue())


if __name__ == "__main__":
    unittest.main()
