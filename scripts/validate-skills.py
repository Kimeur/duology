#!/usr/bin/env python3
"""Check every Duology skill before it ships.

For each folder under plugins/<plugin>/skills/<skill>/ this script checks that:

- the folder has a SKILL.md;
- SKILL.md starts with YAML front matter that a strict YAML parser accepts;
- `name` follows the Agent Skills rules and matches the folder name;
- `description` is 1 to 1024 characters and isn't cut short by a YAML comment;
- `metadata.verified` says where the skill was tested (see CONTRIBUTING.md);
- `metadata.sources`, when it's a path, exists;
- SKILL.md is 300 lines or fewer (change it with --max-lines);
- relative links in SKILL.md and in references/*.md point at files that exist,
  with the same letter case (Linux and GitHub are case-sensitive);
- relative links stay inside their plugin folder. /plugin install copies only
  plugins/<plugin>/ (code.claude.com/docs/en/plugins/loading), so a link to
  reference/ or to another plugin breaks for users. Link to the file on GitHub
  instead (https://github.com/Kimeur/duology/blob/main/...);
- paths named in inline code, such as `references/rules.md`, exist (warning).

It also checks that the front matter of plugins/*/commands/*.md and
plugins/*/agents/*.md parses, because a YAML mistake there breaks the command.

It needs only the Python 3 standard library. It reads front matter with its own
parser for the YAML subset that skills use, so results don't depend on whether
PyYAML is installed. It rejects the mistakes that real YAML parsers reject,
such as an unquoted value that contains ": ", and refuses YAML features that
front matter doesn't need (anchors, tags, {...} mappings) instead of guessing.
A value may start on the line after its key, as in YAML.

Usage:
  python3 scripts/validate-skills.py                  # every skill in the repo
  python3 scripts/validate-skills.py plugins/duology  # one plugin
  python3 scripts/validate-skills.py --format github  # GitHub Actions annotations
  python3 scripts/validate-skills.py --portable       # also flag links that leave the skill, not the plugin

Exit codes: 0 no errors, 1 errors found (or warnings with --strict), 2 bad arguments.
"""

import argparse
import os
import re
import sys
import urllib.parse

VERSION = "0.1.0"

DEFAULT_MAX_LINES = 300
MAX_NAME = 64
MAX_DESCRIPTION = 1024
MAX_COMPATIBILITY = 500
CLAUDE_LISTING_CAP = 1536  # Claude Code truncates description + when_to_use here

NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
VERIFIED_EXAMPLE = "Xcode 27.1 (27A9275), iOS 27.1 simulator, device: no"

# Front matter keys from the Agent Skills spec (agentskills.io/specification)
# and from Claude Code's skill docs (code.claude.com/docs/en/skills).
SPEC_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
CLAUDE_CODE_KEYS = {
    "when_to_use", "argument-hint", "arguments", "disable-model-invocation",
    "user-invocable", "disallowed-tools", "model", "effort", "context", "agent",
    "background", "hooks", "paths", "shell",
}

SKILL_SUBDIRS_FOR_LINKS = ("references",)
REPO_URL = "https://github.com/Kimeur/duology"  # links out of a plugin should point here
REPO_BRANCH = "main"
MENTION_RE = re.compile(r"^(?:\./)?(?:references|scripts|assets|templates?|tests|examples)/[\w.\-/]+$")


# --------------------------------------------------------------------------
# Findings and output
# --------------------------------------------------------------------------

class Finding:
    __slots__ = ("severity", "path", "line", "message")

    def __init__(self, severity, path, line, message):
        self.severity = severity  # "error" or "warning"
        self.path = path
        self.line = line
        self.message = message

    def text(self):
        where = self.path if not self.line else "%s:%d" % (self.path, self.line)
        return "%s: %s: %s" % (where, self.severity, self.message)

    def github(self):
        def prop(value):
            return (str(value).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
                    .replace(":", "%3A").replace(",", "%2C"))

        def data(value):
            return str(value).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")

        parts = ["file=" + prop(self.path)]
        if self.line:
            parts.append("line=%d" % self.line)
        parts.append("title=validate-skills")
        return "::%s %s::%s" % (self.severity, ",".join(parts), data(self.message))


# --------------------------------------------------------------------------
# A strict parser for the YAML subset used in skill front matter
# --------------------------------------------------------------------------

class FrontMatterError(Exception):
    def __init__(self, message, line):
        super().__init__(message)
        self.message = message
        self.line = line


class YamlTimestamp(str):
    """A plain value that YAML parsers turn into a date, not a string."""


_KEY_PLAIN = re.compile(r"""^([^\s#'"\[\]{},:&*!|>%@`-][^:#]*?|-[^\s:#][^:#]*?)[ \t]*:(?:[ \t]+(.*)|[ \t]*)$""")
_KEY_DOUBLE = re.compile(r'''^"((?:[^"\\]|\\.)*)"[ \t]*:(?:[ \t]+(.*)|[ \t]*)$''')
_KEY_SINGLE = re.compile(r"""^'((?:[^']|'')*)'[ \t]*:(?:[ \t]+(.*)|[ \t]*)$""")
_BLOCK_HEADER = re.compile(r"^([|>])(?:([+-])([1-9])?|([1-9])([+-])?)?[ \t]*(?:#.*)?$")
_TIMESTAMP = re.compile(
    r"^\d{4}-\d\d?-\d\d?(?:(?:[Tt]|[ \t]+)\d\d?:\d\d:\d\d(?:\.\d*)?(?:[ \t]*(?:Z|[-+]\d\d?(?::\d\d)?))?)?$")
_ESCAPES = {
    "0": "\0", "a": "\a", "b": "\b", "t": "\t", "\t": "\t", "n": "\n", "v": "\v",
    "f": "\f", "r": "\r", "e": "\x1b", " ": " ", '"': '"', "/": "/", "\\": "\\",
    "N": "\x85", "_": "\xa0", "L": "\u2028", "P": "\u2029",
}


class MiniYaml:
    """Parse block mappings, block sequences, plain, quoted and block scalars,
    and one-line [a, b] lists. A value can start on the line after its key or
    '-'. Anchors, aliases, tags and {...} mappings are refused with a clear
    message instead of being guessed at."""

    def __init__(self, lines, first_line):
        self.lines = list(lines)
        self.first = first_line  # file line number of self.lines[0]
        self.notes = []  # (line, key path, kind, message)

    # -- helpers ----------------------------------------------------------

    def _fail(self, message, idx):
        raise FrontMatterError(message, self.first + idx)

    def _note(self, idx, path, kind, message):
        self.notes.append((self.first + idx, path, kind, message))

    def _indent(self, idx):
        line = self.lines[idx]
        count = 0
        for ch in line:
            if ch == " ":
                count += 1
            elif ch == "\t":
                self._fail("a tab is used for indentation; YAML allows only spaces", idx)
            else:
                break
        return count

    def _skip(self, idx):
        while idx < len(self.lines):
            stripped = self.lines[idx].strip()
            if stripped and not stripped.startswith("#"):
                break
            idx += 1
        return idx

    @staticmethod
    def _is_item(content):
        return content == "-" or content.startswith("- ")

    def _match_key(self, content):
        for regex, kind in ((_KEY_DOUBLE, "double"), (_KEY_SINGLE, "single"), (_KEY_PLAIN, "plain")):
            m = regex.match(content)
            if m:
                key = m.group(1)
                if kind == "double":
                    key = self._unescape(key, None)
                elif kind == "single":
                    key = key.replace("''", "'")
                else:
                    key = key.rstrip()
                return key, (m.group(2) or "")
        return None

    # -- structure --------------------------------------------------------

    def parse(self):
        idx = self._skip(0)
        if idx >= len(self.lines):
            return {}
        if self._indent(idx) != 0:
            self._fail("the first key must start at the beginning of the line", idx)
        value, idx = self._block(idx, 0, "")
        idx = self._skip(idx)
        if idx < len(self.lines):
            self._fail("unexpected text; check the indentation", idx)
        if not isinstance(value, dict):
            self._fail("front matter must be a set of 'key: value' lines", 0)
        return value

    def _block(self, idx, indent, path):
        content = self.lines[idx][indent:]
        if self._is_item(content):
            return self._sequence(idx, indent, path)
        return self._mapping(idx, indent, path)

    def _node_below(self, idx, parent_indent, path):
        """Parse a value that starts on its own line, below its key or '-'.

        It is a list or a mapping when the line starts with '- ' or 'key:'.
        Otherwise it is a scalar (plain, quoted, | or > block) or a [...] list,
        and a plain scalar continues on lines indented more than the parent."""
        indent = self._indent(idx)
        content = self.lines[idx][indent:]
        if self._is_item(content) or self._match_key(content) is not None:
            return self._block(idx, indent, path)
        return self._value(idx, parent_indent, content, path)

    def _mapping(self, idx, indent, path):
        result = {}
        while True:
            idx = self._skip(idx)
            if idx >= len(self.lines):
                break
            ind = self._indent(idx)
            if ind < indent:
                break
            if ind > indent:
                self._fail("unexpected indentation", idx)
            content = self.lines[idx][ind:]
            if self._is_item(content):
                self._fail("a '- ' list item where a 'key: value' line was expected", idx)
            matched = self._match_key(content)
            if matched is None:
                self._fail("expected 'key: value' (a space must follow the colon)", idx)
            key, rest = matched
            if key in result:
                self._fail("duplicate key '%s'" % key, idx)
            child = key if not path else path + "." + key
            value, idx = self._value(idx, ind, rest, child)
            result[key] = value
        return result, idx

    def _sequence(self, idx, indent, path):
        items = []
        while True:
            idx = self._skip(idx)
            if idx >= len(self.lines):
                break
            ind = self._indent(idx)
            if ind < indent:
                break
            if ind > indent:
                self._fail("unexpected indentation in a list", idx)
            content = self.lines[idx][ind:]
            if not self._is_item(content):
                break
            rest = content[1:]
            after = rest.lstrip(" ")
            child = "%s[%d]" % (path, len(items))
            if after == "" or after.startswith("#"):
                nxt = self._skip(idx + 1)
                if nxt < len(self.lines) and self._indent(nxt) > ind:
                    value, idx = self._node_below(nxt, ind, child)
                else:
                    value, idx = None, idx + 1
            elif self._is_item(after) or self._match_key(after) is not None:
                new_indent = ind + 1 + (len(rest) - len(after))
                self.lines[idx] = " " * new_indent + after
                value, idx = self._block(idx, new_indent, child)
            else:
                value, idx = self._value(idx, ind, after, child)
            items.append(value)
        return items, idx

    def _value(self, idx, ind, rest, path):
        stripped = rest.strip()
        if stripped == "" or stripped.startswith("#"):
            nxt = self._skip(idx + 1)
            if nxt < len(self.lines):
                nind = self._indent(nxt)
                ncontent = self.lines[nxt][nind:]
                if nind == ind and self._is_item(ncontent):
                    return self._sequence(nxt, nind, path)
                if nind > ind:
                    return self._node_below(nxt, ind, path)
            return None, idx + 1
        first = stripped[0]
        if first in "|>":
            return self._block_scalar(idx, ind, stripped)
        if first == '"':
            return self._quoted(idx, stripped, '"')
        if first == "'":
            return self._quoted(idx, stripped, "'")
        if first == "[":
            return self._flow_list(idx, stripped, path)
        if first == "{":
            self._fail("{...} mappings aren't supported in front matter; use indented 'key: value' lines", idx)
        if first in "&*!":
            self._fail("anchors (&), aliases (*) and tags (!) aren't supported in front matter", idx)
        if first in "@`%,]}":
            self._fail("an unquoted value can't start with '%s'; put the value in quotes" % first, idx)
        if self._is_item(stripped):
            self._fail("a list can't start on the same line as its key; put each '- item' on its own line", idx)
        if stripped.startswith("? ") or stripped.startswith(": ") or stripped in ("?", ":"):
            self._fail("an unquoted value can't start with '%s'; put the value in quotes" % first, idx)
        return self._plain(idx, ind, stripped, path)

    # -- scalars ----------------------------------------------------------

    def _scan_plain(self, text, idx, path):
        """Return (kept text, was it cut by a comment)."""
        cut = re.search(r"[ \t]#", text)
        kept = text[:cut.start()].rstrip() if cut else text
        if re.search(r":(?:[ \t]|$)", kept):
            self._fail("%s: the unquoted value contains ': ', which YAML reads as a new key "
                       "(\"mapping values are not allowed here\"); put the whole value in quotes" % path, idx)
        if cut:
            self._note(idx, path, "comment-cut",
                       "' #' starts a YAML comment, so everything after it is dropped from %s; "
                       "put the whole value in quotes" % path)
        return kept, bool(cut)

    def _plain(self, idx, ind, text, path):
        kept, cut = self._scan_plain(text, idx, path)
        out = kept
        end = idx + 1
        j = idx + 1
        blanks = 0
        while not cut and j < len(self.lines):
            line = self.lines[j]
            if line.strip() == "":
                blanks += 1
                j += 1
                continue
            if self._indent(j) <= ind:
                break
            stripped = line.strip()
            if stripped.startswith("#"):
                break
            seg, cut = self._scan_plain(stripped, j, path)
            out += ("\n" * blanks) if blanks else " "
            out += seg
            blanks = 0
            j += 1
            end = j
        return self._resolve(out, idx, path), end

    def _resolve(self, s, idx, path):
        if s in ("~", "null", "Null", "NULL"):
            return None
        if s in ("true", "True", "TRUE"):
            return True
        if s in ("false", "False", "FALSE"):
            return False
        if re.fullmatch(r"[-+]?[0-9]+", s):
            return int(s)
        if re.fullmatch(r"0o[0-7]+", s):
            return int(s[2:], 8)
        if re.fullmatch(r"0x[0-9a-fA-F]+", s):
            return int(s[2:], 16)
        if re.fullmatch(r"[-+]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)(?:[eE][-+]?[0-9]+)?", s):
            return float(s)
        if re.fullmatch(r"[-+]?\.(?:inf|Inf|INF)", s):
            return float("-inf") if s.startswith("-") else float("inf")
        if s in (".nan", ".NaN", ".NAN"):
            return float("nan")
        if _TIMESTAMP.match(s):
            return YamlTimestamp(s)
        if s.lower() in ("yes", "no", "on", "off", "y", "n"):
            self._note(idx, path, "yaml11-bool",
                       "some YAML parsers read '%s' as true or false; put it in quotes" % s)
        return s

    def _quoted(self, idx, text, quote):
        segments = []
        escaped_breaks = []
        seg = text[1:]
        j = idx
        while True:
            close = self._find_close(seg, quote)
            if close is not None:
                segments.append(seg[:close])
                after = seg[close + 1:]
                break
            segments.append(seg)
            j += 1
            if j >= len(self.lines):
                self._fail("this %s-quoted value is never closed" % ("double" if quote == '"' else "single"), idx)
            seg = self.lines[j].strip()
        after = after.strip()
        if after and not after.startswith("#"):
            self._fail("unexpected text after the closing quote", j)
        # Fold line breaks the way YAML does: one break -> space, blank lines -> newlines.
        out = ""
        pending = 0
        for n, part in enumerate(segments):
            last = n == len(segments) - 1
            if n > 0:
                part = part.lstrip(" \t")
            if not last:
                if quote == '"' and re.search(r"(?<!\\)(?:\\\\)*\\$", part):
                    escaped_breaks.append(n)
                    part = part[:-1]
                else:
                    part = part.rstrip(" \t")
            if n == 0:
                out = part
            elif part == "" and not last:
                pending += 1
                continue
            else:
                if (n - 1 - pending) in escaped_breaks:
                    out += part
                elif pending:
                    out += "\n" * pending + part
                else:
                    out += " " + part
                pending = 0
        if quote == '"':
            out = self._unescape(out, idx)
        else:
            out = out.replace("''", "'")
        return out, j + 1

    @staticmethod
    def _find_close(seg, quote):
        k = 0
        while k < len(seg):
            ch = seg[k]
            if quote == '"' and ch == "\\":
                k += 2
                continue
            if ch == quote:
                if quote == "'" and k + 1 < len(seg) and seg[k + 1] == "'":
                    k += 2
                    continue
                return k
            k += 1
        return None

    def _unescape(self, s, idx):
        out = []
        k = 0
        while k < len(s):
            ch = s[k]
            if ch != "\\":
                out.append(ch)
                k += 1
                continue
            if k + 1 >= len(s):
                out.append("\\")
                break
            nxt = s[k + 1]
            if nxt in _ESCAPES:
                out.append(_ESCAPES[nxt])
                k += 2
            elif nxt in "xuU":
                width = {"x": 2, "u": 4, "U": 8}[nxt]
                digits = s[k + 2:k + 2 + width]
                if not re.fullmatch(r"[0-9a-fA-F]{%d}" % width, digits):
                    if idx is not None:
                        self._fail("bad \\%s escape in a double-quoted value" % nxt, idx)
                    out.append(s[k:k + 2])
                    k += 2
                    continue
                out.append(chr(int(digits, 16)))
                k += 2 + width
            else:
                if idx is not None:
                    self._fail("unknown escape '\\%s' in a double-quoted value; write '\\\\' for a backslash" % nxt,
                               idx)
                out.append(s[k:k + 2])
                k += 2
        return "".join(out)

    def _flow_list(self, idx, text, path):
        body = text[1:]
        items, cur, k, quote = [], "", 0, None
        closed_at = None
        while k < len(body):
            ch = body[k]
            if quote:
                cur += ch
                if quote == '"' and ch == "\\" and k + 1 < len(body):
                    cur += body[k + 1]
                    k += 2
                    continue
                if ch == quote:
                    if quote == "'" and k + 1 < len(body) and body[k + 1] == "'":
                        cur += "'"
                        k += 2
                        continue
                    quote = None
            elif ch in "\"'" and cur.strip() == "":
                quote = ch
                cur += ch
            elif ch in "[{":
                self._fail("nested [...] or {...} values aren't supported in front matter", idx)
            elif ch == ",":
                items.append(cur)
                cur = ""
            elif ch == "]":
                items.append(cur)
                closed_at = k
                break
            else:
                cur += ch
            k += 1
        if closed_at is None:
            self._fail("a [...] list must open and close on one line; or use one '- item' per line", idx)
        tail = body[closed_at + 1:].strip()
        if tail and not tail.startswith("#"):
            self._fail("unexpected text after ']'", idx)
        values = []
        for n, raw in enumerate(items):
            item = raw.strip()
            if item == "":
                if n == len(items) - 1 and n > 0:
                    continue  # trailing comma
                if len(items) == 1:
                    break  # []
                self._fail("empty item in a [...] list", idx)
            if item[0] in "\"'":
                value, _ = self._quoted(idx, item, item[0])
            else:
                if re.search(r":(?:[ \t]|$)", item):
                    self._fail("an unquoted list item contains ': '; put it in quotes", idx)
                value = self._resolve(item, idx, "%s[%d]" % (path, n))
            values.append(value)
        return values, idx + 1

    def _block_scalar(self, idx, ind, header):
        m = _BLOCK_HEADER.match(header)
        if not m:
            self._fail("bad block scalar header '%s'" % header, idx)
        style = m.group(1)
        chomp = m.group(2) or m.group(5) or ""
        explicit = m.group(3) or m.group(4)
        j = idx + 1
        raw = []
        content_indent = ind + int(explicit) if explicit else None
        while j < len(self.lines):
            line = self.lines[j]
            if line.strip() == "":
                raw.append("")
                j += 1
                continue
            lead = len(line) - len(line.lstrip(" "))
            if content_indent is None:
                if lead <= ind:
                    break
                content_indent = lead
            if lead < content_indent:
                if lead > ind:
                    self._fail("a line in this block is indented less than the first line", j)
                break
            raw.append(line[content_indent:])
            j += 1
        trailing = 0
        while raw and raw[-1] == "":
            raw.pop()
            trailing += 1
        if style == "|":
            text = "\n".join(raw)
        else:
            text = ""
            pending = 0
            prev = None
            for line in raw:
                if line == "":
                    pending += 1
                    continue
                kind = "more" if line[:1] in (" ", "\t") else "text"
                if prev is None:
                    text = "\n" * pending + line
                elif pending == 0:
                    text += (" " if prev == "text" and kind == "text" else "\n") + line
                else:
                    extra = 0 if prev == "text" and kind == "text" else 1
                    text += "\n" * (pending + extra) + line
                pending = 0
                prev = kind
        if raw:
            if chomp == "-":
                pass
            elif chomp == "+":
                text += "\n" + "\n" * trailing
            else:
                text += "\n"
        return text, j


def split_front_matter(text):
    """Return (front matter lines, file line of the first one, body lines, file line of the body)."""
    lines = text.split("\n")
    if not lines or lines[0].rstrip() != "---":
        raise FrontMatterError("SKILL.md must start with a '---' line that opens the front matter", 1)
    for idx in range(1, len(lines)):
        if lines[idx].rstrip() in ("---", "..."):
            return lines[1:idx], 2, lines[idx + 1:], idx + 2
    raise FrontMatterError("the front matter has no closing '---' line", 1)


def parse_front_matter(text):
    """Parse SKILL.md text. Return (data, notes, body lines, body start line)."""
    fm_lines, first, body, body_start = split_front_matter(text)
    parser = MiniYaml(fm_lines, first)
    data = parser.parse()
    return data, parser.notes, body, body_start


# --------------------------------------------------------------------------
# Markdown helpers
# --------------------------------------------------------------------------

_FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
_INLINE_CODE = re.compile(r"(`+)(.+?)(?<!`)\1(?!`)")
_INLINE_LINK = re.compile(
    r"!?\[(?:[^\[\]\\]|\\.|\[[^\[\]]*\])*\]"
    r"\(\s*(<[^<>\n]*>|(?:[^\s()\\]|\\.|\((?:[^\s()\\]|\\.)*\))*)"
    r"(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^()]*\)))?\s*\)")
_REF_DEF = re.compile(r"^ {0,3}\[((?:[^\]\\]|\\.)+)\]:[ \t]*(<[^<>]*>|\S+)")
_HTML_ATTR = re.compile(r"<(?:a|img|source|link)\b[^>]*?\b(?:href|src|srcset)\s*=\s*([\"'])(.*?)\1", re.I)
_HEADING = re.compile(r"^ {0,3}(#{1,6})[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$")
_HTML_ANCHOR = re.compile(r"<a\s[^>]*\b(?:id|name)\s*=\s*[\"']([^\"']+)[\"']", re.I)
_SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.\-]*:")


def mask_markdown(lines):
    """Blank out fenced code, inline code and HTML comments, keeping line numbers.

    Return (masked lines, inline code spans as (line number, text))."""
    masked = []
    spans = []
    fence = None
    in_comment = False
    for number, line in enumerate(lines, start=1):
        m = _FENCE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) \
                    and line.strip() == m.group(1):
                fence = None
            masked.append("")
            continue
        if m and not in_comment:
            fence = m.group(1)
            masked.append("")
            continue
        out = ""
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
                out += rest
                break
            out += rest[:start]
            rest = rest[start + 4:]
            in_comment = True

        def keep(match, number=number):
            spans.append((number, match.group(2).strip()))
            return " " * len(match.group(0))

        masked.append(_INLINE_CODE.sub(keep, out))
    return masked, spans


def find_links(masked):
    """Yield (line number, target) for links in masked markdown lines."""
    for number, line in enumerate(masked, start=1):
        for m in _INLINE_LINK.finditer(line):
            yield number, m.group(1)
        m = _REF_DEF.match(line)
        if m:
            yield number, m.group(2)
        for m in _HTML_ATTR.finditer(line):
            value = m.group(2).strip()
            if value:
                yield number, value.split()[0].rstrip(",")


def slugify(heading):
    """GitHub-style heading anchor."""
    text = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", heading)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


_anchor_cache = {}


def anchors_in(path):
    if path in _anchor_cache:
        return _anchor_cache[path]
    anchors = set()
    counts = {}
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except (OSError, UnicodeDecodeError):
        _anchor_cache[path] = anchors
        return anchors
    fence = None
    for line in lines:
        m = _FENCE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and line.strip() == m.group(1):
                fence = None
            continue
        if m:
            fence = m.group(1)
            continue
        h = _HEADING.match(line)
        if h:
            slug = slugify(h.group(2))
            n = counts.get(slug, 0)
            anchors.add(slug if n == 0 else "%s-%d" % (slug, n))
            counts[slug] = n + 1
        for a in _HTML_ANCHOR.finditer(line):
            anchors.add(a.group(1).lower())
    _anchor_cache[path] = anchors
    return anchors


def exact_case(path, root):
    """Return 'ok', 'case' (exists with other letter case) or 'missing'."""
    if not os.path.exists(path):
        return "missing"
    rel = os.path.relpath(path, root)
    if rel.startswith(".."):
        return "ok"
    cur = root
    for part in rel.split(os.sep):
        if part in ("", "."):
            continue
        try:
            entries = os.listdir(cur)
        except OSError:
            return "ok"
        if part not in entries:
            return "case"
        cur = os.path.join(cur, part)
    return "ok"


def is_inside(path, folder):
    path = os.path.normpath(path)
    folder = os.path.normpath(folder)
    return path == folder or path.startswith(folder + os.sep)


def plugin_folder(skill_dir):
    """plugins/<plugin>/ for a skill at plugins/<plugin>/skills/<skill>/, else None."""
    skills = os.path.dirname(os.path.normpath(skill_dir))
    if os.path.basename(skills) != "skills":
        return None
    return os.path.dirname(skills)


# --------------------------------------------------------------------------
# Checks
# --------------------------------------------------------------------------

class Checker:
    def __init__(self, root, max_lines, portable):
        self.root = os.path.abspath(root)
        self.max_lines = max_lines
        self.portable = portable
        self.findings = []
        self.outside_links = 0
        self.skills_checked = 0

    def rel(self, path):
        return os.path.relpath(path, self.root)

    def skill_index(self):
        """Every skill folder in the repo, by name."""
        if getattr(self, "_skill_index", None) is None:
            index = {}
            plugins = os.path.join(self.root, "plugins")
            if os.path.isdir(plugins):
                for plugin in sorted(os.listdir(plugins)):
                    skills = os.path.join(plugins, plugin, "skills")
                    if not plugin.startswith(".") and os.path.isdir(skills):
                        for d in self._children(skills):
                            index.setdefault(os.path.basename(d), d)
            self._skill_index = index
        return self._skill_index

    def add(self, severity, path, line, message):
        self.findings.append(Finding(severity, self.rel(path), line, message))

    # -- discovery --------------------------------------------------------

    def skill_dirs(self, targets):
        """Return skill folders for the given targets (default: every plugin)."""
        plugins = os.path.join(self.root, "plugins")
        if not targets:
            targets = [plugins]
        dirs = []
        for target in targets:
            target = os.path.abspath(target)
            if os.path.isfile(target) and os.path.basename(target) == "SKILL.md":
                dirs.append(os.path.dirname(target))
            elif os.path.isfile(os.path.join(target, "SKILL.md")):
                dirs.append(target)
            elif os.path.isdir(os.path.join(target, "skills")):
                dirs.extend(self._children(os.path.join(target, "skills")))
            elif os.path.basename(target) == "skills" and os.path.isdir(target):
                dirs.extend(self._children(target))
            elif os.path.basename(os.path.dirname(target)) == "skills" and os.path.isdir(target):
                dirs.append(target)  # a skill folder that has no SKILL.md yet
            elif os.path.isdir(target):
                for plugin in sorted(os.listdir(target)):
                    skills = os.path.join(target, plugin, "skills")
                    if not plugin.startswith(".") and os.path.isdir(skills):
                        dirs.extend(self._children(skills))
            else:
                raise SystemExit("validate-skills: no such file or folder: %s" % target)
        seen = []
        for d in dirs:
            if d not in seen:
                seen.append(d)
        return seen

    @staticmethod
    def _children(skills):
        return [os.path.join(skills, name) for name in sorted(os.listdir(skills))
                if not name.startswith(".") and os.path.isdir(os.path.join(skills, name))]

    def check_layout(self):
        """Flag SKILL.md files that Claude Code won't discover, and duplicate names."""
        plugins = os.path.join(self.root, "plugins")
        if not os.path.isdir(plugins):
            return
        by_name = {}
        for dirpath, dirnames, filenames in os.walk(plugins):
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in ("build", "DerivedData")]
            if "SKILL.md" not in filenames:
                continue
            parts = os.path.relpath(dirpath, plugins).split(os.sep)
            if len(parts) != 3 or parts[1] != "skills":
                self.add("warning", os.path.join(dirpath, "SKILL.md"), 0,
                         "this SKILL.md isn't at plugins/<plugin>/skills/<skill>/SKILL.md, "
                         "so agents won't find it")
                continue
            by_name.setdefault(parts[2], []).append(dirpath)
        for name, paths in sorted(by_name.items()):
            if len(paths) > 1:
                for p in paths:
                    self.add("error", os.path.join(p, "SKILL.md"), 0,
                             "skill name '%s' is used by more than one plugin; installing both "
                             "would make one replace the other" % name)

    def check_commands(self):
        """Commands and agents: front matter must parse, and should have a description."""
        plugins = os.path.join(self.root, "plugins")
        if not os.path.isdir(plugins):
            return
        for plugin in sorted(os.listdir(plugins)):
            for kind in ("commands", "agents"):
                folder = os.path.join(plugins, plugin, kind)
                if plugin.startswith(".") or not os.path.isdir(folder):
                    continue
                for name in sorted(os.listdir(folder)):
                    if not name.endswith(".md"):
                        continue
                    path = os.path.join(folder, name)
                    try:
                        with open(path, encoding="utf-8") as fh:
                            text = fh.read().replace("\r\n", "\n")
                    except (OSError, UnicodeDecodeError) as exc:
                        self.add("error", path, 0, "can't read this file (%s)" % exc)
                        continue
                    if not text.startswith("---"):
                        continue
                    try:
                        data, notes, _, _ = parse_front_matter(text)
                    except FrontMatterError as exc:
                        self.add("error", path, exc.line, "front matter: " + exc.message)
                        continue
                    for line, key, note_kind, message in notes:
                        self.add("error" if note_kind == "comment-cut" and key == "description" else "warning",
                                 path, line, "front matter: " + message)
                    desc = data.get("description")
                    if type(desc) is not str or not desc.strip():
                        self.add("warning", path, 2, "no 'description'; the %s list will show the first line "
                                                     "of the file instead" % kind[:-1])
                    stem = name[:-3]
                    if type(data.get("name")) is str and data["name"] != stem:
                        self.add("warning", path, 2, "'name: %s' differs from the file name '%s'"
                                 % (data["name"], name))

    # -- one skill --------------------------------------------------------

    def check_skill(self, skill_dir):
        self.skills_checked += 1
        folder = os.path.basename(os.path.normpath(skill_dir))
        skill_md = os.path.join(skill_dir, "SKILL.md")
        if not os.path.isfile(skill_md):
            self.add("error", skill_dir, 0, "skill folder has no SKILL.md")
            return
        if exact_case(skill_md, self.root) == "case":
            self.add("error", skill_md, 0, "the file must be named SKILL.md, in capitals")
        try:
            with open(skill_md, "rb") as fh:
                raw = fh.read()
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            self.add("error", skill_md, 0, "SKILL.md isn't valid UTF-8 (%s)" % exc)
            return
        if text.startswith("\ufeff"):
            self.add("warning", skill_md, 1, "SKILL.md starts with a byte order mark; remove it")
            text = text[1:]
        if "\r\n" in text:
            self.add("warning", skill_md, 0, "SKILL.md uses Windows line endings; use \\n")
            text = text.replace("\r\n", "\n")

        line_count = len(text.splitlines())
        if line_count > self.max_lines:
            self.add("error", skill_md, self.max_lines + 1,
                     "SKILL.md has %d lines; keep it to %d or fewer and move detail into references/"
                     % (line_count, self.max_lines))

        try:
            data, notes, body, body_start = parse_front_matter(text)
        except FrontMatterError as exc:
            self.add("error", skill_md, exc.line, "front matter: " + exc.message)
            data, notes, body, body_start = None, [], None, 1

        if data is not None:
            key_lines = self._key_lines(text)
            self._check_fields(skill_md, folder, data, notes, key_lines)
            if body is not None and not "".join(body).strip():
                self.add("warning", skill_md, body_start, "SKILL.md has no instructions after the front matter")

        self._check_file_links(skill_md, skill_dir, text.split("\n"))
        for sub in SKILL_SUBDIRS_FOR_LINKS:
            base = os.path.join(skill_dir, sub)
            if not os.path.isdir(base):
                continue
            for dirpath, dirnames, filenames in os.walk(base):
                dirnames.sort()
                for name in sorted(filenames):
                    if name.lower().endswith(".md"):
                        path = os.path.join(dirpath, name)
                        try:
                            with open(path, encoding="utf-8") as fh:
                                lines = fh.read().replace("\r\n", "\n").split("\n")
                        except (OSError, UnicodeDecodeError) as exc:
                            self.add("error", path, 0, "can't read this file (%s)" % exc)
                            continue
                        self._check_file_links(path, skill_dir, lines)

    @staticmethod
    def _key_lines(text):
        """Map 'name', 'metadata.verified', ... to their line numbers (best effort)."""
        found = {}
        parent = None
        for number, line in enumerate(text.split("\n")[1:], start=2):
            if line.rstrip() in ("---", "..."):
                break
            m = re.match(r"^( *)([A-Za-z0-9_][A-Za-z0-9_.\-]*)[ \t]*:", line)
            if not m:
                continue
            if m.group(1) == "":
                parent = m.group(2)
                found.setdefault(parent, number)
            elif parent:
                found.setdefault(parent + "." + m.group(2), number)
        return found

    def _check_fields(self, skill_md, folder, data, notes, key_lines):
        def line_of(key):
            return key_lines.get(key, key_lines.get(key.split(".")[0], 2))

        cut_keys = set()
        for line, path, kind, message in notes:
            if kind == "comment-cut":
                cut_keys.add(path)
                severity = "error" if path in ("name", "description") or path.startswith("metadata.") else "warning"
                self.add(severity, skill_md, line, "front matter: " + message)
            else:
                self.add("warning", skill_md, line, "front matter: %s: %s" % (path, message))

        # name
        name = data.get("name")
        if "name" not in data:
            self.add("error", skill_md, 2, "front matter has no 'name'")
        elif type(name) is not str:
            self.add("error", skill_md, line_of("name"), "'name' must be text; put it in quotes")
        else:
            problems = []
            if not 1 <= len(name) <= MAX_NAME:
                problems.append("must be 1 to %d characters" % MAX_NAME)
            if not NAME_RE.match(name):
                problems.append("may use only a-z, 0-9 and single hyphens, and can't start or end with a hyphen")
            if problems:
                self.add("error", skill_md, line_of("name"), "'name: %s' %s" % (name, "; ".join(problems)))
            if name != folder:
                self.add("error", skill_md, line_of("name"),
                         "'name: %s' must match the folder name '%s'" % (name, folder))

        # description
        desc = data.get("description")
        if "description" not in data:
            self.add("error", skill_md, 2, "front matter has no 'description'")
        elif type(desc) is not str:
            self.add("error", skill_md, line_of("description"), "'description' must be text; put it in quotes")
        else:
            if not desc.strip():
                self.add("error", skill_md, line_of("description"), "'description' is empty")
            elif len(desc) > MAX_DESCRIPTION:
                self.add("error", skill_md, line_of("description"),
                         "'description' has %d characters; the Agent Skills limit is %d"
                         % (len(desc), MAX_DESCRIPTION))
            when = data.get("when_to_use")
            if type(when) is str and len(desc) + len(when) > CLAUDE_LISTING_CAP:
                self.add("warning", skill_md, line_of("when_to_use"),
                         "description + when_to_use is %d characters; Claude Code cuts the listing at %d"
                         % (len(desc) + len(when), CLAUDE_LISTING_CAP))

        # metadata
        meta = data.get("metadata")
        if "metadata" not in data or meta is None:
            self.add("error", skill_md, line_of("metadata"),
                     "front matter has no 'metadata' with a 'verified' line (for example "
                     "verified: \"%s\")" % VERIFIED_EXAMPLE)
        elif not isinstance(meta, dict):
            self.add("error", skill_md, line_of("metadata"), "'metadata' must be indented 'key: value' lines")
        else:
            for key, value in meta.items():
                if type(value) is not str:
                    kind = "a date" if isinstance(value, YamlTimestamp) else type(value).__name__
                    if value is None:
                        kind = "empty"
                    self.add("error", skill_md, line_of("metadata." + key),
                             "metadata.%s is %s, but metadata values must be text; put it in quotes" % (key, kind))
            verified = meta.get("verified")
            if "verified" not in meta:
                self.add("error", skill_md, line_of("metadata"),
                         "metadata has no 'verified' line (for example verified: \"%s\")" % VERIFIED_EXAMPLE)
            elif type(verified) is str and "metadata.verified" not in cut_keys:
                if not re.search(r"\bXcode \d+(?:\.\d+)*", verified) or \
                        not re.search(r"\bdevice:\s*(?:yes|no)\b", verified):
                    self.add("error", skill_md, line_of("metadata.verified"),
                             "metadata.verified must name the Xcode version and say 'device: yes' or "
                             "'device: no', for example \"%s\"" % VERIFIED_EXAMPLE)
            sources = meta.get("sources")
            if type(sources) is str and re.fullmatch(r"[\w./\-]+\.md", sources):
                target = os.path.join(self.root, sources)
                state = exact_case(target, self.root)
                if state != "ok":
                    self.add("error", skill_md, line_of("metadata.sources"),
                             "metadata.sources points at %s, which %s" % (
                                 sources, "has different letter case on disk" if state == "case" else "doesn't exist"))

        # optional spec fields
        compat = data.get("compatibility")
        if "compatibility" in data and (type(compat) is not str or not 1 <= len(compat) <= MAX_COMPATIBILITY):
            self.add("error", skill_md, line_of("compatibility"),
                     "'compatibility' must be text of 1 to %d characters" % MAX_COMPATIBILITY)
        if "license" in data and type(data.get("license")) is not str:
            self.add("error", skill_md, line_of("license"), "'license' must be text")
        tools = data.get("allowed-tools")
        if "allowed-tools" in data and not (type(tools) is str or (
                isinstance(tools, list) and all(type(t) is str for t in tools))):
            self.add("error", skill_md, line_of("allowed-tools"), "'allowed-tools' must be text or a list of text")

        for key in data:
            if key not in SPEC_KEYS and key not in CLAUDE_CODE_KEYS:
                self.add("warning", skill_md, line_of(key),
                         "unknown front matter key '%s'; agents will ignore it" % key)

    # -- links ------------------------------------------------------------

    def _check_file_links(self, path, skill_dir, lines):
        # Skip the front matter of SKILL.md: it holds no links.
        offset = 0
        if os.path.basename(path) == "SKILL.md" and lines and lines[0].rstrip() == "---":
            for idx in range(1, len(lines)):
                if lines[idx].rstrip() in ("---", "..."):
                    offset = idx + 1
                    break
        body = lines[offset:]
        masked, spans = mask_markdown(body)
        here = os.path.dirname(path)
        for number, target in find_links(masked):
            self._check_link(path, number + offset, here, skill_dir, target)
        for number, code in spans:
            self._check_mention(path, number + offset, skill_dir, code, body[number - 1])

    def _check_link(self, path, line, here, skill_dir, target):
        target = target.strip()
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1].strip()
        if not target or _SCHEME.match(target) or target.startswith("//"):
            return
        if target.startswith("#"):
            fragment = urllib.parse.unquote(target[1:]).lower()
            if fragment and path.lower().endswith(".md") and fragment not in anchors_in(path):
                self.add("warning", path, line, "link to #%s, but this file has no such heading or anchor" % fragment)
            return
        if target.startswith("/"):
            self.add("error", path, line,
                     "link '%s' starts with '/'; use a path relative to this file" % target)
            return
        file_part, _, fragment = target.partition("#")
        file_part = file_part.split("?", 1)[0]
        file_part = urllib.parse.unquote(file_part)
        resolved = os.path.normpath(os.path.join(here, file_part))
        if not is_inside(resolved, self.root):
            self.add("error", path, line, "link '%s' points outside the repository" % target)
            return
        state = exact_case(resolved, self.root)
        if state == "missing":
            self.add("error", path, line, "broken link: %s doesn't exist" % self.rel(resolved))
            return
        if state == "case":
            self.add("error", path, line,
                     "link '%s' only matches a file with different letter case; "
                     "it breaks on Linux and GitHub" % target)
            return
        plugin_dir = plugin_folder(skill_dir)
        if plugin_dir and not is_inside(resolved, plugin_dir):
            url = "%s/%s/%s/%s" % (REPO_URL, "tree" if os.path.isdir(resolved) else "blob", REPO_BRANCH,
                                   self.rel(resolved).replace(os.sep, "/"))
            if fragment:
                url += "#" + fragment
            self.add("error", path, line,
                     "link '%s' leaves the plugin folder %s/. /plugin install copies only that folder, "
                     "so the link breaks for users. Link to %s instead, or copy what the reader needs "
                     "into this skill's references/" % (target, self.rel(plugin_dir), url))
        elif not is_inside(resolved, skill_dir):
            self.outside_links += 1
            if self.portable:
                self.add("warning", path, line,
                         "link '%s' leaves the skill folder; it works after /plugin install but breaks "
                         "when this skill is installed on its own" % target)
        if fragment and resolved.lower().endswith(".md") and os.path.isfile(resolved):
            frag = urllib.parse.unquote(fragment).lower()
            if frag not in anchors_in(resolved):
                self.add("warning", path, line,
                         "link '%s': %s has no heading or anchor '#%s'" % (target, self.rel(resolved), frag))

    def _check_mention(self, path, line, skill_dir, code, line_text=""):
        if not MENTION_RE.match(code) or any(ch in code for ch in "<>*{}$"):
            return
        rel = code[2:] if code.startswith("./") else code
        target = os.path.normpath(os.path.join(skill_dir, rel))
        state = exact_case(target, self.root)
        if state == "ok":
            return
        if state == "case":
            self.add("warning", path, line,
                     "`%s` only matches a file with different letter case in this skill" % code)
            return
        # "`duo-continuity`'s `references/testing.md`": the path belongs to the skill named on the line.
        own = os.path.basename(os.path.normpath(skill_dir))
        for name, other in self.skill_index().items():
            if name != own and re.search(r"(?<![\w-])%s(?![\w-])" % re.escape(name), line_text):
                if exact_case(os.path.normpath(os.path.join(other, rel)), self.root) == "ok":
                    return
        if exact_case(os.path.normpath(os.path.join(self.root, rel)), self.root) == "ok":
            self.add("warning", path, line,
                     "`%s` exists at the repo root, not in this skill folder; say which folder you mean" % code)
            return
        self.add("warning", path, line, "`%s` names a file that doesn't exist in this skill" % code)


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def default_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="validate-skills.py",
        description="Check every SKILL.md under plugins/: front matter, size and links.",
        epilog="Exit codes: 0 no errors, 1 errors found (or warnings with --strict), 2 bad arguments.")
    parser.add_argument("paths", nargs="*", metavar="PATH",
                        help="skill folders, SKILL.md files or plugin folders (default: all of plugins/)")
    parser.add_argument("--root", default=default_root(), help="repository root (default: this script's parent)")
    parser.add_argument("--max-lines", type=int, default=DEFAULT_MAX_LINES,
                        help="most lines a SKILL.md may have (default: %(default)s)")
    parser.add_argument("--format", choices=("text", "github"), default="text", help="output format")
    parser.add_argument("--strict", action="store_true", help="exit 1 on warnings too")
    parser.add_argument("--portable", action="store_true",
                        help="warn about each link that leaves its skill folder but stays in its plugin "
                             "(links that leave the plugin folder are always errors)")
    parser.add_argument("-q", "--quiet", action="store_true", help="print only problems and the summary")
    parser.add_argument("--version", action="version", version="%(prog)s " + VERSION)
    args = parser.parse_args(argv)

    root = os.path.abspath(args.root)
    if not os.path.isdir(os.path.join(root, "plugins")):
        print("validate-skills: %s has no plugins/ folder" % root, file=sys.stderr)
        return 2
    if args.max_lines < 1:
        print("validate-skills: --max-lines must be 1 or more", file=sys.stderr)
        return 2

    checker = Checker(root, args.max_lines, args.portable)
    try:
        dirs = checker.skill_dirs(args.paths)
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        return 2
    if not args.paths:
        checker.check_layout()
        checker.check_commands()
    for d in dirs:
        checker.check_skill(d)

    errors = [f for f in checker.findings if f.severity == "error"]
    warnings = [f for f in checker.findings if f.severity == "warning"]
    for f in checker.findings:
        print(f.github() if args.format == "github" else f.text())

    if not args.quiet and checker.outside_links and not args.portable:
        one = checker.outside_links == 1
        print("note: %d %s skill folder but %s plugin. %s after /plugin install and %s when one skill "
              "is installed alone (npx skills add --skill, or a copied folder); run with --portable to list %s"
              % (checker.outside_links,
                 "link leaves its" if one else "links leave their",
                 "stays in its" if one else "stay in their",
                 "It works" if one else "They work",
                 "breaks" if one else "break",
                 "it" if one else "them"))
    print("%d skill%s checked · %d error%s · %d warning%s" % (
        checker.skills_checked, "" if checker.skills_checked == 1 else "s",
        len(errors), "" if len(errors) == 1 else "s",
        len(warnings), "" if len(warnings) == 1 else "s"))
    if errors or (args.strict and warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
