#!/usr/bin/env python3
"""Checks that a piece of state lives in one place that a fold can't rebuild.

usage: single_owner.py PATTERN [ROOT]

PATTERN is a regular expression, matched line by line, for the line that creates the state, for example
'AVPlayer\\(' or '@State[^=]*\\bquery\\b'. The check walks up from each match:

1. The type that holds the match is its owner. Every match must have the same owner.
   Lines that only point at state owned elsewhere (@Binding, @Bindable, @Environment,
   @EnvironmentObject, @ObservedObject) are skipped, and so are plain properties of a
   View struct (values passed in by the parent). A plain property of a View struct that
   creates an object (let player = AVPlayer(...)) fails: SwiftUI makes a new view value
   on every update. A static property or a file-scope declaration owns its state for
   the life of the app.
2. A class or actor owner is fine if whoever creates that class passes the same test.
3. A struct owner must be created in exactly one place. A creation inside a static
   factory (static func make() -> Model { Model() }) counts where the factory is called.
4. A creation site in a @State, @StateObject or static property is stable for as long
   as the type that holds it lives: the check moves on to that type. Any other creation
   site must not sit in a type that switches layout with if/switch/guard on size class,
   width, height, orientation or idiom, ViewThatFits, or an .id() tied to layout. Then
   repeat for the type that creates it, up to the App.

Test code is skipped: any folder whose name contains Tests, and files ending in Tests.swift.
It is a heuristic for Swift sources, not a parser. It prints why it fails.
Tests: python3 evals/lib/checks/test_single_owner.py
Exit 0 = pass, 1 = fail, 2 = usage error.
"""
import os
import re
import sys

SKIP_DIRS = {".git", "DerivedData", "build", ".build", "Pods", "Carthage", "SourcePackages"}
DECL = re.compile(r"\b(struct|class|enum|actor|extension)\s+([A-Za-z_][A-Za-z0-9_]*)")
LAYOUT_SWITCH = re.compile(
    r"\b(if|switch|guard)\b[^{\n]*(sizeClass|SizeClass|isPad|isIPad|isiPad|isPhone|isWide|isNarrow|"
    r"isRegular|isCompact|isLandscape|isPortrait|orientation|Idiom|idiom|\.width|\.height|width\s*[<>=]|"
    r"height\s*[<>=])"
    r"|ViewThatFits"
    r"|\.id\([^)]*(sizeClass|SizeClass|isPad|isWide|isRegular|isCompact|width|height|orientation)")
# Lines that point at state owned somewhere else.
NOT_OWNER = re.compile(r"@(Binding|Bindable|Environment|EnvironmentObject|ObservedObject)\b")
# A stored or computed property declaration, with any modifiers.
PROP_DECL = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:private|fileprivate|internal|public|package|"
                       r"nonisolated|static|class|lazy|final|weak|unowned)(?:\([^)]*\))?\s+)*(?:var|let)\s+\w+")
WRAPPER = re.compile(r"@\w+")
CREATES_OBJECT = re.compile(r"=\s*[A-Z][A-Za-z0-9_.]*\s*\(")
# A creation site that lives as long as the type that holds it.
STABLE_SITE = re.compile(r"@(State|StateObject)\b|\bstatic\s+(let|var)\b")
FILE_SCOPE = "(file scope or static)"


def swift_files(root):
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS and not x.endswith((".xcresult", ".app")))
        for f in sorted(files):
            if f.endswith(".swift"):
                path = os.path.join(d, f)
                folders = os.path.relpath(path, root).split(os.sep)[:-1]
                if any("Tests" in x for x in folders) or f.endswith("Tests.swift"):
                    continue
                yield path


def strip_comments(text):
    """Blanks out comments and string contents but keeps offsets and line breaks."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"' and text[j] != "\n":
                if text[j] == "\\" and j + 1 < n and text[j + 1] == "(":
                    # keep interpolations: skip to the matching parenthesis
                    depth, j = 1, j + 2
                    while j < n and depth:
                        depth += {"(": 1, ")": -1}.get(text[j], 0)
                        j += 1
                    continue
                j += 2 if text[j] == "\\" else 1
            for k in range(i + 1, min(j, n)):
                out[k] = " "
            i = j + 1
        else:
            i += 1
    return "".join(out)


class TypeSpan:
    def __init__(self, kind, name, path, start, end, header):
        self.kind, self.name, self.path, self.start, self.end, self.header = kind, name, path, start, end, header

    def __repr__(self):
        return "%s %s (%s)" % (self.kind, self.name, os.path.basename(self.path))


def index(root):
    files = {}
    spans = []
    for path in swift_files(root):
        with open(path, encoding="utf-8", errors="replace") as f:
            text = strip_comments(f.read())
        files[path] = text
        for m in DECL.finditer(text):
            if m.group(2) in ("func", "var", "let", "init", "subscript", "protocol"):
                continue
            brace = text.find("{", m.end())
            if brace < 0:
                continue
            between = text[m.end():brace]
            if "\n\n" in between or ";" in between or "=" in between:
                continue
            j = closing_brace(text, brace)
            spans.append(TypeSpan(m.group(1), m.group(2), path, brace, j, text[m.start():brace]))
    return files, spans


def closing_brace(text, brace):
    depth, j = 0, brace
    while j < len(text):
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    return j


def owner_at(spans, path, offset):
    best = None
    for s in spans:
        if s.path == path and s.start <= offset <= s.end:
            if best is None or s.start > best.start:
                best = s
    return best


def kind_of(spans, name):
    kinds = {s.kind for s in spans if s.name == name and s.kind != "extension"}
    if not kinds:
        return None
    return sorted(kinds)[0]


def is_view(span):
    return bool(re.search(r":\s*[^{]*\bView\b", span.header))


def line_at(text, offset):
    start = text.rfind("\n", 0, offset) + 1
    end = text.find("\n", offset)
    return text[start:] if end < 0 else text[start:end]


def is_app(spans, name):
    for s in spans:
        if s.name == name and re.search(r":\s*[^{]*\bApp\b", s.header):
            return True
    return False


def in_preview(text, offset):
    before = text[:offset]
    p = max(before.rfind("#Preview"), before.rfind("PreviewProvider"))
    if p < 0:
        return False
    return before.count("{", p) > before.count("}", p)


def creation_sites(files, spans, name):
    pat = re.compile(r"(?<![A-Za-z0-9_.])" + re.escape(name) + r"\s*(\(|\{|\.init\b)")
    sites = []
    for path, text in files.items():
        for m in pat.finditer(text):
            line_start = text.rfind("\n", 0, m.start()) + 1
            prefix = text[line_start:m.start()]
            if re.search(r"\b(struct|class|enum|actor|extension|func|typealias)\s*$", prefix):
                continue
            if re.search(r"\b(let|var)\s+\w+\s*:\s*$", prefix):
                continue  # a type annotation, not a call
            if re.search(r"->\s*$", prefix):
                continue  # a return type, not a call
            if in_preview(text, m.start()):
                continue
            owner = owner_at(spans, path, m.start())
            if owner is not None and owner.name == name:
                continue  # recursion inside the type itself
            sites.append((path, m.start(), owner))
    return sites


def static_factory(text, holder, offset):
    """The name of the static func of HOLDER that contains OFFSET, if any."""
    name = None
    for m in re.finditer(r"\b(?:static|class)\s+func\s+(\w+)", text[:offset]):
        if m.start() < holder.start:
            continue
        brace = text.find("{", m.end())
        if 0 <= brace < offset and offset <= closing_brace(text, brace):
            name = m.group(1)
    return name


def factory_calls(files, spans, holder, func):
    """Where Holder.func( is called: those calls are the real creation sites."""
    pat = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(holder) + r"\." + re.escape(func) + r"\s*\(")
    calls = []
    for path, text in files.items():
        for m in pat.finditer(text):
            if not in_preview(text, m.start()):
                calls.append((path, m.start(), owner_at(spans, path, m.start())))
    return calls


def line_no(text, offset):
    return text.count("\n", 0, offset) + 1


def check_chain(files, spans, name, root, seen, depth=0):
    """Returns None when NAME is created stably, else a reason."""
    if depth > 8 or name in seen:
        return None
    seen = seen | {name}
    if is_app(spans, name):
        return None
    sites = creation_sites(files, spans, name)
    kind = kind_of(spans, name)
    if kind in ("class", "actor"):
        if not sites:
            return None
        if len(sites) > 1:
            where = ", ".join("%s:%d" % (os.path.relpath(p, root), line_no(files[p], o)) for p, o, _ in sites)
            return "%s %s is created in %d places (%s)" % (kind, name, len(sites), where)
    else:
        if not sites:
            return "%s is never created in the sources, so its state can't be traced" % name
        if len(sites) > 1:
            where = ", ".join("%s:%d" % (os.path.relpath(p, root), line_no(files[p], o)) for p, o, _ in sites)
            return ("%s is created in %d places (%s); each copy has its own state, so a fold that "
                    "swaps them resets it" % (name, len(sites), where))
    path, offset, holder = sites[0]
    if holder is None:
        return None
    func = static_factory(files[path], holder, offset)
    if func:
        calls = factory_calls(files, spans, holder.name, func)
        where = ", ".join("%s:%d" % (os.path.relpath(p, root), line_no(files[p], o)) for p, o, _ in calls)
        if not calls:
            return "%s is made by %s.%s(), which nothing calls, so its state can't be traced" % (
                name, holder.name, func)
        if len(calls) > 1:
            return ("%s is made by %s.%s(), which is called in %d places (%s); each call makes a new copy, "
                    "so a fold that swaps them resets it" % (name, holder.name, func, len(calls), where))
        path, offset, holder = calls[0]
        if holder is None:
            return None
    site_line = line_at(files[path], offset)
    if STABLE_SITE.search(site_line):
        if re.search(r"\bstatic\s+(let|var)\b", site_line):
            return None  # lives as long as the app
        # @State / @StateObject: created once per identity of the holder.
        return check_chain(files, spans, holder.name, root, seen, depth + 1)
    body = files[holder.path][holder.start:holder.end]
    m = LAYOUT_SWITCH.search(body)
    if m and holder.kind != "class":
        return ("%s is created inside %s, which switches layout (%s at %s:%d), so the fold can "
                "rebuild it" % (name, holder.name, m.group(0).strip()[:40], os.path.relpath(holder.path, root),
                                line_no(files[holder.path], holder.start + m.start())))
    return check_chain(files, spans, holder.name, root, seen, depth + 1)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    pattern = re.compile(argv[1])
    root = argv[2] if len(argv) > 2 else "."
    files, spans = index(root)
    owners = {}
    problems = []
    for path, text in files.items():
        offset = 0
        for line in text.split("\n"):
            m = pattern.search(line)
            start = offset
            offset += len(line) + 1
            if not m:
                continue
            where = "%s:%d" % (os.path.relpath(path, root), line_no(text, start))
            if NOT_OWNER.search(line):
                continue  # points at state owned elsewhere
            o = owner_at(spans, path, start + m.start())
            if o is None or re.search(r"\bstatic\s+(let|var)\b", line):
                owners.setdefault(FILE_SCOPE, []).append(where)
                continue
            if o.kind == "struct" and is_view(o) and PROP_DECL.match(line) and not WRAPPER.search(line):
                if CREATES_OBJECT.search(line):
                    problems.append("%s creates it in a plain property of the view %s; SwiftUI makes a new "
                                    "view value on every update, so keep it in @State or a model" % (where, o.name))
                continue  # a value passed in by the parent, not an owner
            owners.setdefault(o.name, []).append(where)
    if problems:
        print("FAIL: " + "; ".join(problems))
        return 1
    if not owners:
        print("FAIL: nothing matches %s" % argv[1])
        return 1
    if len(owners) > 1:
        print("FAIL: the state is declared in %d types: %s" % (
            len(owners), "; ".join("%s at %s" % (k, ", ".join(v)) for k, v in sorted(owners.items()))))
        return 1
    name = next(iter(owners))
    if name == FILE_SCOPE:
        print("ok: a static or file-scope declaration owns it (%s)" % ", ".join(owners[name]))
        return 0
    reason = check_chain(files, spans, name, root, set())
    if reason:
        print("FAIL: " + reason)
        return 1
    print("ok: %s owns it (%s) and is created once, above any layout switch" % (name, ", ".join(owners[name])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
