# Use cases

When two people on one iPhone Duo works, what each half shows, and who owns which control. These are Duology's recommendations. Apple has no page on shared-screen use; the Apple rules they lean on are linked.

## The rule for all of them

Both people can read both halves. Never put a password, PIN, card number, private message, staff note or another customer's data on either side. Sign-in, payment and purchases happen before or after the shared part, upright, by the phone's owner.

## Two-player games

| | |
|---|---|
| Seating | face to face on a table, or side by side on a sofa; let them choose |
| Gate | `.together` for races and buzzers; `.takeTurns` for board and card games |
| Each half | that player's board or hand, controls and score; the other player's score small, if at all |
| Destructive controls | Leave and Restart on one seat, confirmed in place |
| Haptics | own successes and the win; not mistakes |

- Make the game playable in every pose and fill the screen; change the aspect ratio before you letterbox ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)).
- Closed, each half is small (382 × 321 pt, *measured*). Keep the same rules and pieces; shrink spacing and labels, not touch targets.
- A race is fair only if both halves get the same space. `SharedSplit` gives exact halves; don't let a long name push the seam.
- Keep the rules in plain Swift and test them on the Mac ([testing.md](testing.md#rules-on-the-mac)).
- Shared moments (countdown, winner) can span both halves, but show them twice, once per half and turned for each person, rather than once across the seam.

## Teaching: tutor and learner

| | |
|---|---|
| Seating | side by side at a desk is most common; face to face across a table also works |
| Gate | `.takeTurns`, or `.together` with the tutor's controls gated to the tutor seat |
| Tutor half | the answer, hints to reveal, Next and Reset |
| Learner half | the exercise and the learner's input only |
| Destructive controls | Reset and End on the tutor seat |

- The learner can't advance or reveal answers. Gate those actions to the tutor seat in the model, not by hiding buttons.
- Show the tutor what the learner sees (a small live copy of the exercise) so the tutor never has to lean over.
- Keep the learner's half free of the tutor's notes. The learner can read them.

## Showing a customer

A quote, a plan, a product choice, a form to confirm.

| | |
|---|---|
| Seating | face to face across a counter or desk |
| Gate | `.together`, with editing gated to the staff seat |
| Staff half | editing, prices, options, Cancel |
| Customer half | a read-only summary and one Confirm |
| Destructive controls | Cancel and Start again on the staff seat |

- The customer's Confirm is the only action on their side. Make it big, clear and reversible until the staff side completes the sale.
- Assume the customer reads the staff half. Show no margins, commissions, other customers or internal notes there either.
- Payment and identity checks use the system's own UI, upright, after the shared part.

## Kid and parent

| | |
|---|---|
| Seating | side by side is most common; face to face for games |
| Gate | `.together` for play; parent-only actions gated to the parent seat |
| Kid half | big targets, few words, no settings, no links out, no purchases |
| Parent half | the same play, plus Stop and settings |
| Destructive controls | Leave on the parent seat, confirmed in place, so a child can't end the session by accident |

- Apps in the Kids category must keep links out of the app and purchases behind a parental gate ([App Review Guidelines 1.3](https://developer.apple.com/app-store/review/guidelines/#kids-category)). Put that gate in a parent-only area, not inside the kid's half.
- A kid's half should still work alone if the parent steps away: no timers that need the parent's input to continue.
- Give the kid's half the simpler variant, not a smaller one. Same touch target sizes.

## Two languages, one conversation

| | |
|---|---|
| Seating | face to face |
| Gate | `.together`, or `.takeTurns` if only one person may speak at a time |
| Each half | the other person's words in this person's language, and a button to speak |

- Turn the far half so each person reads their text the right way up.
- Don't use the keyboard during the conversation: it does not turn with the half ([input.md](input.md#typing)).

## When not to share

- One person who needs more room: use `duo-patterns`.
- Anything one person types for long.
- Anything private (see the rule at the top).
- Split View: the app already has only half the inner display, and two people would split it again.
