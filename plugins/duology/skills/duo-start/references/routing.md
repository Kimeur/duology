# Routing map

Which skill to load for which job. Duology v0.1 shipped 11 skills in four plugins, plus three commands. v0.2 (released 19 October 2026) added seven skills, two commands and a review agent. v0.3 (released 21 October 2026) added eight iOS 27 feature skills in a fifth plugin, `duology-features`, and four recipes. v0.4 (released 29 October 2026) added `duo-migrate`, `duo-app-store`, `recipe-kids-learning`, the `/duo-ship` command and the `duo-pose-tester` agent, ahead of plan. `recipe-notes-ai` is on `main` since, also ahead of plan. The other two of the 36 are "coming"; for each one, this page names the Apple source to use until it lands. Dates come from the [roadmap](https://github.com/Kimeur/duology/blob/main/ROADMAP.md) and are targets.

## v0.1 skills

| Skill | Plugin | Load it when | Not for |
|---|---|---|---|
| `duo-start` | `duology` | The task is "make it work on iPhone Duo" and you don't know where to begin. | Fixing code. It routes. |
| `duo-setup` | `duology` | Xcode 27.1 sits next to an older Xcode; the iPhone Duo simulator or Device Hub is missing; Xcode's agent connection (`xcrun mcpbridge`) fails; Swift 6 project settings. | Layout. |
| `duo-layout` | `duology` | Content lands in the fold or under a camera; a screen breaks on one display; size classes, asymmetric safe areas and margins, reserved regions, `ArrangementView`, `UIArrangementViewController`, a split that must always show both halves. | Bars and sheets (`duo-navigation`). |
| `duo-navigation` | `duology` | Toolbars and tab bars turn vertical; items go missing into overflow; tabs should become a sidebar on the inner display; `NavigationSplitView`; sheet placement. | Custom layouts inside a screen. |
| `duo-continuity` | `duology` | Scroll position, playback, typed text, keyboard focus, selection, the navigation stack, an upload or sign-in resets on fold, unfold, rotate or resize. | Deciding the layout. |
| `duo-patterns` | `duology-design` | Choosing a layout for the inner display: list-detail, supporting pane, two-page, dual view, extended canvas, feed reflow, tabs to sidebar, displacement. | API details (`duo-layout`). |
| `duo-shared-screen` | `duology-design` | Two people use one phone: games, teaching, showing a customer. | Single-user layouts. |
| `duo-design-review` | `duology-design` | Reviewing screenshots or Figma frames against the Duo checklist. | Writing code. |
| `duo-testing` | `duology-ship` | Unit and UI tests that must hold up on the Duo simulator: logic tested on the Mac, launch switches, UI tests that reach SwiftUI gestures. | Visual pose checks (`duo-pose-matrix`). |
| `duo-lint` | `duology-ship` | Finding code Apple warns against (`UIScreen.main`, orientation and idiom checks, fixed sizes) before it ships. It reports each finding and explains the fix for its rule. | Checking screenshots; it reads code only. Use `/duo-audit` or `duo-design-review`. |
| `recipe-two-player-game` | `duology-recipes` | Building a two-player game on one phone from scratch. Run it with `/duo-new recipe-two-player-game`. | Existing apps. |

## v0.2 skills

| Skill | Plugin | Load it when | Not for |
|---|---|---|---|
| `duo-scenes` | `duology` | A second window (`openWindow`, `activateSceneSession`, `UIWindowScene.ActivationAction`), errors from new-window requests on the outer display, Split View, a camera capture accessory on the outer display, state per window, the scene life cycle through fold and unfold. | Layout inside one window (`duo-layout`). |
| `duo-design-system` | `duology-design` | Spacing, margins, even-column grids, one type scale for both displays, Liquid Glass, concentric corners, colours and contrast, a token module; a two-frame Figma design turned into code. | Choosing the layout pattern (`duo-patterns`). |
| `duo-postures` | `duology-design` | Closed, open, book, tabletop, tent and flipped: what each pose needs; a tabletop media player or video call; a book layout with two regions; the hinge as an effect. | A posture API: there is none. |
| `duo-transitions` | `duology-design` | Fold, unfold, partial fold or rotation flashes, reloads, jumps or moves controls; opting a resize into animation; Reduce Motion; 120 Hz. | Keeping the state itself (`duo-continuity`). |
| `duo-ergonomics` | `duology-design` | Where primary actions, floating buttons and player controls go; thumb reach on the open display; left-handed people and right-to-left; small touch targets. | Bar placement rules (`duo-navigation`). |
| `duo-accessibility` | `duology-design` | VoiceOver order across panes and after a fold, Dynamic Type on the outer display, Reduce Motion, Increase Contrast, hardware keyboard, Switch Control and Voice Control, accessibility audits. | Visual design review (`duo-design-review`). |
| `duo-pose-matrix` | `duology-ship` | Screenshots of an installed app closed, open, in book pose and in tabletop, by pressing Device Hub's pose buttons (with the user's Accessibility permission), or poses set by hand. Run it with `/duo-poses`. | Split View (a drag in Device Hub), tent and flipped (Device Hub can't set them). |

## v0.3 skills

| Skill | Plugin | Load it when | Not for |
|---|---|---|---|
| `duo-intelligence` | `duology-features` | Foundation Models on both displays: an AI pane beside the content when open, a short summary when closed, streaming that survives a fold, availability and fallbacks, Private Cloud Compute. | Siri and Shortcuts (`duo-app-intents`). |
| `duo-app-intents` | `duology-features` | Intents and entities that act on the right pane, opening a pane or window from Siri, Shortcuts or the Action button, intents that work on the closed phone, AppIntentsTesting. | The AI pane itself (`duo-intelligence`). |
| `duo-camera` | `duology-features` | The virtual front camera, choosing a camera by the way it faces, rotation and mirroring through a fold, a preview on the outer display, hands-free capture in tabletop. | Registering the scene accessory alone (`duo-scenes`). |
| `duo-media` | `duology-features` | A player that keeps playing through fold and unfold, video above the fold and controls below in tabletop, Picture in Picture, "up next", Now Playing, the iOS 27 audio session notifications. | Layout of a tabletop screen without media (`duo-postures`). |
| `duo-reading` | `duology-features` | Books and documents: two facing pages open and in book pose, one page closed, the reader's place kept through a fold, notes beside the text, Dynamic Type reflow, PDFs. | A new reader app from scratch (`recipe-reader`). |
| `duo-games` | `duology-features` | Games that fill every pose, touch controls off the fold, the bottom half as a controller in tabletop, SpriteKit and Metal views that resize without restarting, game controllers. | Two players on one screen (`duo-shared-screen`). |
| `duo-swiftui-27` | `duology-features` | The iOS 27 SwiftUI changes on both displays: reordering, swipe actions on any view, the `@State` macro and its source breaks (TN3211), prominent tabs, toolbar minimizing, `AsyncImage` requests. | Vertical bars and overflow (`duo-navigation`). |
| `duo-system-surfaces` | `duology-features` | Widgets, Live Activities and the vertical Dynamic Island, StandBy and Controls on both displays, and what Apple has and hasn't published about them. | The app's own screens. |
| `recipe-finance-dashboard` | `duology-recipes` | A new personal finance dashboard. Run it with `/duo-new recipe-finance-dashboard`. | Existing apps. |
| `recipe-media-player` | `duology-recipes` | A new video podcast player. Run it with `/duo-new recipe-media-player`. | Existing apps (`duo-media`). |
| `recipe-reader` | `duology-recipes` | A new e-book reader. Run it with `/duo-new recipe-reader`. | Existing apps (`duo-reading`). |
| `recipe-shop` | `duology-recipes` | A new shop for digital packs with StoreKit purchases and a subscription. Run it with `/duo-new recipe-shop`. | Existing apps. |

Install a missing plugin with `/plugin install <plugin>@duology`. On other agents, `npx skills add Kimeur/duology --skill <name>` adds one skill.

## v0.4 skills

| Skill | Plugin | Load it when | Not for |
|---|---|---|---|
| `duo-migrate` | `duology-ship` | An app that ships today moves to Xcode 27.1: what people see with its current SDK, the scene life cycle for UIKit apps, the patterns to fix in order, the Xcode pin in CI, the April 2027 App Store rules. | Building Duo layouts in an app already on the iOS 27.1 SDK (`duo-layout`, `duo-patterns`). |
| `duo-app-store` | `duology-ship` | The App Store submission for iPhone Duo: screenshots of both displays at the exact sizes, without alpha, none black (`scripts/duo-shots`), previews, the App Store Connect API display type, the badge, App Review notes, the privacy manifest, the April 2027 rules. | Moving the build to Xcode 27.1 first (`duo-migrate`); screenshots for a design review only (`duo-pose-matrix`). |
| `recipe-kids-learning` | `duology-recipes` | A new learning app for young children: one question at a time read aloud, big answer buttons below the fold in tabletop, progress that stays on the device, a parental gate, a privacy manifest and nothing tracked. Run `/duo-new recipe-kids-learning`. | An existing app made for kids (`duo-app-store` for the submission, `duo-accessibility`, `duo-postures`). |
| `recipe-notes-ai` | `duology-recipes` | A new notes app with summaries from the on-device model: a headline, key points and to-dos streamed into a pane beside the note when open and one line when closed, a summary without AI when the model can't run, notes that never leave the device. Run `/duo-new recipe-notes-ai`. | Adding an AI pane to an existing app, or Private Cloud Compute (`duo-intelligence`). |

## Commands and agents

| Command | Use it for |
|---|---|
| `/duo-doctor` | Check Xcode 27.1, the Duo simulator and Xcode's agent connection. Run it first when anything in the build step fails. |
| `/duo-new <recipe>` | Create a new app from a recipe and run it on the Duo simulator. Recipes: `recipe-two-player-game`, `recipe-finance-dashboard`, `recipe-media-player`, `recipe-reader`, `recipe-shop`, `recipe-kids-learning`, `recipe-notes-ai`. |
| `/duo-audit` | Run `duo-lint` and the checklist and list what to fix, most serious first. Use it after the first pass. |
| `/duo-poses <bundle-id>` | Screenshot the installed app closed, open, in book pose and in tabletop with `duo-pose-matrix`, and put the simulator back. (v0.2) |
| `/duo-review [folder]` | Hand screenshots or Figma exports (default: the newest `/duo-poses` run) to the `duo-design-reviewer` agent for a design critique, most serious first. It reads only. (v0.2) |
| `/duo-ship [app-folder]` | Before a submission: the April 2027 build rules, `duo-lint`, every pose with the `duo-pose-tester` agent, App Store screenshots of both displays, the privacy manifest and draft App Review notes. Ready, Fix or Check for each. Never uploads. |

The `duo-design-reviewer` agent (`duology-design`, v0.2) applies the 15-point `duo-design-review` checklist plus the `duo-postures`, `duo-patterns`, `duo-ergonomics` and `duo-accessibility` rules to pictures. It never edits files.

The `duo-pose-tester` agent (`duology-ship`) reads `duo-pose-matrix` runs (the app launched in every pose, and kept running while it folds) and reports each failure with its screenshot: a crash, letterboxing, cut-off content, a control on the fold, tabletop upside down, state lost. It reads only; `/duo-ship` and `/duo-poses` make the runs.

## Symptom to skill

| What you see | Load |
|---|---|
| Open phone shows a small centred window with empty space around it | `duo-start` (SDK row: the app ships with the iOS 26 SDK or earlier), then `duo-migrate` |
| A UIKit app crashes at launch after the rebuild with Xcode 27.1 | `duo-migrate` (Step 2: the scene life cycle) |
| App Store screenshots for iPhone Duo, or the April 2027 rules | `duo-app-store` |
| App won't launch after the move to Xcode 27.1 (UIKit) | Scene life cycle blocker: Apple's App Resizability skill, see [detect.md](detect.md#swiftui-uikit-or-mixed) |
| Buttons or text sit in the middle of a half-folded phone | `duo-layout` (reserved regions, `.division`) |
| Content hides under the status bar or a camera | `duo-layout` (safe areas, `.occlusion`) |
| Toolbar items vanish or bars look wrong on the outer display | `duo-navigation` |
| Tabs should become a sidebar when open | `duo-navigation` |
| A sheet covers the wrong half | `duo-navigation` |
| Scroll position, typing or video resets when the phone folds | `duo-continuity` |
| One long column stretched across the inner display | `duo-patterns`, then `duo-layout` |
| Two players or two people at once | `duo-shared-screen`, or `recipe-two-player-game` for a new game |
| "Open in new window" fails or does nothing; content should appear on the outer display while the camera runs | `duo-scenes` |
| The screen flashes, reloads or controls jump when the phone opens | `duo-transitions`, then `duo-continuity` |
| Half folded: video should sit above the fold with controls below | `duo-postures` |
| Buttons at the top centre of the open display, or out of thumb reach | `duo-ergonomics` |
| Spacing, fonts or corners differ between screens; an odd number of columns open | `duo-design-system` |
| VoiceOver reads two panes row by row, or text truncates at large sizes closed | `duo-accessibility` |
| "Show me every pose" | `duo-pose-matrix` (`/duo-poses`), then `/duo-review` |
| "Does it survive folding?", "does it crash in tabletop?" | `/duo-poses` and `/duo-poses --no-relaunch`, then the `duo-pose-tester` agent on both runs |
| "Is it ready for the App Store?" | `/duo-ship`, with `duo-app-store` behind it |
| "Review these designs for Duo" | `duo-design-review`, or `/duo-review` for the agent |
| UI tests pass on iPhone and fail on the Duo simulator | `duo-testing` |
| An AI summary or chat should sit beside the content when open | `duo-intelligence` |
| Siri or a shortcut opens the app but not the right pane or window | `duo-app-intents` |
| The front camera switches, mirrors or rotates wrongly after a fold | `duo-camera` |
| Video restarts after a fold, or Picture in Picture and Now Playing misbehave | `duo-media`, then `duo-continuity` |
| A book or document should show two facing pages and keep its place | `duo-reading` |
| A game letterboxes, or its touch controls sit on the fold | `duo-games` |
| Reordering, swipe actions or the new toolbar modifiers act oddly after a fold | `duo-swiftui-27` |
| A widget, Live Activity or control looks wrong on one display | `duo-system-surfaces` |
| `UIScreen.main`, `userInterfaceIdiom`, orientation checks in the code | `duo-lint` to list them with the fix for each rule; Apple's App Resizability skill for the generic fixes |
| The agent can't reach Xcode, or the wrong Xcode builds | `duo-setup` |

## Coming skills and what to use until then

Say "coming" when one of these fits, and work from the Apple source in the last column.

| Skill | Release | Covers | Until then |
|---|---|---|---|
| `duo-performance` | v1.0 | Smooth resizing at 120 Hz | Test on a device: the simulator reports a 60 fps maximum (*measured*, see [device facts](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md)) |
| `recipe-camera-studio` | v1.0 | App recipe | Start from the closest ready recipe, then load `duo-patterns` and `duo-camera` |

## Apple's skills in Xcode 27.1

Xcode ships its own agent skills. Duology links to them and never copies them.

- **App Resizability** (`app-resizability`). The generic resizing work: main-screen reads, orientation and idiom checks, safe-area assumptions and moving UIKit apps to the scene life cycle. It was called the app modernization skill in Xcode 27 ([WWDC26 session 278](https://developer.apple.com/videos/play/wwdc2026/278/)); Xcode 27.1 renamed it and added SwiftUI and iPhone Duo support ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)). Apple says it finds most issues, not all ([prepare page](https://developer.apple.com/iphone-duo/prepare/)).
- The rest of the export. On our Mac (16 Oct 2026) the export wrote 10 skills, each in a folder named after the skill, each with a `SKILL.md`. We read each header and skimmed `device-interaction`; we didn't run them.

| Skill | What it is for |
|---|---|
| `app-resizability` | The generic resizing pass above. |
| `device-interaction` | Checking an app on a simulator or device through Xcode: screenshots, the UI tree, taps. It runs as a subagent and needs Xcode's agent connection (`duo-setup`). Useful in the first pass after each pose change. |
| `modernize-tests` | Moving tests to Swift Testing. |
| `swiftui-specialist`, `swiftui-whats-new-27` | SwiftUI practice, and what changed in SwiftUI for iOS 27. |
| `app-intents-specialist`, `app-intents-whats-new-27` | App Intents, and what changed in iOS 26 and iOS 27. |
| `building-document-based-swiftui-applications` | Document-based SwiftUI apps. |
| `audit-xcode-security-settings` | Turning on security-related build settings and checks. |
| `adopt-c-bounds-safety` | The C `-fbounds-safety` extension. |

How to get them into Claude Code or another agent. Use the same folder as `duo-setup`:

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
  xcrun agent skills export --output-dir ~/xcode-skills
```

- `--output-dir` and `--replace-existing` are the two options in the command's help (Xcode 27.1). Without `--output-dir`, the help says it writes to `./xcode-skills`.
- *Measured:* the command opened Xcode, took about two minutes (17:20 to 17:22 on 16 Oct 2026) and printed one line per exported skill. If it seems stuck, wait for Xcode to finish launching.
- It changes the user's own setup, so ask before running it, or let the user run it. Export outside any repo and never commit Apple's skill text.
- Don't export into `~/.claude/skills`. That loads all 10 skills in every Claude Code session. `app-resizability` also triggers on the same request as `duo-start` and runs every task on its list at once, which skips duo-start's report-first rule.
- To use only `app-resizability` in Claude Code, copy that one folder, with the user's consent: `cp -R ~/xcode-skills/app-resizability ~/.claude/skills/`. For another agent, point it at `~/xcode-skills/app-resizability/SKILL.md`, or copy the folder into that agent's own skills folder.
- If `duo-start` and `app-resizability` both load for one request, `duo-start` goes first. Run `app-resizability` at duo-start's Step 4, after the first-pass report.
- Inside Xcode, no export is needed: ask Xcode's coding assistant to "get my app ready for iPhone Duo" ([prepare page](https://developer.apple.com/iphone-duo/prepare/)).

Order of fixes after the first-pass report: App Resizability first for the generic fixes, then `duo-lint` to catch what it missed, then the Duology skill for each Duo-specific problem.

## Outside Duology

- **Flutter, React Native, Capacitor:** [mirzaaghazadeh/iphone-duo-skills](https://github.com/mirzaaghazadeh/iphone-duo-skills) (MIT). Duology covers native SwiftUI and UIKit only.
- **SwiftUI in general:** Apple's `swiftui-specialist` skill, or the community skills credited in Duology's README.
