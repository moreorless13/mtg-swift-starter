# MTG Swift Starter

A small SwiftUI starter app that fetches Magic: The Gathering card data with the official [`MTGSDKSwift`](https://github.com/MagicTheGathering/mtg-sdk-swift) package.

The app ships with a simple card search screen, a thin service wrapper around the SDK, and unit tests for the app-owned card mapping and error behavior.

## Requirements

- Xcode 26.5 or newer
- iOS simulator or iOS device
- Network access for Swift Package Manager and the MTG API

## Setup

1. Clone the repository.
2. Open `mtg-xproject-starter.xcodeproj` in Xcode.
3. Let Xcode resolve Swift Package dependencies.
4. Select the `mtg-xproject-starter` scheme.
5. Build and run on an iOS simulator or device.

From the command line:

```sh
xcodebuild -project mtg-xproject-starter.xcodeproj \
  -scheme mtg-xproject-starter \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## SDK Usage

The live service uses `MTGSDKSwift` behind the `MTGCardFetching` protocol so the UI does not depend directly on SDK types:

```swift
let service = MTGCardService()
let cards = try await service.fetchCards(named: "Black Lotus")
```

Internally, the service builds a `CardSearchParameter` and bridges the SDK completion handler into `async/await`.

## Project Layout

- `ContentView.swift`: SwiftUI search screen and result list.
- `MTGCardService.swift`: SDK integration and async wrapper.
- `MTGCardSummary.swift`: App-owned card summary model for UI and tests.
- `mtg-xproject-starterTests`: Unit tests for mapping, validation, and error propagation.

## Troubleshooting

- If Xcode cannot find `MTGSDKSwift`, use **File > Packages > Reset Package Caches**, then resolve packages again.
- If searches fail, confirm the simulator or device has internet access and that `https://api.magicthegathering.io` is reachable.
- The official SDK is intentionally wrapped in a local service so the data layer can be swapped later without rewriting the SwiftUI screen. Tiny abstraction, big future sideboard.
