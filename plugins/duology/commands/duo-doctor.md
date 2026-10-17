---
name: duo-doctor
description: "Check that this Mac can build, run and test iPhone Duo apps (macOS, Xcode 27.1, the iOS 27.1 simulator runtime, an iPhone Duo simulator, Xcode's MCP bridge, python3 for duo-lint), then explain how to fix each failure."
argument-hint: "[--skip-claude]"
allowed-tools:
  - Bash(duo-doctor *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/bin/duo-doctor *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/bin/duo-doctor" *)
  - Read
---

# /duo-doctor

Check this Mac for iPhone Duo work, then help the user fix what fails.

## 1. Run the doctor

Run this with the Bash tool. Pass the user's arguments through:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/duo-doctor" $ARGUMENTS
```

`duo-doctor` is also on your PATH while the plugin is enabled, so `duo-doctor $ARGUMENTS` works too.

The script only reads. It installs, boots and registers nothing. Its one side effect: it runs `claude mcp get xcode`, which starts Xcode's MCP bridge for a moment. Pass `--skip-claude` to skip that check.

Exit code 1 means a required check failed. That is a result, not an error. Read the output and go on.

## 2. Read the output

| Mark | Meaning |
|---|---|
| `[x]` | Pass. |
| `[ ]` | Fails. The `fix:` lines under it say what to do. |
| `[-]` | Skipped. The reason follows. A skipped required check counts as failed. |
| `(optional)` | Doesn't block Duo work. `xcodebuild` and `simctl` work without it. |
| `note:` | Context for the line above. Read it. |

The last line says `Ready` or `Not ready`.

## 3. Report to the user

Keep it short:

1. One sentence: ready or not ready, and how many required checks failed.
2. For each `[ ]` line, required ones first: what is wrong in plain words, the fix command copied from the output, and who does it (you or the user).
3. One line for the optional items that are open, with their fix.
4. Repeat any `note:` that changes how to run commands, such as "put `DEVELOPER_DIR=...` in front of `xcrun` and `xcodebuild`".

Don't list the `[x]` lines one by one. Don't invent fixes that aren't in the output or in the `duo-setup` skill.

## 4. Fix only what is safe

Never run `sudo`, `xcode-select --switch` or `xcode-select -s`. They change the Xcode every tool on the Mac uses. Use `DEVELOPER_DIR` instead.

| Fix | Who | Rule |
|---|---|---|
| Install or update Xcode 27.1 or macOS | User | Explain where to get it. |
| Turn on Xcode > Settings > Intelligence > "Allow external agents to use Xcode tools" | User | Never change it for them. |
| Click Closed, Partially Open or Open in Device Hub | User | `simctl` has no pose command. |
| `xcrun simctl bootstatus <UDID> -b`, `open .../DeviceHub.app` | You | Safe. Run it if the user wants the simulator up. A first boot can take minutes. |
| `export DEVELOPER_DIR=...` | You | Safe for your own shell commands. Prefix every `xcrun` and `xcodebuild` call with it. |
| `xcrun simctl create "iPhone Duo" ...` | You, after the user says yes | Adds a simulator. |
| `claude mcp add ...` or `claude mcp remove ...` | You, after the user says yes | Changes Claude Code's configuration. Show the exact command first. |
| `xcodebuild -downloadPlatform iOS` | You, after the user says yes | Downloads several GB. |
| `xcodebuild -runFirstLaunch` | You, after the user says yes | Its help says it accepts the license. |

After you fix something, run the doctor again and report the new result.

## 5. Go deeper

For anything the output doesn't cover, load the `duo-setup` skill from this plugin. It covers Xcode 27.1 next to an older Xcode, Device Hub, Xcode's MCP server and project build settings.

Plugin-specific notes:

- The doctor looks for an MCP server named `xcode`. If the user registered Xcode's bridge under another name, the optional line fails; say so and move on.
- "Connected" for the `xcode` server only means the bridge answered. The bridge answers even while Xcode is closed. Xcode's tools work once the user opens the project in Xcode 27.1 with the Intelligence setting on.
- "connected, but its tools didn't load" means the bridge started but Claude Code stopped waiting for its tool list, often on a cold start. The registration is fine. Don't offer to remove and re-add the server. Run the doctor again; if it fails every time, ask the user to open the project in Xcode 27.1 with the Intelligence setting on.
