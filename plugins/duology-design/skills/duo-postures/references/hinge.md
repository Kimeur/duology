# The hinge: effects, and input as a novelty

iPhone Duo reports its hinge to apps: a status (closed, partially open, fully open) and a continuous angle. Apple shows two uses: the wallpaper zooming as the phone opens, and a guitar app that bends the pitch as the phone folds, like a whammy bar. Apple's line is clear: hinge data is live and suits interactions and effects; layout comes from arrangements and reserved regions ([talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=49)).

## APIs

| Need | SwiftUI | UIKit | Availability |
|---|---|---|---|
| Hear changes | [`onHingeChange(isEnabled:_:)`](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)), with old and new `DeviceHingeContext` | [`UIHingeInteraction`](https://developer.apple.com/documentation/uikit/uihingeinteraction) added to a view; its handler gets an `Update` | iOS 27.1 |
| The hinge | `context.hinge`, a [`DeviceHinge`](https://developer.apple.com/documentation/swiftui/devicehinge)? | `update.hinge`, a [`UIHinge`](https://developer.apple.com/documentation/uikit/uihinge)? | iOS 27.1 |
| Status | `DeviceHinge.Status`: `.closed`, `.partiallyOpen`, `.fullyOpen` (a struct: compare with `==`) | `UIHinge.Status`: `.unknown`, `.closed`, `.partiallyOpen`, `.fullyOpen` | iOS 27.1 |
| Angle | `angle`, an `Angle` | `angle`, a `CGFloat` in radians | iOS 27.1 |
| Turn it off | `isEnabled: false` | `isEnabled = false` | iOS 27.1 |
| Reduce Motion | [`@Environment(\.accessibilityReduceMotion)`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion) | [`UIAccessibility.isReduceMotionEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducemotionenabled) and `UIAccessibility.reduceMotionStatusDidChangeNotification` | iOS 13 / iOS 8 |

Facts from the SDK headers and Apple's pages:

- `hinge` is `nil` on a device without a hinge. In UIKit it is also `nil` when the interaction leaves a hierarchy that reports the hinge ([`UIHingeInteraction`](https://developer.apple.com/documentation/uikit/uihingeinteraction)).
- The angle's update rate and precision are system policy and can change. Use `status` when you only need closed, partly open or open (`UIHinge.h`).
- The system decides the status from the angle and the device orientation ([`DeviceHinge`](https://developer.apple.com/documentation/swiftui/devicehinge)).
- *Measured:* fully open, the probe read `fullyOpen` at 180°. Partly open angles are not yet measured.

## Rules

1. **Never lay out from the hinge.** Status is not pose: open and turned around, the phone is open while your app is on the outer display. Use size classes and `.division`.
2. **Decoration first.** The app works the same with the effect off, on an iPhone without a hinge, on iPad and Mac, and on a phone lying still.
3. **Reduce Motion turns it off.** Apple asks apps to cut zooming, scaling and peripheral motion when the setting is on ([HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Cognitive)). Use `isEnabled: !reduceMotion` and reset the effect.
4. **Input is opt-in and has an alternative.** A control the person turns on, and an on-screen control that does the same job. Some people can't fold the phone with ease, use it on a mount or a stand, or use Switch Control or Voice Control ([HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Mobility)).
5. **No actions at angles.** Folding happens by accident: in a pocket, when someone shifts their grip. Never send, delete, buy or end something because the hinge crossed an angle.
6. **Reset outside `partiallyOpen`.** Closed and fully open are rest states. Return the effect to neutral there, as Apple's guitar example does.
7. **Keep it subtle and short.** Motion should support the experience, not compete with it ([HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion#Best-practices)).
8. **Don't announce angles.** No VoiceOver announcements or haptics on every angle change. If the hinge changes a value, the on-screen control's accessibility value already says so.

## Recipe: a decorative zoom

```swift
import SwiftUI

/// Decoration only: the artwork zooms a little as the phone folds.
/// Off with Reduce Motion. Nothing depends on it.
@available(iOS 27.1, *)
struct HingeZoomArtwork: View {
    let image: Image
    @State private var zoom: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Color.clear takes the space offered; the image fills it and is clipped to it.
        Color.clear
            .overlay {
                image
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(reduceMotion ? 1 : zoom)
            }
            .clipped()
            .accessibilityHidden(true)
            .onHingeChange(isEnabled: !reduceMotion) { _, context in
                // Nil hinge: no hinge in this hierarchy (another iPhone, iPad, Mac).
                guard let hinge = context.hinge, hinge.status == .partiallyOpen else {
                    zoom = 1
                    return
                }
                // 180 degrees is flat. Up to 8 percent larger as the phone closes.
                let folded = 1 - min(max(hinge.angle.degrees / 180, 0), 1)
                zoom = 1 + 0.08 * folded
            }
    }
}
```

- The artwork is hidden from VoiceOver because it carries no information.
- `scaleEffect(reduceMotion ? 1 : zoom)` resets the picture at once if someone turns Reduce Motion on while the phone is partly open; the disabled handler would not run again.
- 8 percent is a nudge. Big zooms, rotations and parallax are the effects Reduce Motion exists for.

## Recipe: hinge input with an alternative

The guitar idea from Apple's talk, made accessible: a slider bends the pitch, and the hinge can drive the same value once the person turns it on.

```swift
import SwiftUI

/// Input, used sparingly: the hinge can bend the pitch, but only after the
/// person turns it on, and the slider always does the same job.
@available(iOS 27.1, *)
struct PitchBendControl: View {
    @Binding var bend: Double
    @State private var followsHinge = false

    var body: some View {
        VStack(alignment: .leading) {
            Slider(value: $bend, in: 0...1) {
                Text("Pitch Bend")
            }
            Toggle("Bend with the Hinge", isOn: $followsHinge)
        }
        .onHingeChange(isEnabled: followsHinge) { _, context in
            guard let hinge = context.hinge, hinge.status == .partiallyOpen else {
                bend = 0
                return
            }
            bend = 1 - min(max(hinge.angle.degrees / 180, 0), 1)
        }
        .onChange(of: followsHinge) {
            if !followsHinge { bend = 0 }
        }
    }
}
```

- The slider is the primary control. VoiceOver, Switch Control and Voice Control users get the full feature from it.
- The toggle is off by default. On an iPhone without a hinge, turning it on changes nothing and the slider still works.
- The slider moves as the hinge drives it, so the person sees the value either way.

## UIKit

```swift
import UIKit

/// Tilts a decorative view a little while the phone is partly open.
/// Skips the effect with Reduce Motion and follows the setting when it changes.
@available(iOS 27.1, *)
final class HingeTiltViewController: UIViewController {
    private let artwork = UIImageView(image: UIImage(systemName: "sun.max.fill"))
    private var hingeInteraction: UIHingeInteraction?

    override func viewDidLoad() {
        super.viewDidLoad()
        artwork.isAccessibilityElement = false
        artwork.frame = view.bounds
        artwork.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        artwork.contentMode = .scaleAspectFit
        view.addSubview(artwork)

        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            // Nil: no hinge here. Not partly open: back to neutral.
            guard let hinge = update.hinge, hinge.status == .partiallyOpen else {
                artwork.transform = .identity
                return
            }
            // Radians. Flat should read pi, as SwiftUI reads 180 degrees (UIKit not measured).
            let folded = 1 - min(max(hinge.angle / .pi, 0), 1)
            artwork.transform = CGAffineTransform(scaleX: 1 + 0.08 * folded, y: 1 + 0.08 * folded)
        }
        view.addInteraction(interaction)
        hingeInteraction = interaction
        applyReduceMotion()

        NotificationCenter.default.addObserver(
            self, selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    @objc private func reduceMotionChanged() {
        applyReduceMotion()
    }

    private func applyReduceMotion() {
        let reduce = UIAccessibility.isReduceMotionEnabled
        hingeInteraction?.isEnabled = !reduce
        if reduce { artwork.transform = .identity }
    }
}
```

## Test it

- In Device Hub, press Partially Open, then hold Option and drag the slider below the bezel to sweep the angle ([Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)).
- Turn on Reduce Motion in the simulator's Settings > Accessibility > Motion. The effect stops and resets.
- Run on an iPhone without a hinge, or in a preview: `hinge` is `nil` and nothing breaks.
- Only a real iPhone Duo shows how the effect feels in the hand, how fast the angle updates and how smooth it looks at 120 Hz. The simulator reported 60 frames per second ([device facts](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#displays)).

## Pitfalls

- **Layout from the angle.** "Below 150° use the book layout" breaks when flipped, in Split View, and when the angle updates late. Use `.division`.
- **Effects that never reset.** Forgetting the `else` branch leaves the picture zoomed after the phone is fully open.
- **Ignoring Reduce Motion.** A zoom that follows the hinge is exactly the scaling motion the setting is meant to stop.
- **Hinge-only features.** A feature that exists only through folding is out of reach for anyone who can't or won't fold the phone.
- **Heavy work per update.** The handler can run often while someone folds. Update a value; don't reload data or relayout the screen.

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): V4 (talk 111464), D4 (Device Hub). Apple's HIG pages on [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) and [motion](https://developer.apple.com/design/human-interface-guidelines/motion).
