# Xcode's agent connection and Apple's agent skills

Claude Code can build, run and inspect a project through Xcode's own tools. Xcode exposes them as a Model Context Protocol (MCP) server, reached with `xcrun mcpbridge`. Apple's guide: [Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode).

Checked on 16 October 2026 with Xcode 27.1 (27A9275) and Claude Code 2.1. We read the help of every command below. We did not register the server or connect it to a running Xcode; see [Not verified](#not-verified). On 17 October, with no Xcode running, we sent the bridge an MCP `initialize` message and kept its input open, as Claude Code does. It replied within a second, as `xcode-tools`.

## Turn it on

1. **The user** opens Xcode, chooses Xcode > Settings, selects Intelligence and, under Model Context Protocol, turns on "Allow external agents to use Xcode tools". An agent must not change this setting.
2. **Register the server** with Claude Code. Show the user the command and run it only after they agree. With more than one Xcode installed, use the `-e DEVELOPER_DIR` form in [Two Xcodes on one Mac](#two-xcodes-on-one-mac) instead:

   ```bash
   claude mcp add --transport stdio xcode -- xcrun mcpbridge
   claude mcp list
   ```

3. **The user opens the project** in Xcode before you prompt. Xcode shows when an external agent connects and while it is active.

Apple's page gives the same command for Claude Code and `codex mcp add xcode -- xcrun mcpbridge` for Codex.

### Where Claude Code saves it

`claude mcp add` takes `-s, --scope` (`claude mcp add --help`):

| Scope | Saved for | Use when |
|---|---|---|
| `local` (default) | You, in this project only | Trying it out |
| `project` | Everyone who clones the repo (a shared `.mcp.json`) | The whole team uses Xcode 27.1 at the same path |
| `user` | You, in every project | You always work with Xcode open |

Changing Claude Code's configuration is the user's decision. Show the command and let the user run it, or ask first.

## What `mcpbridge` is

`xcrun mcpbridge --help` describes it as a stdio bridge: it reads JSON-RPC 2.0 messages from stdin, passes them to Xcode's MCP tool service, and writes the replies to stdout. It reads two optional environment variables:

| Variable | What it does |
|---|---|
| `MCP_XCODE_PID` | The process ID of the Xcode to connect to. Without it, the bridge connects to the Xcode that `xcode-select` picks. |
| `MCP_XCODE_SESSION_ID` | A UUID that names one Xcode tool session. |

## Two Xcodes on one Mac

Both Xcode 26.5 and Xcode 27.1 ship `mcpbridge`. Which one runs, and which Xcode it talks to, both follow the developer directory:

- `xcrun` finds `mcpbridge` in `DEVELOPER_DIR`, or in the `xcode-select` default.
- The bridge connects to the Xcode that `xcode-select` picks. `xcode-select -p` honours `DEVELOPER_DIR` (we checked), so passing `DEVELOPER_DIR` should point both at 27.1.

Claude Code starts the bridge without your shell's `DEVELOPER_DIR`. So check the Mac-wide default with the variable removed:

```bash
env -u DEVELOPER_DIR xcode-select -p
```

Plain `xcode-select -p` won't do: with `DEVELOPER_DIR` set, it prints the variable, not the default. If the command above doesn't print the 27.1 path, register the server like this. With more than one Xcode installed, use this form anyway; it keeps working if the user later switches the default:

```bash
claude mcp add --transport stdio xcode \
  -e DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
  -- xcrun mcpbridge
```

If both Xcodes are open at once, `MCP_XCODE_PID` picks one. A PID changes every time Xcode starts, so use it for a session, not in saved config. Find the PID of Xcode 27.1:

```bash
ps -axo pid=,comm= | grep "/Xcode-27.1.app/Contents/MacOS/Xcode$" | awk '{print $1}'
```

The `comm` column holds each process's executable path, so this matches Xcode itself and nothing that only mentions the path in its arguments.

## When it fails

| Symptom | Likely cause | Fix |
|---|---|---|
| `claude mcp list` shows `xcode` as failed or timing out | The registered command is wrong. The bridge answers even with Xcode closed, so a closed Xcode doesn't cause this. | Read `claude mcp get xcode` to see the command and its environment. Then, after the user agrees, `claude mcp remove xcode` and register it again as above. |
| `xcode` shows Connected, but Xcode's tools fail | "Connected" only means the bridge answered. The project isn't open in Xcode 27.1, or the Intelligence setting is off | Ask the user to open the project in Xcode 27.1 with the setting on |
| Tools act on the wrong project | Another project or another Xcode is in front | Ask the user to open the right project in Xcode 27.1, or set `MCP_XCODE_PID` |
| Builds use the old SDK | The bridge found Xcode 26.x | Register with `-e DEVELOPER_DIR=...` as above |
| Xcode refuses the agent | The Intelligence setting is off | Ask the user to turn it on |

You can always fall back to `xcodebuild` and `xcrun simctl` with `DEVELOPER_DIR`. They need no Xcode window and no MCP server.

## Tell the agent about the project

Apple suggests adding hints about Xcode and the project to `CLAUDE.md` or `AGENTS.md`. For a Duo project, these lines cover what this skill sets up:

```markdown
## Xcode and iPhone Duo
- Use Xcode 27.1. Prefix every xcrun and xcodebuild call with
  DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer. Never run sudo xcode-select.
- Build destination: platform=iOS Simulator,name=iPhone Duo,OS=27.1
- Poses change only in Device Hub. Ask me to click Closed, Partially Open or Open.
- Screenshots: xcrun simctl io booted screenshot --display=primary (outer) or --display=primary-1 (inner).
```

## Apple's agent skills

Xcode 27.1 ships skills for its own agents. Other agents can export them:

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
  xcrun agent skills export --output-dir ~/xcode-skills
```

`xcrun agent` is a small script that runs `mcpbridge run-agent`. The export takes `--output-dir <path>` and `--replace-existing`. Apple's prepare page shows it with no options; the bridge's help says that form writes to `./xcode-skills`.

Pass an absolute path to `--output-dir`. A relative path is resolved from `/`, not the current folder, and fails: `--output-dir rel-xs` stopped with "the volume 'Macintosh HD' is read only" and the path `/rel-xs`. The shell turns `~/xcode-skills` into an absolute path, so that form works. Xcode 26.5's `xcrun agent` has no `skills` agent, so keep the `DEVELOPER_DIR` prefix.

On our Mac it exported 10 skills:

| Skill | Use it for |
|---|---|
| `app-resizability` | Apple's own resizing pass for Duo, Split View and Stage Manager. It replaces main-screen, interface-orientation and idiom checks, old app lifecycle code and safe-area assumptions. Apple's prepare page says to run it first. |
| `device-interaction` | Driving an app on a device or simulator through Xcode: screenshots, UI hierarchy, touches |
| `swiftui-specialist`, `swiftui-whats-new-27` | SwiftUI practice and the iOS 27 SwiftUI changes |
| `app-intents-specialist`, `app-intents-whats-new-27` | App Intents |
| `modernize-tests` | Moving to Swift Testing |
| `building-document-based-swiftui-applications` | Document apps |
| `audit-xcode-security-settings` | Turning on security warnings, analyzer checks and hardening settings |
| `adopt-c-bounds-safety` | The C `-fbounds-safety` extension |

Load `app-resizability` alongside Duology when you make an existing app ready for iPhone Duo. Apple says it finds most issues, not all ([Apple: Three steps](https://developer.apple.com/iphone-duo/prepare/)). Duology adds the Duo layout, design and test rules on top. These skills are Apple software: export them on each Mac, link to them, and never copy them into a repo.

## Agents that run inside Xcode

Xcode can also host agents in its own coding assistant. Their settings live in `~/Library/Developer/Xcode/CodingAssistant/`, with a `ClaudeAgentConfig` folder for Claude. Those files only affect agents that Xcode launches. Plug-ins with skills and MCP servers are added in Intelligence settings, under Agents in Xcode > Plug-ins ([Apple: Extending and customizing agents](https://developer.apple.com/documentation/xcode/extending-and-customizing-agents)). We have not tested Duology inside Xcode's assistant.

## Not verified

- A live connection: we did not register `xcode` with Claude Code on this Mac (that changes the user's configuration) and did not connect to a running Xcode (that shows prompts in the user's Xcode). The commands follow Apple's guide and each tool's `--help`.
- That `-e DEVELOPER_DIR=...` makes the bridge connect to Xcode 27.1 when another Xcode is the default. It follows from the bridge's help and from `xcode-select -p` honouring `DEVELOPER_DIR`, but we did not watch it connect.
- The list of tools the bridge offers, and what each one does once Xcode is open.
