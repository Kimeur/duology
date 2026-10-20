#!/usr/bin/env python3
"""Check that the web pages Duology cites still answer.

By default it reads reference/sources.md and every SKILL.md under plugins/,
finds each http(s) URL outside fenced code blocks and HTML comments, and asks
the server for it: a HEAD request first, then a GET when HEAD is refused.
A server can answer HEAD with 200 while GET fails, so --method get sends
only GET requests. The scheduled CI run uses it.

Each URL ends up in one of three groups:
- ok: the page answered with a status below 400, after redirects;
- blocked: the site asked for a login or a human check (401, 403, 429, or a
  redirect to a human-verification page). Reported as a warning, because a
  person can still open the page;
- broken: 404, 410, another 4xx or 5xx, a timeout, or a DNS or TLS failure.
  Also a redirect up to a parent page, or out of Apple's /videos/play/ pages:
  that is how a site answers a page that doesn't exist (an unknown WWDC or
  Tech Talk ID lands on the event index with HTTP 200). Reported as an error.

Placeholder URLs (example.com, localhost, anything with <...> or {...}) are skipped.
Links into this repo on GitHub (github.com/Kimeur/duology/blob/main/...) are
checked against the local checkout instead, so they pass before a push and
fail when a file is missing or renamed. That check also runs offline.

Usage:
  python3 scripts/check-sources.py                 # sources.md + every SKILL.md
  python3 scripts/check-sources.py --all           # also references/, reference/*.md, README and docs
  python3 scripts/check-sources.py --list          # print the URLs, no network
  python3 scripts/check-sources.py --offline       # no network (also DUOLOGY_OFFLINE=1)
  python3 scripts/check-sources.py --skip-if-offline  # skip when there is no network

Exit codes: 0 nothing broken, 1 broken links (unless --warn-only), 2 bad arguments.
"""

import argparse
import concurrent.futures
import glob
import html
import os
import re
import socket
import ssl
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

VERSION = "0.3.0"
USER_AGENT = "duology-check-sources/%s (+https://github.com/Kimeur/duology)" % VERSION

BLOCKED_STATUSES = {401, 403, 429, 999}
HEAD_FALLBACK_STATUSES = {400, 403, 404, 405, 406, 409, 410, 429, 500, 501, 502, 503}
RETRY_STATUSES = {429, 500, 502, 503, 504}
HUMAN_CHECK = re.compile(r"verify-human|captcha|/cdn-cgi/challenge|/challenge-platform/|are-you-a-robot", re.I)

# Pages that answer 404 to anyone who isn't logged in (checked 16 Oct 2026 on
# several public repos). Treated as blocked, not broken.
LOGIN_ONLY = re.compile(r"^https://github\.com/[^/]+/[^/]+/(?:stargazers|watchers)/?$", re.I)

# Detail pages whose missing IDs redirect to an index instead of answering 404.
# developer.apple.com/videos/play/tech-talks/999999/ ends at /videos/tech-talks/
# with HTTP 200 (checked 17 Oct 2026). Matched on the path, so tests can use a
# local server.
DETAIL_PREFIXES = ("/videos/play/",)

PLACEHOLDER_HOSTS = re.compile(
    r"(^|\.)(example\.(com|org|net)|localhost|invalid|test|local)$|^127\.0\.0\.1$|^0\.0\.0\.0$|^\[::1\]$", re.I)

_FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
_URL_START = re.compile(r"https?://", re.I)
_TRAILING = ".,;:!?*_~'\""


# --------------------------------------------------------------------------
# Finding URLs
# --------------------------------------------------------------------------

def _scan_url(line, start):
    """Read one URL from line[start:], keeping balanced parentheses such as
    .../supportedinterfaceorientations(for:)."""
    k = start
    depth = 0
    while k < len(line):
        ch = line[k]
        if ch.isspace() or ch in "<>\"'`|\\":
            break
        if ch == "(":
            depth += 1
        elif ch == ")":
            if depth == 0:
                break
            depth -= 1
        elif ch in "[]":
            break
        k += 1
    url = line[start:k]
    if k < len(line) and line[k] == "<" and not line.startswith("<!--", k):
        # ".../documentation/<path>.json" is a pattern, not a page: keep the "<"
        # so is_placeholder() skips it.
        return url + "<"
    while url and url[-1] in _TRAILING:
        url = url[:-1]
    return html.unescape(url)


def extract_urls(text):
    """Return [(line number, url)] for URLs outside fenced code and HTML comments."""
    found = []
    fence = None
    in_comment = False
    for number, line in enumerate(text.split("\n"), start=1):
        m = _FENCE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and line.strip() == m.group(1):
                fence = None
            continue
        if m and not in_comment:
            fence = m.group(1)
            continue
        visible = ""
        rest = line
        while rest:
            if in_comment:
                end = rest.find("-->")
                if end < 0:
                    rest = ""
                    break
                rest = rest[end + 3:]
                in_comment = False
                continue
            start = rest.find("<!--")
            if start < 0:
                visible += rest
                break
            visible += rest[:start] + " "
            rest = rest[start + 4:]
            in_comment = True
        for m in _URL_START.finditer(visible):
            url = _scan_url(visible, m.start())
            if len(url) > len(m.group(0)):
                found.append((number, url))
    return found


def is_placeholder(url):
    if any(token in url for token in ("<", ">", "{", "}", "$", "...", "…")):
        return True
    try:
        host = urllib.parse.urlsplit(url).hostname or ""
    except ValueError:
        return True
    return not host or bool(PLACEHOLDER_HOSTS.search(host))


def default_files(root, include_all):
    files = []
    sources = os.path.join(root, "reference", "sources.md")
    if os.path.isfile(sources):
        files.append(sources)
    files.extend(sorted(glob.glob(os.path.join(root, "plugins", "*", "skills", "*", "SKILL.md"))))
    if include_all:
        patterns = [
            ("reference", "*.md"),
            ("plugins", "*", "skills", "*", "references", "**", "*.md"),
            ("docs", "**", "*.md"),
            ("*.md",),
            ("llms.txt",),
            (".github", "**", "*.md"),
            (".github", "**", "*.yml"),
        ]
        for parts in patterns:
            files.extend(sorted(glob.glob(os.path.join(root, *parts), recursive=True)))
    unique = []
    for f in files:
        f = os.path.abspath(f)
        if f not in unique and os.path.isfile(f):
            unique.append(f)
    return unique


def collect(files, root, skip_patterns):
    """Return ({url: [(relpath, line)]}, skipped count)."""
    urls = {}
    skipped = set()
    for path in files:
        try:
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            print("check-sources: can't read %s (%s)" % (path, exc), file=sys.stderr)
            continue
        rel = os.path.relpath(path, root)
        for line, url in extract_urls(text):
            if is_placeholder(url) or any(p.search(url) for p in skip_patterns):
                skipped.add(url)
                continue
            urls.setdefault(url, []).append((rel, line))
    return urls, len(skipped)


# --------------------------------------------------------------------------
# Checking URLs
# --------------------------------------------------------------------------

class Result:
    __slots__ = ("url", "status", "final_url", "error", "kind")

    def __init__(self, url, status=None, final_url=None, error=None):
        self.url = url
        self.status = status
        self.final_url = final_url or url
        self.error = error
        self.kind = classify(status, self.final_url, error, url)

    def describe(self):
        if self.error:
            return self.error
        text = "HTTP %d" % self.status
        if self.kind == "blocked" and HUMAN_CHECK.search(self.final_url or ""):
            text += ", human check at " + self.final_url
        elif self.kind == "broken" and self.status < 400:
            text += ", but the site redirected it to %s, so the page is gone or the link is wrong" % self.final_url
        elif self.final_url and self.final_url.rstrip("/") != self.url.rstrip("/"):
            text += ", now at " + self.final_url
        return text


def local_target(url, repo, root):
    """For a link into this repo on GitHub, return the local file it names, else None.

    github.com/<repo>/blob/<ref>/<path>, .../tree/<ref>/<path> and
    raw.githubusercontent.com/<repo>/<ref>/<path> are checked against this
    checkout, so new files don't fail before they are pushed."""
    if not repo:
        return None
    parts = urllib.parse.urlsplit(url)
    host = (parts.hostname or "").lower()
    path = urllib.parse.unquote(parts.path)
    owner_repo = "/" + repo.strip("/").lower() + "/"
    if not path.lower().startswith(owner_repo):
        return None
    rest = path[len(owner_repo):]
    if host == "github.com":
        segments = rest.split("/", 2)
        if len(segments) < 2 or segments[0] not in ("blob", "tree", "raw"):
            return None
        rel = segments[2] if len(segments) == 3 else ""
    elif host == "raw.githubusercontent.com":
        segments = rest.split("/", 1)
        if len(segments) < 2:
            return None
        rel = segments[1]
    else:
        return None
    return os.path.normpath(os.path.join(root, rel))


def check_local(url, target, root):
    """Check a link into this repo against the checkout, letter case included."""
    rel = os.path.relpath(target, root)
    if rel.startswith(".."):
        return Result(url, error="points outside the repository")
    cur = root
    for part in rel.split(os.sep):
        if part in ("", "."):
            continue
        try:
            entries = os.listdir(cur)
        except OSError:
            entries = []
        if part not in entries:
            return Result(url, error="%s is not in this checkout" % rel)
        cur = os.path.join(cur, part)
    return Result(url, status=200, final_url=url)


def _host_and_segments(url):
    parts = urllib.parse.urlsplit(url)
    host = (parts.hostname or "").lower()
    if host.startswith("www."):
        host = host[4:]
    path = urllib.parse.unquote(parts.path)
    return host, path, [s for s in path.lower().split("/") if s]


def redirected_away(url, final_url):
    """True when a redirect left the cited page for a page above it.

    Two shapes count: the final path is a parent of the original on the same
    host (/a/b/c -> /a/b/ or /), and a detail page such as /videos/play/<event>/<id>/
    that ends outside /videos/play/. Moves to a sibling or a new path, a
    trailing slash, and http -> https don't count."""
    if not url or not final_url or final_url == url:
        return False
    try:
        host, path, segments = _host_and_segments(url)
        final_host, final_path, final_segments = _host_and_segments(final_url)
    except ValueError:
        return False
    if host != final_host:
        return False
    for prefix in DETAIL_PREFIXES:
        if path.startswith(prefix) and not final_path.startswith(prefix):
            return True
    return len(final_segments) < len(segments) and segments[:len(final_segments)] == final_segments


def classify(status, final_url, error, url=None):
    if error is not None or status is None:
        return "broken"
    if status in BLOCKED_STATUSES or HUMAN_CHECK.search(final_url or ""):
        return "blocked"
    if status < 400:
        return "broken" if redirected_away(url, final_url) else "ok"
    return "broken"


class Fetcher:
    def __init__(self, timeout, retries, per_host, method="head"):
        self.method = method
        self.timeout = timeout
        self.retries = retries
        self.per_host = per_host
        self._locks = {}
        self._guard = threading.Lock()
        context = ssl.create_default_context()
        self.opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=context))

    def _host_slot(self, url):
        host = urllib.parse.urlsplit(url).hostname or ""
        with self._guard:
            if host not in self._locks:
                self._locks[host] = threading.BoundedSemaphore(self.per_host)
            return self._locks[host]

    def _request(self, url, method):
        try:
            url = ascii_url(url)
        except (UnicodeError, ValueError) as exc:
            return None, url, "can't encode this URL (%s)" % exc
        req = urllib.request.Request(url, method=method, headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
            "Accept-Language": "en",
        })
        try:
            with self.opener.open(req, timeout=self.timeout) as resp:
                if method == "GET":
                    resp.read(2048)
                return resp.status, resp.geturl(), None
        except urllib.error.HTTPError as exc:
            return exc.code, exc.geturl() or url, None
        except urllib.error.URLError as exc:
            reason = exc.reason
            if isinstance(reason, ssl.SSLCertVerificationError):
                return None, url, "TLS certificate check failed (%s)" % reason.verify_message
            if isinstance(reason, socket.gaierror):
                return None, url, "DNS lookup failed"
            if isinstance(reason, (socket.timeout, TimeoutError)):
                return None, url, "timed out after %gs" % self.timeout
            return None, url, "network error (%s)" % reason
        except (socket.timeout, TimeoutError):
            return None, url, "timed out after %gs" % self.timeout
        except (ConnectionError, OSError, ValueError) as exc:
            return None, url, "network error (%s)" % exc

    def check(self, url):
        slot = self._host_slot(url)
        with slot:
            result = None
            for attempt in range(self.retries + 1):
                if self.method == "get":
                    status, final, error = self._request(url, "GET")
                else:
                    status, final, error = self._request(url, "HEAD")
                    if error is not None or status in HEAD_FALLBACK_STATUSES:
                        status, final, error = self._request(url, "GET")
                result = Result(url, status, final, error)
                if status == 404 and LOGIN_ONLY.match(url):
                    result.kind = "blocked"
                    result.error = "HTTP 404 when logged out; GitHub shows this page only after login"
                retry = error is not None or status in RETRY_STATUSES
                if not retry or attempt == self.retries:
                    break
                time.sleep(1.5 * (attempt + 1))
            return result


def ascii_url(url):
    """Percent-encode non-ASCII characters (for example '·' in a badge URL) so
    urllib can send the request. Characters that are already valid stay as they are."""
    if all(ord(ch) < 128 for ch in url):
        return url
    parts = urllib.parse.urlsplit(url)
    host = parts.hostname.encode("idna").decode("ascii") if parts.hostname else ""
    netloc = host
    if parts.port:
        netloc += ":%d" % parts.port
    if parts.username:
        netloc = parts.username + "@" + netloc
    safe = "/%:@!$&'()*+,;=-._~"
    return urllib.parse.urlunsplit((
        parts.scheme, netloc,
        urllib.parse.quote(parts.path, safe=safe),
        urllib.parse.quote(parts.query, safe=safe + "?"),
        urllib.parse.quote(parts.fragment, safe=safe + "?")))


def network_available(host="developer.apple.com", timeout=5.0):
    try:
        socket.setdefaulttimeout(timeout)
        socket.getaddrinfo(host, 443)
        return True
    except OSError:
        return False
    finally:
        socket.setdefaulttimeout(None)


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def default_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def plural(n):
    return "" if n == 1 else "s"


def truthy(value):
    return (value or "").strip().lower() in ("1", "true", "yes", "on")


def annotate(severity, rel, line, message):
    def prop(v):
        return str(v).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A").replace(":", "%3A").replace(",", "%2C")

    def data(v):
        return str(v).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")

    return "::%s file=%s,line=%d,title=check-sources::%s" % (severity, prop(rel), line, data(message))


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="check-sources.py",
        description="Check that cited web pages still answer (HEAD, then GET).",
        epilog="Exit codes: 0 nothing broken, 1 broken links (unless --warn-only), 2 bad arguments. "
               "Set DUOLOGY_OFFLINE=1 to skip the check, for example in CI without network.")
    parser.add_argument("paths", nargs="*", metavar="PATH",
                        help="files or folders to read (default: reference/sources.md and every SKILL.md)")
    parser.add_argument("--root", default=default_root(), help="repository root (default: this script's parent)")
    parser.add_argument("--all", action="store_true",
                        help="also read references/, reference/*.md, top-level docs, docs/ and .github/")
    parser.add_argument("--list", action="store_true", help="print the URLs and where they appear, then exit")
    parser.add_argument("--offline", action="store_true",
                        help="skip every network request; links into this repo are still checked")
    parser.add_argument("--skip-if-offline", action="store_true",
                        help="skip network requests, with a note, when developer.apple.com can't be resolved")
    parser.add_argument("--method", choices=("head", "get"), default="head",
                        help="head: HEAD, then GET if HEAD fails (default, light); "
                             "get: GET only (slower, catches servers whose HEAD hides an error)")
    parser.add_argument("--timeout", type=float, default=15.0, help="seconds per request (default: %(default)s)")
    parser.add_argument("--retries", type=int, default=1, help="extra tries after a timeout or 5xx (default: 1)")
    parser.add_argument("--workers", type=int, default=8, help="requests in parallel (default: %(default)s)")
    parser.add_argument("--per-host", type=int, default=4, help="parallel requests per host (default: %(default)s)")
    parser.add_argument("--skip", action="append", default=[], metavar="REGEX",
                        help="skip URLs that match REGEX; repeat for more")
    parser.add_argument("--repo", default="Kimeur/duology",
                        help="GitHub owner/name whose blob, tree and raw links are checked against this checkout "
                             "(default: %(default)s; empty to turn off)")
    parser.add_argument("--no-local", action="store_true",
                        help="fetch links into this repo from GitHub instead of checking the checkout")
    parser.add_argument("--warn-only", action="store_true", help="report broken links but exit 0")
    parser.add_argument("--format", choices=("text", "github"), default="text", help="output format")
    parser.add_argument("-v", "--verbose", action="store_true", help="also print ok and redirected URLs")
    parser.add_argument("--version", action="version", version="%(prog)s " + VERSION)
    args = parser.parse_args(argv)

    root = os.path.abspath(args.root)
    if args.timeout <= 0 or args.retries < 0 or args.workers < 1 or args.per_host < 1:
        print("check-sources: --timeout, --workers and --per-host must be positive, --retries 0 or more",
              file=sys.stderr)
        return 2
    try:
        skip = [re.compile(p) for p in args.skip]
    except re.error as exc:
        print("check-sources: bad --skip pattern (%s)" % exc, file=sys.stderr)
        return 2

    if args.paths:
        files = []
        for p in args.paths:
            p = os.path.abspath(p)
            if os.path.isdir(p):
                for dirpath, dirnames, filenames in os.walk(p):
                    dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
                    files.extend(os.path.join(dirpath, f) for f in sorted(filenames)
                                 if f.endswith((".md", ".txt", ".yml", ".yaml")))
            elif os.path.isfile(p):
                files.append(p)
            else:
                print("check-sources: no such file or folder: %s" % p, file=sys.stderr)
                return 2
    else:
        files = default_files(root, args.all)

    urls, skipped = collect(files, root, skip)

    if args.list:
        for url in sorted(urls):
            where = ", ".join("%s:%d" % loc for loc in urls[url])
            print("%s  %s" % (url, where))
        print("%d URL%s in %d file%s (%d placeholder%s skipped)" % (
            len(urls), plural(len(urls)), len(files), plural(len(files)), skipped, plural(skipped)))
        return 0

    # Links into this repo on GitHub are checked against the checkout: no network needed.
    results = {}
    remote = []
    for url in urls:
        target = None if args.no_local else local_target(url, args.repo, root)
        if target is not None:
            results[url] = check_local(url, target, root)
        else:
            remote.append(url)

    offline_note = None
    if args.offline or truthy(os.environ.get("DUOLOGY_OFFLINE")):
        offline_note = "offline mode"
    elif args.skip_if_offline and remote and not network_available():
        offline_note = "no network (can't resolve developer.apple.com)"

    if offline_note is None and remote:
        fetcher = Fetcher(args.timeout, args.retries, args.per_host, args.method)
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(fetcher.check, url): url for url in remote}
            for future in concurrent.futures.as_completed(futures):
                url = futures[future]
                try:
                    results[url] = future.result()
                except Exception as exc:  # a bug here must not hide other results
                    results[url] = Result(url, error="checker error (%s)" % exc)

    counts = {"ok": 0, "blocked": 0, "broken": 0}
    for url in sorted(results, key=lambda u: urls[u][0]):
        result = results[url]
        counts[result.kind] += 1
        rel, line = urls[url][0]
        more = len(urls[url]) - 1
        suffix = " (+%d more place%s)" % (more, "" if more == 1 else "s") if more else ""
        if result.kind == "ok":
            if args.verbose:
                print("%s:%d: ok: %s (%s)%s" % (rel, line, url, result.describe(), suffix))
            continue
        severity = "error" if result.kind == "broken" else "warning"
        message = "%s: %s (%s)%s" % (result.kind, url, result.describe(), suffix)
        if args.format == "github":
            print(annotate(severity, rel, line, message))
        else:
            print("%s:%d: %s: %s" % (rel, line, severity, message))

    not_checked = len(urls) - len(results)
    summary = "%d URL%s in %d file%s · %d ok · %d blocked · %d broken · %d placeholder%s skipped" % (
        len(urls), plural(len(urls)), len(files), plural(len(files)),
        counts["ok"], counts["blocked"], counts["broken"], skipped, plural(skipped))
    if not_checked:
        summary += " · %d not checked (%s)" % (not_checked, offline_note)
    print(summary)
    if counts["broken"] and not args.warn_only:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
