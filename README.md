# RickAndMortySwiftUI

A lightweight SwiftUI app that fetches characters from the Rick and Morty API.

## What it includes

- SwiftUI + MVVM architecture
- Repository + network service layers
- Typed network errors (`RMServiceError`)
- Stable UI states: loading, error, empty, and list
- Enum-based navigation (`Router` / `Route`)
- Unit tests for `CharactersViewModel`, `CharactersRepository`, and `RMService`

## API

- Base URL: `https://rickandmortyapi.com/api`
- Endpoint used: `GET /character`

## Run

1. Open `RickAndMortySwiftUI.xcodeproj`
2. Select scheme `RickAndMortySwiftUI`
3. Run on simulator or device in Xcode

## CLI build/test

```bash
xcodebuild -project RickAndMortySwiftUI.xcodeproj \
  -scheme RickAndMortySwiftUI \
  -destination 'generic/platform=iOS Simulator' \
  build-for-testing

xcodebuild -project RickAndMortySwiftUI.xcodeproj \
  -scheme RickAndMortySwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

## Notes

- Runtime uses live API by default.
- SwiftUI previews use deterministic mock data and skip network calls.
- `CharacterDetailView` is still `WIP`.

## License

MIT (see `LICENSE`).
