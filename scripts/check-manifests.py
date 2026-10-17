#!/usr/bin/env python3
"""Check that Duology's JSON files parse and that the plugin manifests make sense.

1. Every .json file in the repo parses as strict JSON, with no duplicate keys
   (skips .git, .research, build output and node_modules).
2. .claude-plugin/marketplace.json, when it exists, has a valid `name`, an
   `owner` with a `name`, and a non-empty `plugins` list. Each entry has a
   unique `name` and a `source`; a relative source starts with "./" (or is a
   bare name under metadata.pluginRoot), has no "..", and points at a folder.
3. plugins/<plugin>/.claude-plugin/plugin.json, when it exists, has a `name`
   that matches its folder, and every "./" path it lists exists.
4. plugins/<plugin>/hooks/hooks.json, when it exists, wraps its events in a
   "hooks" object, each hook has a `type`, command hooks have a `command`, and
   every ${CLAUDE_PLUGIN_ROOT}/... path in a command exists.

Rules come from Claude Code's plugin docs:
https://code.claude.com/docs/en/plugins/marketplace-reference and
https://code.claude.com/docs/en/plugins-reference

Usage:
  python3 scripts/check-manifests.py
  python3 scripts/check-manifests.py --format github

Exit codes: 0 no errors, 1 errors found (or warnings with --strict), 2 bad arguments.
"""

import argparse
import json
import os
import re
import sys

VERSION = "0.1.0"

SKIP_DIRS = {".git", ".research", "build", "DerivedData", "node_modules", "__pycache__", ".build"}
MARKETPLACE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
KEBAB = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PLUGIN_NAME_BAD = re.compile(r"[\s@:/\\]|[\x00-\x1f\x7f]")
ROOT_PATH = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}\"?/([^\s\"';|&)]+)")
COMPONENT_KEYS = ("commands", "agents", "skills", "hooks", "mcpServers", "outputStyles", "lspServers")


class DuplicateKey(ValueError):
    pass


def _no_duplicates(pairs):
    seen = {}
    for key, value in pairs:
        if key in seen:
            raise DuplicateKey("duplicate key %r" % key)
        seen[key] = value
    return seen


def load_json(path):
    """Return (data, error message or None)."""
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        return None, "can't read the file (%s)" % exc
    if text.startswith("﻿"):
        return None, "starts with a byte order mark; save it as UTF-8 without one"
    try:
        return json.loads(text, object_pairs_hook=_no_duplicates), None
    except DuplicateKey as exc:
        return None, str(exc)
    except json.JSONDecodeError as exc:
        return None, "invalid JSON at line %d, column %d: %s" % (exc.lineno, exc.colno, exc.msg)


class Checker:
    def __init__(self, root):
        self.root = os.path.abspath(root)
        self.findings = []  # (severity, relpath, message)
        self.files_checked = 0

    def add(self, severity, path, message):
        self.findings.append((severity, os.path.relpath(path, self.root), message))

    def json_files(self):
        for dirpath, dirnames, filenames in os.walk(self.root):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS and not d.endswith(".xcresult"))
            for name in sorted(filenames):
                if name.endswith(".json"):
                    yield os.path.join(dirpath, name)

    def run(self):
        parsed = {}
        for path in self.json_files():
            self.files_checked += 1
            data, error = load_json(path)
            if error:
                self.add("error", path, error)
            else:
                parsed[os.path.normpath(path)] = data

        marketplace = os.path.join(self.root, ".claude-plugin", "marketplace.json")
        if os.path.normpath(marketplace) in parsed:
            self.check_marketplace(marketplace, parsed[os.path.normpath(marketplace)])

        plugins = os.path.join(self.root, "plugins")
        if os.path.isdir(plugins):
            for plugin in sorted(os.listdir(plugins)):
                plugin_dir = os.path.join(plugins, plugin)
                if plugin.startswith(".") or not os.path.isdir(plugin_dir):
                    continue
                manifest = os.path.normpath(os.path.join(plugin_dir, ".claude-plugin", "plugin.json"))
                if manifest in parsed:
                    self.check_plugin(plugin_dir, manifest, parsed[manifest])
                hooks = os.path.normpath(os.path.join(plugin_dir, "hooks", "hooks.json"))
                if hooks in parsed:
                    self.check_hooks(plugin_dir, hooks, parsed[hooks])

    # -- marketplace ------------------------------------------------------

    def check_marketplace(self, path, data):
        if not isinstance(data, dict):
            self.add("error", path, "must be a JSON object")
            return
        name = data.get("name")
        if not isinstance(name, str) or not name:
            self.add("error", path, "'name' is required and must be text")
        elif not MARKETPLACE_NAME.match(name) or ".." in name:
            self.add("error", path, "'name: %s' may use only letters, digits, '.', '_' and '-', "
                                    "must start with a letter or digit and can't contain '..'" % name)
        owner = data.get("owner")
        if not isinstance(owner, dict) or not isinstance(owner.get("name"), str) or not owner.get("name"):
            self.add("error", path, "'owner' is required and needs a 'name'")
        entries = data.get("plugins")
        if not isinstance(entries, list) or not entries:
            self.add("error", path, "'plugins' is required and must be a non-empty list")
            return
        meta = data.get("metadata") if isinstance(data.get("metadata"), dict) else {}
        plugin_root = meta.get("pluginRoot")
        seen = set()
        listed_dirs = set()
        for i, entry in enumerate(entries):
            where = "plugins[%d]" % i
            if not isinstance(entry, dict):
                self.add("error", path, "%s must be an object" % where)
                continue
            pname = entry.get("name")
            if not isinstance(pname, str) or not pname:
                self.add("error", path, "%s needs a 'name'" % where)
            else:
                where = "plugin '%s'" % pname
                if PLUGIN_NAME_BAD.search(pname):
                    self.add("error", path, "%s: the name can't contain spaces, '@', ':' or slashes" % where)
                elif not KEBAB.match(pname):
                    self.add("warning", path, "%s: use kebab-case for plugin names" % where)
                if pname in seen:
                    self.add("error", path, "%s is listed twice" % where)
                seen.add(pname)
            source = entry.get("source")
            if source is None:
                self.add("error", path, "%s needs a 'source'" % where)
            elif isinstance(source, str):
                folder = self._relative_source(path, where, source, plugin_root)
                if folder:
                    listed_dirs.add(os.path.normpath(folder))
            elif isinstance(source, dict):
                if not isinstance(source.get("source"), str):
                    self.add("error", path, "%s: an object 'source' needs a 'source' type such as 'github'" % where)
            else:
                self.add("error", path, "%s: 'source' must be a path or an object" % where)

        plugins = os.path.join(self.root, "plugins")
        if os.path.isdir(plugins):
            for plugin in sorted(os.listdir(plugins)):
                folder = os.path.normpath(os.path.join(plugins, plugin))
                if not plugin.startswith(".") and os.path.isdir(folder) and folder not in listed_dirs:
                    self.add("warning", path, "plugins/%s isn't listed in the marketplace, so it can't be "
                                              "installed with /plugin install" % plugin)

    def _relative_source(self, path, where, source, plugin_root):
        if source == ".":
            return self.root
        if source.startswith("./"):
            rel = source[2:]
        elif "/" not in source and isinstance(plugin_root, str) and plugin_root:
            rel = os.path.join(plugin_root[2:] if plugin_root.startswith("./") else plugin_root, source)
        else:
            self.add("error", path, "%s: a relative 'source' must start with './' (got '%s')" % (where, source))
            return None
        if ".." in rel.split("/"):
            self.add("error", path, "%s: 'source' can't use '..'" % where)
            return None
        folder = os.path.join(self.root, rel)
        if not os.path.isdir(folder):
            self.add("error", path, "%s: source folder %s doesn't exist (install would fail with "
                                    "'Source path does not exist')" % (where, source))
            return None
        return folder

    # -- plugin.json ------------------------------------------------------

    def check_plugin(self, plugin_dir, path, data):
        if not isinstance(data, dict):
            self.add("error", path, "must be a JSON object")
            return
        folder = os.path.basename(plugin_dir)
        name = data.get("name")
        if not isinstance(name, str) or not name:
            self.add("error", path, "'name' is required and must be text")
        else:
            if PLUGIN_NAME_BAD.search(name):
                self.add("error", path, "'name' can't contain spaces, '@', ':' or slashes")
            elif not KEBAB.match(name):
                self.add("warning", path, "use kebab-case for 'name'")
            if name != folder:
                self.add("warning", path, "'name: %s' differs from its folder 'plugins/%s'" % (name, folder))
        version = data.get("version")
        if version is not None and (not isinstance(version, str) or
                                    not re.match(r"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$", version)):
            self.add("warning", path, "'version' should be semantic, like \"0.1.0\"")
        for key in COMPONENT_KEYS:
            value = data.get(key)
            values = value if isinstance(value, list) else [value]
            for item in values:
                if isinstance(item, str) and item.startswith("./"):
                    target = os.path.normpath(os.path.join(plugin_dir, item[2:]))
                    if not target.startswith(os.path.normpath(plugin_dir)):
                        self.add("error", path, "'%s' path %s leaves the plugin folder" % (key, item))
                    elif not os.path.exists(target):
                        self.add("error", path, "'%s' lists %s, which doesn't exist" % (key, item))

    # -- hooks.json -------------------------------------------------------

    def check_hooks(self, plugin_dir, path, data):
        if not isinstance(data, dict) or not isinstance(data.get("hooks"), dict):
            self.add("error", path, "a hooks file must wrap its events in a top-level \"hooks\" object")
            return
        for event, groups in data["hooks"].items():
            if not isinstance(groups, list):
                self.add("error", path, "hooks.%s must be a list" % event)
                continue
            for gi, group in enumerate(groups):
                where = "hooks.%s[%d]" % (event, gi)
                if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
                    self.add("error", path, "%s needs a 'hooks' list" % where)
                    continue
                if "matcher" in group and not isinstance(group["matcher"], str):
                    self.add("error", path, "%s: 'matcher' must be text" % where)
                for hi, hook in enumerate(group["hooks"]):
                    hwhere = "%s.hooks[%d]" % (where, hi)
                    if not isinstance(hook, dict) or not isinstance(hook.get("type"), str):
                        self.add("error", path, "%s needs a 'type'" % hwhere)
                        continue
                    if "timeout" in hook and (not isinstance(hook["timeout"], (int, float))
                                              or isinstance(hook["timeout"], bool) or hook["timeout"] <= 0):
                        self.add("error", path, "%s: 'timeout' must be a positive number of seconds" % hwhere)
                    if hook["type"] != "command":
                        continue
                    command = hook.get("command")
                    if not isinstance(command, str) or not command.strip():
                        self.add("error", path, "%s: a command hook needs a 'command'" % hwhere)
                        continue
                    for rel in ROOT_PATH.findall(command):
                        if not os.path.exists(os.path.join(plugin_dir, rel)):
                            self.add("error", path, "%s runs ${CLAUDE_PLUGIN_ROOT}/%s, which doesn't exist"
                                     % (hwhere, rel))


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="check-manifests.py",
        description="Check that every JSON file parses and that plugin manifests make sense.",
        epilog="Exit codes: 0 no errors, 1 errors found (or warnings with --strict), 2 bad arguments.")
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        help="repository root (default: this script's parent)")
    parser.add_argument("--format", choices=("text", "github"), default="text", help="output format")
    parser.add_argument("--strict", action="store_true", help="exit 1 on warnings too")
    parser.add_argument("--version", action="version", version="%(prog)s " + VERSION)
    args = parser.parse_args(argv)

    if not os.path.isdir(args.root):
        print("check-manifests: no such folder: %s" % args.root, file=sys.stderr)
        return 2
    checker = Checker(args.root)
    checker.run()
    errors = warnings = 0
    for severity, rel, message in checker.findings:
        if severity == "error":
            errors += 1
        else:
            warnings += 1
        if args.format == "github":
            prop = rel.replace("%", "%25").replace(":", "%3A").replace(",", "%2C")
            print("::%s file=%s,title=check-manifests::%s" % (severity, prop, message.replace("%", "%25")))
        else:
            print("%s: %s: %s" % (rel, severity, message))
    print("%d JSON file%s checked · %d error%s · %d warning%s" % (
        checker.files_checked, "" if checker.files_checked == 1 else "s",
        errors, "" if errors == 1 else "s", warnings, "" if warnings == 1 else "s"))
    if errors or (args.strict and warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
