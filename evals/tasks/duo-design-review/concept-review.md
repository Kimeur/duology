---
id: duo-design-review/concept-review
skill: duo-design-review
title: Review a written design spec before it is built
readme: no
fixture: review-concept
build: no
lint: no
timeout: 1200
status: ready
---

# Review a written design spec before it is built

## Prompt

```text prompt
Our designer wrote concept.md for the foldable iPhone (iPhone Duo). Review it before we build anything. Write your findings to review.md, most serious first. For each one say what's wrong, which frame it's in, and what to do instead.
```

## Starting point

Fixture [`review-concept`](../../fixtures/review-concept): one file, `concept.md`, describing four frames of a recipe app. It hides these problems, each tied to a rule in [rubric.md](../../rubric.md):

| Problem | Frame | Rule | Severity |
|---|---|---|---|
| Edit and Share exist only on the open phone | 1, 2 | R10 | Blocker |
| The main "Start cooking" button floats centred on the fold | 3 | R4 | Blocker |
| Opening the phone reloads the list and scrolls to the top | 2 | R2 | Major |
| A custom bottom tab bar with icon-only tabs on the closed phone | 1 | R6 | Major |
| A three-column grid across the full width of the open phone | 2 | R5 | Major |
| 30 pt Next and Back buttons | 4 | R13 | Major |
| Sizes scaled up from another iPhone's designs | notes | R3 | Major |

One line is fine and should not be flagged: Frame 4's scrolling steps run across the fold. Apple says scrolling content doesn't need to avoid it. The reviewer checks that by hand.

## Pass checks

```sh check report-written
[ -s review.md ] || { echo "review.md is missing or empty"; exit 1; }
```

```sh check finds-outer-parity
para_has review.md 'edit|shar' 'closed|outer|front|cover|both displays|every pose|same features|parity'
```

```sh check finds-button-on-fold
para_has review.md 'start cooking' 'fold|hinge|crease'
```

```sh check finds-reset-on-open
para_has review.md 'reload|top of the list|reset|lose|lost|scroll position|jump|start(s)? clean' 'open|unfold'
```

```sh check finds-tab-bar
para_has review.md 'tab' 'vertical|side|title|label|text|system'
```

```sh check finds-odd-grid
para_has review.md 'column|grid' 'three|3|odd|even'
```

```sh check finds-small-targets
para_has review.md 'next|back|30 ?pt|button' '44|small|target|tap'
```

```sh check blockers-first
# A blocker (missing features closed, or the main button in the fold) comes
# before the grid finding.
a="$(first_offset review.md 'start cooking|(edit|shar)[^\n]{0,80}(closed|outer)')"
b="$(first_offset review.md 'column')"
[ "$a" -lt "$b" ] || { echo "the first blocker appears after the grid finding"; exit 1; }
```

## Checklist

None, so the checks above decide the verdict. Before you publish results, also read each `review.md`: a review that tells the designer to keep the scrolling steps clear of the fold, or names an API that doesn't exist, is worse than its score. Note it under the results table.
