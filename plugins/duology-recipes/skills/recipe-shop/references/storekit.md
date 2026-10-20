# StoreKit in the shop recipe

What `Store.swift` does, how the local configuration works, how the tests drive purchases, and what to do before release. Apple's overview: [Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode).

## What it sells

`StoreKit/Shop.storekit` is a local StoreKit configuration file. No App Store Connect account, no network.

| Product | Type | Price (USA storefront) |
|---|---|---|
| 12 sound packs, `pack.rain` … `pack.wind` | Non-consumable, Family Sharing on | $1.99 to $3.99 |
| `plus.yearly` | Auto-renewable, 1 year, a free week for new subscribers | $29.99 |
| `plus.monthly` | Auto-renewable, 1 month | $3.99 |

Both plans sit in one subscription group, so a person has one or the other. Product IDs use only letters, digits, dots and underscores, which App Store Connect accepts. `Tools/run-model-tests.sh` reads the file and fails when the catalog and the file disagree on an ID, type, name, price, period or trial.

The scheme's Run action points at the file (Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration). In the file it is `StoreKitConfigurationFileReference` with a path relative to the project's workspace.

## Store.swift

| Step | API | Notes |
|---|---|---|
| Listen first | [`Transaction.updates`](https://developer.apple.com/documentation/storekit/transaction/updates) in a task started by `start()` | Apple asks for this at launch: unfinished transactions arrive there once, and so do Ask to Buy approvals, purchases on other devices and renewals. |
| Load products | [`Product.products(for:)`](https://developer.apple.com/documentation/storekit/product/products(for:)) | Prices come from here: `displayPrice` for one product, `price` (a `Decimal`) and `priceFormatStyle` for the basket total. An empty answer shows "–" and a message, never a made-up price. |
| What the person owns | [`Transaction.currentEntitlements`](https://developer.apple.com/documentation/storekit/transaction/currententitlements) | Only verified transactions with no `revocationDate` count. `Ownership` turns the product IDs into packs and a plan. |
| Buy | [`PurchaseAction`](https://developer.apple.com/documentation/storekit/purchaseaction), read with `@Environment(\.purchase)` | Apple's choice for SwiftUI: it knows the view's scene and shows the confirmation next to it. On iPhone Duo that is whichever display the app is on. |
| After a purchase | `.success(.verified(transaction))`: `finish()`, then read entitlements again | `.success(.unverified)` unlocks nothing; `.pending` (Ask to Buy) and `.userCancelled` go back to the checkout. |
| Trial | `subscription?.isEligibleForIntroOffer`, `introductoryOffer` | "Try it free" and "1 week free, then billed each year" show only when the person is eligible and the offer is a free trial. |
| Restore | [`AppStore.sync()`](https://developer.apple.com/documentation/storekit/appstore/sync()) | Asks the person to sign in, so it runs only from the Restore button. Normal launches don't need it. |
| Manage Plus | [`manageSubscriptionsSheet(isPresented:)`](https://developer.apple.com/documentation/swiftui/view/managesubscriptionssheet(ispresented:)) | Shown instead of Subscribe once Plus is on. |

`StoreKit.Transaction` is spelled out in full: in a file that also imports SwiftUI, `Transaction` alone is ambiguous with SwiftUI's own type (*measured*: the compiler stops on it).

`StoreKitError` gains a case in iOS 27, `invalidPresentationContext` (iOS 27.1 SDK). We never saw it with `PurchaseAction`, which brings its own scene; when the system throws it is unverified.

## Testing

**Run from Xcode:** Product > Run uses the scheme's configuration. Purchases are free and stay on the Mac. Clear them in Debug > StoreKit > Manage Transactions.

**`xcodebuild test`:** *measured*, the scheme's configuration did not reach the app under test, with the file set on the Run action and again on the Test action: prices stayed unavailable. So the UI tests open an [`SKTestSession`](https://developer.apple.com/documentation/storekittest/sktestsession) themselves:

```swift
let file = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("StoreKit/Shop.storekit")
let session = try SKTestSession(contentsOf: file)
session.resetToDefaultState()
session.disableDialogs = true      // purchases complete without the confirmation sheet
session.clearTransactions()        // every test starts with nothing bought
```

*Measured* on the iPhone Duo simulator: a session opened in the UI test runner applied to the app under test. Prices loaded, purchases went through with no sheet, `askToBuyEnabled = true` made a purchase come back `.pending`, and `setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)` made it fail until set back to `nil`. `#filePath` is a path on the Mac, which the simulator can read; a device can't, so these tests run on a simulator only.

The session's state outlives the test run. *Measured:* after the subscribe test, the app launched with `simctl` still showed Plus as on, and before any session it showed no prices. Run `testPricesComeFromTheStoreKitConfiguration` alone to leave a clean state for screenshots.

**On a device:** use a Sandbox account and products created in App Store Connect (not tested here).

## Before release

1. Create every product in App Store Connect with the same ID, type, price tier and group. Fill in the subscription group's display name and each product's localizations.
2. Replace the sample catalog and `Shop.storekit` together, or create a synced StoreKit configuration file from App Store Connect and keep the catalog in step with it.
3. Replace the Privacy Policy link in `Plus/PlusScreen.swift`. Keep the Terms of Use link (Apple's standard licence, or your own).
4. Read App Review guideline 3.1 ([guidelines](https://developer.apple.com/app-store/review/guidelines/)): 3.1.1 for unlocking content with in-app purchase, 3.1.2 for subscriptions, 3.1.3(e) for goods and services used outside the app, which must not use in-app purchase.
5. Test once on a device with a Sandbox account: a purchase, a restore on a second device, and an Ask to Buy approval.
