# Roadmap

Duology is built in the open. Dates are targets, not promises. Each release says which Xcode and iOS versions it was checked on.

## v0.1: launch (released 18 October 2026)

- Plugins: `duology`, `duology-design`, `duology-recipes`, `duology-ship`
- 11 skills: `duo-start`, `duo-setup`, `duo-layout`, `duo-navigation`, `duo-continuity`, `duo-patterns`, `duo-shared-screen`, `duo-design-review`, `duo-testing`, `duo-lint`, `recipe-two-player-game`
- Commands: `/duo-doctor`, `/duo-new`, `/duo-audit`
- `duo-lint`, the fold linter
- Gallery app with every layout pattern
- First test tasks in `evals/` (the with/without harness)

## v0.2: design (by 20 November 2026)

Built on `main`, not released yet. Checked on Xcode 27.1 and the iPhone Duo simulator.

- [x] `duo-design-system`, `duo-postures`, `duo-transitions`, `duo-ergonomics`, `duo-accessibility`
- [x] `duo-pose-matrix` and `/duo-poses` (screenshots closed, open, in book pose and in tabletop; it doesn't cover Split View, tent or flipped)
- [x] `duo-design-reviewer` agent and `/duo-review`
- [x] `duo-scenes`
- [x] Gallery screens for the tabletop player, the fold transition and the design tokens
- [x] Test tasks for every v0.2 skill in `evals/` (29 tasks in all; the pose task waits until the eval account can run the pose tools)
- [ ] First published test results (the harness runs in a separate macOS user account or a VM)
- [ ] First checks on a real iPhone Duo: the hinge, 120 Hz transitions, the camera capture accessory, new windows on the outer display

## v0.3: iOS 27 features (by 18 December 2026)

- Plugin `duology-features`: `duo-intelligence`, `duo-app-intents`, `duo-camera`, `duo-media`, `duo-reading`, `duo-games`, `duo-swiftui-27`, `duo-system-surfaces`
- Recipes: `recipe-finance-dashboard`, `recipe-media-player`, `recipe-reader`, `recipe-shop`

## v1.0: complete (by end of January 2027)

- All 36 skills and 8 recipes, including `recipe-notes-ai`, `recipe-camera-studio`, `recipe-kids-learning`
- `duo-performance`, `duo-app-store`, `duo-migrate`, `/duo-ship`, `duo-pose-tester` agent
- Ready before Apple's April 2027 rule that App Store listings include iPhone Duo screenshots
- Full test results published

Want something sooner? [Open an issue](https://github.com/Kimeur/duology/issues).
