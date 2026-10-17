# Concept-shot mistakes

Foldable concepts on Dribbble, Behance and in pitch decks repeat the same mistakes. Most come from designing one flat, wide picture instead of an app that changes shape. Check every concept for these, and file each one under its rule.

## Text across the fold (R4)

The most common one. A headline, a price, a paragraph or a text button runs straight across the inner display, with the fold through the middle of the words.

- **Why it fails.** Partly folded, the display curves through the centre. A line of text across it bends away and reads as two pieces. Apple shows the same thing with a photo spread across a book's spine ([talk 111463, 1:29](https://developer.apple.com/videos/play/tech-talks/111463/?time=89)). System text and images move away from the curve ([talk 111466, 0:28](https://developer.apple.com/videos/play/tech-talks/111466/?time=28)); custom views must do it themselves ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)).
- **How to spot it.** Draw the fold band (x 455–495 pt held wide, see [frames.md](frames.md)). Any static text that crosses it is a finding.
- **Severity.** Major. Blocker if the text is the only label of a control people must use.
- **Fix.** Keep each text block inside one region. Or set two columns with the fold as the gap. Or move the block to the leading or trailing part.
- **Not a finding.** Scrolling body text that passes under the fold. Apple says scrolling content doesn't need to avoid it ([talk 111466, 9:28](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)). Do flag its line length if one column spans the whole 951 pt width.

## The subject on the fold (R4, R1)

A hero photo with a face, a product or a logo exactly on the centre line. Flat it's fine; folded, the subject bends. Fix: move the focal point off the centre, or split the hero into two images. A cropped subject on the other display is R1.

## A button in the middle (R4)

A floating action button, a Play button or a "Get started" button centred on the inner display. It lands in the fold when the phone is partly folded. Fix: let the system place it (toolbar, sheet), or move it to the trailing or bottom part while the fold is active.

## Odd columns on the inner display (R5)

Three product cards or five photos across the inner display. The fold cuts the middle tile. Fix: an even count, with the fold in the middle gap. Odd counts are fine on the outer display.

## A horizontal tab bar on the closed phone (R6)

A bottom tab bar and a top navigation bar on the outer display, copied from other iPhones. On iPhone Duo the system puts both in one vertical bar on the trailing edge, closed and open in landscape ([HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)). The reverse mistake: side bars on the inner display held tall, where Apple keeps horizontal bars.

## Symmetric margins (R6)

Content centred on the full width with equal margins, under or against the vertical bar. Space for content is asymmetric on iPhone Duo; most content needs an offset, which the safe area gives you ([talk 111466, 6:33](https://developer.apple.com/videos/play/tech-talks/111466/?time=393)). Exception: immersive screens that don't scroll may centre on the full display if nothing interactive sits under the bar.

## Controls in the camera corner (R4)

Buttons in the top-trailing corner of the outer display, where the camera and status bar sit. Closed, in portrait, that column is 84 pt wide (measured on the simulator). Fix: keep controls inside the safe area.

## Two different apps (R10, R2)

A "closed app" and an "open app" with different navigation, different features or a different look. People open and close the phone often; Apple asks for the same functionality and state on both ([HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)). The open layout may add one level of hierarchy, nothing more.

## Features that need a pose (R10, R7)

"Prop it on the table to unlock the timer." Apple says not to tie functionality to a pose ([talk 111466, 3:42](https://developer.apple.com/videos/play/tech-talks/111466/?time=222)). A tabletop layout may rearrange controls; it must not add or remove them.

## A stretched iPhone frame (R3)

A frame made by widening another iPhone mockup, often with the wrong aspect ratio or a made-up ratio such as "4:3". Apple gives no ratio. The outer display is 466 × 678 pt and the inner one 951 × 669 pt held wide; see [frames.md](frames.md). Fix: start from Apple's iPhone Duo bezels in [Apple Design Resources](https://developer.apple.com/design/resources/).

## Pose names as if they were features (all rules)

Specs that say "in tabletop mode the app calls the posture API". There is no posture API. The hinge reports closed, partly open and fully open, plus an angle, and Apple says to use it for effects only. Layout comes from size classes, the view's size, arrangements and reserved regions ([talk 111464, 2:35](https://developer.apple.com/videos/play/tech-talks/111464/?time=155)). Review the layout, not the pose name.

## One screen, never resized (R8, R3)

A concept shows one wide frame and nothing else. Real apps also run in a Split View half and under a pinned Picture in Picture video ([talk 111466, 0:28](https://developer.apple.com/videos/play/tech-talks/111466/?time=28)). Ask for those frames; mark R8 Check until you have them.

## Letterboxed "safe" concepts (R1)

A concept that plays it safe by showing a normal iPhone layout in the middle of the inner display, with wallpaper around it. That is what an app built with an old SDK looks like on iPhone Duo ([prepare page](https://developer.apple.com/iphone-duo/prepare/)). It is a Blocker, not a design choice.
