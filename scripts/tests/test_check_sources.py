#!/usr/bin/env python3
"""Tests for scripts/check-sources.py. They use a local HTTP server, never the internet.

Run: python3 -m unittest discover -s scripts/tests -v"""

import contextlib
import http.server
import importlib.util
import io
import os
import shutil
import tempfile
import threading
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)

_spec = importlib.util.spec_from_file_location("check_sources", os.path.join(SCRIPTS, "check-sources.py"))
cs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cs)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _reply(self, code, location=None, body=b"ok"):
        self.send_response(code)
        if location:
            self.send_header("Location", location)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command == "GET":
            self.wfile.write(body)

    def do_HEAD(self):
        self.route()

    def do_GET(self):
        self.route()

    def route(self):
        path = self.path
        if path == "/ok":
            self._reply(200)
        elif path == "/missing":
            self._reply(404)
        elif path == "/forbidden":
            self._reply(403)
        elif path == "/moved":
            self._reply(301, "/ok")
        elif path == "/no-head":
            self._reply(405 if self.command == "HEAD" else 200)
        elif path == "/head-lies":
            self._reply(200 if self.command == "HEAD" else 500)
        elif path == "/human":
            self._reply(302, "/forums/verify-human/verify.html?next=/x")
        elif path.startswith("/forums/verify-human/"):
            self._reply(200)
        elif path == "/videos/play/x/1/":
            self._reply(200)
        elif path == "/videos/play/x/999999/":
            # How developer.apple.com answers an unknown video ID.
            self._reply(302, "/videos/x")
        elif path == "/videos/x":
            self._reply(301, "/videos/x/")
        elif path == "/videos/x/":
            self._reply(200)
        elif path == "/docs/a/gone":
            self._reply(302, "/docs/a/")
        elif path == "/docs/a/":
            self._reply(200)
        elif path == "/docs/old/page":
            self._reply(301, "/docs/new/page")
        elif path == "/docs/new/page":
            self._reply(200)
        else:
            self._reply(404)


class ServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.base = "http://127.0.0.1:%d" % cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def check(self, path, method="head"):
        return cs.Fetcher(timeout=5, retries=0, per_host=2, method=method).check(self.base + path)

    def test_ok(self):
        self.assertEqual(self.check("/ok").kind, "ok")

    def test_missing_is_broken(self):
        result = self.check("/missing")
        self.assertEqual((result.kind, result.status), ("broken", 404))

    def test_forbidden_is_blocked(self):
        self.assertEqual(self.check("/forbidden").kind, "blocked")

    def test_redirect_is_followed(self):
        result = self.check("/moved")
        self.assertEqual(result.kind, "ok")
        self.assertTrue(result.final_url.endswith("/ok"))
        self.assertIn("now at", result.describe())

    def test_get_fallback_when_head_refused(self):
        self.assertEqual(self.check("/no-head").kind, "ok")

    def test_get_method_catches_lying_head(self):
        self.assertEqual(self.check("/head-lies").kind, "ok")
        self.assertEqual(self.check("/head-lies", method="get").kind, "broken")

    def test_human_check_is_blocked(self):
        result = self.check("/human")
        self.assertEqual(result.kind, "blocked")
        self.assertIn("human check", result.describe())

    def test_unknown_video_id_redirected_to_index_is_broken(self):
        self.assertEqual(self.check("/videos/play/x/1/").kind, "ok")
        for method in ("head", "get"):
            with self.subTest(method=method):
                result = self.check("/videos/play/x/999999/", method=method)
                self.assertEqual((result.kind, result.status), ("broken", 200))
                self.assertTrue(result.final_url.endswith("/videos/x/"))
                self.assertIn("page is gone", result.describe())

    def test_redirect_up_to_parent_is_broken(self):
        self.assertEqual(self.check("/docs/a/gone").kind, "broken")
        self.assertEqual(self.check("/docs/old/page").kind, "ok")

    def test_redirected_away(self):
        away = cs.redirected_away
        apple = "https://developer.apple.com"
        self.assertTrue(away(apple + "/videos/play/tech-talks/999999/", apple + "/videos/tech-talks/"))
        self.assertTrue(away(apple + "/videos/play/wwdc2026/99999/", apple + "/videos/wwdc2026/"))
        self.assertTrue(away(apple + "/documentation/swiftui/gone", apple + "/"))
        self.assertFalse(away(apple + "/videos/play/tech-talks/111461/?time=166",
                              apple + "/videos/play/tech-talks/111461/?time=166"))
        self.assertFalse(away(apple + "/videos/wwdc2025", apple + "/videos/wwdc2025/"))
        self.assertFalse(away("http://apple.com/iphone-duo/specs", "https://www.apple.com/iphone-duo/specs/"))
        self.assertFalse(away(apple + "/design/human-interface-guidelines/foundations/layout",
                              apple + "/design/human-interface-guidelines/layout"))
        self.assertFalse(away("https://learn.microsoft.com/dual-screen/intro",
                              "https://learn.microsoft.com/en-us/dual-screen/intro"))
        self.assertFalse(away("https://apple.co/x", "https://www.apple.com/"))
        self.assertFalse(away(apple + "/x/y", None))

    def test_login_only_github_pages_are_blocked(self):
        fetcher = cs.Fetcher(timeout=5, retries=0, per_host=1)
        fetcher._request = lambda url, method: (404, url, None)
        result = fetcher.check("https://github.com/Kimeur/duology/stargazers")
        self.assertEqual(result.kind, "blocked")
        self.assertIn("logged out", result.describe())
        self.assertEqual(fetcher.check("https://github.com/Kimeur/duology/nope").kind, "broken")

    def test_connection_refused_is_broken(self):
        result = cs.Fetcher(timeout=2, retries=0, per_host=1).check("http://127.0.0.1:9/")
        self.assertEqual(result.kind, "broken")
        self.assertIsNotNone(result.error)


class ExtractTests(unittest.TestCase):
    def test_extract(self):
        text = "\n".join([
            "| A1 | https://www.apple.com/iphone-duo/specs/ | x |",
            "[doc](https://developer.apple.com/documentation/uikit/x/supportedinterfaceorientations(for:)).",
            "Swap `https://developer.apple.com/documentation/<path>` for JSON.",
            "<!-- https://trendshift.io/repositories/ID -->",
            "```bash",
            "curl https://example.org/in-code",
            "```",
            '<img src="https://img.shields.io/x?a=1&amp;b=2" />',
            "(see https://learn.microsoft.com/en-us/previous-versions/dual-screen/introduction)",
            "<https://github.com/Kimeur/duology>",
        ])
        urls = [u for _, u in cs.extract_urls(text)]
        self.assertEqual(urls, [
            "https://www.apple.com/iphone-duo/specs/",
            "https://developer.apple.com/documentation/uikit/x/supportedinterfaceorientations(for:)",
            "https://developer.apple.com/documentation/<",
            "https://img.shields.io/x?a=1&b=2",
            "https://learn.microsoft.com/en-us/previous-versions/dual-screen/introduction",
            "https://github.com/Kimeur/duology",
        ])

    def test_placeholders(self):
        for url in ("https://example.com/x", "http://localhost:8080", "https://developer.apple.com/documentation/<",
                    "https://a.test/", "https://x/{id}"):
            self.assertTrue(cs.is_placeholder(url), url)
        self.assertFalse(cs.is_placeholder("https://developer.apple.com/iphone-duo/"))

    def test_ascii_url(self):
        self.assertEqual(cs.ascii_url("https://img.shields.io/badge/a_·_b-1?x=é"),
                         "https://img.shields.io/badge/a_%C2%B7_b-1?x=%C3%A9")
        plain = "https://developer.apple.com/documentation/x/y(for:)"
        self.assertEqual(cs.ascii_url(plain), plain)


class LocalLinkTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="check-sources-")
        os.makedirs(os.path.join(self.root, "reference"))
        with open(os.path.join(self.root, "reference", "sources.md"), "w") as fh:
            fh.write("# Sources\n"
                     "- https://github.com/Kimeur/duology/blob/main/reference/sources.md\n"
                     "- https://github.com/Kimeur/duology/blob/main/reference/missing.md\n"
                     "- https://raw.githubusercontent.com/Kimeur/duology/main/reference/sources.md\n")

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def run_main(self, *args, env=None):
        out = io.StringIO()
        with mock.patch.dict(os.environ, env or {}, clear=False), contextlib.redirect_stdout(out), \
                contextlib.redirect_stderr(io.StringIO()):
            code = cs.main(["--root", self.root] + list(args))
        return code, out.getvalue()

    def test_local_target(self):
        target = cs.local_target("https://github.com/Kimeur/duology/blob/main/reference/x.md#a",
                                 "Kimeur/duology", self.root)
        self.assertEqual(target, os.path.join(self.root, "reference", "x.md"))
        self.assertIsNone(cs.local_target("https://github.com/other/repo/blob/main/x.md",
                                          "Kimeur/duology", self.root))
        self.assertIsNone(cs.local_target("https://github.com/Kimeur/duology/stargazers",
                                          "Kimeur/duology", self.root))

    def test_offline_still_checks_local_links(self):
        code, out = self.run_main("--offline")
        self.assertEqual(code, 1)
        self.assertIn("reference/missing.md is not in this checkout", out)
        self.assertIn("2 ok", out)

    def test_env_offline(self):
        code, out = self.run_main(env={"DUOLOGY_OFFLINE": "1"})
        self.assertIn("missing.md", out)

    def test_warn_only(self):
        code, _ = self.run_main("--offline", "--warn-only")
        self.assertEqual(code, 0)

    def test_list_needs_no_network(self):
        code, out = self.run_main("--list")
        self.assertEqual(code, 0)
        self.assertIn("3 URLs in 1 file", out)

    def test_bad_arguments(self):
        self.assertEqual(self.run_main("--timeout", "0")[0], 2)
        self.assertEqual(self.run_main("--skip", "(")[0], 2)
        self.assertEqual(self.run_main(os.path.join(self.root, "nope.md"))[0], 2)

    def test_skip_if_offline(self):
        with mock.patch.object(cs, "network_available", return_value=False):
            code, out = self.run_main("--skip-if-offline", "--repo", "")
        self.assertEqual(code, 0)
        self.assertIn("not checked (no network", out)


if __name__ == "__main__":
    unittest.main()
