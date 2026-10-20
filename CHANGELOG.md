# Changelog

All notable changes to Duology are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release says which Xcode and iOS versions it was checked on.

## [Unreleased]

### Added

- `duo-camera` (new plugin `duology-features`): camera capture on both displays. The virtual front camera, choosing each camera by the way it faces, rotation and mirroring through fold and unfold, a preview on the outer display with `CameraCaptureAccessory`, and tabletop hands-free capture.
- `duo-media` (`duology-features`): video and audio on both displays. A player owned above the layout switch so playback survives fold and unfold, the tabletop player (video above the fold, the same controls below), Picture in Picture, "up next" as an overlay arrangement, Now Playing and the iOS 27 audio session notifications.
- `duo-intelligence` (`duology-features`): Foundation Models on both displays. An AI pane beside the content when open, a short summary when closed, streaming that survives fold and unfold, availability and fallbacks, and the Private Cloud Compute options.
- `duo-app-intents` (`duology-features`): App Intents on both displays. Intents and entities that act on the right pane, opening a specific pane or window from Siri or Shortcuts, intents that work on the closed phone, and testing with AppIntentsTesting.
- `duo-swiftui-27` (`duology-features`): the iOS 27 SwiftUI changes that matter on iPhone Duo: reordering, swipe actions on any view, the `@State` macro and its source-breaking cases (TN3211), prominent tabs, toolbar minimizing, visibility priority and overflow.
- `duo-system-surfaces` (`duology-features`): widgets, Live Activities and the vertical Dynamic Island, StandBy and Controls on both displays, with what Apple has and hasn't published.
- `duo-reading` (`duology-features`): books and documents on both displays. Two facing pages in book pose and when open, one page when closed, the reader's place kept through fold and unfold, notes beside the text, and Dynamic Type reflow.

## [0.2.0] - 2026-10-19

Checked on Xcode 27.1 (27A9275) and the iPhone Duo simulator on iOS 27.1. Not yet checked on a real iPhone Duo, and the first published test results are not in yet; both are planned for v0.3.

### Added

- 7 skills, so 18 in all:
  - `duo-design-system` (`duology-design`): design tokens by size class, a drop-in SwiftUI token module, even-column grids with the fold as the middle gutter, one type scale with Dynamic Type for both displays, Liquid Glass, concentric corners, colour and contrast, 44 pt targets, and a UIKit version.
  - `duo-postures` (`duology-design`): what each pose needs (closed, open, book, tabletop, tent, flipped), with `FoldGeometry` and `FoldRegionsLayout`, a tabletop media recipe, a book layout with two regions, and the hinge for effects only.
  - `duo-transitions` (`duology-design`): fold and unfold without a reload. Stable identity, opting a resize into animation, Reduce Motion, UIKit transition coordinators and 120 Hz frame budgets, with measured evidence from Device Hub's pose buttons.
  - `duo-ergonomics` (`duology-design`): grips and thumb reach, primary actions near the hands, a `ThumbCorner` modifier for floating controls, left-handed and right-to-left use, touch target audits.
  - `duo-accessibility` (`duology-design`): VoiceOver order across panes and after a fold, Dynamic Type on the outer display, Reduce Motion, Increase Contrast, hardware keyboard, Switch Control and Voice Control, accessibility audits and `XCUIDevice.voiceOverService` in UI tests.
  - `duo-scenes` (`duology`): second windows and their errors, Split View, scene accessories such as the camera capture accessory, state per window and the scene life cycle through fold and unfold.
  - `duo-pose-matrix` (`duology-ship`): `duo-pose` (`status`, `list`, `set`) and `duo-pose-matrix`, which press Device Hub's pose buttons through the macOS Accessibility API, with the user's permission, and screenshot an installed app closed, open, in book pose and in tabletop. A manual mode captures poses set by hand. It refuses to run while UI tests share the simulator and puts the simulator back. Unit tests run without a simulator.
- Commands: `/duo-poses` (`duology-ship`) and `/duo-review` (`duology-design`).
- The `duo-design-reviewer` agent (`duology-design`): reviews screenshots or Figma exports with the 15-point checklist and the pose, layout, reach and accessibility rules. It reads only.
- Gallery app: three screens, `tabletopPlayer`, `foldTransition` and `designTokens`, with screenshots in four poses.
- 9 test tasks in `evals/` for the v0.2 skills, with seven new fixtures (`Steps`, `Album`, `Trail`, `Inbox`, `Trips`, `Notes`, `Shoot`). 29 tasks in all; 28 are ready.
- `reference/api-index.md`: the standard SwiftUI, UIKit, XCUIAutomation and macOS APIs the v0.2 skills use (Liquid Glass and corners, type and touch targets, scenes and windows, accessibility, animation and frame rate, scrolling, test tools, the macOS Accessibility API), each checked in the SDK and linked to Apple's documentation. `focusSection()` joins "Not in the SDK": it is unavailable on iOS.
- `reference/sources.md`: 23 Apple documentation and HIG pages, 6 WWDC sessions and one Apple Support page.
- CI runs the `duo-pose-matrix` unit tests.
- A 25-second demo at the top of the README (GIF, linked to the MP4 in `docs/assets/demo/`): duo-lint finds four problems in an app built before iPhone Duo, Claude fixes them, then the gallery app in every pose.

### Changed

- `duo-start` routes to the v0.2 skills, commands and agent. Its debug logger's struct is now `DuoFirstPassSize`, so it no longer clashes with `duo-design-system`'s `DuoSpace`.
- `duo-navigation`: a lone floating control goes on the vertical bar's side, near the thumb, as Apple's `toolbarVerticalEdge` example does, matching `duo-ergonomics`. v0.1 said the opposite side.
- `duo-patterns`: `FoldGeometry` ignores fold regions that lie outside the view, the same helper `duo-postures` and the gallery use.
- `duo-continuity`: a fold on the simulator kept the root view, with no relaunch and no `.inactive` phase (measured in v0.2); one exception for scroll position when long text reflows.
- `duo-setup`, `duo-testing`, `duo-design-review` and `/duo-audit` point to `duo-pose-matrix` for scripted poses. Asking the user to press the pose stays the default.
- `reference/device-facts.md`: the closed window, 466 × 678 pt, is now measured. New-window requests on the closed simulator did not fail, unlike what Apple's talk describes for the device.
- The how-it-works diagram shows the v0.2 pose screenshots as built.
- `.gitattributes` marks the Python tooling as vendored, so GitHub lists the repo as Swift.
- `README.md`, `AGENTS.md`, `llms.txt` and the plugin manifests list the v0.2 skills, commands and agent. Plugin, marketplace and tool versions are 0.2.0.

### Removed

- The French README. The README is English only.

## [0.1.0] - 2026-10-18

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
- First test tasks in `evals/`: a with/without harness with scoped permissions. Published results come with v0.2.
- French README.
- `scripts/validate-skills.py`: checks every `SKILL.md` for valid front matter, a `name` that matches its folder, a description of 1 to 1024 characters, a `metadata.verified` line, 300 lines or fewer, and relative links that resolve and stay inside their plugin folder, since `/plugin install` copies only that folder. It also checks the front matter of commands and agents. Standard library only.
- `scripts/check-manifests.py`: checks that every JSON file parses and that the marketplace, plugin manifests and hooks point at files that exist.
- `scripts/check-sources.py`: checks that the web pages Duology cites still answer. A redirect up to a parent page or an index counts as broken, because that is how Apple answers an unknown WWDC or Tech Talk ID. Links into this repo are checked against the local checkout, so they also work offline.
- Unit tests for the three scripts in `scripts/tests/`.
- GitHub Actions workflow `.github/workflows/validate.yml`: skills, manifests, duo-lint tests, duo-lint on Duology's own Swift, and the script tests on every push to `main` and every pull request. A weekly job checks the web links.
- Issue forms for bugs, API corrections, new layout patterns and showcases, and a pull request template.
- `AGENTS.md` for Codex, Cursor, GitHub Copilot, Gemini CLI and other agents, and `llms.txt`.
- `SECURITY.md`, `CODE_OF_CONDUCT.md` and this changelog.

[Unreleased]: https://github.com/Kimeur/duology/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Kimeur/duology/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Kimeur/duology/releases/tag/v0.1.0
