#!/usr/bin/env python3
"""Checks that SwiftUI `body` properties do no heavy work: nothing a fold must redo.

usage: body_work.py [--root ROOT] PATTERN...

A fold reruns `body` for every view that reads the size, once per resize step.
This check fails when a PATTERN (a regular expression, for example
'DateFormatter\\(' or '\\.sorted\\b') matches inside the body of a View, a
ViewModifier or a Layout-free container: `var body: some View { ... }` and
`func body(content: Content) -> some View { ... }`. Work done once, in a model,
an initializer or a task, passes. So does the same call outside any body.

Comments and string literals are blanked first, and so are #Preview blocks and
PreviewProvider types. Test code is skipped: any folder whose name contains
Tests, and files ending in Tests.swift.

It is a heuristic for Swift sources, not a parser. It prints each match.
Tests: python3 evals/lib/checks/test_body_work.py
Exit 0 = pass, 1 = fail, 2 = usage error.
"""
import os
import re
import sys

SKIP_DIRS = {".git", "DerivedData", "build", ".build", "Pods", "Carthage", "SourcePackages"}
BODY = re.compile(r"\bvar\s+body\s*:\s*some\s+View\s*\{|\bfunc\s+body\s*\(\s*content\s*:[^)]*\)\s*->\s*some\s+View\s*\{")
PREVIEW = re.compile(r"#Preview\b[^{]*\{|\bstruct\s+\w+\s*:\s*PreviewProvider\s*\{")


def blank(text, start, end):
    return text[:start] + re.sub(r"[^\n]", " ", text[start:end]) + text[end:]


def mask(text):
    """Blanks comments and string literals; keeps line breaks, so line numbers stay."""
    out, i, n = list(text), 0, len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
        elif text.startswith('"""', i):
            j = text.find('"""', i + 3)
            j = n if j < 0 else j + 3
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] not in '"\n':
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n)
        else:
            i += 1
            continue
        out[i:j] = [c if c == "\n" else " " for c in out[i:j]]
        i = j
    return "".join(out)


def closing(text, i):
    """Index of the brace that closes the one at text[i]."""
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return j
    return len(text) - 1


def without_previews(text):
    for m in reversed(list(PREVIEW.finditer(text))):
        text = blank(text, m.start(), closing(text, m.end() - 1) + 1)
    return text


def bodies(text):
    """(start, end) of each body block in masked text."""
    spans = []
    for m in BODY.finditer(text):
        open_brace = m.end() - 1
        spans.append((open_brace, closing(text, open_brace)))
    return spans


def matches(path, text, patterns):
    """[(path, line, pattern, code)] for every pattern match inside a body."""
    clean = without_previews(mask(text))
    found = []
    for start, end in bodies(clean):
        block = clean[start:end]
        for pattern in patterns:
            for m in re.finditer(pattern, block):
                at = start + m.start()
                line = clean.count("\n", 0, at) + 1
                code = text.splitlines()[line - 1].strip() if line <= len(text.splitlines()) else ""
                found.append((path, line, pattern, code))
    return sorted(set(found))


def swift_files(root):
    for folder, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and "Tests" not in d
                         and not d.endswith((".xcresult", ".app")))
        for name in sorted(names):
            if name.endswith(".swift") and not name.endswith("Tests.swift"):
                yield os.path.join(folder, name)


def main(argv):
    args = list(argv)
    root = "."
    if args[:1] == ["--root"]:
        if len(args) < 2:
            print("usage: body_work.py [--root ROOT] PATTERN...")
            return 2
        root, args = args[1], args[2:]
    if not args:
        print("usage: body_work.py [--root ROOT] PATTERN...")
        return 2
    try:
        patterns = [re.compile(p) and p for p in args]
    except re.error as exc:
        print("bad pattern: %s" % exc)
        return 2
    found, bodies_seen = [], 0
    for path in swift_files(root):
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        bodies_seen += len(bodies(without_previews(mask(text))))
        found += matches(os.path.relpath(path, root), text, patterns)
    if not found:
        print("pass: none of %d pattern(s) in %d body block(s)" % (len(patterns), bodies_seen))
        return 0
    print("FAIL: work a fold would redo, inside body:")
    for path, line, pattern, code in found:
        print("  %s:%d  %s   (%s)" % (path, line, code, pattern))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
