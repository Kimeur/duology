## What this changes

<!-- One or two sentences. Link the issue it closes, for example "Closes #12". -->

## Type

- [ ] New skill
- [ ] Change to an existing skill
- [ ] New pattern or recipe
- [ ] duo-lint rule or fix
- [ ] API correction
- [ ] Docs, scripts or CI

## Checklist

Delete the lines that don't apply.

- [ ] Every API name I added is in the iOS 27.1 SDK or on an Apple doc page, and I linked that page (and added it to `reference/sources.md` if it's new).
- [ ] I explained Apple's guidance in my own words and didn't paste Apple's text or other repos' text.
- [ ] Every Swift snippet I added typechecks:
      `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun -sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios27.1-simulator <file>`
- [ ] Each `SKILL.md` I touched has an up-to-date `metadata.verified` line, for example `"Xcode 27.1 (27A9275), iOS 27.1 simulator, device: no"`.
- [ ] A new skill comes with at least one test task in `evals/tasks/`.
- [ ] `python3 scripts/validate-skills.py` passes (front matter, 300-line limit, links).
- [ ] `python3 scripts/check-manifests.py` passes.
- [ ] `python3 -m unittest discover plugins/duology-ship/skills/duo-lint/tests` passes, if I changed duo-lint.
- [ ] `python3 -m unittest discover -s scripts/tests` passes, if I changed `scripts/`.
- [ ] `python3 scripts/check-sources.py` passes, if I added web links.
- [ ] No code, names or assets from private projects, and no Apple logos or images.

## How I tested it

<!-- Where you ran it: Xcode version and build, iPhone Duo simulator or device, which poses (Closed, Partially Open, Open). Screenshots of both displays help reviewers. -->
