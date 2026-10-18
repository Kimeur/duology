# Grips and reach on iPhone Duo

Depth for [`../SKILL.md`](../SKILL.md). For each way of holding the phone: what Apple says, what follows for layout, and what is Duology's judgement.

Labels: a link means Apple says it. *Measured* means we ran it on the iPhone Duo simulator (iOS 27.1). *Derived* means arithmetic on Apple's numbers. *Judgement* means Duology's design advice. *Unverified* means we could not confirm it.

## Sources

| Tag | Page |
|---|---|
| HIG Duo | [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo): Anatomy, Device poses, Best practices, Reserved regions, Vertical controls |
| HIG iOS | [Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios): Ergonomics, Best practices |
| Hub | [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) |
| 111461 | [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) |
| 111462 | [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/) |
| 111463 | [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/) |
| 111466 | [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) |
| Specs | [iPhone Duo – Technical Specifications](https://www.apple.com/iphone-duo/specs/) |

Duology's full list, with IDs and check dates: [reference/sources.md](https://github.com/Kimeur/duology/blob/main/reference/sources.md). We searched all the pages above for "thumb", "reach", "hold", "hand", "grip", "left" and "stable".

## Why the bars moved to the side

Apple gives four reasons. Each one matters for where your own controls go.

| Reason | Source |
|---|---|
| Closed, the screen is wide and short for an iPhone, so bars on the side leave more height for content. | HIG Duo (Best practices); [111466, 1:10](https://developer.apple.com/videos/play/tech-talks/111466/?time=70); [111462, 0:41](https://developer.apple.com/videos/play/tech-talks/111462/?time=41) |
| On the side, controls are easier to reach. The closed-phone example names the right thumb. | [111466, 1:10](https://developer.apple.com/videos/play/tech-talks/111466/?time=70); [111462, 0:47](https://developer.apple.com/videos/play/tech-talks/111462/?time=47); HIG Duo (Vertical controls) |
| The bars keep the same place when you open the phone held wide, so nothing jumps between displays. | HIG Duo (Anatomy); [111462, 1:02](https://developer.apple.com/videos/play/tech-talks/111462/?time=62) |
| The bar lines up with the hardware: the same spot next to the outer camera, and the same edge in right-to-left languages. | HIG Duo (Vertical controls); [111462, 4:18](https://developer.apple.com/videos/play/tech-talks/111462/?time=258) |

The inner display held tall is the exception: it has room for normal top and bottom bars ([111466, 5:27](https://developer.apple.com/videos/play/tech-talks/111466/?time=327)).

The vertical bar holds, from top to bottom: the Dynamic Island, the status bar, top-bar items, bottom-bar items, then the tab bar ([111466, 6:04 to 6:15](https://developer.apple.com/videos/play/tech-talks/111466/?time=364); HIG Duo, Vertical controls). Apple reserves the top for Back or Close, then prominent actions such as Done, and says this order keeps the important actions reachable (HIG Duo, Vertical controls).

## One hand, closed

**Apple:** closed, the phone is compact and fits comfortably in the hand ([111466, 0:28](https://developer.apple.com/videos/play/tech-talks/111466/?time=28)). Controls move to the right side partly so the right thumb reaches them ([111466, 1:10](https://developer.apple.com/videos/play/tech-talks/111466/?time=70)). On any iPhone, the middle and bottom of the display are easier to reach than the top (HIG iOS, Best practices).

**Measured** (closed, portrait, left to right): the window is 466 pt wide. The bar takes an 84 pt strip on the right; the content area is 382 × 562 pt below the title, from y 82 to y 644. Close and Done sat at the top of the bar, Share and Delete at its foot.

**Judgement:**

- Easy: the bottom half and the whole bar edge.
- Hard: the top corner away from the bar (top left in left-to-right use). Don't put frequent actions there.
- Swipe actions in list rows and swipe-to-go-back stay useful, as Apple says for every iPhone (HIG iOS).

*Derived:* the closed phone is 84.1 mm wide (Specs), wider than other iPhones; this is why the far corner is hard.

## Two hands, open and held wide

**Apple:** the bars stay on the side of the inner display, keeping controls within easy reach ([111466, 1:51](https://developer.apple.com/videos/play/tech-talks/111466/?time=111)). Controls that belong to the leading pane stay with it, as Mail keeps list controls above the list (HIG Duo, Vertical controls).

**Derived:** open, the phone is 164.6 × 117.8 mm (Specs). The centre is about 82 mm from either side edge. The window is 951 × 669 pt held wide (*measured* by [device-facts](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#how-we-measured)).

**Measured by Duology** (see `duo-layout` and `duo-patterns`): the fold is a 40 pt band, x 455–495, top to bottom. The status bar corner is an occlusion at x 867–951, y 0–124. An inactive occlusion at x 677–735, y 21–58 is likely the inner camera (our reading).

**Judgement:**

- Easy: the lower two thirds of the left and right bands, and the bar.
- Hard: the top centre. For screenshot reviews, take it as the middle third of the width in the top half: about x 317–634, y 0–335 pt held wide. The fold's top end runs through it.
- Controls for the leading pane may sit at the top of that pane, as Apple's Mail does. Keep the ones people tap many times in a row lower, or in the bar.

## Book grip

**Apple:** folded like a book, the display curves through the centre. Text and images move away from the curve so they're easier to read; buttons move to the sides, where they are easier to target ([111466, 2:03 and 2:09](https://developer.apple.com/videos/play/tech-talks/111466/?time=129)). Alerts move to the trailing side, near where they will appear once the phone closes ([111463, 4:09](https://developer.apple.com/videos/play/tech-talks/111463/?time=249)). Split views even out to 50/50 at the fold (HIG Duo, Reserved regions).

Apple's Podcasts example: with the transcript hidden, the Now Playing view stays in the left region instead of centring, so its controls stay reachable and clear of the fold ([111463, 10:01](https://developer.apple.com/videos/play/tech-talks/111463/?time=601)).

**Judgement:**

- Each hand owns one half. Put each half's controls toward its outer edge and lower part.
- Never anything interactive in the fold band. A control centred on the fold line while the phone is flat must move when it folds; see displacement in `duo-patterns`.
- Move as little as you can: Apple warns that moving an element far from its source weakens their link ([111463, 3:14](https://developer.apple.com/videos/play/tech-talks/111463/?time=194)).

## Tabletop, hands-free

**Apple:**

- iPhone Duo is good for hands-free use on a table. Media can sit at the top, tappable controls on the steady lower half ([111466, 4:24 and 4:48](https://developer.apple.com/videos/play/tech-talks/111466/?time=264)).
- Partly folded in portrait, the system shifts controls into the lower half, easier to reach while the phone stays steady on the surface ([111466, 2:32](https://developer.apple.com/videos/play/tech-talks/111466/?time=152)).
- The top region suits content seen from a distance; the bottom region suits controls, a more stable surface for touch ([111463, 4:23 to 4:43](https://developer.apple.com/videos/play/tech-talks/111463/?time=263)).
- A special layout for this pose is optional. If you make one, keep all the same controls and the same hierarchy ([111466, 4:55 and 5:03](https://developer.apple.com/videos/play/tech-talks/111466/?time=295)).

**Judgement:**

- People sit back from a phone on a table. Use larger type for content in the top half and `.controlSize(.large)` for controls in the bottom half.
- Avoid controls in the top half: a tap there pushes against the raised half. How firm the hinge feels is *unverified*; it needs a real device.
- An overlay `ArrangementView` puts its primary view in the bottom part when the fold runs side to side ([Hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo#Arrange-views-in-different-poses)). Make the controls the primary.

## Two hands, open and held tall

**Apple:** this is the one pose with horizontal bars, because the display has plenty of height ([111466, 5:27](https://developer.apple.com/videos/play/tech-talks/111466/?time=327)).

**Judgement:** treat it like a large phone held low. The bottom bar is the easy zone; the top bar and the top centre are hard. Bottom-bar items from your toolbar land in the easy zone without extra work.

## Split View

**Apple:** two apps share the inner display 50/50. Each app's controls sit on its outer edge, within reach of the thumb and away from the fold ([111466, 3:07](https://developer.apple.com/videos/play/tech-talks/111466/?time=187)). Safe areas are asymmetric: the bar can be on the left in Split View and in landscape, so handle each side on its own ([111461, 7:12 and 7:25](https://developer.apple.com/videos/play/tech-talks/111461/?time=432)).

**Judgement:** in the left app, your floating control belongs bottom left. `ThumbCorner` with `.automatic` does this when `toolbarVerticalEdge` reports that edge. *Unverified:* we did not measure Split View.

## Which side for a floating control

Apple gives no rule for your own floating controls. The evidence points to the bar's side:

- Apple put the bars on the side partly so the thumb reaches them ([111466, 1:10](https://developer.apple.com/videos/play/tech-talks/111466/?time=70); [111462, 0:47](https://developer.apple.com/videos/play/tech-talks/111462/?time=47)).
- The example on Apple's `toolbarVerticalEdge` page aligns a floating palette to the trailing edge when the bar is trailing, and to the leading edge otherwise ([doc](https://developer.apple.com/documentation/swiftui/environmentvalues/toolbarverticaledge)).
- In Split View, Apple moves each app's controls to its outer edge to keep them near the thumb ([111466, 3:07](https://developer.apple.com/videos/play/tech-talks/111466/?time=187)).

**Judgement:** default to the bar's side, 16 pt clear of its items. The case for the far side is a left hand holding the closed phone, with the bar on the right. Apple offers no handedness setting, so give people an in-app choice (`HandPreference` in `SKILL.md`) instead of guessing.

## What Apple doesn't say

We found no Apple guidance on these. Treat everything Duology says about them as judgement.

- Left-handed use, or any handedness setting. The iOS 27.1 SwiftUI and UIKit interfaces have no handedness API either.
- Thumb-reach maps or distances for iPhone Duo.
- Whether iOS Reachability works on iPhone Duo.
- How much the raised half moves when someone taps it on a table.

## Prior art outside Apple

Other foldables also put controls in the lower half when the device sits half folded on a table, for example Samsung's [Flex mode](https://developer.samsung.com/galaxy-z/flex-mode.html) and Android's [tabletop posture](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/learn-about-foldables). They describe other hardware: treat them as ideas to test, not rules for iPhone Duo.
