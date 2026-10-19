# Security policy

## Supported versions

Duology is young, so only the newest code gets security fixes.

| Version | Fixes |
|---|---|
| `main` | Yes |
| Latest release (0.x) | Yes |
| Older releases | No. Update to the latest release. |

## What to report

Most of Duology is text, but some of it runs on your Mac, and all of it steers an AI agent that can run commands. Report anything that could hurt a user through:

- **Scripts that Duology ships:** `duo-lint` and its Claude Code hook, `duo-doctor`, the recipe generator (`new-project.sh`), and the scripts in `scripts/`.
- **Commands that pre-approve tools.** Some commands list `allowed-tools`, so Claude Code runs those shell commands without asking. A pattern that is wider than it needs to be is a security bug.
- **Skill text that steers an agent into harm.** For example, a skill, reference file or recipe template that tells the agent to run code from an untrusted source, send data off the Mac, turn off code signing or the sandbox, or ignore the user's instructions. This includes hidden or encoded instructions.
- **Projects that recipes create.** For example, a template that ships a hard-coded secret, an App Transport Security exception it doesn't need, or tracking in a kids' app.
- **The CI workflow.** For example, a way for a pull request to run code with write access.

Not security issues:

- Bugs in iOS, Xcode or the simulator. Report those to Apple with [Feedback Assistant](https://feedbackassistant.apple.com/).
- A wrong API claim. Use the public [API correction form](https://github.com/Kimeur/duology/issues/new?template=api-correction.yml).

## How to report

Security contact: gazouzimarouane@gmail.com. Duology has applied to Anthropic's OSS Scanner (application pending); if accepted, its findings go to this address.

Please don't open a public issue, discussion or pull request for a security problem.

1. Use GitHub's private form: [Report a vulnerability](https://github.com/Kimeur/duology/security/advisories/new). GitHub explains how it works in [Privately reporting a security vulnerability](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability).
2. Or email the maintainer at gazouzimarouane@gmail.com with "Duology security" in the subject.
3. If neither works, open an issue titled "Security contact request" with no details. The maintainer will reply with a private way to send them.

Include:

- the file, script, skill or command;
- the steps to reproduce, or the prompt that makes the agent misbehave;
- what an attacker could do with it;
- a fix, if you have one.

## What happens next

The maintainer will confirm that the report arrived, check the problem, and agree a date with you before anything is made public. Fixes ship in a new release with a GitHub security advisory. We credit you in the advisory and the changelog, unless you'd rather stay anonymous.

## Using Duology safely

- Duology's scripts read files on your Mac. They don't send data anywhere. `duo-doctor` changes nothing; its one side effect is a quick `claude mcp get xcode` call, which you can skip with `--skip-claude`.
- The lint hook is off until you set `DUOLOGY_LINT_HOOK=1`, and it never blocks Claude.
- Treat a skill pack like any code you install: read what it does before you install it, and review what changed before you update.
