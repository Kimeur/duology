# Scene and renderer: resize, never restart

A fold on iPhone Duo is a resize. Opening the phone also moves the app to the other display. This file covers what SpriteKit, `MTKView` and a UIKit `CAMetalLayer` loop do then, and the one case where letterboxing is allowed.

## SpriteKit

`ArenaScene` in SKILL.md uses `.resizeFill`. The other scale modes and what they do on iPhone Duo:

| `scaleMode` | What happens when the view changes shape | On iPhone Duo |
|---|---|---|
| `.resizeFill` | The scene's size becomes the view's size ([doc](https://developer.apple.com/documentation/spritekit/skscenescalemode/resizefill)) | Use it, with a camera that fits the play area. |
| `.aspectFit` | The whole scene shows, scaled, with bars on two sides | Letterboxing: only as a last resort, with artwork (below). |
| `.aspectFill` | The scene fills the view and the overflow is cut off | Crops the play area differently in each pose: something visible closed vanishes open. Avoid. |
| `.fill` (the default) | The scene stretches to the view | Distorts every fold. Never. |

What we measured with `ArenaScene` and `GameScreen` (iPhone Duo simulator, iOS 27.1, 20 Oct 2026):

- **One scene, one view.** The scene's `ObjectIdentifier` stayed the same from launch to the last pose in every run. `didMove(to:)` ran once.
- **It kept running.** The frame counter kept counting through closed, open, book, tabletop and closed.
- **Size changes come twice.** `didChangeSize(_:)` ran twice for each change, with the same sizes.
- **Passing sizes.** Closing from tabletop gave 466 × 455.7 pt for one pass, then 466 × 678 pt. Rotating out of tabletop gave the touch controls 951 × 139.5 pt for one pass.
- **Book changes nothing.** Folding from flat to book didn't change the scene size (951 × 669 pt). Only `isActive` on the fold changed.
- **Pause the scene, not the view.** `SpriteView(isPaused:)` set the scene's `isPaused` when it turned `true`, and didn't clear it when it turned `false`: the game stayed frozen. Set `scene.isPaused` yourself, as `GameScreen` does ([measurements.md](measurements.md#pausing)).

So `didChangeSize(_:)` must be cheap, repeatable and free of side effects on game state. Don't spawn, reset, save or pause there.

### Text and the score

Put the score, timers and menus in SwiftUI over the `SpriteView`, sized in points. The camera's scale changes with every fold (in `ArenaScene`, from 1.37 closed to 0.67 open, *derived* from the measured sizes), so text drawn in the world would change size too. Apple asks for text and control sizes that stay as consistent as possible ([HIG: iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)). Keep game text at 11 pt or more ([HIG: Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games)).

### When you must letterbox

Some games can't show more or less of the world: a fixed puzzle board, a level built for one screen shape. Apple allows letterboxing then, with artwork in the padding so the game still feels full screen ([HIG: iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)).

```swift
import SpriteKit
import SwiftUI

/// Last resort, for a game that must keep one aspect ratio: the scene at its own
/// ratio inside the safe area, and artwork behind it that fills the whole screen.
struct LetterboxedGame: View {
    let scene: SKScene          // a fixed size, with scaleMode .aspectFit
    let ratio: CGFloat          // the scene's width divided by its height
    let artwork: Image

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 120)
            .aspectRatio(ratio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // Artwork, never plain black bars. A background doesn't change the layout.
                artwork
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
    }
}
```

*Measured* with a 16:10 scene (the safe area, then the scene's frame in the window):

| Pose | Safe area | Scene | Share of the safe area's height |
|---|---|---|---|
| Closed | 382 × 644 pt | 382 × 238.8 pt | 37 percent |
| Open, held wide | 867 × 635 pt | 867 × 541.9 pt | 85 percent |
| Tabletop | 669 × 835 pt | 669 × 418.1 pt at y = 290.4, across the fold | 50 percent |

- The artwork filled the whole screen in every pose, status bar area included; there were no plain bars.
- In tabletop the centred scene ran straight across the fold (455.5 to 495.5 pt). Put a letterboxed scene in `GameLayout` too, so it sits in the top region.
- Pick the ratio that wastes least across poses. The closed phone is about 0.69 wide per unit of height in portrait, and the open phone about 1.42 held wide (*derived* from the measured windows, 466 × 678 and 951 × 669 pt). No single ratio suits both: a 4:3 board leaves 6 percent of the open display's width empty, but fills only about half the height of the closed phone held upright (*derived*).
- In book, a centred board sits on the fold. Prefer a ratio that fills one region, or let the board cross the fold only if nothing the player must tap lands there.

## Metal with MTKView

Keep the renderer, its device, queue, pipelines and textures for the life of the game. Create it in the game session, above every layout switch. The view only shows it.

```swift
import MetalKit
import SwiftUI

/// Keeps the device, queue, pipelines and game state for the life of the game.
/// A fold changes only what depends on size: the projection and size-matched targets.
@MainActor
final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private(set) var aspect: Float = 1

    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let device, let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        super.init()
        // Build pipelines and load textures here, once.
    }

    /// Fold, unfold, rotation, Split View: new drawable size in pixels. Never rebuild the world.
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspect = Float(size.width / max(size.height, 1))
        // Recreate only textures that must match the drawable (depth, offscreen targets).
    }

    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        // Draw the world with a projection built from `aspect`.
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }
}

/// The renderer is owned by the game session, above every layout switch.
struct MetalGameView: UIViewRepresentable {
    let renderer: Renderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.autoResizeDrawable = true          // the default: the drawable follows the view
        view.preferredFramesPerSecond = 120     // ProMotion; the system picks what the display allows
        view.delegate = renderer
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {}
}
```

What we measured, with `MetalGameView` full screen (`.ignoresSafeArea()`):

| Pose | View bounds | Drawable (`drawableSizeWillChange`) |
|---|---|---|
| Closed | 466 × 678 pt | 1398 × 2034 px |
| Open, flat, held wide | 951 × 669 pt | 2853 × 2007 px |
| Book | 951 × 669 pt | not called: no change |
| Tabletop | 669 × 951 pt | 2007 × 2853 px |

- One renderer drew without a break: about 5,100 frames over the run, with `drawableSizeWillChange` once per real size change. Every rotation step out of tabletop called it again.
- The drawable is in pixels at scale 3 on both displays. Build the projection from the drawable's own ratio, never from a screen size.
- `MTKView` asks for 120 fps; the simulator ran at 60 (*measured* in `reference/device-facts.md`). Add `CADisableMinimumFrameDurationOnPhone` to Info.plist for more than 60 Hz on a device ([ProMotion guide](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays)).

## UIKit with CAMetalLayer

```swift
import QuartzCore
import UIKit

/// A UIKit game loop on a CAMetalLayer. The display link comes from the window
/// scene, so it follows the scene when the phone opens or closes and the app
/// moves to the other display.
final class GameViewController: UIViewController {
    private let metalLayer = CAMetalLayer()
    private var link: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = .bgra8Unorm
        view.layer.addSublayer(metalLayer)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        guard link == nil, let scene = view.window?.windowScene else { return }
        if #available(iOS 27.0, *) {
            link = scene.displayLink(target: self, selector: #selector(step(_:)))
        } else {
            link = CADisplayLink(target: self, selector: #selector(step(_:)))
        }
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link?.add(to: .main, forMode: .common)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        link?.invalidate()          // the link retains its target
        link = nil
    }

    /// Fold, unfold, rotation and Split View all land here. Resize; don't restart.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        metalLayer.frame = view.bounds
        let scale = traitCollection.displayScale
        metalLayer.drawableSize = CGSize(width: view.bounds.width * scale,
                                         height: view.bounds.height * scale)
    }

    @objc private func step(_ link: CADisplayLink) {
        // Advance the game by link.targetTimestamp - link.timestamp, then draw.
    }
}
```

- `UIWindowScene.displayLink(target:selector:)` is new in iOS 27. Apple's doc says the link is retargeted on its own when the scene moves between displays ([doc](https://developer.apple.com/documentation/uikit/uiwindowscene/displaylink(target:selector:))). On iPhone Duo, that happens every time the phone opens or closes. `UIScreen`'s display link is deprecated in iOS 27.
- Use `traitCollection.displayScale`, never `UIScreen.main.scale` (deprecated since iOS 26).
- Step the game by `targetTimestamp - timestamp`, so a frame-rate change on the other display doesn't change the game's speed.
- This view controller typechecks but did not run in our probe (unverified on the simulator).

## Touch Controller

Apple's Touch Controller framework (iOS 26) renders virtual controls inside your Metal pass ([doc](https://developer.apple.com/documentation/touchcontroller/tctouchcontroller)).

```swift
import MetalKit
import TouchController

/// Apple's Touch Controller framework draws virtual controls with Metal, inside
/// your render pass. It places each control from an anchor on the view's edges and
/// knows nothing about the fold, so give it the right size on every fold.
@MainActor
final class TouchOverlay {
    let controller: TCTouchController

    init?(view: MTKView) {
        // Creating a touch controller where it isn't supported is a fatal error.
        guard TCTouchController.isSupported else { return nil }
        controller = TCTouchController(descriptor: TCTouchControllerDescriptor(mtkView: view))
        controller.automaticallyLayoutControls(for: [.leftThumbstick, .buttonA, .buttonB])
        controller.connect()
    }

    /// Call from mtkView(_:drawableSizeWillChange:): every fold, unfold and rotation.
    func resize(viewSize: CGSize, drawableSize: CGSize) {
        controller.size = viewSize
        controller.drawableSize = drawableSize
    }

    /// Call inside your render pass, after the world.
    func draw(with encoder: any MTLRenderCommandEncoder) {
        controller.render(using: encoder)
    }

    /// Forward touches from the view. `index` must stay the same for one finger.
    func touchBegan(at point: CGPoint, index: Int) -> Bool {
        controller.handleTouchBegan(at: point, index: index)
    }

    func touchMoved(at point: CGPoint, index: Int) -> Bool {
        controller.handleTouchMoved(at: point, index: index)
    }

    func touchEnded(at point: CGPoint, index: Int) -> Bool {
        controller.handleTouchEnded(at: point, index: index)
    }
}
```

- *Measured:* `TCTouchController.isSupported` was `false` on the iPhone Duo simulator, so `TouchOverlay(view:)` returned `nil` there. Keep `TouchControls` as the fallback.
- Where `automaticallyLayoutControls(for:)` puts the controls on iPhone Duo is unverified. After a fold, read each control's `position` and check that none sits inside the fold frame. If one does, set its `anchor` to a corner and its `offset` yourself.
- `ControllerAware` skips the controller it creates (product category "Touch Controller"), so the on-screen controls never count as a physical controller.
