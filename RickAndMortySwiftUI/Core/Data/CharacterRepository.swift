//
//  CharacterRepository.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

private enum LiveRMService {
    static let shared = RMService.live()
}

private enum LiveRepositoryCache {
    static let shared = RepositoryLocalCache()
}

private struct CharactersPageCacheKey: Hashable {
    let page: Int
    let name: String
    let status: String
    let gender: String
    
    init(page: Int, query: CharactersQuery) {
        self.page = max(page, 1)
        self.name = query.trimmedName.lowercased()
        self.status = query.status.rawValue
        self.gender = query.gender.rawValue
    }
}

private struct EpisodesCacheKey: Hashable {
    let ids: [Int]
    
    init(ids: [Int]) {
        self.ids = Self.normalized(ids)
    }
    
    private static func normalized(_ ids: [Int]) -> [Int] {
        var seen = Set<Int>()
        var unique: [Int] = []
        
        for id in ids where id > 0 {
            if seen.insert(id).inserted {
                unique.append(id)
            }
        }
        
        return unique
    }
}

@MainActor
private final class RepositoryLocalCache {
    private struct TimedEntry<Value> {
        let value: Value
        let savedAt: Date
    }
    
    private var charactersPages: [CharactersPageCacheKey: TimedEntry<CharactersPage>] = [:]
    private var characterDetails: [Int: TimedEntry<CharacterDetail>] = [:]
    private var episodesByIDs: [EpisodesCacheKey: TimedEntry<[Episode]>] = [:]
    
    func freshCharactersPage(
        for key: CharactersPageCacheKey,
        now: Date,
        maxAge: TimeInterval
    ) -> CharactersPage? {
        guard
            let entry = charactersPages[key],
            isFresh(entry.savedAt, now: now, maxAge: maxAge)
        else {
            return nil
        }
        
        return entry.value
    }
    
    func charactersPage(for key: CharactersPageCacheKey) -> CharactersPage? {
        charactersPages[key]?.value
    }
    
    func setCharactersPage(_ page: CharactersPage, for key: CharactersPageCacheKey, at date: Date) {
        charactersPages[key] = TimedEntry(value: page, savedAt: date)
    }
    
    func freshCharacterDetail(
        for id: Int,
        now: Date,
        maxAge: TimeInterval
    ) -> CharacterDetail? {
        guard
            let entry = characterDetails[id],
            isFresh(entry.savedAt, now: now, maxAge: maxAge)
        else {
            return nil
        }
        
        return entry.value
    }
    
    func characterDetail(for id: Int) -> CharacterDetail? {
        characterDetails[id]?.value
    }
    
    func setCharacterDetail(_ detail: CharacterDetail, for id: Int, at date: Date) {
        characterDetails[id] = TimedEntry(value: detail, savedAt: date)
    }
    
    func freshEpisodes(
        for key: EpisodesCacheKey,
        now: Date,
        maxAge: TimeInterval
    ) -> [Episode]? {
        guard
            let entry = episodesByIDs[key],
            isFresh(entry.savedAt, now: now, maxAge: maxAge)
        else {
            return nil
        }
        
        return entry.value
    }
    
    func episodes(for key: EpisodesCacheKey) -> [Episode]? {
        episodesByIDs[key]?.value
    }
    
    func setEpisodes(_ episodes: [Episode], for key: EpisodesCacheKey, at date: Date) {
        episodesByIDs[key] = TimedEntry(value: episodes, savedAt: date)
    }
    
    func clearAll() {
        charactersPages.removeAll(keepingCapacity: false)
        characterDetails.removeAll(keepingCapacity: false)
        episodesByIDs.removeAll(keepingCapacity: false)
    }
    
    private func isFresh(_ savedAt: Date, now: Date, maxAge: TimeInterval) -> Bool {
        now.timeIntervalSince(savedAt) <= max(0, maxAge)
    }
}

/// Tiny repository wrapper so the ViewModel can stay unaware of
/// *how* data is loaded. Swap `.live()` and `.mock()` freely.
///
/// - Important: `fetch` is an async closure that returns a specific
///   page of characters or throws on failure.
struct CharactersRepository {
    /// The fetch function used by the ViewModel.
    let fetch: (_ page: Int, _ query: CharactersQuery) async throws -> CharactersPage
    
    /// Production repository. Uses the real network service.
    static func live() -> CharactersRepository {
        let service = LiveRMService.shared
        return makeCached(
            maxAge: 300,
            now: Date.init,
            cache: LiveRepositoryCache.shared,
            fetchRemote: { page, query in
                try await service.fetchCharacters(page: page, query: query)
            }
        )
    }
    
    @MainActor
    static func clearLiveCache() {
        LiveRepositoryCache.shared.clearAll()
    }
    
    static func cached(
        maxAge: TimeInterval = 300,
        now: @escaping () -> Date = Date.init,
        fetchRemote: @escaping (_ page: Int, _ query: CharactersQuery) async throws -> CharactersPage
    ) -> CharactersRepository {
        makeCached(
            maxAge: maxAge,
            now: now,
            cache: RepositoryLocalCache(),
            fetchRemote: fetchRemote
        )
    }
    
    private static func makeCached(
        maxAge: TimeInterval,
        now: @escaping () -> Date,
        cache: RepositoryLocalCache,
        fetchRemote: @escaping (_ page: Int, _ query: CharactersQuery) async throws -> CharactersPage
    ) -> CharactersRepository {
        let safeMaxAge = max(0, maxAge)
        
        return .init(fetch: { page, query in
            let normalizedPage = max(page, 1)
            let key = CharactersPageCacheKey(page: normalizedPage, query: query)
            let nowValue = now()
            
            if let cachedPage = cache.freshCharactersPage(for: key, now: nowValue, maxAge: safeMaxAge) {
                return cachedPage
            }
            
            do {
                let remotePage = try await fetchRemote(normalizedPage, query)
                cache.setCharactersPage(remotePage, for: key, at: nowValue)
                return remotePage
            } catch {
                if let stalePage = cache.charactersPage(for: key) {
                    return stalePage
                }
                throw error
            }
        })
    }
    
    /// Preview/testing repository. Returns stable mock data.
    static func mock() -> CharactersRepository {
        .init(fetch: { page, _ in
            guard page == 1 else {
                return CharactersPage(characters: [], nextPage: nil)
            }
            
            return CharactersPage(
                characters: CharactersPreviewData.some(),
                nextPage: nil
            )
        })
    }
}

struct CharacterDetailRepository {
    let fetchDetail: (_ id: Int) async throws -> CharacterDetail
    let fetchEpisodes: (_ ids: [Int]) async throws -> [Episode]
    
    static func live() -> CharacterDetailRepository {
        let service = LiveRMService.shared
        return makeCached(
            maxAge: 300,
            now: Date.init,
            cache: LiveRepositoryCache.shared,
            fetchDetailRemote: { id in
                try await service.fetchCharacterDetail(id: id)
            },
            fetchEpisodesRemote: { ids in
                try await service.fetchEpisodes(ids: ids)
            }
        )
    }
    
    @MainActor
    static func clearLiveCache() {
        LiveRepositoryCache.shared.clearAll()
    }
    
    static func cached(
        maxAge: TimeInterval = 300,
        now: @escaping () -> Date = Date.init,
        fetchDetailRemote: @escaping (_ id: Int) async throws -> CharacterDetail,
        fetchEpisodesRemote: @escaping (_ ids: [Int]) async throws -> [Episode]
    ) -> CharacterDetailRepository {
        makeCached(
            maxAge: maxAge,
            now: now,
            cache: RepositoryLocalCache(),
            fetchDetailRemote: fetchDetailRemote,
            fetchEpisodesRemote: fetchEpisodesRemote
        )
    }
    
    private static func makeCached(
        maxAge: TimeInterval,
        now: @escaping () -> Date,
        cache: RepositoryLocalCache,
        fetchDetailRemote: @escaping (_ id: Int) async throws -> CharacterDetail,
        fetchEpisodesRemote: @escaping (_ ids: [Int]) async throws -> [Episode]
    ) -> CharacterDetailRepository {
        let safeMaxAge = max(0, maxAge)
        
        return .init(
            fetchDetail: { id in
                let nowValue = now()
                if let cachedDetail = cache.freshCharacterDetail(for: id, now: nowValue, maxAge: safeMaxAge) {
                    return cachedDetail
                }
                
                do {
                    let detail = try await fetchDetailRemote(id)
                    cache.setCharacterDetail(detail, for: id, at: nowValue)
                    return detail
                } catch {
                    if let staleDetail = cache.characterDetail(for: id) {
                        return staleDetail
                    }
                    throw error
                }
            },
            fetchEpisodes: { ids in
                let key = EpisodesCacheKey(ids: ids)
                guard !key.ids.isEmpty else { return [] }
                
                let nowValue = now()
                if let cachedEpisodes = cache.freshEpisodes(for: key, now: nowValue, maxAge: safeMaxAge) {
                    return cachedEpisodes
                }
                
                do {
                    let episodes = try await fetchEpisodesRemote(key.ids)
                    cache.setEpisodes(episodes, for: key, at: nowValue)
                    return episodes
                } catch {
                    if let staleEpisodes = cache.episodes(for: key) {
                        return staleEpisodes
                    }
                    throw error
                }
            }
        )
    }
    
    static func mock(
        detail: CharacterDetail = .preview(),
        episodes: [Episode] = Episode.previewList()
    ) -> CharacterDetailRepository {
        .init(
            fetchDetail: { _ in detail },
            fetchEpisodes: { _ in episodes }
        )
    }
}
