# @State and ContentBuilder in Xcode 27

Building with Xcode 27 changes two things in every SwiftUI file, whatever your deployment target:

- `@State` is now a macro, not a property wrapper. The macro makes the initial value lazy: SwiftUI evaluates it once per view identity, instead of on every `init` of the view struct.
- SwiftUI's result builders now share one builder, `@ContentBuilder` (a type alias of `ViewBuilder`). It no longer forces builder contents to be views, which makes type checking much faster and removes a few overload tie-breakers that old code relied on.

Apple explains both in [TN3211](https://developer.apple.com/documentation/technotes/tn3211-resolving-swiftui-source-incompatibilities-for-state-and-contentbuilder) and in [What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/?time=1377) (WWDC26 session 269). This file adds what we saw with Xcode 27.1 (27A9275) and why it matters on iPhone Duo.

## Why this matters more on iPhone Duo

Every fold, unfold, rotation and Split View resize changes the window size. SwiftUI then runs the `body` of every view that reads the size or the size class, and every child view it builds runs its `init` again. With the old property wrapper, a class stored in `@State` was allocated on each of those `init` calls and then thrown away. SwiftUI kept the first instance, so the app looked fine, but the work and any side effects in the class's `init` ran again.

*Measured* on the iPhone Duo simulator (iOS 27.1, 20 Oct 2026), with the probe below. One launch on the closed phone, then open, then closed again ([evidence.md](evidence.md#state-macro)):

| | Objects created |
|---|---|
| `@State private var model = ProbeModel()` (the macro) | 1 |
| `private var model = State(wrappedValue: ProbeModel())` (the old wrapper timing) | 5 |

The parent rebuilt its children four times during one unfold and one fold. Its size inside the safe area passed through intermediate values on the way: 466 × 562 pt (compact width), then 951 × 553 pt, then 867 × 635 pt, then back to 382 × 644 pt. Each pass ran both children's `init`. Only the macro kept a single model.

Apple also brought the lazy behaviour back to iOS 17 for apps built with Xcode 27 ([session 269](https://developer.apple.com/videos/play/wwdc2026/269/?time=1410)). You get it on every iPhone, not only on Duo, once you build with Xcode 27.

Never put work that must run once (a network call, a timer, a file read) in a view's `init`. The `init` still runs on every pass. Start that work in `.task` or in the model.

```swift
import SwiftUI

@Observable
final class ProbeModel {
    nonisolated(unsafe) static var created = 0
    init() { ProbeModel.created += 1 }
}

struct MacroChild: View {
    @State private var model = ProbeModel()      // built once per view identity
    var body: some View { Text("macro") }
}

struct EagerChild: View {
    private var model = State(wrappedValue: ProbeModel())   // built on every init
    var body: some View { Text("eager") }
}

struct FoldCounter: View {
    var body: some View {
        GeometryReader { proxy in
            VStack {
                Text("\(Int(proxy.size.width)) x \(Int(proxy.size.height))")
                MacroChild()
                EagerChild()
            }
        }
    }
}
```

## Source breaks: what Xcode 27.1 says and the fix

Match each case by its shape. In our checks two of the messages differ from the text in TN3211, so search for the shape, not the wording.

| Shape | What we saw in Xcode 27.1 | Fix |
|---|---|---|
| `@State var x = 0` with a default, and `init` assigns `x` before another stored property | `error: variable 'self.<other>' used before being initialized` | Remove the inline default. Keep the assignment in `init`. |
| `@State var x = 0` with a default, and `init` assigns `x` after the other properties | Compiles. At run time the default wins and the value from `init` is dropped (TN3211). *Measured*: a view built with `startPage: 42` showed page 0; the same view without the default showed 42. | Remove the inline default. |
| `@State var x: Int` with no default, assigned first in `init` | Compiled with no error in our check (Swift 5 and 6 modes, iOS 17, 26 and 27.1 targets, `-emit-sil`), although TN3211 shows this shape failing | Nothing to do. If your build reports it, set the other stored properties first. |
| Another property wrapper on the same property (`@State @Clamped var x`) | `error: property wrapper cannot be applied to a computed property` (TN3211 quotes "invalid redeclaration of synthesized property") | Remove the second wrapper; move the clamping into the model or a setter. |
| All-private stored properties, `@State` among them, and an `init` in an extension that calls `self.init(x:y:)` | `error: extraneous argument label 'bar:' in call` (TN3211 quotes "no exact matches in call to initializer") | Write the memberwise `init` yourself. |
| `.overlay(Color.blue.opacity(0.7).blendMode(.overlay))`, the non-closure form | `error: ambiguous use of 'opacity'` | Use the closure form: `.overlay { Color.blue.opacity(0.7).blendMode(.overlay) }`. |
| A generic constraint that spells `TupleView<(Text, Text)>`, deployment target iOS 27 | `error: cannot convert value of type 'VStack<TupleContent<Text, Text>>' ...` | Return `some View` and spell no builder type. If you must spell it, the type depends on the deployment target: `TupleContent<Text, Text>` at iOS 27, `TupleView<(Text, Text)>` below (*measured*: at an iOS 26.0 target the builder still produced `TupleView`). |
| `Group { }` (or an `#if` that leaves it empty) in a file where MapKit is visible | `error: return type of property 'body' requires that 'EmptyMapContent' conform to 'View'` | Put `EmptyView()` inside, or add an `#else` branch with one. `EmptyContent` is a type alias of `EmptyView`, so either name works on any target. |
| A Swift Charts `Chart` with about ten or more `if`/`switch` branches, deploying below iOS 27 | "unable to type-check this expression in reasonable time" (TN3211; we did not reproduce it) | Move the branches into a `@ChartContentBuilder` function. |

The fix for the first row is the one Apple's own Xcode skill warns about: moving the assignment below the other properties makes the error go away, but the second row shows that the value from `init` is then silently ignored. Remove the default instead.

```swift
import SwiftUI

struct ReaderPage: View {
    let book: String
    @State private var page: Int          // no inline default: init supplies it

    init(book: String, startPage: Int) {
        self.book = book
        self.page = startPage
    }

    var body: some View {
        Text("\(book), page \(page)")
    }
}
```

## Checking snippets: typecheck is not enough for @State

`swiftc -typecheck` expands the `@State` macro but stops before the compiler's initialization checks. The first row of the table passes `-typecheck` and fails only in a real build. *Measured* with Xcode 27.1: the shape typechecked with no error, and `swiftc -emit-sil -o /dev/null` reported it. A full build runs the same checks.

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
xcrun -sdk iphonesimulator swiftc -emit-sil -o /dev/null \
  -target arm64-apple-ios27.1-simulator MyView.swift
```

Run this on any view with `@State` and an `init`. The ContentBuilder errors appear with plain `-typecheck`.

## Apple's own skill

Xcode 27 ships `swiftui-whats-new-27`, an agent skill with a reference file for each of these changes. Export it with `xcrun agent skills export --output-dir <folder>` and read its `state-macro.md` and `content-builder.md`. Duology links to it and does not copy it.
