# Roadmap

Duology is built in the open. Dates are targets, not promises. Each release says which Xcode and iOS versions it was checked on.

## v0.1: launch (released 18 October 2026)

- Plugins: `duology`, `duology-design`, `duology-recipes`, `duology-ship`
- 11 skills: `duo-start`, `duo-setup`, `duo-layout`, `duo-navigation`, `duo-continuity`, `duo-patterns`, `duo-shared-screen`, `duo-design-review`, `duo-testing`, `duo-lint`, `recipe-two-player-game`
- Commands: `/duo-doctor`, `/duo-new`, `/duo-audit`
- `duo-lint`, the fold linter
- Gallery app with every layout pattern
- First test tasks in `evals/` (the with/without harness)

## v0.2: design (released 19 October 2026)

Checked on Xcode 27.1 and the iPhone Duo simulator. Two items moved to v0.3 (below).

- [x] `duo-design-system`, `duo-postures`, `duo-transitions`, `duo-ergonomics`, `duo-accessibility`
- [x] `duo-pose-matrix` and `/duo-poses` (screenshots closed, open, in book pose and in tabletop; it doesn't cover Split View, tent or flipped)
- [x] `duo-design-reviewer` agent and `/duo-review`
- [x] `duo-scenes`
- [x] Gallery screens for the tabletop player, the fold transition and the design tokens
- [x] Test tasks for every v0.2 skill in `evals/` (29 tasks in all; the pose task waits until the eval account can run the pose tools)

## v0.3: iOS 27 features (released 21 October 2026)

Checked on Xcode 27.1 and the iPhone Duo simulator. The two items carried over from v0.2 move to v1.0 (below).

- [x] Plugin `duology-features`: `duo-intelligence`, `duo-app-intents`, `duo-camera`, `duo-media`, `duo-reading`, `duo-games`, `duo-swiftui-27`, `duo-system-surfaces`
- [x] Recipes: `recipe-finance-dashboard`, `recipe-media-player`, `recipe-reader`, `recipe-shop`
- [x] Test tasks for every v0.3 skill and recipe in `evals/` (41 tasks in all; 40 are ready)

## v0.4: existing apps (next)

- [x] `duo-migrate`, moved up from v1.0: an app that ships today, moved to Xcode 27.1 and iPhone Duo step by step, with the `Tally` fixture and a test task
- [x] `duo-app-store`, moved up from v1.0: App Store screenshots of both displays at the exact Duo sizes (`duo-shots`), App Review notes, the privacy manifest and the April 2027 rules, with a test task
- [x] `recipe-kids-learning`, moved up from v1.0: a learning app for young children with a parental gate, a privacy manifest and nothing tracked, with a test task
- [x] `/duo-ship`, moved up from v1.0: the App Store checklist for Duo, from the build rules to screenshots of both displays and draft App Review notes
- [x] `duo-pose-tester` agent, moved up from v1.0: runs the app in every pose and while it folds, and reports each failure with its screenshot

## v1.0: complete (by end of January 2027)

- [ ] Carried over from v0.3: first checks on a real iPhone Duo (the hinge, 120 Hz transitions, the camera capture accessory, new windows on the outer display)
- [ ] Carried over from v0.3: first published test results (the harness runs in a separate macOS user account or a VM)
- All 36 skills and 8 recipes, including `recipe-notes-ai` and `recipe-camera-studio`
- `duo-performance`
- Ready before Apple's April 2027 rule that App Store listings include iPhone Duo screenshots
- Full test results published

Want something sooner? [Open an issue](https://github.com/Kimeur/duology/issues).
