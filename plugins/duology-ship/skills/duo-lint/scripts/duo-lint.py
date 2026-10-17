#!/usr/bin/env python3
"""duo-lint: the fold linter from Duology.

Finds code that Apple tells you to remove before your app runs on iPhone Duo:
sizing from the main screen, orientation and idiom checks, "regular width
means iPad", hard-coded device sizes, fixed widths and UIRequiresFullScreen.

Python 3.9 or later, standard library only. Nothing leaves your machine.
MIT license. https://github.com/Kimeur/duology

Run `duo-lint --help` for options and `duo-lint --list-rules` for the rules.
"""

import argparse
import bisect
import fnmatch
import json
import os
import plistlib
import re
import shlex
import sys

VERSION = "0.1.0"

# Apple sources. See reference/sources.md in the Duology repo.
PREPARE = "https://developer.apple.com/iphone-duo/prepare/"
HIG = ("https://developer.apple.com/design/human-interface-guidelines/"
       "designing-for-iphone-duo")
TN3192 = ("https://developer.apple.com/documentation/technotes/"
          "tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key")

ERROR = "error"
WARNING = "warning"


class Rule(object):
    __slots__ = ("id", "name", "severity", "message", "fix", "source")

    def __init__(self, rule_id, name, severity, message, fix, source):
        self.id = rule_id
        self.name = name
        self.severity = severity
        self.message = message
        self.fix = fix
        self.source = source

    def as_dict(self):
        return {k: getattr(self, k) for k in self.__slots__}


RULES = [
    Rule("DUO001", "main-screen", ERROR,
         "your window is not the screen on a two-display phone; size from the view or window",
         "Use view.bounds or window.bounds in UIKit, GeometryReader or onGeometryChange in "
         "SwiftUI. Get scale from traitCollection.displayScale or @Environment(\\.displayScale). "
         "Create windows with UIWindow(windowScene:). If you need the screen, read "
         "view.window?.windowScene?.screen when you use it; don't store it.",
         PREPARE),
    Rule("DUO002", "device-orientation", WARNING,
         "orientation doesn't tell you your window's shape on iPhone Duo; compare width and height",
         "Compare the width and height you have: view.bounds in a view controller, "
         "superview.bounds in a view, the GeometryReader size in SwiftUI. For camera "
         "rotation use AVCaptureDevice.RotationCoordinator.",
         PREPARE),
    Rule("DUO003", "deprecated-interface-orientation", ERROR,
         "deprecated orientation API; compare the width and height you have",
         "Remove layout logic that depends on it. Compare the width and height of "
         "view.bounds or the GeometryReader size. For non-layout uses, read "
         "windowScene.effectiveGeometry.interfaceOrientation instead; DUO002 still warns, "
         "so add a disable comment with the reason.",
         PREPARE),
    Rule("DUO004", "idiom-layout", WARNING,
         "layout picked by device type; pick it by size class or space",
         "Branch on horizontalSizeClass, ViewThatFits or the width you have. Keep idiom "
         "checks only for behaviour that really differs by device type, not for layout.",
         PREPARE),
    Rule("DUO005", "regular-width-is-ipad", WARNING,
         "size class treated as a device; iPhone Duo gets regular and compact widths",
         "Name the layout after the space, not the device (isWide, not isIPad). Show the "
         "regular-width layout wherever the width is regular, iPhone included.",
         PREPARE),
    Rule("DUO006", "device-size-literal", WARNING,
         "hard-coded device size; it won't match iPhone Duo windows",
         "Delete the size check. Pick the layout by size class, by ViewThatFits, or by "
         "comparing width to height of the space you have.",
         PREPARE),
    Rule("DUO007", "fixed-width", WARNING,
         "fixed width of 320 pt or more; let the container size it",
         "Use .frame(maxWidth:) to cap a width, .frame(maxWidth: .infinity) to fill, or "
         "containerRelativeFrame. In Auto Layout, use a lessThanOrEqualToConstant width "
         "or pin to the readable content guide.",
         HIG),
    Rule("DUO008", "requires-full-screen", WARNING,
         "deprecated; with the iOS 27 SDK it no longer stops your app from resizing",
         "Remove the key from Info.plist and the INFOPLIST_KEY_UIRequiresFullScreen build "
         "setting, then make the app resize. If an older iOS still needs it, add "
         "UIRequiresFullScreenIgnoredStartingWithVersion (TN3192).",
         TN3192),
    Rule("DUO009", "geometry-device-size", WARNING,
         "GeometryReader size compared to a device size; use size class or ViewThatFits",
         "Compare the proxy's width to its height, use ViewThatFits, or switch layouts "
         "with AnyLayout on horizontalSizeClass. Never match a device's point size.",
         PREPARE),
]
RULES_BY_ID = {r.id: r for r in RULES}

# Fix hints that depend on what the code reads.
FIX_DUO001_SCALE = (
    "Read scale from the trait collection: traitCollection.displayScale in UIKit, "
    "@Environment(\\.displayScale) in SwiftUI.")
FIX_DUO001_WINDOW = (
    "Create the window from its scene: UIWindow(windowScene: windowScene).")
FIX_DUO001_SCREENS = (
    "Don't list screens. Use UIApplication.shared.openSessions or connectedScenes "
    "to find scenes, and windowScene.screen for each one.")

# --------------------------------------------------------------------------
# Device sizes. Never put these in an app. duo-lint uses them to find apps
# that already did.

# Point sizes that are rarely anything but a device dimension.
DISTINCT_POINT_SIZES = {
    375, 390, 393, 402, 414, 420, 428, 430, 440,            # iPhone widths
    568, 667, 736, 812, 844, 852, 874, 896, 912, 926, 932, 956,  # iPhone heights
    744, 810, 820, 834, 1032,                                # iPad widths
    1112, 1133, 1180, 1194, 1210, 1366, 1376,                # iPad heights
    466, 678, 669, 951,                                      # iPhone Duo windows
}
# Device sizes that are also common for other things (image sizes, breakpoints).
# Flagged only when the line clearly talks about the screen, window or view.
COMMON_POINT_SIZES = {320, 768, 1024}
POINT_SIZES = DISTINCT_POINT_SIZES | COMMON_POINT_SIZES

# Native pixel sizes. Only checked on lines that read nativeBounds or nativeScale.
PIXEL_SIZES = {
    640, 750, 828, 1080, 1125, 1170, 1179, 1206, 1242, 1260, 1284, 1290, 1320,
    1136, 1334, 1792, 1920, 2208, 2436, 2532, 2556, 2622, 2688, 2736, 2778, 2796, 2868,
    1488, 1536, 1620, 1640, 1668, 2048, 2064, 2160, 2266, 2360, 2388, 2420, 2732, 2752,
    1398, 2034, 1878, 2670, 2007, 2853,
}

DEVICE_WIDTHS = {320, 375, 390, 393, 402, 414, 420, 428, 430, 440, 466,
                 744, 768, 810, 820, 834, 951, 1024, 1032}
DEVICE_HEIGHTS = {568, 667, 669, 678, 736, 812, 844, 852, 874, 896, 912, 926, 932, 956,
                  1024, 1080, 1112, 1133, 1180, 1194, 1210, 1366, 1376}

FIXED_WIDTH_MIN = 320

# --------------------------------------------------------------------------
# Lexing: blank out comments and string literals, keep line and column numbers.

_SWIFT_STR_OPEN = re.compile(r'(#*)("""|")')
_SWIFT_CODE_STOP = re.compile(r'[/"#()]')
_C_CODE_STOP = re.compile(r"""[/"']""")


def split_code_and_comments(text, lang):
    """Return (code, comments), two strings with the same length as text.

    code keeps program text. Comments and the contents of string literals become
    spaces. Swift string interpolations stay code. comments keeps only comment
    text. Both keep every newline, so lines and columns match the source.
    """
    if lang == "swift":
        return _split_swift(text)
    return _split_c(text)


def _blank(buf, text, a, b):
    for k in range(a, b):
        if text[k] != "\n":
            buf[k] = " "


def _copy(buf, text, a, b):
    for k in range(a, b):
        buf[k] = text[k]


def _block_comment_end(text, i, nested):
    n = len(text)
    depth = 1
    j = i + 2
    while j < n and depth > 0:
        if nested and text.startswith("/*", j):
            depth += 1
            j += 2
        elif text.startswith("*/", j):
            depth -= 1
            j += 2
        else:
            j += 1
    return j


def _split_swift(text):
    n = len(text)
    code = list(text)
    comments = [c if c == "\n" else " " for c in text]
    # Stack of contexts. ("str", multiline, hashes) or ("interp", paren_depth).
    # Empty stack or "interp" on top means code.
    stack = []
    i = 0
    while i < n:
        top = stack[-1] if stack else None
        if top is None or top[0] == "interp":
            m = _SWIFT_CODE_STOP.search(text, i)
            if not m:
                break
            i = m.start()
            ch = text[i]
            if ch == "/" and text.startswith("//", i):
                j = text.find("\n", i)
                j = n if j == -1 else j
                _copy(comments, text, i, j)
                _blank(code, text, i, j)
                i = j
                continue
            if ch == "/" and text.startswith("/*", i):
                j = _block_comment_end(text, i, nested=True)
                _copy(comments, text, i, j)
                _blank(code, text, i, j)
                i = j
                continue
            if ch in '"#':
                sm = _SWIFT_STR_OPEN.match(text, i)
                if sm:
                    stack.append(("str", sm.group(2) == '"""', len(sm.group(1))))
                    i = sm.end()
                    continue
                i += 1
                continue
            if top is not None and ch == "(":
                stack[-1] = ("interp", top[1] + 1)
            elif top is not None and ch == ")":
                if top[1] == 0:
                    stack.pop()
                else:
                    stack[-1] = ("interp", top[1] - 1)
            i += 1
            continue

        # Inside a string literal.
        _, multiline, hashes = top
        ch = text[i]
        if ch == "\\":
            j = i + 1
            if text.startswith("#" * hashes, j):
                j2 = j + hashes
                if j2 < n and text[j2] == "(":
                    _blank(code, text, i, j2 + 1)
                    stack.append(("interp", 0))
                    i = j2 + 1
                    continue
                end = min(j2 + 1, n)
                _blank(code, text, i, end)
                i = end
                continue
            _blank(code, text, i, i + 1)
            i += 1
            continue
        closer = ('"""' if multiline else '"') + "#" * hashes
        if text.startswith(closer, i):
            stack.pop()
            i += len(closer)
            continue
        if ch == "\n":
            if not multiline:
                stack.pop()  # Unterminated string: recover at the end of the line.
            i += 1
            continue
        code[i] = " "
        i += 1
    return "".join(code), "".join(comments)


def _split_c(text):
    n = len(text)
    code = list(text)
    comments = [c if c == "\n" else " " for c in text]
    i = 0
    while i < n:
        m = _C_CODE_STOP.search(text, i)
        if not m:
            break
        i = m.start()
        ch = text[i]
        if ch == "/":
            if text.startswith("//", i):
                j = text.find("\n", i)
                j = n if j == -1 else j
                _copy(comments, text, i, j)
                _blank(code, text, i, j)
                i = j
            elif text.startswith("/*", i):
                j = _block_comment_end(text, i, nested=False)
                _copy(comments, text, i, j)
                _blank(code, text, i, j)
                i = j
            else:
                i += 1
            continue
        # String or character literal.
        quote = ch
        j = i + 1
        while j < n:
            c = text[j]
            if c == "\\":
                j += 2
                continue
            if c == quote or c == "\n":
                break
            j += 1
        _blank(code, text, i + 1, min(j, n))
        i = j + 1
    return "".join(code), "".join(comments)


# --------------------------------------------------------------------------
# Suppression comments.

_DIRECTIVE = re.compile(r"duo-lint:(disable-next-line|disable-line|disable-file)\b([^\n]*)")
_RULE_ID = re.compile(r"\bDUO\d{3}\b")


def parse_directives(comment_text):
    """Return (by_line, whole_file). Values are sets of rule ids; None means all rules."""
    by_line = {}
    whole_file = set()
    all_file = False
    for lineno, line in enumerate(comment_text.split("\n"), start=1):
        for m in _DIRECTIVE.finditer(line):
            kind, tail = m.group(1), m.group(2)
            tail = re.split(r"--|\*/|-->", tail, maxsplit=1)[0]
            ids = set(_RULE_ID.findall(tail))
            if kind == "disable-file":
                if ids:
                    whole_file |= ids
                else:
                    all_file = True
                continue
            target = lineno + 1 if kind == "disable-next-line" else lineno
            current = by_line.get(target, set())
            if current is None or not ids:
                by_line[target] = None
            else:
                by_line[target] = current | ids
    return by_line, (None if all_file else whole_file)


def is_suppressed(rule_id, line, by_line, whole_file):
    if whole_file is None or rule_id in whole_file:
        return True
    if line in by_line:
        ids = by_line[line]
        return ids is None or rule_id in ids
    return False


# --------------------------------------------------------------------------
# Findings.

class Finding(object):
    __slots__ = ("path", "line", "column", "rule", "snippet", "fix", "code", "project")

    def __init__(self, path, line, column, rule, snippet, fix=None, code=""):
        self.project = None  # DUO008 build settings only: project folder still to check
        self.path = path
        self.line = line
        self.column = column
        self.rule = rule
        self.snippet = snippet
        self.fix = fix or rule.fix
        self.code = code

    @property
    def severity(self):
        return self.rule.severity

    def as_dict(self, display_path):
        return {
            "path": display_path,
            "line": self.line,
            "column": self.column,
            "rule": self.rule.id,
            "name": self.rule.name,
            "severity": self.rule.severity,
            "snippet": self.snippet,
            "message": self.rule.message,
            "fix": self.fix,
            "source": self.rule.source,
            "code": self.code,
        }


# --------------------------------------------------------------------------
# Swift and Objective-C rules.

_RE_MAIN_SCREEN = re.compile(
    r"\bUIScreen\s*\.\s*(main|mainScreen|screens)\b(?:\s*\.\s*(\w+))?"
    r"|\[\s*UIScreen\s+(mainScreen|screens)\s*\](?:\s*\.\s*(\w+))?")
# `.main` where Swift infers UIScreen: a UIScreen declaration or default value, a body
# that returns it, `screen ?? .main`, and an argument labelled `screen:`.
_RE_IMPLICIT_MAIN_SCREEN = re.compile(
    r"\bUIScreen\s*[?!]?\s*=\s*\.\s*main\b"
    r"|\bUIScreen\s*[?!]?\s*\{\s*(?:return\s+)?\.\s*main\b"
    r"|\b\w*[sS]creen\s*[?!]?\s*\)?\s*\?\?\s*\.\s*main\b"
    r"|\b\w*[sS]creen\s*:\s*\.\s*main\b")
_RE_RETURNS_UISCREEN = re.compile(r"\bUIScreen\s*[?!]?\s*\{\s*$")
_RE_LONE_MAIN = re.compile(r"^\s*(?:return\s+)?\.\s*main\b(?!\s*[.(])")
_RE_DEVICE_ORIENTATION = re.compile(
    r"\bUIDevice\s*\.\s*current(?:Device)?\s*\.\s*orientation\b"
    r"|\[\s*\[\s*UIDevice\s+currentDevice\s*\]\s+orientation\s*\]"
    r"|\bUIDevice\s*\.\s*orientationDidChangeNotification\b"
    r"|\bUIDeviceOrientationDidChangeNotification\b"
    r"|\bbeginGeneratingDeviceOrientationNotifications\b")

# DUO003 and DUO002: interfaceOrientation, and what it is read from. duo-lint reads text,
# not types, so it reports DUO003 only when the code shows a deprecated receiver.
_RE_STATUS_BAR_ORIENTATION = re.compile(r"\bstatusBarOrientation\b")
_RE_MEMBER_INTERFACE_ORIENTATION = re.compile(r"\.\s*interfaceOrientation\b")
_RE_BARE_INTERFACE_ORIENTATION = re.compile(r"(?<![\w.$])interfaceOrientation\b")
_RE_OBJC_INTERFACE_ORIENTATION = re.compile(
    r"\[\s*(?:([\w.]+)|\[[^\[\]]*?\s(\w+)\s*\])\s+interfaceOrientation\s*\]")
_RE_DECLARES_INTERFACE_ORIENTATION = re.compile(
    r"\b(?:let|var)\s+interfaceOrientation\b"
    r"|\binterfaceOrientation\s*:\s*UIInterfaceOrientation\b"
    r"|\b\w+\s+interfaceOrientation\s*:"
    r"|\binterfaceOrientation\s+in\b")
SCENE, GEOMETRY, CONTROLLER, SELF = "scene", "geometry", "controller", "self"
_TYPE = (r"(UIWindowScene\s*\.\s*Geometry\b|UIWindowSceneGeometry\b|UIWindowScene\b(?!\s*\.)"
         r"|\w*Controller\b)")
_RE_CAST_END = re.compile(r"\bas\s*[?!]?\s*" + _TYPE + r"\s*[?!]?\s*$")
_RE_BIND_TYPED = re.compile(r"\b([A-Za-z_]\w*)\s*:\s*" + _TYPE)
_RE_BIND_OBJC = re.compile(
    r"\b(UIWindowSceneGeometry|UIWindowScene|\w*Controller)\s*\*\s*\)?\s*"
    r"(?:(?:_Nullable|_Nonnull|const)\s+)*([A-Za-z_]\w*)")
_RE_BIND_ASSIGN = re.compile(
    r"\b(?:let|var)\s+([A-Za-z_]\w*)\s*(:\s*[\w.<>\[\]]+\s*[?!]?\s*)?=(?!=)\s*([^\n,{}]+)")
_RE_TRAIL_IDENT = re.compile(r"([A-Za-z_]\w*)\s*$")
_RE_VC_CONTEXT = re.compile(
    r"\bclass\s+\w+(?:\s*<[^>{]*>)?\s*:\s*[^{]*?\b\w*ViewController\b"
    r"|\bextension\s+\w*ViewController\b"
    r"|@interface\s+\w+\s*:\s*\w*ViewController\b"
    r"|@(?:implementation|interface)\s+\w*ViewController\b")
_KEYWORDS_BEFORE_PAREN = {"if", "guard", "while", "return", "switch", "case", "where", "in",
                          "try", "await", "else", "repeat"}

# DUO004: the idiom compared with .pad or .phone.
_RE_IDIOM_TOKEN = re.compile(r"\buserInterfaceIdiom\b|\bUI_USER_INTERFACE_IDIOM\b")
_PAD_PHONE = (r"((?:\bUIUserInterfaceIdiom\s*)?\.\s*(?:pad|phone)\b"
              r"|\bUIUserInterfaceIdiom(?:Pad|Phone)\b)")
_RE_PAD_PHONE = re.compile(_PAD_PHONE)
_RE_IDIOM_TYPED = re.compile(r"\b([A-Za-z_]\w*)\s*:\s*UIUserInterfaceIdiom\b(?!\s*\.)")
_RE_IDIOM_OBJC_VAR = re.compile(r"\bUIUserInterfaceIdiom\s+([A-Za-z_]\w*)\s*[=;]")
_RE_IDIOM_ASSIGN = re.compile(
    r"\b(?:let|var)\s+([A-Za-z_]\w*)\s*(?::\s*UIUserInterfaceIdiom\s*[?!]?\s*)?=(?!=)\s*([^\n,{}]+)")
_RE_ORIENTATION_MASK_DECL = re.compile(
    r"\b(?:var|func)\s+supportedInterfaceOrientations\b"
    r"|\bfunc\s+application\s*\([^{]*?\bsupportedInterfaceOrientationsFor\b"
    r"|^[ \t]*[-+]\s*\([^)]*\)\s*supportedInterfaceOrientations\b"
    r"|^[ \t]*[-+]\s*\([^)]*\)\s*application\s*:[^{]*?\bsupportedInterfaceOrientationsForWindow\b",
    re.M)
_CHAIN = r"[\w.\s\[\]()?!]*?"

_RE_SIZE_CLASS_ENV = re.compile(
    r"@Environment\s*\(\s*\\\s*\.\s*horizontalSizeClass\s*\)\s*"
    r"(?:(?:private|fileprivate|internal|public)(?:\s*\(\s*set\s*\))?\s+)*var\s+(\w+)")
_RE_REGULAR = re.compile(r"\.\s*regular\b|\bUIUserInterfaceSizeClassRegular\b")
_RE_COMPACT = re.compile(r"\.\s*compact\b|\bUIUserInterfaceSizeClassCompact\b")
_RE_IPAD_HINT = re.compile(r"(?i)ipad|tablet")
_RE_IPHONE_HINT = re.compile(r"(?i)iphone(?!\s*duo)|\bis_?phone\b")

_RE_PROXY_NAMES = [
    re.compile(r"\bGeometryReader\s*(?:\(\s*content\s*:\s*)?\{\s*\(?\s*(\w+)\s*\)?\s+in\b"),
    re.compile(r"\b(\w+)\s*:\s*GeometryProxy\b"),
]

_OP = r"(==|!=|<=|>=|(?<![<\-.])<(?![<=])|(?<![>\-])>(?![>=]))"
_NUM = r"(\d+(?:\.\d+)?)"
_RE_CMP_RIGHT = re.compile(
    _OP + r"\s*(?:(?:CGFloat|Double|Int|Float)\s*\(\s*|\(\s*)?" + _NUM + r"(?![\w.])")
_RE_CMP_LEFT = re.compile(r"(?<![\w.])" + _NUM + r"\s*\)?\s*" + _OP)
_RE_STRONG_CONTEXT = re.compile(
    r"(?i)bounds|screen|window|scene|safearea|display|device|geometry|proxy|container"
    r"|\bgeo\b|\bview\b|frame\s*\.\s*(?:width|height|size)")
_RE_WEAK_CONTEXT = re.compile(r"(?i)width|height|size|frame|\b[wh]\b")
_RE_PIXEL_CONTEXT = re.compile(r"\bnative(?:Bounds|Scale)\b")
_RE_SWITCH = re.compile(r"\bswitch\b")
_RE_CASE = re.compile(r"^\s*case\b")
_RE_NUMBER = re.compile(r"(?<![\w.])(\d+(?:\.\d+)?)(?![\w])")
_RE_ARRAY = re.compile(r"\[([^\[\]]*)\]")
_RE_PREVIEW = re.compile(r"previewLayout|previewDevice|#Preview|PreviewProvider")
_RE_SIZE_PAIR = [
    re.compile(r"\bCG(?:Size|Rect)\s*\(\s*(?:x\s*:\s*[^,()]+,\s*y\s*:\s*[^,()]+,\s*)?"
               r"width\s*:\s*" + _NUM + r"\s*,\s*height\s*:\s*" + _NUM + r"\s*\)"),
    re.compile(r"\bCGRectMake\s*\(\s*[^,()]+,\s*[^,()]+,\s*" + _NUM + r"\s*,\s*" + _NUM + r"\s*\)"),
    re.compile(r"\bCGSizeMake\s*\(\s*" + _NUM + r"\s*,\s*" + _NUM + r"\s*\)"),
]

_RE_FRAME_CALL = re.compile(r"\.\s*frame\s*\(")
_RE_FRAME_WIDTH_ARG = re.compile(
    r"(?<![\w])(width|minWidth)\s*:\s*(?:CGFloat\s*\(\s*)?" + _NUM + r"(?:\s*\))?(?=\s*(?:,|\Z))")
_RE_ANCHOR_WIDTH = re.compile(
    r"\bwidthAnchor\s*\.\s*constraint\s*\(\s*(?:equalToConstant|greaterThanOrEqualToConstant)"
    r"\s*:\s*" + _NUM + r"(?![\w.])"
    r"|\bwidthAnchor\s+constraint(?:EqualTo|GreaterThanOrEqualTo)Constant\s*:\s*" + _NUM + r"(?![\w.])")


def _tidy(text):
    """Collapse whitespace in a code snippet and drop spaces around member dots."""
    text = re.sub(r"\s+", " ", text.strip())
    return re.sub(r"(?<=[\w)\]?!])\s*\.\s*(?=\w)", ".", text)


_RE_PP = re.compile(r"^\s*#\s*(if|ifdef|ifndef|elseif|elif|else|endif)\b(.*)$")
_NON_IOS_ATOM = re.compile(
    r"^(?:os\s*\(\s*(?:macOS|OSX|watchOS|tvOS|visionOS)\s*\)"
    r"|targetEnvironment\s*\(\s*macCatalyst\s*\)"
    r"|canImport\s*\(\s*AppKit\s*\)"
    r"|!\s*os\s*\(\s*iOS\s*\)|!\s*canImport\s*\(\s*UIKit\s*\)"
    r"|TARGET_OS_(?:OSX|WATCH|TV|VISION|MACCATALYST)|!\s*TARGET_OS_(?:IPHONE|IOS))$")
_IOS_ATOM = re.compile(
    r"^(?:os\s*\(\s*iOS\s*\)|canImport\s*\(\s*UIKit\s*\)|TARGET_OS_(?:IPHONE|IOS))$")


def _cond_kind(cond):
    """Classify a #if condition: "non_ios", "ios" (true on iOS) or "unknown"."""
    cond = cond.strip()
    if not cond or "&&" in cond:
        return "unknown"
    parts = []
    for part in cond.split("||"):
        part = part.strip()
        while part.startswith("(") and part.endswith(")") and part.count("(") == part.count(")"):
            inner = part[1:-1].strip()
            if inner.count("(") != inner.count(")"):
                break
            part = inner
        parts.append(part)
    if all(_NON_IOS_ATOM.match(p) for p in parts):
        return "non_ios"
    if any(_IOS_ATOM.match(p) for p in parts):
        return "ios"
    return "unknown"


def non_ios_lines(code_lines):
    """Return the line numbers inside #if blocks that never build for iOS."""
    skipped = set()
    stack = []  # [skip, seen_ios]
    for idx, line in enumerate(code_lines):
        m = _RE_PP.match(line)
        if m:
            kind, cond = m.group(1), m.group(2)
            if kind in ("if", "ifdef", "ifndef"):
                k = _cond_kind(cond) if kind == "if" else "unknown"
                stack.append([k == "non_ios", k == "ios"])
            elif kind in ("elseif", "elif") and stack:
                top = stack[-1]
                if top[1]:
                    top[0] = True
                else:
                    k = _cond_kind(cond)
                    top[0], top[1] = k == "non_ios", k == "ios"
            elif kind == "else" and stack:
                stack[-1][0] = stack[-1][1]
            elif kind == "endif" and stack:
                stack.pop()
            continue
        if any(frame[0] for frame in stack):
            skipped.add(idx + 1)
    return skipped


_RE_PREVIEW_START = re.compile(r"#Preview\b|:\s*PreviewProvider\b")


def preview_lines(code):
    """Return the line numbers inside #Preview blocks and PreviewProvider types."""
    lines = set()
    for m in _RE_PREVIEW_START.finditer(code):
        start = code.find("{", m.end())
        if start == -1:
            continue
        depth = 0
        j = start
        while j < len(code):
            if code[j] == "{":
                depth += 1
            elif code[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        first = code.count("\n", 0, m.start()) + 1
        last = code.count("\n", 0, j) + 1
        lines.update(range(first, last + 1))
    return lines


def _as_int(text):
    try:
        value = float(text)
    except ValueError:
        return None
    if value != int(value):
        return None
    return int(value)


def _is_device_literal(value, strong, pixel):
    if value is None:
        return False
    if pixel and value in PIXEL_SIZES:
        return True
    if value in DISTINCT_POINT_SIZES:
        return True
    return strong and value in COMMON_POINT_SIZES


def _line_col(text, offset):
    line = text.count("\n", 0, offset) + 1
    start = text.rfind("\n", 0, offset) + 1
    return line, offset - start + 1


def _brace_body(code, start):
    """Return (open, close) offsets of the first {...} block at or after start, or None."""
    first = code.find("{", start)
    if first == -1:
        return None
    depth = 0
    for j in range(first, len(code)):
        if code[j] == "{":
            depth += 1
        elif code[j] == "}":
            depth -= 1
            if depth == 0:
                return first, j
    return first, len(code)


def orientation_mask_lines(code):
    """Return the line numbers inside supportedInterfaceOrientations bodies.

    Idiom checks there pick the orientations the app supports, not a layout.
    """
    lines = set()
    for m in _RE_ORIENTATION_MASK_DECL.finditer(code):
        brace = code.find("{", m.end())
        if brace == -1:
            continue
        between = code[m.end():brace].replace("->", "")
        if "=" in between or ";" in between:
            continue  # a declaration without a body
        body = _brace_body(code, brace)
        first = code.count("\n", 0, m.start()) + 1
        last = code.count("\n", 0, body[1]) + 1
        lines.update(range(first, last + 1))
    return lines


def _type_kind(name):
    name = re.sub(r"\s+", "", name)
    if name in ("UIWindowScene.Geometry", "UIWindowSceneGeometry"):
        return GEOMETRY
    if name == "UIWindowScene":
        return SCENE
    if name.endswith("Controller"):
        return CONTROLLER
    return None


def _member_kind(member):
    """What a property returns, when its name says so for certain in UIKit."""
    if member == "windowScene":
        return SCENE
    if member == "effectiveGeometry":
        return GEOMETRY
    if member.endswith("ViewController"):
        return CONTROLLER
    return None


def _trailing_name(text, end):
    """Return (start, name) of the identifier that ends at text[end], or (end, "")."""
    i = end
    while i > 0 and (text[i - 1].isalnum() or text[i - 1] == "_"):
        i -= 1
    name = text[i:end]
    if not name or name[0].isdigit():
        return end, ""
    return i, name


def _receiver(text, end, lookup, base=0, depth=0):
    """Classify the expression that ends just before text[end].

    Returns (kind, label). kind is SCENE, GEOMETRY, CONTROLLER, SELF, or None when the
    code doesn't show the type. label is the last name in the expression. base is the
    offset of text[0] in the file, for lookup.
    """
    head = text[:end]
    cast = _RE_CAST_END.search(head)
    if cast:
        return _type_kind(cast.group(1)), re.sub(r"\s+", "", cast.group(1))
    j = len(head.rstrip(" \t\n?!"))
    if j and head[j - 1] == ")":
        k, d = j - 1, 0
        while k >= 0:
            if head[k] == ")":
                d += 1
            elif head[k] == "(":
                d -= 1
                if d == 0:
                    break
            k -= 1
        if k < 0 or depth > 3:
            return None, ""
        before = head[:k].rstrip()
        word = _trailing_name(before, len(before))[1]
        if before and (before[-1] in "?!)]>" or (word and word not in _KEYWORDS_BEFORE_PAREN)):
            return None, ""  # a call, such as make(x).interfaceOrientation
        return _receiver(head, j - 1, lookup, base, depth + 1)
    i, name = _trailing_name(head, j)
    if not name:
        return None, ""
    if head[:i].rstrip().endswith("."):
        return _member_kind(name), name
    if name in ("self", "super"):
        return SELF, name
    return lookup(name, base + i), name


def _orientation_lookup(code, swift):
    """Return lookup(name, offset): the kind of the nearest binding of name, or None.

    It knows names typed as UIWindowScene, UIWindowScene.Geometry or a view controller,
    casts to those types, and names assigned from .windowScene or .effectiveGeometry.
    """
    bindings = []  # (offset, name, kind), sorted by offset
    if swift:
        for m in _RE_BIND_TYPED.finditer(code):
            bindings.append((m.start(1), m.group(1), _type_kind(m.group(2))))
    else:
        for m in _RE_BIND_OBJC.finditer(code):
            bindings.append((m.start(2), m.group(2), _type_kind(m.group(1))))
    bindings.sort(key=lambda b: b[0])

    def lookup(name, offset):
        found, kind = False, None
        for off, nm, k in bindings:
            if nm != name:
                continue
            if off < offset:
                found, kind = True, k
            elif not found:
                return k
            else:
                break
        return kind

    if swift:
        for m in _RE_BIND_ASSIGN.finditer(code):
            if m.group(2):
                continue  # `let name: Type = ...`: the type annotation already counts
            rhs = re.sub(r"\s+else\s*$", "", m.group(3).rstrip())
            kind = _receiver(rhs, len(rhs), lookup, m.start(3))[0]
            at = bisect.bisect_right([b[0] for b in bindings], m.start(1))
            bindings.insert(at, (m.start(1), m.group(1), kind))
    return lookup


def lint_source(text, path="<memory>", lang="swift", rules=None):
    """Lint Swift or Objective-C source text. Returns a list of Finding."""
    code, comments = split_code_and_comments(text, lang)
    raw_lines = text.split("\n")
    code_lines = code.split("\n")
    found = {}

    def add(rule_id, line, col, snippet, fix=None):
        if rules is not None and rule_id not in rules:
            return
        key = (line, rule_id)
        if key in found:
            return
        code_line = raw_lines[line - 1].strip() if 0 < line <= len(raw_lines) else ""
        found[key] = Finding(path, line, col, RULES_BY_ID[rule_id], snippet, fix, code_line)

    swift = lang == "swift"
    proxy_names = set()
    for rx in _RE_PROXY_NAMES:
        proxy_names.update(m.group(1) for m in rx.finditer(code))
    proxy_names.discard("_")
    proxy_rx = None
    if proxy_names:
        proxy_rx = re.compile(r"\b(?:%s)\s*\.\s*size\b" % "|".join(
            re.escape(p) for p in sorted(proxy_names)))
    size_class_names = {m.group(1) for m in _RE_SIZE_CLASS_ENV.finditer(code)}
    size_class_rx = re.compile(r"\bhorizontalSizeClass\b" + "".join(
        r"|\b%s\b" % re.escape(nm) for nm in sorted(size_class_names)))
    skip = non_ios_lines(code_lines)
    previews = preview_lines(code)
    line_starts = [0]
    for line in code_lines[:-1]:
        line_starts.append(line_starts[-1] + len(line) + 1)

    def line_col(offset):
        idx = bisect.bisect_right(line_starts, offset) - 1
        return idx + 1, offset - line_starts[idx] + 1

    # DUO003 and DUO002: interfaceOrientation. DUO003 (error) only when the code shows
    # the receiver is one of the deprecated properties; DUO002 (warning) otherwise.
    if "interfaceOrientation" in code:
        lookup = _orientation_lookup(code, swift)
        vc_context = bool(_RE_VC_CONTEXT.search(code))
        declared = bool(_RE_DECLARES_INTERFACE_ORIENTATION.search(code))

        def orientation_rule(kind):
            if kind in (SCENE, CONTROLLER):
                return "DUO003"
            if kind == SELF and vc_context and not declared:
                return "DUO003"
            return "DUO002"

        for m in _RE_MEMBER_INTERFACE_ORIENTATION.finditer(code):
            line, col = line_col(m.start())
            if line in skip:
                continue
            lo = max(0, m.start() - 300)
            kind, label = _receiver(code[lo:m.start()], m.start() - lo, lookup, lo)
            add(orientation_rule(kind), line, col,
                (label + "." if label else ".") + "interfaceOrientation")
        if swift and not declared:
            for m in _RE_BARE_INTERFACE_ORIENTATION.finditer(code):
                rest = code[m.end():m.end() + 80]
                if re.match(r"\s*:|\s+[A-Za-z_]\w*\s*:|\s+in\b", rest):
                    continue  # an argument label, a parameter label or a closure parameter
                if re.search(r"\b(?:let|var|case|func)\s+$", code[max(0, m.start() - 40):m.start()]):
                    continue
                line, col = line_col(m.start())
                if line not in skip:
                    add(orientation_rule(SELF), line, col, "interfaceOrientation")
        if not swift:
            for m in _RE_OBJC_INTERFACE_ORIENTATION.finditer(code):
                line, col = line_col(m.start())
                if line in skip:
                    continue
                if m.group(1):
                    kind, label = _receiver(m.group(1), len(m.group(1)), lookup, m.start(1))
                else:
                    label = m.group(2)
                    kind = _member_kind(label)
                add(orientation_rule(kind), line, col, "[%s interfaceOrientation]" % label)

    # DUO004: the idiom compared with .pad or .phone, directly or through a variable.
    idiom_rx = None
    if _RE_IDIOM_TOKEN.search(code) or "UIUserInterfaceIdiom" in code:
        aliases = {m.group(1) for m in _RE_IDIOM_TYPED.finditer(code)}
        aliases.update(m.group(1) for m in _RE_IDIOM_OBJC_VAR.finditer(code))
        for m in _RE_IDIOM_ASSIGN.finditer(code):
            if _RE_IDIOM_TOKEN.search(m.group(2)) and not re.search(r"==|!=|\?\s|:", m.group(2)):
                aliases.add(m.group(1))
        aliases -= {"userInterfaceIdiom", "UI_USER_INTERFACE_IDIOM"}
        subj = (r"(\buserInterfaceIdiom\b|\bUI_USER_INTERFACE_IDIOM\s*\(\s*\)"
                + "".join(r"|\b%s\b" % re.escape(a) for a in sorted(aliases)) + ")")
        idiom_rx = (
            re.compile(subj + r"\s*[\])]*\s*(==|!=)\s*" + _PAD_PHONE),
            re.compile(_PAD_PHONE + r"\s*(==|!=)\s*" + _CHAIN + subj),
            re.compile(r"\bcase\s+" + _PAD_PHONE + r"\s*=\s*" + _CHAIN + subj),
            re.compile(r"(\[[^\[\]\n]*\])\s*\.\s*contains\s*\(\s*" + _CHAIN + subj),
            re.compile(r"\bswitch\b\s*\(?\s*" + _CHAIN + subj),
        )
        mask_lines = orientation_mask_lines(code)

    def idiom_finding(c, start):
        """Return (column, snippet) for an idiom comparison on line c, or None."""
        left, right, case, contains, switch = idiom_rx
        m = left.search(c)
        if m:
            return m.start() + 1, "%s %s %s" % (_tidy(m.group(1)), m.group(2), _tidy(m.group(3)))
        m = right.search(c)
        if m:
            return m.start() + 1, "%s %s %s" % (_tidy(m.group(1)), m.group(2), _tidy(m.group(3)))
        m = case.search(c)
        if m:
            return m.start() + 1, "case %s = %s" % (_tidy(m.group(1)), _tidy(m.group(2)))
        m = contains.search(c)
        if m and _RE_PAD_PHONE.search(m.group(1)):
            return m.start() + 1, "%s.contains(%s)" % (_tidy(m.group(1)), _tidy(m.group(2)))
        m = switch.search(c)
        if m:
            body = _brace_body(code, start + m.end())
            if body and re.search(r"\bcase\b[^:\n]*" + _PAD_PHONE, code[body[0]:body[1]]):
                return m.start() + 1, "switch %s" % _tidy(m.group(1))
        return None

    last_switch = None       # (line index, strong, weak, pixel, proxy)
    last_size_switch = None  # line index of a switch on the horizontal size class

    for idx, c in enumerate(code_lines):
        lineno = idx + 1
        if not c.strip() or lineno in skip:
            continue

        # DUO001: main screen.
        for m in _RE_MAIN_SCREEN.finditer(c):
            which = m.group(1) or m.group(3)
            member = m.group(2) or m.group(4) or ""
            fix = None
            if which == "screens":
                fix = FIX_DUO001_SCREENS
            elif re.search(r"\bUIWindow\s*\(\s*frame\s*:", c) or (
                    "UIWindow" in c and "initWithFrame" in c):
                fix = FIX_DUO001_WINDOW
            elif member in ("scale", "nativeScale"):
                fix = FIX_DUO001_SCALE
            add("DUO001", lineno, m.start() + 1, _tidy(m.group(0)), fix)
        if swift:
            m = _RE_IMPLICIT_MAIN_SCREEN.search(c)
            if m:
                add("DUO001", lineno, m.start() + 1, re.sub(r"\s+", " ", m.group(0)))
            elif _RE_LONE_MAIN.match(c):
                prev = next((p for p in reversed(code_lines[max(0, idx - 3):idx]) if p.strip()), "")
                if _RE_RETURNS_UISCREEN.search(prev):
                    add("DUO001", lineno, len(c) - len(c.lstrip()) + 1,
                        re.sub(r"\s+", " ", c.strip()) + " (UIScreen)")

        # DUO002: device orientation.
        m = _RE_DEVICE_ORIENTATION.search(c)
        if m:
            add("DUO002", lineno, m.start() + 1, _tidy(m.group(0)))

        # DUO003: statusBarOrientation exists only on UIApplication.
        m = _RE_STATUS_BAR_ORIENTATION.search(c)
        if m:
            add("DUO003", lineno, m.start() + 1, "statusBarOrientation")

        # DUO004: idiom used to pick a layout.
        if idiom_rx and lineno not in mask_lines:
            hit = idiom_finding(c, line_starts[idx])
            if hit:
                add("DUO004", lineno, hit[0], hit[1])

        # DUO005: size class treated as a device type.
        sm = size_class_rx.search(c)
        if sm and _RE_SWITCH.search(c):
            last_size_switch = idx
        in_size_case = (last_size_switch is not None and _RE_CASE.search(c)
                        and idx - last_size_switch <= 40)
        if sm or in_size_case:
            col = (sm.start() if sm else len(c) - len(c.lstrip())) + 1
            window = "\n".join(raw_lines[max(0, idx - 2):idx + 3])
            if _RE_REGULAR.search(c) and _RE_IPAD_HINT.search(window):
                add("DUO005", lineno, col, "regular width as iPad")
            elif _RE_COMPACT.search(c) and _RE_IPHONE_HINT.search(window):
                add("DUO005", lineno, col, "compact width as iPhone")

        # DUO006 and DUO009: device sizes.
        proxy_hit = bool(proxy_rx and proxy_rx.search(c))
        strong = proxy_hit or bool(_RE_STRONG_CONTEXT.search(c))
        weak = bool(_RE_WEAK_CONTEXT.search(c))
        pixel = bool(_RE_PIXEL_CONTEXT.search(c))
        if _RE_SWITCH.search(c):
            last_switch = (idx, strong, weak, pixel, proxy_hit)
        preview = lineno in previews or bool(_RE_PREVIEW.search(c))

        if (strong or weak) and not preview:
            for rx in (_RE_CMP_RIGHT, _RE_CMP_LEFT):
                for m in rx.finditer(c):
                    if rx is _RE_CMP_RIGHT:
                        op, num, col = m.group(1), m.group(2), m.start(2)
                        snippet = "%s %s" % (op, num)
                    else:
                        num, op, col = m.group(1), m.group(2), m.start(1)
                        snippet = "%s %s" % (num, op)
                    if _is_device_literal(_as_int(num), strong, pixel):
                        add("DUO009" if proxy_hit else "DUO006", lineno, col + 1, snippet)
            for m in _RE_ARRAY.finditer(c):
                nums = [_as_int(x) for x in _RE_NUMBER.findall(m.group(1))]
                hits = [v for v in nums if v in POINT_SIZES or (pixel and v in PIXEL_SIZES)]
                distinct = [v for v in hits if v in DISTINCT_POINT_SIZES or pixel]
                if len(hits) >= 2 and (strong or distinct):
                    add("DUO009" if proxy_hit else "DUO006", lineno, m.start() + 1,
                        "[%s]" % ", ".join(str(v) for v in hits))

        if last_switch and not preview and _RE_CASE.search(c) and idx - last_switch[0] <= 40:
            _, s_strong, s_weak, s_pixel, s_proxy = last_switch
            if s_strong or s_weak:
                for m in _RE_NUMBER.finditer(c):
                    if _is_device_literal(_as_int(m.group(1)), s_strong, s_pixel):
                        add("DUO009" if s_proxy else "DUO006", lineno, m.start() + 1,
                            "case " + m.group(1))
                        break

        if not preview:
            for rx in _RE_SIZE_PAIR:
                for m in rx.finditer(c):
                    w, h = _as_int(m.group(1)), _as_int(m.group(2))
                    if (w in DEVICE_WIDTHS and h in DEVICE_HEIGHTS) or \
                            (h in DEVICE_WIDTHS and w in DEVICE_HEIGHTS):
                        add("DUO006", lineno, m.start() + 1, "%s x %s" % (w, h))

        # DUO007 (UIKit): width constraints.
        m = _RE_ANCHOR_WIDTH.search(c)
        if m and not preview:
            value = m.group(1) or m.group(2)
            if float(value) >= FIXED_WIDTH_MIN:
                add("DUO007", lineno, m.start() + 1, "widthAnchor = %s" % value)

    # DUO007 (SwiftUI): .frame(width:) and .frame(minWidth:), across lines.
    for m in _RE_FRAME_CALL.finditer(code):
        start = m.end()
        depth = 1
        j = start
        while j < len(code) and depth:
            if code[j] == "(":
                depth += 1
            elif code[j] == ")":
                depth -= 1
            j += 1
        args = code[start:j - 1] if depth == 0 else code[start:j]
        for a in _RE_FRAME_WIDTH_ARG.finditer(args):
            if float(a.group(2)) < FIXED_WIDTH_MIN:
                continue
            line, col = _line_col(code, start + a.start())
            if line in skip or line in previews or _RE_PREVIEW.search(code_lines[line - 1]):
                continue
            add("DUO007", line, col, "frame(%s: %s)" % (a.group(1), a.group(2)))

    by_line, whole_file = parse_directives(comments)
    results = [f for f in found.values()
               if not is_suppressed(f.rule.id, f.line, by_line, whole_file)]
    results.sort(key=lambda f: (f.line, f.column, f.rule.id))
    return results


# --------------------------------------------------------------------------
# Info.plist and build settings.

_RE_XML_COMMENT = re.compile(r"<!--.*?-->", re.S)
_RE_PLIST_FULL_SCREEN = re.compile(
    r"<key>\s*UIRequiresFullScreen(?:~\w+)?\s*</key>\s*<(true|false)\s*/>")
_RE_BUILD_SETTING_FULL_SCREEN = re.compile(
    r"\bINFOPLIST_KEY_UIRequiresFullScreen(?:\[[^\]]*\])?\s*=\s*\"?(YES|true|1)\"?")
IGNORE_KEY = "UIRequiresFullScreenIgnoredStartingWithVersion"
_RE_IGNORE_KEY = re.compile(r"<key>\s*" + IGNORE_KEY + r"\s*</key>")
_RE_INFOPLIST_FILE = re.compile(r"\bINFOPLIST_FILE\s*=\s*\"?([^\";\n]+?)\"?\s*(?:;|$)", re.M)
_RE_BUILD_SETTINGS_BLOCK = re.compile(r"\bbuildSettings\s*=\s*\{")
_PROJECT_VARS = ("$(SRCROOT)", "${SRCROOT}", "$(PROJECT_DIR)", "${PROJECT_DIR}",
                 "$(SOURCE_ROOT)", "${SOURCE_ROOT}")


def _blank_xml_comments(text):
    return _RE_XML_COMMENT.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)


def lint_plist_bytes(data, path="<memory>", rules=None):
    if rules is not None and "DUO008" not in rules:
        return []
    rule = RULES_BY_ID["DUO008"]
    text = None
    if not data.startswith(b"bplist"):
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            text = None
    if text is not None:
        by_line, whole_file = parse_directives(text)
        body = _blank_xml_comments(text)
        if _RE_IGNORE_KEY.search(body):
            return []
        raw_lines = text.split("\n")
        results = []
        for m in _RE_PLIST_FULL_SCREEN.finditer(body):
            if m.group(1) != "true":
                continue
            line, col = _line_col(body, m.start())
            if is_suppressed("DUO008", line, by_line, whole_file):
                continue
            results.append(Finding(path, line, col, rule, "UIRequiresFullScreen = true",
                                   code=raw_lines[line - 1].strip()))
        return results
    try:
        plist = plistlib.loads(data)
    except Exception:
        return []
    if isinstance(plist, dict) and IGNORE_KEY not in plist:
        for key, value in plist.items():
            if re.match(r"UIRequiresFullScreen(~\w+)?$", key) and value is True:
                return [Finding(path, 1, 1, rule, "UIRequiresFullScreen = true",
                                code="(binary plist)")]
    return []


def plist_has_ignore_key(data):
    """True when plist bytes (XML or binary) set UIRequiresFullScreenIgnoredStartingWithVersion."""
    if data.startswith(b"bplist"):
        try:
            plist = plistlib.loads(data)
        except Exception:
            return False
        return isinstance(plist, dict) and IGNORE_KEY in plist
    return bool(_RE_IGNORE_KEY.search(_blank_xml_comments(data.decode("utf-8", errors="replace"))))


def project_dir(path):
    """Return the folder that holds the .xcodeproj for path, or the file's own folder."""
    full = os.path.abspath(path)
    parts = full.split(os.sep)
    for i in range(len(parts) - 1, 0, -1):
        if parts[i].endswith(".xcodeproj"):
            return os.sep.join(parts[:i]) or os.sep
    folder = probe = os.path.dirname(full)
    for _ in range(10):
        try:
            if any(n.endswith(".xcodeproj") for n in os.listdir(probe)):
                return probe
        except OSError:
            break
        parent = os.path.dirname(probe)
        if parent == probe:
            break
        probe = parent
    return folder


def _infoplist_path(value, proj):
    """Resolve an INFOPLIST_FILE value against the project folder, or return None."""
    value = value.strip()
    for var in _PROJECT_VARS:
        if value.startswith(var):
            value = value[len(var):].lstrip("/")
            break
    if not value or "$" in value:
        return None
    full = value if os.path.isabs(value) else os.path.join(proj, value)
    return full if os.path.isfile(full) else None


def lint_build_settings(text, path="<memory>", rules=None):
    """Flag INFOPLIST_KEY_UIRequiresFullScreen = YES.

    Xcode merges these generated keys into the Info.plist named by INFOPLIST_FILE. When
    that plist (for the same build configuration) has the ignore key, the setting is fine.
    """
    if rules is not None and "DUO008" not in rules:
        return []
    rule = RULES_BY_ID["DUO008"]
    by_line, whole_file = parse_directives(text)
    raw_lines = text.split("\n")
    proj = project_dir(path) if os.path.isfile(path) else None
    pbxproj = os.path.basename(path) == "project.pbxproj"
    blocks = [_brace_body(text, m.end() - 1) for m in _RE_BUILD_SETTINGS_BLOCK.finditer(text)]
    results = []
    for m in _RE_BUILD_SETTING_FULL_SCREEN.finditer(text):
        line, col = _line_col(text, m.start())
        if is_suppressed("DUO008", line, by_line, whole_file):
            continue
        scope = "" if pbxproj else text
        for a, b in blocks:
            if a <= m.start() <= b:
                scope = text[a:b]
                break
        plist = None
        if proj:
            im = _RE_INFOPLIST_FILE.search(scope)
            plist = _infoplist_path(im.group(1), proj) if im else None
        if plist:
            try:
                with open(plist, "rb") as fh:
                    if plist_has_ignore_key(fh.read()):
                        continue
            except (IOError, OSError):
                plist = None
        f = Finding(path, line, col, rule, "INFOPLIST_KEY_UIRequiresFullScreen",
                    code=raw_lines[line - 1].strip())
        f.project = None if plist else proj  # still open: decided by the plists in the run
        results.append(f)
    return results


# --------------------------------------------------------------------------
# Files.

SKIP_DIRS = {".git", ".hg", ".svn", ".build", "build", "DerivedData", "Pods", "Carthage",
             "node_modules", ".swiftpm", "SourcePackages", "xcuserdata",
             ".claude", ".agents"}  # agent folders hold installed skills, duo-lint's included
SKIP_DIR_SUFFIXES = (".xcassets", ".xcframework", ".framework", ".bundle", ".xcworkspace",
                     ".xcresult", ".lproj", ".docc")
OBJC_EXTENSIONS = (".m", ".mm", ".h")


def file_kind(path, objc=False, explicit=False):
    base = os.path.basename(path)
    lower = base.lower()
    if lower.endswith(".swift"):
        return "swift"
    if lower.endswith(OBJC_EXTENSIONS) and (objc or explicit):
        return "objc"
    if lower.endswith(".plist") and (explicit or lower.endswith("info.plist")):
        return "plist"
    if lower.endswith(".xcconfig") or base == "project.pbxproj":
        return "settings"
    return None


def _excluded(path, patterns):
    """True when the path, or any folder above it, matches one of the glob patterns."""
    if not patterns:
        return False
    parts = os.path.normpath(path).replace(os.sep, "/").split("/")
    candidates = ["/".join(parts[:i]) for i in range(1, len(parts) + 1)]
    for pat in patterns:
        pat = pat.rstrip("/")
        for c in candidates:
            if fnmatch.fnmatch(c, pat) or fnmatch.fnmatch(c, "*/" + pat) or \
                    fnmatch.fnmatch(c.rsplit("/", 1)[-1], pat):
                return True
    return False


def _own_fixtures(dirpath, name):
    """True for duo-lint's own tests/fixtures folder, wherever the skill is installed."""
    parent = os.path.abspath(dirpath)
    return (name == "fixtures" and os.path.basename(parent) == "tests"
            and os.path.isfile(os.path.join(os.path.dirname(parent), "scripts", "duo-lint.py")))


def collect_files(paths, objc=False, excludes=()):
    """Yield (path, kind). Raise FileNotFoundError for a missing path."""
    seen = set()
    for root in paths:
        if not os.path.exists(root):
            raise FileNotFoundError(root)
        if os.path.isfile(root):
            kind = file_kind(root, objc, explicit=True)
            if kind and root not in seen:
                seen.add(root)
                yield root, kind
            elif not kind:
                sys.stderr.write("duo-lint: skipped %s (not a Swift, Objective-C, plist or "
                                 "build settings file)\n" % root)
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = sorted(
                d for d in dirnames
                if d not in SKIP_DIRS and not d.endswith(SKIP_DIR_SUFFIXES)
                and not _own_fixtures(dirpath, d)
                and not _excluded(os.path.relpath(os.path.join(dirpath, d), root), excludes))
            for name in sorted(filenames):
                full = os.path.join(dirpath, name)
                kind = file_kind(full, objc)
                if kind and full not in seen and \
                        not _excluded(os.path.relpath(full, root), excludes):
                    seen.add(full)
                    yield full, kind


def lint_paths(paths, objc=False, excludes=(), rules=None):
    """Lint files and folders. Return (findings, number of files checked).

    Raises FileNotFoundError for a missing path.
    """
    findings, files, ignore_plists = [], 0, []
    for path, kind in collect_files(paths, objc=objc, excludes=excludes):
        files += 1
        try:
            findings.extend(lint_file(path, kind, rules))
            if kind == "plist":
                with open(path, "rb") as fh:
                    if plist_has_ignore_key(fh.read()):
                        ignore_plists.append(os.path.abspath(path))
        except (IOError, OSError) as exc:
            sys.stderr.write("duo-lint: could not read %s: %s\n" % (path, exc))
    if ignore_plists:
        # A build setting whose own Info.plist duo-lint couldn't find: fine when an
        # Info.plist in the same project folder has the ignore key.
        findings = [f for f in findings if not (
            f.project and any(p.startswith(f.project.rstrip(os.sep) + os.sep)
                              for p in ignore_plists))]
    return findings, files


def lint_file(path, kind, rules=None):
    with open(path, "rb") as fh:
        data = fh.read()
    if kind == "plist":
        return lint_plist_bytes(data, path, rules)
    text = data.decode("utf-8", errors="replace")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    if kind == "settings":
        return lint_build_settings(text, path, rules)
    return lint_source(text, path, "swift" if kind == "swift" else "objc", rules)


# --------------------------------------------------------------------------
# Output.

def display_path(path, base=None):
    base = os.path.abspath(base or os.getcwd())
    full = os.path.abspath(path)
    try:
        rel = os.path.relpath(full, base)
    except ValueError:
        return path
    if rel.startswith(".."):
        return path
    return rel


def summary_line(findings, files):
    errors = sum(1 for f in findings if f.severity == ERROR)
    warnings = len(findings) - errors

    def plural(n, word):
        return "%d %s%s" % (n, word, "" if n == 1 else "s")

    return "%s · %s · %s (%s checked)" % (
        plural(len(findings), "finding"), plural(errors, "error"),
        plural(warnings, "warning"), plural(files, "file"))


def format_text(findings, files, verbose=False, base=None):
    lines = []
    if findings:
        locs = ["%s:%d" % (display_path(f.path, base), f.line) for f in findings]
        loc_w = max(len(x) for x in locs)
        snip_w = min(max(len(f.snippet) for f in findings), 32)
        for loc, f in zip(locs, findings):
            lines.append("%s  %s  %s  %s  %s" % (
                loc.ljust(loc_w), f.rule.id, f.severity.ljust(7),
                f.snippet.ljust(snip_w), f.rule.message))
            if verbose:
                lines.append("    fix: %s" % f.fix)
                lines.append("    see: %s" % f.rule.source)
    lines.append(summary_line(findings, files))
    return "\n".join(lines)


def _gh_escape(value, prop=False):
    value = value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    if prop:
        value = value.replace(":", "%3A").replace(",", "%2C")
    return value


def format_github(findings, files, base=None):
    lines = []
    for f in findings:
        level = "error" if f.severity == ERROR else "warning"
        props = "file=%s,line=%d,col=%d,title=%s" % (
            _gh_escape(display_path(f.path, base), True), f.line, f.column,
            _gh_escape("%s %s" % (f.rule.id, f.rule.name), True))
        msg = "%s: %s. Fix: %s See %s" % (f.snippet, f.rule.message, f.fix, f.rule.source)
        lines.append("::%s %s::%s" % (level, props, _gh_escape(msg)))
    lines.append(summary_line(findings, files))
    return "\n".join(lines)


def format_json(findings, files, base=None):
    errors = sum(1 for f in findings if f.severity == ERROR)
    return json.dumps({
        "tool": "duo-lint",
        "version": VERSION,
        "summary": {"files": files, "findings": len(findings), "errors": errors,
                    "warnings": len(findings) - errors},
        "findings": [f.as_dict(display_path(f.path, base)) for f in findings],
    }, indent=2)


# --------------------------------------------------------------------------
# Claude Code hook mode (PostToolUse on Edit, Write, MultiEdit).

HOOK_MAX_FINDINGS = 15


def _changed_lines(tool_name, tool_input, text):
    """Return a set of changed line numbers, or None for the whole file."""
    if tool_name == "Write":
        return None
    if tool_name == "Edit":
        news = [tool_input.get("new_string")]
    elif tool_name == "MultiEdit":
        news = [e.get("new_string") for e in (tool_input.get("edits") or [])
                if isinstance(e, dict)]
    else:
        return None
    lines = set()
    located = False
    for new in news:
        if not isinstance(new, str):
            return None
        if not new.strip():
            continue
        pos = text.find(new)
        if pos == -1:
            return None
        while pos != -1:
            located = True
            first = text.count("\n", 0, pos) + 1
            lines.update(range(first, first + new.count("\n") + 1))
            pos = text.find(new, pos + max(1, len(new)))
    return lines if located else set()


def run_claude_hook(stdin_text):
    """Lint the file Claude just edited. Print hook JSON on findings. Never block."""
    try:
        event = json.loads(stdin_text or "{}")
    except ValueError:
        return 0
    if not isinstance(event, dict):
        return 0
    tool_input = event.get("tool_input") or {}
    tool_response = event.get("tool_response") or {}
    path = tool_input.get("file_path") if isinstance(tool_input, dict) else None
    if not path and isinstance(tool_response, dict):
        path = tool_response.get("filePath")
    if not isinstance(path, str) or not path.lower().endswith(".swift"):
        return 0
    cwd = event.get("cwd") if isinstance(event.get("cwd"), str) else None
    if not os.path.isabs(path) and cwd:
        path = os.path.join(cwd, path)
    if not os.path.isfile(path):
        return 0
    with open(path, "rb") as fh:
        text = fh.read().decode("utf-8", errors="replace").replace("\r\n", "\n")
    findings = lint_source(text, path, "swift")
    if not findings:
        return 0
    changed = _changed_lines(event.get("tool_name"), tool_input, text)
    if changed is None:
        shown, others = findings, []
    else:
        shown = [f for f in findings if f.line in changed]
        others = [f for f in findings if f.line not in changed]
    if not shown:
        return 0
    rel = display_path(path, cwd)
    extra = shown[HOOK_MAX_FINDINGS:]
    shown = shown[:HOOK_MAX_FINDINGS]
    where = "in the lines you just changed in" if changed is not None else "in"
    out = ["duo-lint (Duology) found %d iPhone Duo %s %s %s:" % (
        len(shown) + len(extra), "issue" if len(shown) + len(extra) == 1 else "issues",
        where, rel)]
    out.append(format_text(shown, 1, verbose=True, base=cwd).rsplit("\n", 1)[0])
    if extra or others:
        # Print the full path: the Bash tool's PATH may not have duo-lint on it.
        launcher = os.path.join(os.path.dirname(os.path.realpath(__file__)), "duo-lint")
        out.append("%d more %s in this file. Run: \"%s\" %s" % (
            len(extra) + len(others),
            "finding" if len(extra) + len(others) == 1 else "findings",
            launcher, shlex.quote(rel)))
    out.append("This is advice; the edit went through. Fix the finding, or if the code is "
               "not layout, add // duo-lint:disable-next-line <RULE> -- <reason> above it.")
    errors = sum(1 for f in shown + extra if f.severity == ERROR)
    message = "duo-lint: %d iPhone Duo %s in %s (%d %s)" % (
        len(shown) + len(extra), "finding" if len(shown) + len(extra) == 1 else "findings",
        os.path.basename(path), errors, "error" if errors == 1 else "errors")
    sys.stdout.write(json.dumps({
        "systemMessage": message,
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "\n".join(out),
        },
    }) + "\n")
    return 0


# --------------------------------------------------------------------------
# Command line.

def _parse_ids(value):
    ids = {x.strip().upper() for x in re.split(r"[,\s]+", value or "") if x.strip()}
    unknown = sorted(i for i in ids if i not in RULES_BY_ID)
    if unknown:
        raise argparse.ArgumentTypeError("unknown rule id: %s" % ", ".join(unknown))
    return ids


def build_parser():
    p = argparse.ArgumentParser(
        prog="duo-lint",
        description="Find code that breaks on iPhone Duo: main-screen sizing, orientation "
                    "and idiom checks, regular width treated as iPad, hard-coded device "
                    "sizes, fixed widths and UIRequiresFullScreen.",
        epilog="Exit codes: 0 no errors, 1 errors found (or warnings with --strict), "
               "2 bad arguments or missing path.")
    p.add_argument("paths", nargs="*", metavar="PATH",
                   help="files or folders to check (default: the current folder)")
    p.add_argument("--format", choices=("text", "json", "github"), default="text",
                   help="output format (default: text)")
    p.add_argument("--json", action="store_true", help="same as --format json")
    p.add_argument("--strict", action="store_true", help="exit 1 on warnings too")
    p.add_argument("--objc", action="store_true",
                   help="also check .m, .mm and .h files in folders")
    p.add_argument("--select", type=_parse_ids, metavar="IDS",
                   help="only run these rules, for example DUO001,DUO004")
    p.add_argument("--ignore", type=_parse_ids, metavar="IDS", help="skip these rules")
    p.add_argument("--exclude", action="append", default=[], metavar="GLOB",
                   help="skip paths that match GLOB; repeat for more")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="print the fix and the Apple source under each finding")
    p.add_argument("--list-rules", action="store_true", help="print the rules and exit")
    p.add_argument("--claude-hook", action="store_true",
                   help="read a Claude Code PostToolUse event on stdin (used by the hook)")
    p.add_argument("--version", action="version", version="duo-lint %s" % VERSION)
    return p


def main(argv=None):
    try:
        sys.stdout.reconfigure(errors="replace")
    except Exception:
        pass
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.claude_hook:
        try:
            return run_claude_hook(sys.stdin.read())
        except Exception:
            return 0

    fmt = "json" if args.json else args.format

    if args.list_rules:
        if fmt == "json":
            print(json.dumps([r.as_dict() for r in RULES], indent=2))
        else:
            for r in RULES:
                print("%s  %-7s  %-34s %s" % (r.id, r.severity, r.name, r.message))
        return 0

    rules = set(RULES_BY_ID)
    if args.select:
        rules &= args.select
    if args.ignore:
        rules -= args.ignore

    paths = args.paths or ["."]
    try:
        findings, files = lint_paths(paths, objc=args.objc, excludes=args.exclude, rules=rules)
    except FileNotFoundError as exc:
        sys.stderr.write("duo-lint: no such file or folder: %s\n" % exc.args[0])
        return 2

    findings.sort(key=lambda f: (display_path(f.path), f.line, f.column, f.rule.id))
    if fmt == "json":
        print(format_json(findings, files))
    elif fmt == "github":
        print(format_github(findings, files))
    else:
        print(format_text(findings, files, verbose=args.verbose))

    errors = sum(1 for f in findings if f.severity == ERROR)
    if errors or (args.strict and findings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
