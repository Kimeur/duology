# Contributing to Duology

Thanks for helping. Duology is useful only if every rule in it is true, so contributions follow three rules.

1. **Source every API claim.** Link the Apple documentation page or Tech Talk it comes from, in the skill and in `reference/sources.md`. Explain it in your own words; don't paste Apple's text.
2. **Say where you tested it.** Every `SKILL.md` has a `verified:` line, for example `verified: Xcode 27.1 (27A9275), iOS 27.1 simulator, device: no`. Change `device` to `yes` only after testing on a real iPhone Duo.
3. **Add a test task.** A new skill comes with at least one task in `evals/tasks/` that shows the skill changes what Claude produces.

## Good first contributions

- A new layout pattern for `duo-patterns`, with a screen in the gallery app
- A new app recipe
- A test task for an existing skill
- A correction to an API claim, with the Apple link

## Found a wrong API claim?

[Open an issue](https://github.com/Kimeur/duology/issues/new) with the Apple link that shows the correct behaviour.

## Style

Short sentences, plain words, active voice. Keep each `SKILL.md` under about 300 lines and move details into its `references/` folder.

Duology is not affiliated with Apple Inc. Don't use Apple logos or images in contributions.
