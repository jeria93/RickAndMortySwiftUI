# RickAndMortySwiftUI

A lightweight SwiftUI app that fetches characters from the Rick and Morty API.

## What it includes

- SwiftUI + MVVM architecture
- Repository + network service layers
- Typed network errors (`RMServiceError`)
- URL cache + lightweight repository cache (with stale fallback on network errors)
- Stable UI states: loading, error, empty, and list
- Enum-based navigation (`Router` / `Route`)
- Unit tests for `CharactersViewModel`, `CharactersRepository`, and `RMService`

## API

- Base URL: `https://rickandmortyapi.com/api`
- Endpoints used:
  - `GET /character`
  - `GET /character/{id}`
  - `GET /episode/{id,id,...}`

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
- `CharacterDetailView` includes detail info + episode list.

## Caching

- Network layer uses `URLCache` (in-memory + disk) with conservative request/resource timeouts.
- Repository layer caches:
  - character pages by `page + query`
  - character detail by `id`
  - episodes by normalized `ids`
- Fresh cache entries are served directly.
- If cache is stale, repository tries network first; if network fails, stale cache is used as fallback.
- Live cache can be invalidated via:
  - `CharactersRepository.clearLiveCache()`
  - `CharacterDetailRepository.clearLiveCache()`

## License

MIT (see `LICENSE`).
