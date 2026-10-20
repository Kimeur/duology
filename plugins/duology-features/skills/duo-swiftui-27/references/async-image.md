# AsyncImage caching through a fold

What changed in iOS 27, when it matters on iPhone Duo, and the runs that show it.

## What Apple changed

- On iOS 27 and the other 2027 releases, `AsyncImage` caches downloaded image data by the HTTP rules, using a cache made from the default session configuration. No code change turns it on ([doc](https://developer.apple.com/documentation/swiftui/asyncimage), [session 269](https://developer.apple.com/videos/play/wwdc2026/269/?time=1257)). The talk says this is on for every app.
- With the iOS 27 SDK you can pass a `URLRequest` instead of a URL, through `AsyncImage(request:scale:)` and its `content:placeholder:` and `transaction:content:` forms, to set a cache policy or other request fields per image (iOS 27.0).
- `asyncImageURLSession(_:)` (iOS 27.0) sets the `URLSession` that every `AsyncImage` below it uses. Give that session its own `URLCache` when you need a bigger cache ([doc](https://developer.apple.com/documentation/swiftui/view/asyncimageurlsession(_:))).
- The server decides what is cached and for how long, through its `Cache-Control` and related headers. A response marked `no-store` is not kept.

Before iOS 27, `AsyncImage` kept nothing once a view went away, so images reloaded when they came back on screen (session 269).

## When a fold rebuilds image views

A fold changes the window size. What happens to your images depends on whether the views that hold them survive.

| Your layout | What a fold does to the image views | Does the cache matter? |
|---|---|---|
| One grid whose column count follows the size class | The cells keep their identity; they move and resize | No. *Measured*: no refetch, cache or not. |
| Different containers per size class (`List` closed, grid open), or `if`/`else` branches | Every cell is new | Yes. *Measured*: refetch on every fold without the cache, none with it. |
| A lazy container scrolled far away and back | Cells off screen are thrown away | Yes, as on any iPhone (session 269). |

So on Duo, the cache earns its keep when your layout changes view trees between the outer and inner display. Keep one container when you can (`duo-layout` uses `AnyLayout` for that). When you can't, make sure the image server sends cache headers.

## What we measured

iPhone Duo simulator, iOS 27.1, Xcode 27.1, 20 October 2026. A local server on the Mac served small PNGs with `Cache-Control: max-age=3600` and logged each request. The probe app loaded them through `AsyncImage(request:)`, with `.useProtocolCachePolicy` (the default behaviour) or `.reloadIgnoringLocalCacheData` (cache bypassed). A UI test held the simulator while a script set the poses closed, open, closed, open in Device Hub, and the app logged its size, size classes and fold state. Logs: [evidence.md](evidence.md#asyncimage).

| Screen | Cache | Closed | First unfold | Fold | Second unfold | Requests |
|---|---|---|---|---|---|---|
| `LazyVGrid`, 2 columns closed, 4 open, 24 images | bypassed | 12 | 12 | 0 | 0 | 24 |
| same | default | 12 | 12 | 0 | 0 | 24 |
| `List` closed, `LazyVGrid` open, 8 images | bypassed | 7 | 8 | 7 | 8 | 30 |
| same | default | 7 | 1 | 0 | 0 | 8 |

- The grid kept its loaded images whether or not the cache was on. The cache made no difference there.
- The swapping screen rebuilt every image view on each fold. The cache cut 30 requests to 8.
- After the default run, the app's shared cache file (`Library/Caches/<bundle id>/Cache.db`) held one entry per image URL.

## Code

The SKILL.md example sets a bigger cache for a whole wall of covers with `asyncImageURLSession(_:)`. For one image that must always be fresh, set the policy on the request instead:

```swift
import SwiftUI

@available(iOS 27.0, *)
struct LiveScoreBadge: View {
    let url: URL

    var body: some View {
        // Revalidate with the server each time, so a changed badge shows at once.
        AsyncImage(request: URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData)) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            ProgressView()
        }
        .frame(width: 44, height: 44)
    }
}
```

Below iOS 27 these initializers don't exist. Keep `AsyncImage(url:)` behind the `else` of `if #available(iOS 27.0, *)`; on iOS 27 it caches anyway.

Apple's `swiftui-whats-new-27` skill (`references/async-image.md` in its export) covers the rest. Duology links to it and does not copy it.
