---
id: duo-design-review/screenshot-review
skill: duo-design-review
title: Review real screenshots of the closed phone
readme: no
fixture: review-shots
build: no
lint: no
timeout: 1200
status: ready
---

# Review real screenshots of the closed phone

## Prompt

```text prompt
Review these screenshots of my app for iPhone Duo. frames.md says what each one shows. Write your findings to review.md, most serious first. For each one say what's wrong, where it is on screen, and how to fix it. Tell me too if you need more screenshots to finish the review.
```

## Starting point

Fixture [`review-shots`](../../fixtures/review-shots): two real captures of the [`Places`](../../fixtures/Places) fixture on the iPhone Duo simulator, closed and upright (outer display, 1398 × 2034 px), plus `frames.md`. What they show:

- `places-closed-list.png`: the system put the tab bar and the icon-only sort button in the vertical side bar. The text-only "Edit" button stayed in a horizontal bar at the top. The floating + button covers the "Glass Lake" row.
- `places-closed-detail.png`: the app's own bottom bar (Share, Directions, heart) runs across the bottom, under the system's vertical tab bar, instead of joining it. The header gradient stops at the status bar column.

No open, folded, landscape or Split View frames are included, so a good review asks for them.

## Pass checks

No build or lint: the agent only writes `review.md`.

```sh check report-written
[ -s review.md ] || { echo "review.md is missing or empty"; exit 1; }
```

```sh check finds-custom-bottom-bar
para_has review.md '(bottom|action|custom|tool) ?bar|directions' 'vertical|side ?bar|system|toolbar'
```

```sh check finds-covered-row
para_has review.md '\+|plus|add|floating' 'cover|overlap|obscur|hide|hidden|block|on top of'
```

```sh check finds-bar-item-titles
para_has review.md 'edit|sort' 'title|label|text|symbol|icon'
```

```sh check asks-for-more-frames
para_has review.md 'open|inner|unfold|fold|book|table|landscape|sideways|split view' 'frame|screenshot|capture|shot'
```

```sh check app-unchanged
unchanged places-closed-list.png places-closed-detail.png frames.md
```
