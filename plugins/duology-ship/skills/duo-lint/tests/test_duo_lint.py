#!/usr/bin/env python3
"""Tests for duo-lint. Run: python3 -m unittest discover -s tests -v (from the skill folder)."""

import importlib.util
import json
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
PLUGIN = os.path.dirname(os.path.dirname(SKILL))
REPO = os.path.dirname(os.path.dirname(PLUGIN))
FIXTURES = os.path.join(HERE, "fixtures")
SAMPLE = os.path.join(FIXTURES, "sample")
SCRIPT = os.path.join(SKILL, "scripts", "duo-lint.py")
LAUNCHER = os.path.join(SKILL, "scripts", "duo-lint")
PLUGIN_BIN = os.path.join(PLUGIN, "bin", "duo-lint")
HOOK_SH = os.path.join(PLUGIN, "hooks", "lint-hook.sh")
HOOKS_JSON = os.path.join(PLUGIN, "hooks", "hooks.json")

_spec = importlib.util.spec_from_file_location("duo_lint", SCRIPT)
duo_lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(duo_lint)

_EXPECT = re.compile(r"expect:((?:\s+DUO\d{3})+)")


def expected_findings(path):
    """Read the (line, rule) pairs a fixture promises with 'expect:' markers."""
    pairs = set()
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, start=1):
            m = _EXPECT.search(line)
            if m:
                for rule in m.group(1).split():
                    pairs.add((lineno, rule))
    return pairs


def lint_text(text, lang="swift", rules=None):
    return [(f.line, f.rule.id) for f in duo_lint.lint_source(text, "t.swift", lang, rules)]


def run_cli(*args, stdin=None, env=None):
    full_env = dict(os.environ)
    full_env.update(env or {})
    return subprocess.run([sys.executable, SCRIPT] + list(args), input=stdin,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          universal_newlines=True, env=full_env, cwd=FIXTURES)


class FixtureTests(unittest.TestCase):
    def check_fixture(self, name, kind):
        path = os.path.join(FIXTURES, name)
        got = {(f.line, f.rule.id) for f in duo_lint.lint_file(path, kind)}
        want = expected_findings(path)
        self.assertTrue(want, "fixture has no expect: markers")
        self.assertEqual(sorted(got - want), [], "unexpected findings")
        self.assertEqual(sorted(want - got), [], "missing findings")

    def test_bad_swift(self):
        self.check_fixture("bad.swift", "swift")

    def test_bad_objc(self):
        self.check_fixture("bad.m", "objc")

    def test_bad_swift_covers_every_source_rule(self):
        rules = {r for _, r in expected_findings(os.path.join(FIXTURES, "bad.swift"))}
        self.assertEqual(rules, {r.id for r in duo_lint.RULES} - {"DUO008"})

    def test_good_swift_is_clean(self):
        findings = duo_lint.lint_file(os.path.join(FIXTURES, "good.swift"), "swift")
        self.assertEqual([(f.line, f.rule.id) for f in findings], [])

    def test_info_plist(self):
        findings = duo_lint.lint_file(os.path.join(FIXTURES, "Info.plist"), "plist")
        self.assertEqual([(f.line, f.rule.id) for f in findings], [(8, "DUO008")])

    def test_xcconfig(self):
        findings = duo_lint.lint_file(os.path.join(FIXTURES, "Legacy.xcconfig"), "settings")
        self.assertEqual([(f.line, f.rule.id) for f in findings], [(3, "DUO008")])


class PlistTests(unittest.TestCase):
    XML = ('<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0">\n<dict>\n'
           '{extra}\t<key>UIRequiresFullScreen</key>\n\t<{value}/>\n</dict>\n</plist>\n')

    def lint(self, text):
        return [(f.line, f.rule.id) for f in duo_lint.lint_plist_bytes(text.encode("utf-8"))]

    def test_false_is_fine(self):
        self.assertEqual(self.lint(self.XML.format(extra="", value="false")), [])

    def test_ignored_starting_with_version_is_fine(self):
        extra = ("\t<key>UIRequiresFullScreenIgnoredStartingWithVersion</key>\n"
                 "\t<string>26</string>\n")
        self.assertEqual(self.lint(self.XML.format(extra=extra, value="true")), [])

    def test_disable_comment(self):
        extra = "\t<!-- duo-lint:disable-next-line DUO008 -->\n"
        self.assertEqual(self.lint(self.XML.format(extra=extra, value="true")), [])

    def test_binary_plist(self):
        data = plistlib.dumps({"UIRequiresFullScreen": True}, fmt=plistlib.FMT_BINARY)
        findings = duo_lint.lint_plist_bytes(data)
        self.assertEqual([(f.line, f.rule.id) for f in findings], [(1, "DUO008")])

    def test_pbxproj_build_setting(self):
        text = ('\t\t\t\tINFOPLIST_KEY_UIRequiresFullScreen = YES;\n'
                '\t\t\t\tINFOPLIST_KEY_UIRequiresFullScreen = NO;\n')
        findings = duo_lint.lint_build_settings(text)
        self.assertEqual([(f.line, f.rule.id) for f in findings], [(1, "DUO008")])


class LexerTests(unittest.TestCase):
    def code(self, text, lang="swift"):
        return duo_lint.split_code_and_comments(text, lang)[0]

    def test_keeps_length_and_newlines(self):
        text = 'let a = "x\\"y" // c\n/* b\n c */ let d = 1\n'
        code, comments = duo_lint.split_code_and_comments(text, "swift")
        self.assertEqual(len(code), len(text))
        self.assertEqual(len(comments), len(text))
        self.assertEqual(code.count("\n"), text.count("\n"))
        self.assertIn("let d = 1", code)
        self.assertNotIn("x", code.split("\n")[0].split("=")[1])
        self.assertIn("// c", comments)

    def test_nested_block_comment_in_swift(self):
        code = self.code("/* a /* b */ UIScreen.main */ let x = 1")
        self.assertNotIn("UIScreen", code)
        self.assertIn("let x = 1", code)

    def test_block_comment_in_objc_is_not_nested(self):
        code = self.code("/* a /* b */ int x = 1;", "objc")
        self.assertIn("int x = 1;", code)

    def test_interpolation_stays_code(self):
        code = self.code('let s = "w \\(UIScreen.main.bounds.width) \\("x")"')
        self.assertIn("UIScreen.main.bounds.width", code)
        self.assertNotIn("w ", code.split("=", 1)[1].replace("UIScreen", ""))

    def test_raw_string(self):
        code = self.code('let s = #"say "UIScreen.main" \\(no)"# ; let t = 2')
        self.assertNotIn("UIScreen", code)
        self.assertIn("let t = 2", code)

    def test_raw_string_interpolation(self):
        code = self.code('let s = #"a \\#(UIScreen.main.scale) b"#')
        self.assertIn("UIScreen.main.scale", code)

    def test_multiline_string(self):
        code = self.code('let s = """\n  UIScreen.main\n  "quoted"\n  """\nlet t = 3\n')
        self.assertNotIn("UIScreen", code)
        self.assertIn("let t = 3", code)

    def test_hash_directives_are_code(self):
        code = self.code("#if DEBUG\nlet x = UIScreen.main\n#endif\n")
        self.assertIn("UIScreen.main", code)

    def test_objc_strings_and_chars(self):
        code = self.code("NSString *s = @\"[UIScreen mainScreen]\"; char c = '\"'; int y = 2;",
                         "objc")
        self.assertNotIn("UIScreen", code)
        self.assertIn("int y = 2;", code)


class RuleTests(unittest.TestCase):
    def test_comments_and_strings_are_ignored(self):
        text = ('// UIScreen.main.bounds\n'
                'let s = "UIDevice.current.orientation == .pad"\n'
                '/* if view.bounds.height == 844 { } */\n')
        self.assertEqual(lint_text(text), [])

    def test_effective_geometry_is_a_warning_not_an_error(self):
        text = "let o = scene.effectiveGeometry.interfaceOrientation\n"
        self.assertEqual(lint_text(text), [(1, "DUO002")])

    def test_window_scene_interface_orientation_is_an_error(self):
        text = ("func f(windowScene: UIWindowScene) {\n"
                "    let o = windowScene.interfaceOrientation\n"
                "}\n")
        self.assertEqual(lint_text(text), [(2, "DUO003")])

    def test_untyped_receiver_is_only_a_warning(self):
        # duo-lint can't see the type, so it doesn't claim the API is deprecated.
        self.assertEqual(lint_text("let o = windowScene.interfaceOrientation\n"),
                         [(1, "DUO002")])

    def test_geometry_through_any_name_is_a_warning(self):
        text = ("func f(_ ws: UIWindowScene, previous p: UIWindowScene.Geometry) {\n"
                "    let current = ws.effectiveGeometry\n"
                "    let g = current\n"
                "    print(current.interfaceOrientation, g.interfaceOrientation)\n"
                "    print(p.interfaceOrientation)\n"
                "    print((ws.effectiveGeometry).interfaceOrientation)\n"
                "    print(ws.effectiveGeometry\n"
                "        .interfaceOrientation)\n"
                "}\n")
        self.assertEqual(lint_text(text), [(4, "DUO002"), (5, "DUO002"), (6, "DUO002"),
                                           (8, "DUO002")])

    def test_deprecated_receivers_are_errors(self):
        text = ("func f(scene: UIScene, vc: UIViewController) {\n"
                "    guard let ws = scene as? UIWindowScene else { return }\n"
                "    print(ws.interfaceOrientation)\n"
                "    print(vc.interfaceOrientation)\n"
                "    print((scene as? UIWindowScene)?.interfaceOrientation as Any)\n"
                "    let fromView = vc.view.window?.windowScene\n"
                "    print(fromView?.interfaceOrientation as Any)\n"
                "    print(vc.view.window?\n"
                "        .windowScene?\n"
                "        .interfaceOrientation as Any)\n"
                "}\n")
        self.assertEqual(lint_text(text), [(3, "DUO003"), (4, "DUO003"), (5, "DUO003"),
                                           (7, "DUO003"), (10, "DUO003")])

    def test_shadowed_name_uses_the_nearest_binding(self):
        text = ("func a(scene: UIWindowScene) { print(scene.interfaceOrientation) }\n"
                "func b(scene: UIWindowScene.Geometry) { print(scene.interfaceOrientation) }\n")
        self.assertEqual(lint_text(text), [(1, "DUO003"), (2, "DUO002")])

    def test_bare_interface_orientation_needs_a_view_controller(self):
        vc = ("final class A: UIViewController {\n"
              "    func f() -> Bool { interfaceOrientation.isPortrait }\n"
              "    func g() -> Bool { self.interfaceOrientation.isPortrait }\n"
              "}\n")
        self.assertEqual(lint_text(vc), [(2, "DUO003"), (3, "DUO003")])
        other = "extension Model {\n    func f() -> Bool { interfaceOrientation.isPortrait }\n}\n"
        self.assertEqual(lint_text(other), [(2, "DUO002")])

    def test_labels_are_not_reads(self):
        text = ("final class D: NSObject, UIWindowSceneDelegate {\n"
                "    func windowScene(_ windowScene: UIWindowScene,\n"
                "                     didUpdate previousCoordinateSpace: UICoordinateSpace,\n"
                "                     interfaceOrientation previousInterfaceOrientation: "
                "UIInterfaceOrientation,\n"
                "                     traitCollection previousTraitCollection: UITraitCollection) {}\n"
                "}\n"
                "let p = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)\n")
        self.assertEqual(lint_text(text), [])

    def test_objc_interface_orientation(self):
        text = ("@implementation ReaderViewController\n"
                "- (void)f:(UIWindowScene *)scene {\n"
                "    if ([self interfaceOrientation] == 1) {}\n"
                "    if (scene.interfaceOrientation == 1) {}\n"
                "    if (scene.effectiveGeometry.interfaceOrientation == 1) {}\n"
                "    if ([[self.view.window windowScene] interfaceOrientation] == 1) {}\n"
                "}\n"
                "@end\n")
        self.assertEqual(lint_text(text, "objc"), [(3, "DUO003"), (4, "DUO003"), (5, "DUO002"),
                                                   (6, "DUO003")])

    def test_local_interface_orientation_variable_is_not_flagged(self):
        text = ("let interfaceOrientation = scene.effectiveGeometry.interfaceOrientation\n"
                "if interfaceOrientation.isLandscape { }\n")
        self.assertEqual(lint_text(text), [(1, "DUO002")])

    def test_idiom_for_mac_is_fine(self):
        self.assertEqual(lint_text("if UIDevice.current.userInterfaceIdiom == .mac { }\n"), [])

    def test_idiom_switch_is_flagged(self):
        text = "switch UIDevice.current.userInterfaceIdiom {\ncase .pad: break\ndefault: break\n}\n"
        self.assertEqual(lint_text(text), [(1, "DUO004")])

    def test_idiom_switch_without_pad_or_phone_is_fine(self):
        text = "switch UIDevice.current.userInterfaceIdiom {\ncase .mac: break\ndefault: break\n}\n"
        self.assertEqual(lint_text(text), [])

    def test_idiom_reads_and_declarations_are_fine(self):
        text = ("let idiom = UIDevice.current.userInterfaceIdiom\n"
                "print(idiom)\n"
                "var userInterfaceIdiom: UIUserInterfaceIdiom { .phone }\n"
                "let traits = UITraitCollection(userInterfaceIdiom: .pad)\n"
                "func f(userInterfaceIdiom: UIUserInterfaceIdiom) {}\n"
                "vc.traitOverrides.userInterfaceIdiom = .pad\n")
        self.assertEqual(lint_text(text), [])

    def test_idiom_comparisons_in_every_form(self):
        text = ("let a = UIDevice.current.userInterfaceIdiom == .pad\n"
                "let b = .phone != traitCollection.userInterfaceIdiom\n"
                "if case .pad = UIDevice.current.userInterfaceIdiom {}\n"
                "let c = [.pad, .mac].contains(UIDevice.current.userInterfaceIdiom)\n"
                "let idiom = UIDevice.current.userInterfaceIdiom\n"
                "let d = idiom == .phone\n"
                "func e(_ kind: UIUserInterfaceIdiom) -> Bool { kind == .pad }\n")
        self.assertEqual(lint_text(text), [(1, "DUO004"), (2, "DUO004"), (3, "DUO004"),
                                           (4, "DUO004"), (6, "DUO004"), (7, "DUO004")])
        f = duo_lint.lint_source(text)[1]
        self.assertEqual(f.snippet, ".phone != userInterfaceIdiom")

    def test_idiom_anywhere_in_an_orientation_mask_body_is_fine(self):
        text = ("override var supportedInterfaceOrientations: UIInterfaceOrientationMask {\n"
                "    let a: UIInterfaceOrientationMask = .all\n"
                "    let b: UIInterfaceOrientationMask = .portrait\n"
                "    let c: UIInterfaceOrientationMask = .allButUpsideDown\n"
                "    if UIDevice.current.userInterfaceIdiom == .pad { return a }\n"
                "    return traitCollection.userInterfaceIdiom == .phone ? b : c\n"
                "}\n"
                "func windowScene(_ s: UIWindowScene) -> Bool {\n"
                "    UIDevice.current.userInterfaceIdiom == .pad\n"
                "}\n"
                "func supportedInterfaceOrientations(for windowScene: UIWindowScene)"
                " -> UIInterfaceOrientationMask {\n"
                "    UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait\n"
                "}\n")
        self.assertEqual(lint_text(text), [(9, "DUO004")])

    def test_objc_idiom_switch_and_reverse_compare(self):
        text = ("switch ([UIDevice currentDevice].userInterfaceIdiom) {\n"
                "    case UIUserInterfaceIdiomPad: break;\n"
                "    default: break;\n"
                "}\n"
                "if (UIUserInterfaceIdiomPhone == UI_USER_INTERFACE_IDIOM()) {}\n")
        self.assertEqual(lint_text(text, "objc"), [(1, "DUO004"), (5, "DUO004")])

    def test_idiom_compared_with_the_type_named(self):
        text = ("if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {}\n"
                "let b = UIUserInterfaceIdiom.phone != traitCollection.userInterfaceIdiom\n"
                "if case UIUserInterfaceIdiom.pad = UIDevice.current.userInterfaceIdiom {}\n"
                "switch UIDevice.current.userInterfaceIdiom {\n"
                "case UIUserInterfaceIdiom.phone: break\n"
                "default: break\n"
                "}\n"
                "let fine = UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.mac\n")
        self.assertEqual(lint_text(text), [(1, "DUO004"), (2, "DUO004"), (3, "DUO004"),
                                           (4, "DUO004")])

    def test_implicit_main_screen(self):
        text = ("let a: UIScreen = .main\n"
                "let b: UIScreen? = .main\n"
                "let c = scene?.screen ?? .main\n"
                "let d = (window?.windowScene?.screen) ?? .main\n"
                "func e(screen: UIScreen = .main) {}\n"
                "let f = Observer(screen: .main)\n"
                "var g: UIScreen { .main }\n"
                "func h() -> UIScreen {\n"
                "    .main\n"
                "}\n"
                "func i() -> UIScreen {\n"
                "    return .main\n"
                "}\n")
        self.assertEqual(lint_text(text), [(n, "DUO001") for n in (1, 2, 3, 4, 5, 6, 7, 9, 12)])

    def test_other_main_singletons_are_fine(self):
        text = ("let q = queue ?? .main\n"
                "let r: RunLoop = .main\n"
                "DispatchQueue.main.async {}\n"
                "let b = Bundle.main\n"
                "let s = screenQueue ?? .main\n"
                "func j() -> DispatchQueue {\n"
                "    .main\n"
                "}\n")
        self.assertEqual(lint_text(text), [])

    def test_regular_width_without_ipad_hint_is_fine(self):
        text = "let wide = horizontalSizeClass == .regular\n"
        self.assertEqual(lint_text(text), [])

    def test_compact_width_as_iphone(self):
        text = "let isIPhone = horizontalSizeClass == .compact\n"
        self.assertEqual(lint_text(text), [(1, "DUO005")])

    def test_common_sizes_need_screen_context(self):
        self.assertEqual(lint_text("if image.size.width > 1024 { }\n"), [])
        self.assertEqual(lint_text("if view.bounds.width >= 1024 { }\n"), [(1, "DUO006")])
        self.assertEqual(lint_text("if width < 390 { }\n"), [(1, "DUO006")])

    def test_breakpoints_that_are_not_device_sizes_are_fine(self):
        self.assertEqual(lint_text("if proxy.size.width > 600 { }\n"), [])
        self.assertEqual(lint_text("if view.bounds.width > 700 { }\n"), [])

    def test_ranges_and_shifts_are_not_comparisons(self):
        self.assertEqual(lint_text("for i in 0..<390 { }\nlet w = 1 << 10\n"), [])

    def test_native_pixel_sizes(self):
        text = "if UIScreen.main.nativeBounds.height == 2436 { }\n"
        self.assertEqual(sorted(lint_text(text)), [(1, "DUO001"), (1, "DUO006")])
        self.assertEqual(lint_text("if window.screen.nativeBounds.height == 2436 { }\n"),
                         [(1, "DUO006")])
        self.assertEqual(lint_text("let big = [2436, 2532].contains(Int(screen.nativeScale))\n"),
                         [(1, "DUO006")])

    def test_pixel_sizes_need_native_bounds_or_scale(self):
        # rules.md: pixel sizes count only on lines that read nativeBounds or nativeScale.
        self.assertEqual(lint_text("if imagePixelWidth == 1920 { }\n"), [])
        self.assertEqual(lint_text("let fullHD = [1920, 1080].contains(pixelWidth)\n"), [])
        self.assertEqual(lint_text("if pixelSize.width == 2436 { }\n"), [])

    def test_geometry_proxy_parameter(self):
        text = "func pick(_ geo: GeometryProxy) -> Bool { geo.size.width >= 744 }\n"
        self.assertEqual(lint_text(text), [(1, "DUO009")])

    def test_fixed_width_threshold(self):
        self.assertEqual(lint_text("Text(\"a\").frame(width: 319)\n"), [])
        self.assertEqual(lint_text("Text(\"a\").frame(width: 320)\n"), [(1, "DUO007")])
        self.assertEqual(lint_text("Text(\"a\").frame(maxWidth: 600)\n"), [])
        self.assertEqual(lint_text("Text(\"a\").frame(idealWidth: 600)\n"), [])
        self.assertEqual(lint_text("Text(\"a\").frame(width: CGFloat(400))\n"), [(1, "DUO007")])
        self.assertEqual(lint_text("Text(\"a\").frame(width: size.width)\n"), [])
        self.assertEqual(lint_text("Text(\"a\").frame(width: 390.5)\n"), [(1, "DUO007")])
        self.assertEqual(lint_text("v.widthAnchor.constraint(equalToConstant: 400.5)\n"),
                         [(1, "DUO007")])

    def test_strings_inside_interpolation(self):
        text = 'let u = "\\(flag ? "UIScreen.main" : "y")"; let w = 1\n'
        self.assertEqual(lint_text(text), [])

    def test_device_size_pair_in_preview_is_fine(self):
        text = "#Preview { Text(\"a\").previewLayout(.fixed(width: 390, height: 844)) }\n"
        self.assertEqual(lint_text(text), [])

    def test_size_class_switch_case(self):
        text = ("switch horizontalSizeClass {\n"
                "case .regular: // iPad\n"
                "    break\n"
                "default: break\n"
                "}\n")
        self.assertEqual(lint_text(text), [(2, "DUO005")])

    def test_idiom_in_orientation_mask_is_fine(self):
        text = ("override var supportedInterfaceOrientations: UIInterfaceOrientationMask {\n"
                "    UIDevice.current.userInterfaceIdiom == .phone ? .allButUpsideDown : .all\n"
                "}\n")
        self.assertEqual(lint_text(text), [])

    def test_objc_idiom_snippet(self):
        f = duo_lint.lint_source(
            "if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {}\n",
            "t.m", "objc")[0]
        self.assertEqual((f.rule.id, f.snippet),
                         ("DUO004", "userInterfaceIdiom == UIUserInterfaceIdiomPad"))

    def test_code_for_other_platforms_is_skipped(self):
        text = ("#if os(macOS)\n"
                "let a = Text(\"a\").frame(minWidth: 800)\n"
                "#elseif os(iOS)\n"
                "let b = UIScreen.main.bounds\n"
                "#else\n"
                "let c = UIScreen.main.bounds\n"
                "#endif\n"
                "#if canImport(UIKit)\n"
                "let d = UIScreen.main.bounds\n"
                "#else\n"
                "let e = UIScreen.main.bounds\n"
                "#endif\n"
                "#if DEBUG\n"
                "let f = UIScreen.main.bounds\n"
                "#endif\n")
        self.assertEqual(lint_text(text), [(4, "DUO001"), (9, "DUO001"), (14, "DUO001")])

    def test_size_rules_skip_previews(self):
        text = ("#Preview(\"Phone\") {\n"
                "    Text(\"a\")\n"
                "        .frame(width: 390, height: 844)\n"
                "}\n"
                "struct Card_Previews: PreviewProvider {\n"
                "    static var previews: some View { Text(\"b\").frame(width: 430) }\n"
                "}\n"
                "let x = Text(\"c\").frame(width: 430)\n")
        self.assertEqual(lint_text(text), [(8, "DUO007")])

    def test_select_rules(self):
        text = "let a = UIScreen.main.bounds\nlet b = UIDevice.current.orientation\n"
        self.assertEqual(lint_text(text, rules={"DUO002"}), [(2, "DUO002")])

    def test_fix_hint_depends_on_member(self):
        f = duo_lint.lint_source("let s = UIScreen.main.scale\n")[0]
        self.assertIn("displayScale", f.fix)
        f = duo_lint.lint_source("let w = UIWindow(frame: UIScreen.main.bounds)\n")[0]
        self.assertIn("UIWindow(windowScene:", f.fix)


class DirectiveTests(unittest.TestCase):
    LINE = "let s = UIScreen.main.scale\n"

    def test_next_line_with_id(self):
        self.assertEqual(lint_text("// duo-lint:disable-next-line DUO001\n" + self.LINE), [])

    def test_next_line_without_id_means_all(self):
        self.assertEqual(lint_text("// duo-lint:disable-next-line\n" + self.LINE), [])

    def test_next_line_other_id_does_not_hide(self):
        self.assertEqual(lint_text("// duo-lint:disable-next-line DUO004\n" + self.LINE),
                         [(2, "DUO001")])

    def test_same_line(self):
        self.assertEqual(lint_text(self.LINE.rstrip("\n") + " // duo-lint:disable-line DUO001\n"),
                         [])

    def test_whole_file(self):
        text = "// duo-lint:disable-file DUO001 -- generated code\n\n" + self.LINE * 3
        self.assertEqual(lint_text(text), [])

    def test_reason_text_is_not_read_as_ids(self):
        text = "// duo-lint:disable-next-line DUO004 -- unlike DUO001\n" + self.LINE
        self.assertEqual(lint_text(text), [(2, "DUO001")])

    def test_directive_inside_a_string_does_nothing(self):
        text = 'let d = "duo-lint:disable-next-line"\n' + self.LINE
        self.assertEqual(lint_text(text), [(2, "DUO001")])


class CliTests(unittest.TestCase):
    LINE_RE = re.compile(r"^\S+:\d+\s+DUO\d{3}  (error|warning)\s+\S.*  \S.*$")
    SUMMARY_RE = re.compile(r"^\d+ findings? · \d+ errors? · \d+ warnings? "
                            r"\(\d+ files? checked\)$")

    def test_text_output_and_exit_code(self):
        r = run_cli("bad.swift")
        self.assertEqual(r.returncode, 1, r.stderr)
        lines = r.stdout.strip().split("\n")
        for line in lines[:-1]:
            self.assertRegex(line, self.LINE_RE)
        self.assertRegex(lines[-1], self.SUMMARY_RE)
        self.assertRegex(lines[0], r"^bad\.swift:11 +DUO001  error")

    def test_good_file_exits_zero(self):
        r = run_cli("good.swift")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(r.stdout.strip(),
                         "0 findings · 0 errors · 0 warnings (1 file checked)")

    def test_strict_fails_on_warnings(self):
        self.assertEqual(run_cli("Info.plist").returncode, 0)
        self.assertEqual(run_cli("--strict", "Info.plist").returncode, 1)

    def test_json(self):
        r = run_cli("--json", ".")
        data = json.loads(r.stdout)
        self.assertEqual(data["tool"], "duo-lint")
        s = data["summary"]
        self.assertEqual(s["findings"], len(data["findings"]))
        self.assertEqual(s["errors"] + s["warnings"], s["findings"])
        self.assertEqual(s["files"], 8)  # bad, good, Info.plist, Legacy.xcconfig, sample/ (4)
        first = data["findings"][0]
        for key in ("path", "line", "column", "rule", "name", "severity", "snippet",
                    "message", "fix", "source", "code"):
            self.assertIn(key, first)
        self.assertTrue(all(f["source"].startswith("https://developer.apple.com/")
                            for f in data["findings"]))
        self.assertFalse(any(f["path"].endswith(".m") for f in data["findings"]))

    def test_objc_flag_adds_m_files(self):
        data = json.loads(run_cli("--json", "--objc", ".").stdout)
        self.assertTrue(any(f["path"] == "bad.m" for f in data["findings"]))
        self.assertEqual(data["summary"]["files"], 9)

    def test_github_format(self):
        r = run_cli("--format", "github", "bad.swift")
        lines = r.stdout.strip().split("\n")
        self.assertTrue(lines[0].startswith("::error file=bad.swift,line=11,col="))
        self.assertTrue(any(x.startswith("::warning file=bad.swift,") for x in lines))
        self.assertIn("title=DUO001 main-screen::", lines[0])
        self.assertRegex(lines[-1], self.SUMMARY_RE)

    def test_verbose_shows_fix_and_source(self):
        r = run_cli("-v", "Info.plist")
        self.assertIn("    fix: ", r.stdout)
        self.assertIn("    see: https://developer.apple.com/", r.stdout)

    def test_missing_path_exits_two(self):
        r = run_cli("does-not-exist")
        self.assertEqual(r.returncode, 2)
        self.assertIn("no such file or folder", r.stderr)

    def test_unknown_rule_exits_two(self):
        self.assertEqual(run_cli("--select", "DUO999", ".").returncode, 2)

    def test_ignore_and_exclude(self):
        data = json.loads(run_cli("--json", "--ignore", "DUO008", "--exclude", "bad.*",
                                  "--exclude", "sample", ".").stdout)
        self.assertEqual(data["findings"], [])

    def test_exclude_patterns(self):
        tmp = tempfile.mkdtemp()
        try:
            for d in ("Sources", "Tests", os.path.join("App", "Tests"), "AppTests"):
                os.makedirs(os.path.join(tmp, d))
                with open(os.path.join(tmp, d, "A.swift"), "w") as fh:
                    fh.write("let a = UIScreen.main.bounds\n")
            def files(*excludes):
                args = ["--json"] + [x for e in excludes for x in ("--exclude", e)] + [tmp]
                return json.loads(run_cli(*args).stdout)["summary"]["files"]
            self.assertEqual(files(), 4)
            self.assertEqual(files("Tests"), 2)
            self.assertEqual(files("Tests/*"), 2)
            self.assertEqual(files("*Tests*"), 1)
            self.assertEqual(files("Sources/A.swift"), 3)
        finally:
            shutil.rmtree(tmp)

    def test_skips_build_folders(self):
        tmp = tempfile.mkdtemp()
        try:
            os.makedirs(os.path.join(tmp, "DerivedData"))
            os.makedirs(os.path.join(tmp, "Sources"))
            for d in ("DerivedData", "Sources"):
                with open(os.path.join(tmp, d, "A.swift"), "w") as fh:
                    fh.write("let a = UIScreen.main.bounds\n")
            data = json.loads(run_cli("--json", tmp).stdout)
            self.assertEqual(data["summary"]["files"], 1)
        finally:
            shutil.rmtree(tmp)

    def test_skips_agent_folders_and_its_own_fixtures(self):
        tmp = tempfile.mkdtemp()
        try:
            os.makedirs(os.path.join(tmp, "Sources"))
            with open(os.path.join(tmp, "Sources", "A.swift"), "w") as fh:
                fh.write("let a = 1\n")
            # The skill installed for an agent, and copied somewhere else in the project.
            shutil.copytree(SKILL, os.path.join(tmp, ".claude", "skills", "duo-lint"))
            shutil.copytree(SKILL, os.path.join(tmp, ".agents", "skills", "duo-lint"))
            shutil.copytree(SKILL, os.path.join(tmp, "tools", "duo-lint"))
            installed = os.path.join(tmp, ".claude", "skills", "duo-lint", "scripts", "duo-lint")
            r = subprocess.run([installed, "--json", "--strict", "."], cwd=tmp,
                               stdout=subprocess.PIPE, universal_newlines=True)
            data = json.loads(r.stdout)
            self.assertEqual((r.returncode, data["summary"]["files"]), (0, 1), r.stdout)
            # Named on the command line, a skipped folder is checked.
            fixtures = os.path.join(tmp, "tools", "duo-lint", "tests", "fixtures")
            data = json.loads(run_cli("--json", fixtures).stdout)
            self.assertGreater(data["summary"]["findings"], 0)
        finally:
            shutil.rmtree(tmp)

    def test_plugin_bin_wrapper_on_path(self):
        # Claude Code puts each enabled plugin's bin/ folder on the Bash tool's PATH.
        self.assertTrue(os.access(PLUGIN_BIN, os.X_OK))
        env = dict(os.environ)
        env["PATH"] = os.path.dirname(PLUGIN_BIN) + os.pathsep + env.get("PATH", "")
        tmp = tempfile.mkdtemp()
        try:
            r = subprocess.run(["duo-lint", "--version"], cwd=tmp, env=env,
                               stdout=subprocess.PIPE, universal_newlines=True)
            self.assertEqual(r.stdout.strip(), "duo-lint %s" % duo_lint.VERSION)
            # A copy of the plugin elsewhere (the plugin cache) works the same way.
            copy = os.path.join(tmp, "cache", "duology-ship")
            os.makedirs(os.path.dirname(copy))
            for part in ("bin", "skills"):
                shutil.copytree(os.path.join(PLUGIN, part), os.path.join(copy, part))
            env["PATH"] = os.path.join(copy, "bin") + os.pathsep + os.environ.get("PATH", "")
            r = subprocess.run(["duo-lint", os.path.join(FIXTURES, "Info.plist")], cwd=tmp,
                               env=env, stdout=subprocess.PIPE, universal_newlines=True)
            self.assertIn("Info.plist:8  DUO008  warning", r.stdout)
        finally:
            shutil.rmtree(tmp)

    def test_list_rules(self):
        rules = json.loads(run_cli("--list-rules", "--json").stdout)
        self.assertEqual([r["id"] for r in rules], ["DUO%03d" % i for i in range(1, 10)])

    def test_launcher_is_executable(self):
        self.assertTrue(os.access(LAUNCHER, os.X_OK))
        self.assertTrue(os.access(SCRIPT, os.X_OK))
        r = subprocess.run([LAUNCHER, "--version"], stdout=subprocess.PIPE,
                           universal_newlines=True)
        self.assertEqual(r.stdout.strip(), "duo-lint %s" % duo_lint.VERSION)


class FullScreenProjectTests(unittest.TestCase):
    """DUO008 across files: a build setting plus the ignore key in the merged Info.plist."""

    PLIST = ('<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0">\n<dict>\n'
             '{body}</dict>\n</plist>\n')
    IGNORE = ("\t<key>UIRequiresFullScreenIgnoredStartingWithVersion</key>\n"
              "\t<string>26</string>\n")

    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, rel, text):
        path = os.path.join(self.tmp, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write(text)
        return path

    def pbxproj(self, infoplist):
        block = ("\t\tbuildSettings = {{\n\t\t\t{plist}INFOPLIST_KEY_UIRequiresFullScreen = YES;\n"
                 "\t\t\tPRODUCT_NAME = App;\n\t\t}};\n")
        plist = "INFOPLIST_FILE = %s;\n\t\t\t" % infoplist if infoplist else ""
        return self.write("App.xcodeproj/project.pbxproj",
                          "// !$*UTF8*$!\n{\n" + block.format(plist=plist) * 2 + "}\n")

    def lint(self, *paths):
        findings, _ = duo_lint.lint_paths([os.path.join(self.tmp, p) for p in paths])
        return [(os.path.relpath(f.path, self.tmp), f.line, f.rule.id) for f in findings]

    def test_setting_with_ignore_key_in_its_plist_is_fine(self):
        self.write("App/Info.plist", self.PLIST.format(body=self.IGNORE))
        self.pbxproj('"$(SRCROOT)/App/Info.plist"')
        self.assertEqual(self.lint("."), [])
        self.assertEqual(self.lint("App.xcodeproj/project.pbxproj"), [])

    def test_setting_with_a_plist_that_lacks_the_key_is_flagged(self):
        self.write("App/Info.plist", self.PLIST.format(body=""))
        self.write("Other/Info.plist", self.PLIST.format(body=self.IGNORE))
        self.pbxproj("App/Info.plist")
        self.assertEqual(self.lint("."), [("App.xcodeproj/project.pbxproj", 5, "DUO008"),
                                          ("App.xcodeproj/project.pbxproj", 10, "DUO008")])

    def test_xcconfig_with_ignore_key_in_the_project_is_fine(self):
        self.pbxproj(None)
        self.write("Config/Base.xcconfig", "INFOPLIST_KEY_UIRequiresFullScreen = YES\n")
        self.write("App/Info.plist", self.PLIST.format(body=self.IGNORE))
        self.assertEqual(self.lint("."), [])
        # Alone, the setting file can't show which plist it goes with.
        self.assertEqual(self.lint("Config/Base.xcconfig"),
                         [("Config/Base.xcconfig", 1, "DUO008")])
        self.assertEqual(self.lint("Config/Base.xcconfig", "App/Info.plist"), [])

    def test_ignore_key_outside_the_project_does_not_count(self):
        self.pbxproj(None)
        self.write("Config/Base.xcconfig", "INFOPLIST_KEY_UIRequiresFullScreen = YES\n")
        os.makedirs(os.path.join(self.tmp, "Elsewhere"))
        other = tempfile.mkdtemp()
        try:
            plist = os.path.join(other, "Info.plist")
            with open(plist, "w") as fh:
                fh.write(self.PLIST.format(body=self.IGNORE))
            findings, _ = duo_lint.lint_paths([self.tmp, plist])
            self.assertEqual([f.rule.id for f in findings], ["DUO008", "DUO008", "DUO008"])
        finally:
            shutil.rmtree(other)


class HookTests(unittest.TestCase):
    def run_hook(self, event, enabled=True):
        env = dict(os.environ)
        env.pop("DUOLOGY_LINT_HOOK", None)
        if enabled:
            env["DUOLOGY_LINT_HOOK"] = "1"
        payload = event if isinstance(event, str) else json.dumps(event)
        return subprocess.run(["bash", HOOK_SH], input=payload, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, universal_newlines=True, env=env)

    def write_event(self, path):
        return {"hook_event_name": "PostToolUse", "tool_name": "Write", "cwd": FIXTURES,
                "tool_input": {"file_path": path, "content": "..."}}

    def test_off_by_default(self):
        r = self.run_hook(self.write_event(os.path.join(FIXTURES, "bad.swift")), enabled=False)
        self.assertEqual((r.returncode, r.stdout), (0, ""))

    def test_write_reports_findings_without_blocking(self):
        r = self.run_hook(self.write_event(os.path.join(FIXTURES, "bad.swift")))
        self.assertEqual(r.returncode, 0)
        out = json.loads(r.stdout)
        self.assertNotIn("decision", out)
        spec = out["hookSpecificOutput"]
        self.assertEqual(spec["hookEventName"], "PostToolUse")
        self.assertIn("bad.swift:11  DUO001  error", spec["additionalContext"])
        self.assertIn("fix: ", spec["additionalContext"])
        self.assertIn("duo-lint:", out["systemMessage"])

    def test_edit_reports_only_changed_lines(self):
        event = {"tool_name": "Edit", "cwd": FIXTURES,
                 "tool_input": {"file_path": os.path.join(FIXTURES, "bad.swift"),
                                "old_string": "x",
                                "new_string": "        if view.bounds.height == 844 {"}}
        context = json.loads(self.run_hook(event).stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("bad.swift:39  DUO006", context)
        self.assertNotIn("DUO001  error", context)
        self.assertIn("more findings in this file", context)
        # The hint names the launcher by its full path: duo-lint may not be on PATH.
        m = re.search(r'Run: "([^"]+)" bad\.swift', context)
        self.assertIsNotNone(m, context)
        self.assertEqual(os.path.realpath(m.group(1)), os.path.realpath(LAUNCHER))
        self.assertTrue(os.access(m.group(1), os.X_OK))

    def test_clean_edit_is_silent(self):
        event = {"tool_name": "Edit", "cwd": FIXTURES,
                 "tool_input": {"file_path": os.path.join(FIXTURES, "bad.swift"),
                                "old_string": "x", "new_string": "    override func viewDidLoad() {"}}
        r = self.run_hook(event)
        self.assertEqual((r.returncode, r.stdout), (0, ""))

    def test_clean_file_is_silent(self):
        r = self.run_hook(self.write_event(os.path.join(FIXTURES, "good.swift")))
        self.assertEqual((r.returncode, r.stdout), (0, ""))

    def test_other_files_and_bad_input_are_ignored(self):
        for event in (self.write_event(os.path.join(FIXTURES, "Info.plist")),
                      'not json but mentions .swift"', "", {"tool_name": "Write"}):
            r = self.run_hook(event)
            self.assertEqual((r.returncode, r.stdout), (0, ""), event)

    def test_missing_file_is_ignored(self):
        r = self.run_hook(self.write_event(os.path.join(FIXTURES, "gone.swift")))
        self.assertEqual((r.returncode, r.stdout), (0, ""))

    def test_hooks_json(self):
        with open(HOOKS_JSON) as fh:
            config = json.load(fh)
        entries = config["hooks"]["PostToolUse"]
        self.assertEqual(len(entries), 1)
        self.assertEqual(set(entries[0]["matcher"].split("|")), {"Edit", "Write", "MultiEdit"})
        hook = entries[0]["hooks"][0]
        self.assertEqual(hook["type"], "command")
        self.assertIn("${CLAUDE_PLUGIN_ROOT}/hooks/lint-hook.sh", hook["command"])
        self.assertTrue(os.access(HOOK_SH, os.X_OK))

    def test_hook_command_in_an_installed_plugin_copy(self):
        # Run the command from hooks.json the way Claude Code does, from a copy of the
        # plugin in a folder with a space (like Application Support), with a bare PATH.
        with open(HOOKS_JSON) as fh:
            command = json.load(fh)["hooks"]["PostToolUse"][0]["hooks"][0]["command"]
        tmp = tempfile.mkdtemp()
        try:
            root = os.path.join(tmp, "plugin cache", "duology-ship")
            for part in ("bin", "hooks", "skills"):
                shutil.copytree(os.path.join(PLUGIN, part), os.path.join(root, part))
            env = {"PATH": "/usr/bin:/bin", "HOME": tmp, "DUOLOGY_LINT_HOOK": "1",
                   "CLAUDE_PLUGIN_ROOT": root}
            event = {"tool_name": "Edit", "cwd": FIXTURES,
                     "tool_input": {"file_path": os.path.join(FIXTURES, "bad.swift"),
                                    "old_string": "x",
                                    "new_string": "        if view.bounds.height == 844 {"}}
            r = subprocess.run(["bash", "-c", command], input=json.dumps(event), env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               universal_newlines=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            context = json.loads(r.stdout)["hookSpecificOutput"]["additionalContext"]
            # The command the hook suggests must run as printed, without duo-lint on PATH.
            m = re.search(r"Run: (.+ bad\.swift)$", context, re.M)
            self.assertIsNotNone(m, context)
            argv = shlex.split(m.group(1))
            self.assertTrue(os.path.realpath(argv[0]).startswith(os.path.realpath(root)))
            run = subprocess.run(argv, cwd=FIXTURES, env=env, stdout=subprocess.PIPE,
                                 universal_newlines=True)
            self.assertEqual(run.returncode, 1)
            self.assertIn("bad.swift:11  DUO001  error", run.stdout)
        finally:
            shutil.rmtree(tmp)


class DocsTests(unittest.TestCase):
    def read(self, *parts):
        with open(os.path.join(SKILL, *parts), encoding="utf-8") as fh:
            return fh.read()

    def test_every_rule_is_documented(self):
        rules_md = self.read("references", "rules.md")
        skill_md = self.read("SKILL.md")
        for rule in duo_lint.RULES:
            self.assertIn("## %s" % rule.id, rules_md)
            self.assertIn(rule.id, skill_md)
            self.assertIn(rule.source, rules_md)

    def swift_blocks(self, *parts):
        """Yield (section, label, code) for each ```swift block in a doc."""
        text = self.read(*parts)
        section, label = None, None
        for chunk in re.split(r"(```swift\n.*?```)", text, flags=re.S):
            if chunk.startswith("```swift"):
                yield section, label, chunk[len("```swift\n"):-3]
                continue
            for line in chunk.split("\n"):
                m = re.match(r"## (DUO\d{3})\b", line)
                if m:
                    section = m.group(1)
                elif line.startswith("## "):
                    section = None
                if line.startswith("Bad"):
                    label = "bad"
                elif line.startswith("Good"):
                    label = "good"

    def test_rule_examples_lint_as_labelled(self):
        count = 0
        for section, label, code in self.swift_blocks("references", "rules.md"):
            rules = {f.rule.id for f in duo_lint.lint_source(code)}
            if section and label == "bad":
                self.assertIn(section, rules, "bad example for %s:\n%s" % (section, code))
            elif section and label == "good":
                self.assertEqual(rules, set(), "good example for %s:\n%s" % (section, code))
            else:
                self.assertEqual(rules, set(), code)
            count += 1
        self.assertGreaterEqual(count, 18)

    def test_skill_examples_are_clean(self):
        blocks = list(self.swift_blocks("SKILL.md"))
        self.assertTrue(blocks)
        for _, _, code in blocks:
            self.assertEqual(duo_lint.lint_source(code), [], code)

    @unittest.skipUnless(os.environ.get("DUO_LINT_TYPECHECK") == "1" and shutil.which("xcrun"),
                         "set DUO_LINT_TYPECHECK=1 on a Mac with Xcode 27.1 to typecheck docs")
    def test_doc_examples_typecheck(self):
        env = dict(os.environ)
        env.setdefault("DEVELOPER_DIR", "/Applications/Xcode-27.1.app/Contents/Developer")
        tmp = tempfile.mkdtemp()
        try:
            blocks = list(self.swift_blocks("SKILL.md")) + list(
                self.swift_blocks("references", "rules.md"))
            for n, (_, _, code) in enumerate(blocks):
                path = os.path.join(tmp, "snippet%02d.swift" % n)
                with open(path, "w") as fh:
                    fh.write(code)
                r = subprocess.run(
                    ["xcrun", "-sdk", "iphonesimulator", "swiftc", "-typecheck",
                     "-target", "arm64-apple-ios27.1-simulator", path],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    universal_newlines=True, env=env)
                self.assertEqual(r.returncode, 0, "%s\n%s" % (code, r.stdout))
        finally:
            shutil.rmtree(tmp)

    def test_skill_frontmatter(self):
        text = self.read("SKILL.md")
        self.assertTrue(text.startswith("---\nname: duo-lint\ndescription: "))
        self.assertIn('verified: "Xcode 27.1 (27A9275), iOS 27.1 simulator, device: no"', text)
        self.assertLess(text.count("\n"), 300)

    def test_skill_points_to_the_full_audit(self):
        description = self.read("SKILL.md").split("\n")[2]
        for name in ("/duo-audit", "duo-design-review"):
            self.assertIn(name, description)

    def test_skill_says_how_to_run_it_alone(self):
        # Installed with `npx skills add` or copied, the plugin's bin/ is not on PATH.
        text = self.read("SKILL.md")
        self.assertIn("<skill-folder>/scripts/duo-lint", text)
        self.assertTrue(os.access(LAUNCHER, os.X_OK))

    SAMPLE_PROMPT = "$ duo-lint Sources/"

    def example_output(self, path):
        """Return the lines under '$ duo-lint Sources/' in a doc's ```text block."""
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        for block in re.findall(r"```text\n(.*?)```", text, flags=re.S):
            lines = block.rstrip("\n").split("\n")
            if lines[0] == self.SAMPLE_PROMPT:
                return lines[1:]
        self.fail("no ```text block starting with %r in %s" % (self.SAMPLE_PROMPT, path))

    def test_example_output_in_docs_is_real(self):
        r = subprocess.run([sys.executable, SCRIPT, "Sources/"], cwd=SAMPLE,
                           stdout=subprocess.PIPE, universal_newlines=True)
        real = r.stdout.rstrip("\n").split("\n")
        self.assertEqual(r.returncode, 1)
        docs = [os.path.join(SKILL, "SKILL.md"), os.path.join(REPO, "README.md"),
                os.path.join(REPO, "docs", "readme", "README_fr.md")]
        checked = 0
        for doc in docs:
            if not os.path.isfile(doc):
                continue  # the skill installed on its own has no README
            self.assertEqual(self.example_output(doc), real, doc)
            checked += 1
        self.assertGreaterEqual(checked, 1)


if __name__ == "__main__":
    unittest.main()
