//
//  CharactersViewModel.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation
import Combine

@MainActor
final class CharactersViewModel: ObservableObject {
    @Published private(set) var characters: [Characters] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingNextPage: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var paginationErrorMessage: String?
    @Published private(set) var searchText: String = ""
    @Published private(set) var statusFilter: CharacterStatusFilter = .any
    @Published private(set) var genderFilter: CharacterGenderFilter = .any

    private let repository: CharactersRepository
    private let debounceNanoseconds: UInt64
    private var latestLoadID: UInt64 = 0
    private var nextPage: Int? = 1
    private var currentQuery: CharactersQuery = .init()
    private var debouncedReloadTask: Task<Void, Never>?

    init(
        repository: CharactersRepository,
        debounceNanoseconds: UInt64 = 350_000_000
    ) {
        self.repository = repository
        self.debounceNanoseconds = debounceNanoseconds
    }

    static func mock() -> Self { .init(repository: .mock()) }
    static func live() -> Self { .init(repository: .live()) }

    var hasActiveQuery: Bool {
        !currentQuery.isEmpty
    }

    func load() async {
        debouncedReloadTask?.cancel()
        debouncedReloadTask = nil

        latestLoadID += 1
        let loadID = latestLoadID
        isLoading = true
        isLoadingNextPage = false
        errorMessage = nil
        paginationErrorMessage = nil
        nextPage = 1

        do {
            let firstPage = try await repository.fetch(1, currentQuery)
            finishInitialLoad(loadID, page: firstPage)
        } catch is CancellationError {
            finishInitialLoad(loadID)
        } catch {
            finishInitialLoad(loadID, errorMessage: error.localizedDescription)
        }
    }

    func loadNextPageIfNeeded(currentCharacter: Characters) async {
        guard shouldLoadNextPage(for: currentCharacter) else { return }
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading, !isLoadingNextPage else { return }
        guard let pageToLoad = nextPage else { return }

        let loadID = latestLoadID
        isLoadingNextPage = true
        paginationErrorMessage = nil

        do {
            let page = try await repository.fetch(pageToLoad, currentQuery)
            finishNextPageLoad(loadID, page: page)
        } catch is CancellationError {
            finishNextPageLoad(loadID)
        } catch {
            finishNextPageLoad(
                loadID,
                paginationErrorMessage: error.localizedDescription
            )
        }
    }

    func updateSearchText(_ text: String) {
        guard searchText != text else { return }
        searchText = text
        scheduleReloadForQueryChange()
    }

    func updateStatusFilter(_ status: CharacterStatusFilter) {
        guard statusFilter != status else { return }
        statusFilter = status
        scheduleReloadForQueryChange()
    }

    func updateGenderFilter(_ gender: CharacterGenderFilter) {
        guard genderFilter != gender else { return }
        genderFilter = gender
        scheduleReloadForQueryChange()
    }

    func clearSearchAndFilters() {
        searchText = ""
        statusFilter = .any
        genderFilter = .any
        scheduleReloadForQueryChange()
    }

    private func scheduleReloadForQueryChange() {
        let nextQuery = CharactersQuery(
            name: searchText,
            status: statusFilter,
            gender: genderFilter
        )

        guard nextQuery != currentQuery else { return }
        currentQuery = nextQuery

        debouncedReloadTask?.cancel()
        debouncedReloadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            if self.debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: self.debounceNanoseconds)
            }

            guard !Task.isCancelled else { return }
            self.debouncedReloadTask = nil
            await self.load()
        }
    }

    private func shouldLoadNextPage(for currentCharacter: Characters) -> Bool {
        guard !isLoading, !isLoadingNextPage else { return false }
        guard paginationErrorMessage == nil else { return false }
        guard nextPage != nil else { return false }
        guard let currentIndex = characters.firstIndex(where: { $0.id == currentCharacter.id }) else {
            return false
        }

        let thresholdIndex = max(characters.count - 5, 0)
        return currentIndex >= thresholdIndex
    }

    private func finishInitialLoad(
        _ loadID: UInt64,
        page: CharactersPage? = nil,
        errorMessage: String? = nil
    ) {
        guard loadID == latestLoadID else { return }

        if let page {
            characters = page.characters
            nextPage = page.nextPage
        }

        self.errorMessage = errorMessage
        isLoading = false
        isLoadingNextPage = false
    }

    private func finishNextPageLoad(
        _ loadID: UInt64,
        page: CharactersPage? = nil,
        paginationErrorMessage: String? = nil
    ) {
        guard loadID == latestLoadID else { return }

        if let page {
            appendUniqueCharacters(page.characters)
            nextPage = page.nextPage
        }

        self.paginationErrorMessage = paginationErrorMessage
        isLoadingNextPage = false
    }

    private func appendUniqueCharacters(_ newCharacters: [Characters]) {
        var ids = Set(characters.map(\.id))
        let unique = newCharacters.filter { ids.insert($0.id).inserted }
        characters.append(contentsOf: unique)
    }

    func dismissError() { errorMessage = nil }
    func dismissPaginationError() { paginationErrorMessage = nil }
}

extension CharactersViewModel {
    /// Preview-only helper to inject controlled state snapshots.
    @discardableResult
    func _previewInject(
        characters: [Characters] = [],
        isLoading: Bool = false,
        isLoadingNextPage: Bool = false,
        errorMessage: String? = nil,
        paginationErrorMessage: String? = nil,
        nextPage: Int? = nil,
        searchText: String = "",
        statusFilter: CharacterStatusFilter = .any,
        genderFilter: CharacterGenderFilter = .any
    ) -> Self {
        self.characters = characters
        self.isLoading = isLoading
        self.isLoadingNextPage = isLoadingNextPage
        self.errorMessage = errorMessage
        self.paginationErrorMessage = paginationErrorMessage
        self.nextPage = nextPage
        self.searchText = searchText
        self.statusFilter = statusFilter
        self.genderFilter = genderFilter
        self.currentQuery = CharactersQuery(
            name: searchText,
            status: statusFilter,
            gender: genderFilter
        )
        return self
    }
}

@MainActor
final class CharacterDetailViewModel: ObservableObject {
    @Published private(set) var detail: CharacterDetail?
    @Published private(set) var episodes: [Episode] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var episodeWarningMessage: String?

    private let characterID: Int
    private let repository: CharacterDetailRepository
    private var latestLoadID: UInt64 = 0

    init(characterID: Int, repository: CharacterDetailRepository) {
        self.characterID = characterID
        self.repository = repository
    }

    static func live(characterID: Int) -> Self {
        .init(characterID: characterID, repository: .live())
    }

    static func preview() -> Self {
        let previewDetail = CharacterDetail.preview()
        let previewEpisodes = Episode.previewList()
        return Self(
            characterID: previewDetail.id,
            repository: .mock(detail: previewDetail, episodes: previewEpisodes)
        )
        ._previewInject(detail: previewDetail, episodes: previewEpisodes)
    }

    func load() async {
        latestLoadID += 1
        let loadID = latestLoadID
        isLoading = true
        errorMessage = nil
        episodeWarningMessage = nil

        do {
            let detail = try await repository.fetchDetail(characterID)
            let episodeIDs = uniqueEpisodeIDs(from: detail.episode)
            let fetchedEpisodes: [Episode]

            do {
                fetchedEpisodes = try await fetchEpisodesIfNeeded(episodeIDs)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Keep the core detail visible even if episode lookup fails.
                finishLoad(
                    loadID,
                    detail: detail,
                    episodes: [],
                    episodeWarningMessage: "Some episodes couldn't be loaded right now."
                )
                return
            }

            let orderedEpisodes = orderEpisodes(
                fetchedEpisodes,
                using: episodeIDs
            )
            finishLoad(loadID, detail: detail, episodes: orderedEpisodes)
        } catch is CancellationError {
            finishLoad(loadID)
        } catch {
            finishLoad(loadID, errorMessage: error.localizedDescription)
        }
    }

    private func fetchEpisodesIfNeeded(_ ids: [Int]) async throws -> [Episode] {
        guard !ids.isEmpty else { return [] }
        return try await repository.fetchEpisodes(ids)
    }

    private func uniqueEpisodeIDs(from urls: [URL]) -> [Int] {
        var seen = Set<Int>()
        var ids: [Int] = []

        for url in urls {
            guard let id = url.resourceID else { continue }
            if seen.insert(id).inserted {
                ids.append(id)
            }
        }

        return ids
    }

    private func orderEpisodes(_ episodes: [Episode], using orderedIDs: [Int]) -> [Episode] {
        let rank = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, $0) })
        return episodes.sorted { lhs, rhs in
            let leftRank = rank[lhs.id] ?? Int.max
            let rightRank = rank[rhs.id] ?? Int.max
            return leftRank < rightRank
        }
    }

    private func finishLoad(
        _ loadID: UInt64,
        detail: CharacterDetail? = nil,
        episodes: [Episode]? = nil,
        errorMessage: String? = nil,
        episodeWarningMessage: String? = nil
    ) {
        guard loadID == latestLoadID else { return }

        if let detail {
            self.detail = detail
        }

        if let episodes {
            self.episodes = episodes
        }

        self.errorMessage = errorMessage
        self.episodeWarningMessage = episodeWarningMessage
        isLoading = false
    }

    func dismissError() { errorMessage = nil }
}

extension CharacterDetailViewModel {
    @discardableResult
    func _previewInject(
        detail: CharacterDetail,
        episodes: [Episode]
    ) -> Self {
        self.detail = detail
        self.episodes = episodes
        self.errorMessage = nil
        self.episodeWarningMessage = nil
        self.isLoading = false
        return self
    }
}
