# Changelog

All notable changes to Duology are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release says which Xcode and iOS versions it was checked on.

## [Unreleased]

### Added

- `scripts/validate-skills.py`: checks every `SKILL.md` for valid front matter, a `name` that matches its folder, a description of 1 to 1024 characters, a `metadata.verified` line, 300 lines or fewer, and relative links that resolve and stay inside their plugin folder, since `/plugin install` copies only that folder. It also checks the front matter of commands and agents. Standard library only.
- `scripts/check-manifests.py`: checks that every JSON file parses and that the marketplace, plugin manifests and hooks point at files that exist.
- `scripts/check-sources.py`: checks that the web pages Duology cites still answer. A redirect up to a parent page or an index counts as broken, because that is how Apple answers an unknown WWDC or Tech Talk ID. Links into this repo are checked against the local checkout, so they also work offline.
- Unit tests for the three scripts in `scripts/tests/`.
- GitHub Actions workflow `.github/workflows/validate.yml`: skills, manifests, duo-lint tests, duo-lint on Duology's own Swift, and the script tests on every push to `main` and every pull request. A weekly job checks the web links.
- Issue forms for bugs, API corrections, new layout patterns and showcases, and a pull request template.
- `AGENTS.md` for Codex, Cursor, GitHub Copilot, Gemini CLI and other agents, and `llms.txt`.
- `SECURITY.md`, `CODE_OF_CONDUCT.md` and this changelog.

## [0.1.0] - TBD

Planned. Target: by 30 October 2026 (see the [roadmap](ROADMAP.md)). When v0.1.0 is tagged, this section becomes the release notes and the items above move into it.

Checked on Xcode 27.1 (27A9275) and the iPhone Duo simulator on iOS 27.1. Not yet checked on a real iPhone Duo; that is planned for v0.2.

### Added

- Four Claude Code plugins in one marketplace: `duology`, `duology-design`, `duology-recipes` and `duology-ship`.
- 11 skills:
  - `duo-start`: the entry point. Finds out whether the app is SwiftUI or UIKit, new or existing, and which SDK it builds with, then picks the next skill.
  - `duo-setup`: Xcode 27.1 next to an older Xcode, the iPhone Duo simulator in Device Hub, Xcode's agent connection and project settings.
  - `duo-layout`: size classes, uneven safe areas, reserved regions, `ArrangementView` and an even custom split.
  - `duo-navigation`: vertical bars, tabs that become a sidebar, `NavigationSplitView`, sheets and overflow.
  - `duo-continuity`: scroll position, playback, typed text, selection and navigation that survive fold, unfold, rotate and resize.
  - `duo-patterns`: eight layout patterns, each with a SwiftUI recipe.
  - `duo-shared-screen`: two people using one phone at the same time.
  - `duo-design-review`: a 15-point review of screenshots and Figma frames.
  - `duo-testing`: logic tests on the Mac and UI tests on the iPhone Duo simulator.
  - `duo-lint`: the fold linter.
  - `recipe-two-player-game`: a two-player game that builds and runs on the iPhone Duo simulator.
- Commands: `/duo-doctor` (checks the Mac), `/duo-new` (creates an app from a recipe) and `/duo-audit` (duo-lint plus the design checklist).
- `duo-lint` with nine rules (`DUO001` to `DUO009`), text, JSON and GitHub output, and an opt-in Claude Code hook (`DUOLOGY_LINT_HOOK=1`) that never blocks.
- Gallery app in `samples/DuologyGallery` with a screen for each layout pattern.
- Reference files: `reference/api-index.md`, `reference/device-facts.md` and `reference/sources.md`.
- First test tasks and results in `evals/`.
- French README.

<!-- When v0.1.0 is tagged: point Unreleased at https://github.com/Kimeur/duology/compare/v0.1.0...HEAD
     and add "[0.1.0]: https://github.com/Kimeur/duology/releases/tag/v0.1.0". -->
[Unreleased]: https://github.com/Kimeur/duology/commits/main
