# Changelog

All notable changes to Duology are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release says which Xcode and iOS versions it was checked on.

## [Unreleased]

### Added

- `/duo-ship` (`duology-ship`): the App Store checklist for iPhone Duo before a submission. It reads the build rules that start in April 2027 (iOS 27 SDK or later, iOS 15 or later, the scene life cycle, the Xcode the CI archives with), runs `duo-lint`, checks the privacy manifest against the APIs that need a declared reason, builds and launches the app on the iPhone Duo simulator, tests every pose with `duo-pose-tester`, captures App Store screenshots of both displays with `duo-shots`, and drafts the App Review notes and promotional text. Ready, Fix or Check for each item, with its evidence. It never uploads or submits.
- `duo-pose-tester` agent (`duology-ship`): runs an installed app through every pose with `duo-pose-matrix`, once launched fresh in each pose and once kept running while the phone folds, opens every screenshot, and reports each failure with its screenshot: the app quitting in a pose or during a fold (with the crash report), letterboxing, cut-off content, a control on the fold, tabletop upside down, state lost. It puts the pose back and never edits the app.
- `recipe-kids-learning` (`duology-recipes`): a SwiftUI learning app for young children. Counting, first letters and shapes, one question at a time with a read-aloud button and 88 pt answer buttons; closed, the picture above the answers; open and in book pose, the question on the left page and the answers on the right; in tabletop, the answers below the fold. Stars stay on the device and survive relaunch. A parental gate (an adult-level multiplication) guards the grown-ups area with the progress reset and the privacy policy link. The privacy manifest says nothing is tracked or collected and declares `UserDefaults` (CA92.1); a Mac test fails if networking, tracking or purchase APIs appear. 164 Mac tests and 9 UI tests pass closed, and the pose tests pass open, book and tabletop on the iPhone Duo simulator, with every answer off the fold.
- `evals/`: the task `recipe-kids-learning/new-kids-app`, and the recipe's `new-project.sh` in `PLUGIN_SCRIPTS`.
- `duo-app-store` (`duology-ship`): the App Store submission for iPhone Duo. What Apple asks for (both displays' sizes, 1 to 10 per set, no alpha, previews, the badge, the April 2027 rules), which pose to capture for which screen, `scripts/duo-shots` (captures both displays from the simulator, checks the size, skips a display that is off, writes JPEG without alpha), uploading with App Store Connect or its API (`APP_IPHONE_DUO`, not in Apple's API reference yet), metadata, an App Review notes template and the privacy manifest. *Measured:* simulator screenshots come at the exact Duo sizes but with an alpha channel, and the display that is off saves as a full-size black frame.
- `evals/`: the task `duo-app-store/store-screenshots` on the `Places` fixture (screenshots ready to upload, App Review notes, the privacy manifest for `@AppStorage`), and the run with Duology may call `duo-shots` (`PLUGIN_SCRIPTS`).
- `duo-migrate` (`duology-ship`): moves an app that ships today to Xcode 27.1 and iPhone Duo, step by step. What people see with each SDK, the scene life cycle a UIKit app needs to launch, rebuilding locally and in CI, the patterns Apple warns against mapped to duo-lint rules, the fixes in UIKit and SwiftUI, what the new SDK changes on its own, and the April 2027 App Store rules. *Measured* on the iPhone Duo simulator: a UIKit app without scenes, built with Xcode 27.1, crashes at launch; and Xcode 27.1 shows the `UIScreen.main` and `UIWindow(frame:)` deprecations only for deployment targets of iOS 26 or later.
- `evals/`: the `Tally` fixture (a UIKit app without scenes, with an Xcode 26 pin in CI) and the task `duo-migrate/ship-on-duo`.
- `reference/api-index.md`: a "Migrating an existing app" section; `reference/sources.md`: D78 (the scene life cycle guide) and D79 (TN3192).

### Fixed

- `reference/sources.md` M1 and the three places that cite it: the Mac User Guide page on Accessibility permission now uses Apple's canonical URL.
- `scripts/check-sources.py`: when support.apple.com answers HTTP 404 with an empty body, the link is reported as blocked, not broken. The site answers some automated requests from GitHub's runners that way for pages that exist, which turned the weekly link check red; a page that is really missing still gets an error page and still fails.
- `scripts/check-sources.py`: a support.apple.com help topic that redirects to its guide's welcome page is now reported as broken. That is how the site answers a Mac Help topic that was removed (HTTP 301 to the welcome page, which answers 200), so the link used to pass. A link to a guide's own root page, such as `https://support.apple.com/guide/iphone/ios`, also redirects there and still passes.

## [0.3.0] - 2026-10-21

Checked on Xcode 27.1 (27A9275) and the iPhone Duo simulator on iOS 27.1. Not yet checked on a real iPhone Duo, and the first published test results are not in yet; both are planned before v1.0.

### Added

- `duo-camera` (new plugin `duology-features`): camera capture on both displays. The virtual front camera, choosing each camera by the way it faces, rotation and mirroring through fold and unfold, a preview on the outer display with `CameraCaptureAccessory`, and tabletop hands-free capture.
- `duo-media` (`duology-features`): video and audio on both displays. A player owned above the layout switch so playback survives fold and unfold, the tabletop player (video above the fold, the same controls below), Picture in Picture, "up next" as an overlay arrangement, Now Playing and the iOS 27 audio session notifications.
- `duo-intelligence` (`duology-features`): Foundation Models on both displays. An AI pane beside the content when open, a short summary when closed, streaming that survives fold and unfold, availability and fallbacks, and the Private Cloud Compute options.
- `duo-app-intents` (`duology-features`): App Intents on both displays. Intents and entities that act on the right pane, opening a specific pane or window from Siri or Shortcuts, intents that work on the closed phone, and testing with AppIntentsTesting.
- `duo-swiftui-27` (`duology-features`): the iOS 27 SwiftUI changes that matter on iPhone Duo: reordering, swipe actions on any view, the `@State` macro and its source-breaking cases (TN3211), prominent tabs, toolbar minimizing, visibility priority and overflow.
- `duo-system-surfaces` (`duology-features`): widgets, Live Activities and the vertical Dynamic Island, StandBy and Controls on both displays, with what Apple has and hasn't published.
- `duo-reading` (`duology-features`): books and documents on both displays. Two facing pages in book pose and when open, one page when closed, the reader's place kept through fold and unfold, notes beside the text, and Dynamic Type reflow.
- `duo-games` (`duology-features`): games on both displays. Fill the screen in every pose instead of letterboxing, touch controls off the fold, the bottom half as a controller in tabletop, SpriteKit and Metal views that resize without restarting the scene, and game controllers.
- `recipe-media-player` (`duology-recipes`): a video podcast player. A library, a player that keeps playing through every fold, video above the fold and the controls below in tabletop, Picture in Picture and an up next card.
- `recipe-reader` (`duology-recipes`): an e-book reader. One page closed, two facing pages open and in book pose, the reader's place kept through every fold, and Dynamic Type reflow.
- `recipe-finance-dashboard` (`duology-recipes`): a personal finance dashboard. The balance and recent spending when closed; the balance, a spending chart and the transactions side by side when open, with a detail for each transaction.
- `recipe-shop` (`duology-recipes`): a shop for digital packs. The grid and a pack's page side by side when open, a basket, and StoreKit 2 purchases and a subscription tested with a local StoreKit configuration file.
- `reference/api-index.md`: the APIs the v0.3 skills and recipes use, in eight new sections (Foundation Models; App Intents; widgets, Live Activities and Controls; capture sessions and devices; media playback; games; reading and text; StoreKit and Charts), plus new rows for the iOS 27 SwiftUI changes and the test tools (`XCUIScreen.screens`, `SKTestSession`, AppIntentsTesting). Each name was checked in the iOS 27.1 SDK and typechecked, and each doc link answers.
- `reference/sources.md`: 40 rows of Apple documentation, HIG and developer pages (D38 to D77), 8 WWDC26 sessions (V20 to V27), the App Review Guidelines (S5), Apple's Apple Pencil page (A13), the FFmpeg filters page and the local checks behind the v0.3 skills.

### Changed

- `duo-start` and its routing map route to every v0.3 skill and recipe. Only the v1.0 items are still "coming".
- The README, `AGENTS.md`, `llms.txt` and the roadmap list every v0.3 skill and recipe as built. The `duology-features` description no longer says its skills land one by one, and the `duology-features` and `duology-recipes` keywords match between the plugin manifests and the marketplace.
- `reference/api-index.md`: the virtual front camera's limits (1080p at 60 fps, no depth) are no longer unverified, because Tech Talk 111465 states them. `AsyncImage` caching leaves "Not in the SDK": Apple's `AsyncImage` page documents it from iOS 27. `TupleContent` is indexed with its SDK availability (iOS 26.0) and TN3211's deployment-target rule.
- `/duo-new` says that `recipe-shop` prices read "–" after a plain `simctl launch`, until a StoreKit test session has run.
- `recipe-two-player-game`: the layout UI test attaches a screenshot of each display from `XCUIScreen.screens`. `XCUIScreen.main` is the outer display on iPhone Duo, black while the phone is open.
- `evals/`: the run with Duology may call the four new recipes' `new-project.sh` (`PLUGIN_SCRIPTS`). The evals README counts 41 tasks for 30 skills, the fixtures README names the v0.3 tasks that use each fixture, and the tabletop video call task no longer waits for `duo-media`.

### Fixed

- `evals/lib/checks/single_owner.py`: a return type (`-> Model {`) no longer counts as a place the model is created, folders such as `Tools/ModelTests` are skipped like other test code, and a model built in a static factory is traced to where the factory is called. The finance and shop tasks get back their ownership checks (`selection-survives-fold`, `basket-survives-fold`).
- `duo-games` hides the status bar with `toolbarVisibility(.hidden, for: .statusBar)`. The iOS 27.1 SDK marks `statusBarHidden(_:)` to be deprecated. Below iOS 27 a helper falls back to `statusBarHidden()`, because `.statusBar` doesn't build there without a check.
- `duo-postures` and `duo-patterns`: the overlay arrangement was checked folded (in `duo-media`). Read one view inside the primary, `overlayArrangementZIndex` is `1` closed and open flat, `0` in book and tabletop.
- `duo-continuity` and `duo-navigation`: popping a pushed screen during the unfold animation leaves it with the closed phone's insets. Switch panes after the animation (measured in `recipe-finance-dashboard` and `recipe-shop`).
- `duo-scenes`: the simulator showed the camera capture accessory in book at 128°, with no capture session (measured in `duo-camera`). Unverified on a device.
- `recipe-reader`: a "Continue Reading" excerpt no longer ends in a double ellipsis ("paragraph.…"), and adds no "…" when nothing follows.
- README: `duology-design` and `duology-features` install on their own, but point to `duology`'s skills, so install `duology` first.

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

[Unreleased]: https://github.com/Kimeur/duology/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/Kimeur/duology/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Kimeur/duology/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Kimeur/duology/releases/tag/v0.1.0
