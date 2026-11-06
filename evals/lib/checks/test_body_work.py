#!/usr/bin/env python3
"""Tests for body_work.py: work moved out of body must pass, work left in it must fail.

usage: python3 evals/lib/checks/test_body_work.py
"""
import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import body_work  # noqa: E402

HEAVY = [r"DateFormatter\(", r"NumberFormatter\(", r"\.sorted\b", r"Dictionary\(grouping", r"\.reduce\("]


def run(files):
    root = tempfile.mkdtemp()
    for name, text in files.items():
        path = os.path.join(root, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
    out = io.StringIO()
    with redirect_stdout(out):
        code = body_work.main(["--root", root] + HEAVY)
    return code, out.getvalue()


class BodyWork(unittest.TestCase):
    def test_sort_in_body_fails(self):
        code, out = run({"A.swift": """
struct Screen: View {
    let items: [Item]
    var body: some View {
        let shown = items.sorted { $0.date > $1.date }
        List(shown) { Text($0.title) }
    }
}
"""})
        self.assertEqual(code, 1)
        self.assertIn("A.swift:5", out)

    def test_formatter_in_a_nested_closure_of_body_fails(self):
        code, _ = run({"A.swift": """
struct Row: View {
    var body: some View {
        GeometryReader { proxy in
            let f = DateFormatter()
            Text(f.string(from: .now))
        }
    }
}
"""})
        self.assertEqual(code, 1)

    def test_view_modifier_body_counts(self):
        code, _ = run({"A.swift": """
struct Total: ViewModifier {
    let values: [Decimal]
    func body(content: Content) -> some View {
        content.overlay { Text(values.reduce(0, +), format: .number) }
    }
}
"""})
        self.assertEqual(code, 1)

    def test_work_in_a_model_passes(self):
        code, out = run({"A.swift": """
@Observable final class Model {
    private(set) var rows: [Row] = []
    func set(_ items: [Item]) {
        let f = DateFormatter()
        rows = items.sorted { $0.date > $1.date }.map { Row($0, f) }
    }
}
struct Screen: View {
    let model: Model
    var body: some View {
        List(model.rows) { Text($0.title) }
    }
    var total: Decimal { model.rows.reduce(0) { $0 + $1.amount } }
}
"""})
        self.assertEqual(code, 0, out)

    def test_comments_strings_and_previews_are_ignored(self):
        code, out = run({"A.swift": """
struct Screen: View {
    var body: some View {
        // not .sorted here: it moved to the model
        Text("call .sorted { } once, not in body")
    }
}
#Preview {
    Screen().onAppear { _ = [3, 1].sorted() }
}
"""})
        self.assertEqual(code, 0, out)

    def test_tests_are_skipped(self):
        code, _ = run({"AppTests/ATests.swift": """
struct Fake: View {
    var body: some View { Text([2, 1].sorted().description) }
}
"""})
        self.assertEqual(code, 0)

    def test_count_leaves_out_previews_comments_and_strings(self):
        root = tempfile.mkdtemp()
        with open(os.path.join(root, "A.swift"), "w") as fh:
            fh.write("""
struct Screen: View {
    var body: some View {
        EntryList(rows: rows)   // not EntryList( again
        Text("EntryList(")
    }
}
#Preview { EntryList(rows: []) }
""")
        out = io.StringIO()
        with redirect_stdout(out):
            code = body_work.main(["--root", root, "--count", r"(^|[^A-Za-z0-9_.])EntryList *\("])
        self.assertEqual((code, out.getvalue().strip()), (0, "1"))

    def test_a_sorted_property_is_not_a_sort(self):
        code, out = run({"A.swift": """
struct Screen: View {
    let model: Model
    var body: some View {
        List(model.sorted) { Text($0.title) }
    }
}
"""})
        self.assertEqual(code, 1)   # \.sorted\b still matches a property read
        root = tempfile.mkdtemp()
        with open(os.path.join(root, "A.swift"), "w") as fh:
            fh.write("struct S: View {\n  var body: some View { List(model.sorted) { Text($0) } }\n}\n")
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(body_work.main(["--root", root, r"\.sorted *[({]"]), 0)

    def test_usage(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(body_work.main([]), 2)
            self.assertEqual(body_work.main(["--root"]), 2)
            self.assertEqual(body_work.main(["("]), 2)
            self.assertEqual(body_work.main(["--count"]), 2)


if __name__ == "__main__":
    unittest.main()
