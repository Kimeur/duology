<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/banner-dark.svg" />
  <source media="(prefers-color-scheme: light)" srcset="docs/assets/banner-light.svg" />
  <img src="docs/assets/banner-light.svg" alt="Duology: design, build, test and ship apps for iPhone Duo with Claude Code" width="100%" />
</picture>

# Duology

### Claude Code skills for designing, building, testing and shipping apps on iPhone Duo.

**Your agent learned iOS before the iPhone Duo existed. Duology teaches it the rest.**

[![GitHub stars](https://img.shields.io/github/stars/Kimeur/duology?style=flat-square&color=f4c430)](https://github.com/Kimeur/duology/stargazers)
[![Status](https://img.shields.io/badge/status-v0.1_in_progress-9a5a00?style=flat-square)](ROADMAP.md)
[![Skills](https://img.shields.io/badge/skills-36_planned-2b55c7?style=flat-square)](#whats-inside)
[![Recipes](https://img.shields.io/badge/app_recipes-8-2b55c7?style=flat-square)](#app-recipes)
[![Built for Xcode 27.1](https://img.shields.io/badge/built_for-Xcode_27.1_·_iOS_27.1-1d7a4b?style=flat-square)](#verified-on)
[![Claude Code plugin](https://img.shields.io/badge/Claude_Code-plugin-d97757?style=flat-square)](#quick-start)
[![skills.sh](https://skills.sh/b/Kimeur/duology?style=flat-square)](https://skills.sh/Kimeur/duology)
[![Last commit](https://img.shields.io/github/last-commit/Kimeur/duology?style=flat-square)](https://github.com/Kimeur/duology/commits)
[![MIT license](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

<!-- Trendshift badge: add once the repo is listed (trendshift.io assigns the id)
<a href="https://trendshift.io/repositories/ID" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/repositories/ID" alt="Kimeur%2Fduology | Trendshift" width="250" height="55"/></a>
-->

[Quick start](#quick-start) · [What's inside](#whats-inside) · [Patterns](#layout-patterns) · [Recipes](#app-recipes) · [Proof](#proof-not-promises) · [FAQ](#faq) · [Roadmap](ROADMAP.md)

<code>/plugin marketplace add Kimeur/duology</code>

</div>

> [!IMPORTANT]
> **Duology is being built in the open.** v0.1 (11 skills, `/duo-doctor`, `/duo-new`, `/duo-audit`) lands by 30 October 2026. The full pack of 36 skills is planned for v1.0 in January 2027. Until v0.1 is tagged, the install commands below won't work yet. Star or watch the repo to get the release. See the [roadmap](ROADMAP.md).

> [!NOTE]
> Duology is a community project. It is not affiliated with, endorsed by or sponsored by Apple Inc.
> iPhone is a trademark of Apple Inc. Every API claim links to Apple's own documentation in [`reference/sources.md`](reference/sources.md).

<div align="center">
<br />
<img src="docs/assets/poses.svg" alt="The four ways people hold iPhone Duo: closed, open, book and tabletop" width="100%" />
<br /><br />
</div>

---

## The problem

iPhone Duo is in stores from 23 October 2026. It has a 5.4″ outer display, a 7.6″ inner display and a fold. Coding agents were trained before it existed, so when you ask one to "make this work on Duo" it writes code Apple tells you not to write:

- it measures `UIScreen.main.bounds`, which is ambiguous on a phone with two displays;
- it branches on device orientation or `userInterfaceIdiom` and treats "regular width" as "iPad";
- it puts buttons and text where the phone folds;
- it rebuilds the screen when you unfold, so you lose your scroll position, your typing or your video;
- it designs one screen and stretches it, instead of a layout for each way people hold the phone.

Apple published the rules in six Tech Talks, a HIG page and the iOS 27.1 SDK. Duology turns them, plus what we learned shipping a real Duo app, into skills Claude Code loads when it needs them.

### How Duology fixes it

1. **It knows the device.** Size classes, reserved regions, `ArrangementView`, vertical bars, the hinge, scenes and both front cameras. Each fact is checked against the iOS 27.1 SDK.
2. **It designs, not just compiles.** Named layout patterns, guidance for every pose, fold-and-unfold transitions, thumb reach and two-person use, each with a SwiftUI recipe.
3. **It builds whole apps.** Eight recipes create a project that builds and runs on the iPhone Duo simulator.
4. **It checks its own work.** `duo-lint` finds code Apple warns against. `/duo-poses` runs your app in every pose and screenshots it. Failures go back to Claude with the rule that was broken.

<div align="center">
<img src="docs/assets/how-it-works.svg" alt="You ask Claude Code, Duology guides the code, Xcode 27.1 builds it, duo-lint and the pose check verify it, then you ship" width="100%" />
</div>

## Quick start

<details open>
<summary><strong>Claude Code</strong> · plugin marketplace</summary>

**You need:** a Mac with Apple silicon, [Xcode 27.1](https://developer.apple.com/news/releases/) (27A9275 or later) and Claude Code.

```bash
/plugin marketplace add Kimeur/duology
/plugin install duology@duology
```

Add the other plugins when you need them:

```bash
/plugin install duology-design@duology
/plugin install duology-features@duology
/plugin install duology-recipes@duology
/plugin install duology-ship@duology
```

Restart Claude Code, then check your setup:

```
/duo-doctor
```

It checks Xcode 27.1, the iPhone Duo simulator in Device Hub, and Xcode's agent connection (`xcrun mcpbridge`). It tells you how to fix anything that fails.

</details>

<details>
<summary><strong>Cursor, Codex, Copilot, Gemini CLI and others</strong> · skills only</summary>

```bash
npx skills add Kimeur/duology
```

The CLI finds your agent and puts the skills where it looks. You get every skill. Slash commands, review agents and the lint hook are Claude Code features, so on other agents ask for them in plain words ("run the Duo pose check").

One skill only:

```bash
npx skills add Kimeur/duology --skill duo-layout
```

</details>

<details>
<summary><strong>Manual</strong></summary>

Each skill is a folder with a `SKILL.md`. Copy the ones you want into `.claude/skills/` (project) or `~/.claude/skills/` (everyone on this Mac).

</details>

### Ask Claude

```text
Make my app great on iPhone Duo. Start with an audit, fix what it finds,
then show me every pose.
```

```text
/duo-new recipe-notes-ai
A notes app: list on the left, note on the right, an AI summary pane when the phone is open.
```

```text
Review these Figma frames for iPhone Duo and tell me what breaks when the phone is half folded.
```

## What's inside

**36 skills in 5 plugins, plus 6 commands and 2 review agents.** Claude loads a skill only when the task needs it, so the pack costs almost nothing while it sits unused.

<details open>
<summary><strong>duology</strong> · foundation: setup, layout, continuity</summary>

| Skill | Use it when |
|---|---|
| `duo-start` | You're not sure where to begin. Works out SwiftUI or UIKit, new or existing app, and picks the right skills. |
| `duo-setup` | Setting up Xcode 27.1 next to an older Xcode, Device Hub, Xcode's agent connection, Swift 6 project settings. |
| `duo-layout` | Content lands in the fold. Size classes, uneven safe areas, reserved regions, `ArrangementView` and when to use your own split instead. |
| `duo-navigation` | Toolbars and tab bars. Vertical bars, tabs that become a sidebar, `NavigationSplitView`, sheets, overflow. |
| `duo-continuity` | Something resets when you fold. Scroll, playback, typed text, selection and navigation survive fold, unfold, rotate and resize. |
| `duo-scenes` | Several windows, Split View, and showing something on the outer display while the inner one is in use. |

</details>

<details>
<summary><strong>duology-design</strong> · design and interaction</summary>

| Skill | Use it when |
|---|---|
| `duo-design-system` | Setting up spacing, grids (even column counts), type for both displays, iOS 27 Liquid Glass, corners, touch targets. |
| `duo-patterns` | Choosing a layout. List-detail, supporting pane, two-page, dual view, extended canvas, feed reflow, tabs to sidebar, displacement. |
| `duo-postures` | Designing for book, tabletop, standing and flipped. The hinge as an input, used sparingly. |
| `duo-transitions` | The move from closed to open should feel like one app, not a reload. |
| `duo-ergonomics` | Two-handed grip, thumb reach, controls on the side edge. |
| `duo-shared-screen` | Two people use one phone: games, teaching, showing something to a customer. |
| `duo-accessibility` | VoiceOver order across panes, Dynamic Type on both displays, Reduce Motion, hardware keyboard. |
| `duo-design-review` | Reviewing screenshots or Figma frames against the 15-point Duo checklist. |

</details>

<details>
<summary><strong>duology-features</strong> · iOS 27 features on two displays</summary>

| Skill | Use it when |
|---|---|
| `duo-intelligence` | Adding Foundation Models: an AI pane when open, a short summary when closed. |
| `duo-app-intents` | Siri, app actions and onscreen awareness with App Intents. |
| `duo-camera` | Capture apps. Each camera by the way it faces, the virtual front camera, a preview on the outer display. |
| `duo-media` | Video and audio. Tabletop player, Picture in Picture, "up next". |
| `duo-reading` | Books and documents. Two pages in book pose, notes beside the text. |
| `duo-games` | Games. Fill the screen in every pose, keep touch controls off the fold. |
| `duo-swiftui-27` | The iOS 27 SwiftUI changes that matter on Duo: reordering, swipe actions on any view, the `@State` macro, new toolbar APIs. |
| `duo-system-surfaces` | Widgets, Live Activities, StandBy and Controls on either display. |

</details>

<details>
<summary><strong>duology-recipes</strong> · app recipes</summary>

See [App recipes](#app-recipes).

</details>

<details>
<summary><strong>duology-ship</strong> · testing and App Store</summary>

| Skill | Use it when |
|---|---|
| `duo-testing` | Writing tests that hold up on the Duo simulator: logic tested on the Mac, launch switches, UI tests that really reach SwiftUI gestures. |
| `duo-pose-matrix` | Checking every pose with screenshots and the accessibility tree. |
| `duo-lint` | Finding code Apple warns against before it ships. |
| `duo-performance` | Resizing smoothly at 120 Hz when the phone opens. |
| `duo-app-store` | Duo screenshots (required from April 2027), metadata, App Review notes, privacy manifest. |
| `duo-migrate` | Bringing an existing app over: which SDK you build with changes how it looks on Duo. |

</details>

### Commands and agents

| Command | What it does |
|---|---|
| `/duo-doctor` | Checks Xcode 27.1, the Duo simulator and Xcode's agent connection. |
| `/duo-new <recipe>` | Creates a new app from a recipe and runs it on the Duo simulator. |
| `/duo-audit` | Runs `duo-lint` and the checklist on your app and lists what to fix, most serious first. |
| `/duo-poses` | Runs your app closed, open, in book pose and in tabletop, and saves a screenshot of each. |
| `/duo-review` | Design critique of screenshots or Figma frames. |
| `/duo-ship` | App Store checklist for Duo: screenshots, metadata, review notes. |

| Agent | What it does |
|---|---|
| `duo-design-reviewer` | Reviews a screen the way a Duo design lead would, with the rule behind each comment. |
| `duo-pose-tester` | Runs the pose check and reports each failure with its screenshot. |

<details>
<summary><strong>duo-lint</strong> · example report</summary>

The lines below show the report format. They are an example, not output from a real project.

```text
$ duo-lint Sources/
Sources/Feed/FeedView.swift:42     UIScreen.main.bounds     ambiguous on two displays; use the view's geometry
Sources/App/RootView.swift:18      userInterfaceIdiom       pick layout by size class, not device type
Sources/Player/Controls.swift:77   frame(width: 390)        fixed width; let the layout size it
3 findings · 0 errors · 3 warnings
```

Add the optional hook and Claude sees these warnings right after it edits a Swift file.

</details>

## Layout patterns

Every pattern in `duo-patterns` comes with a SwiftUI recipe and a screen in the gallery app ([`samples/DuologyGallery`](samples/DuologyGallery)).

| Pattern | Closed | Open | Good for |
|---|---|---|---|
| List-detail | list, then detail | both side by side | mail, messages, settings |
| Supporting pane | main content, pane in a sheet | main content with a narrower pane | comments, tools, "up next" |
| Two-page | one page | two pages, one per side | books, documents, slides |
| Dual view | one view, toggle | the same data two ways | list and map, text and preview |
| Extended canvas | canvas | the canvas spans the fold, tools stay clear of it | maps, drawing, big tables |
| Feed reflow | 1 or 2 columns | an even number of columns | photos, shops, news |
| Tabs to sidebar | tab bar on the side | sidebar | apps with many sections |
| Displacement | n/a | controls move off the fold, scrolling content stays put | any screen with controls near the middle |

## App recipes

`/duo-new <recipe>` creates the project, builds it and opens it on the iPhone Duo simulator.

| Recipe | What you get |
|---|---|
| `recipe-finance-dashboard` | Balance when closed; balance, charts and transactions when open. |
| `recipe-notes-ai` | Notes list and editor, with an AI summary pane on the inner display. |
| `recipe-media-player` | Player that moves to tabletop on its own, with "up next" and Picture in Picture. |
| `recipe-reader` | Two pages in book pose, and it remembers where you were. |
| `recipe-shop` | Product shelf beside product details, with a two-pane paywall. |
| `recipe-camera-studio` | The person you film sees themselves on the outer display. |
| `recipe-two-player-game` | Each player gets half the screen, with the game logic tested on the Mac. |
| `recipe-kids-learning` | A parent check, a privacy manifest, and nothing tracked. |

## Proof, not promises

Every skill has tasks in [`evals/`](evals). We run each task with Claude Code twice, with and without Duology, in the same sample project. A run passes when the app builds, `duo-lint` finds nothing and every pose screenshot passes the checklist.

| Task | Without Duology | With Duology |
|---|---|---|
| Make an existing list app work on Duo | *first results with v0.1* | *first results with v0.1* |
| Keep video playing through fold and unfold | *first results with v0.1* | *first results with v0.1* |
| Build a two-player game on one phone | *first results with v0.1* | *first results with v0.1* |
| Tabletop layout for a video call | *first results with v0.1* | *first results with v0.1* |

Full results and how to rerun them: [`evals/README.md`](evals/README.md).

### Verified on

| | Status |
|---|---|
| Xcode 27.1 (27A9275) | ✅ |
| iPhone Duo simulator, iOS 27.1 | ✅ |
| iPhone Duo device | ⏳ planned for v0.2 |
| iOS 27.2 beta | not tracked until release |

Each `SKILL.md` repeats this in its front matter, so you can see how far every rule has been tested.

## FAQ

<details>
<summary><strong>How is this different from other iPhone Duo skill repos?</strong></summary>

Other repos explain the Duo APIs well, and [mirzaaghazadeh/iphone-duo-skills](https://github.com/mirzaaghazadeh/iphone-duo-skills) also covers Flutter, React Native and Capacitor. Duology goes from design to the App Store for native SwiftUI and UIKit apps: layout patterns, app recipes, a linter, a pose check and published test results.

</details>

<details>
<summary><strong>Xcode 27 already ships agent skills. Why add more?</strong></summary>

Apple's skills (export them with `xcrun agent skills export`) cover SwiftUI in general and making apps resizable. Duology points to them and doesn't copy them. It adds what they don't cover: design for each pose, two-person use, recipes and verification.

</details>

<details>
<summary><strong>Do I need an iPhone Duo?</strong></summary>

No. Everything runs on the iPhone Duo simulator in Xcode 27.1. A few things only show on real hardware (how the hinge feels, camera handoff, 120 Hz transitions); those skills say so.

</details>

<details>
<summary><strong>Does it work with UIKit?</strong></summary>

Yes. Each layout and navigation skill gives SwiftUI and UIKit versions.

</details>

<details>
<summary><strong>Does Duology send any data anywhere?</strong></summary>

No. Skills are text files, and `duo-lint` and the pose check run on your Mac.

</details>

## Documentation

- [Roadmap](ROADMAP.md): what's planned and when.
- [Device facts](reference/device-facts.md): displays, cameras, poses, size classes.
- [API index](reference/api-index.md): every Duo API with its Apple doc link.
- [Sources](reference/sources.md): the Apple pages and talks behind each rule.
- [Contributing](CONTRIBUTING.md): how to add a skill, a pattern or a recipe.

## Star history

<a href="https://www.star-history.com/?repos=Kimeur%2Fduology&amp;type=date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=Kimeur/duology&amp;type=date&amp;theme=dark&amp;legend=top-left" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=Kimeur/duology&amp;type=date" />
    <img alt="Duology GitHub star history" src="https://api.star-history.com/chart?repos=Kimeur/duology&amp;type=date" />
  </picture>
</a>

## Contributing

Pull requests are welcome, especially new patterns, recipes and test tasks. Each change needs:

- a link to the Apple doc or talk behind any API claim;
- a test task in `evals/` for any new skill;
- a `verified:` line saying where you tested it.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you start. Found a wrong API claim? [Open an issue](https://github.com/Kimeur/duology/issues/new?template=api-correction.yml) with the Apple link.

## Acknowledgements

Built on Apple's iPhone Duo Tech Talks and Human Interface Guidelines, and on design ideas from Microsoft's Surface Duo patterns, Android's adaptive layouts and Samsung's Flex mode. Thanks to the Swift agent-skills community: [twostraws](https://github.com/twostraws/Swift-Agent-Skills), [AvdLee](https://github.com/AvdLee/SwiftUI-Agent-Skill), [Dimillian](https://github.com/Dimillian/Skills) and [mirzaaghazadeh](https://github.com/mirzaaghazadeh/iphone-duo-skills).

## License

[MIT](LICENSE). Apple documentation is linked, never copied. Apple, iPhone and Xcode are trademarks of Apple Inc.
