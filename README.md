# RickAndMortySwiftUI

A lightweight SwiftUI app that fetches characters from the Rick and Morty API.

## What it includes

- SwiftUI + MVVM architecture
- Repository + network service layers
- Typed network errors (`RMServiceError`)
- URL cache + lightweight repository cache (with stale fallback on network errors)
- Bounded `429` retry/backoff that respects `Retry-After` when the API rate-limits requests
- Dedicated remote-image cache/session with reduced per-host concurrency for avatar loading
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
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

## Notes

- Runtime uses live API by default.
- Character, location, and episode requests back off and retry a small number of times on `HTTP 429`.
- SwiftUI previews use deterministic mock data and skip network calls.
- `CharacterDetailView` includes detail info + episode list.

## Caching

- Network layer uses `URLCache` (in-memory + disk) with conservative request/resource timeouts.
- Remote images use a dedicated `URLSession`, memory cache, disk cache, and lower per-host concurrency to avoid aggressive avatar refetching while scrolling.
- Repository layer caches:
  - character pages by `page + query`
  - character detail by `id`
  - episodes by normalized `ids`
- Fresh cache entries are served directly.
- If cache is stale, repository tries network first, if network fails, stale cache is used as fallback.
- Live cache can be invalidated via:
  - `CharactersRepository.clearLiveCache()`
  - `CharacterDetailRepository.clearLiveCache()`

## License

MIT (see `LICENSE`).
