import XCTest
@testable import RickAndMortySwiftUI

@MainActor
final class CharactersViewModelTests: XCTestCase {
    
    func testLoad_whenRequestsOverlap_lastRequestWins() async {
        var continuations: [CheckedContinuation<CharactersPage, Error>] = []
        
        let repository = CharactersRepository { page, query in
            XCTAssertEqual(page, 1)
            XCTAssertTrue(query.isEmpty)
            return try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
            }
        }
        
        let sut = CharactersViewModel(repository: repository)
        
        let firstTask = Task { await sut.load() }
        await Task.yield()
        
        let secondTask = Task { await sut.load() }
        await Task.yield()
        
        for _ in 0..<50 where continuations.count < 2 {
            await Task.yield()
        }
        XCTAssertEqual(continuations.count, 2)
        guard continuations.count == 2 else {
            return
        }
        
        continuations[0].resume(
            returning: CharactersPage(
                characters: [makeCharacter(id: 1, name: "First")],
                nextPage: nil
            )
        )
        await Task.yield()
        
        XCTAssertTrue(sut.isLoading)
        XCTAssertTrue(sut.characters.isEmpty)
        
        continuations[1].resume(
            returning: CharactersPage(
                characters: [makeCharacter(id: 2, name: "Second")],
                nextPage: nil
            )
        )
        
        await firstTask.value
        await secondTask.value
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.characters.map(\.id), [2])
    }
    
    func testLoad_whenCancelled_doesNotSetErrorMessage() async {
        let repository = CharactersRepository { page, query in
            XCTAssertEqual(page, 1)
            XCTAssertTrue(query.isEmpty)
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return CharactersPage(
                characters: [self.makeCharacter(id: 1, name: "Rick")],
                nextPage: nil
            )
        }
        
        let sut = CharactersViewModel(repository: repository)
        
        let task = Task { await sut.load() }
        await Task.yield()
        
        task.cancel()
        await task.value
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testLoad_whenFailureThenSuccess_clearsErrorAndSetsCharacters() async {
        var callCount = 0
        
        let repository = CharactersRepository { page, query in
            callCount += 1
            XCTAssertEqual(page, 1)
            XCTAssertTrue(query.isEmpty)
            
            if callCount == 1 {
                throw URLError(.timedOut)
            }
            
            return CharactersPage(
                characters: [self.makeCharacter(id: 7, name: "Summer")],
                nextPage: nil
            )
        }
        
        let sut = CharactersViewModel(repository: repository)
        
        await sut.load()
        XCTAssertNotNil(sut.errorMessage)
        
        await sut.load()
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.characters.map(\.id), [7])
    }
    
    func testLoadNextPage_whenLastVisibleCharacterReached_appendsNextPage() async {
        var calledPages: [Int] = []
        
        let repository = CharactersRepository { page, query in
            calledPages.append(page)
            XCTAssertTrue(query.isEmpty)
            
            switch page {
            case 1:
                return CharactersPage(
                    characters: [
                        self.makeCharacter(id: 1, name: "Rick"),
                        self.makeCharacter(id: 2, name: "Morty")
                    ],
                    nextPage: 2
                )
            case 2:
                return CharactersPage(
                    characters: [self.makeCharacter(id: 3, name: "Summer")],
                    nextPage: nil
                )
            default:
                XCTFail("Unexpected page request: \(page)")
                return CharactersPage(characters: [], nextPage: nil)
            }
        }
        
        let sut = CharactersViewModel(repository: repository)
        
        await sut.load()
        await sut.loadNextPageIfNeeded(currentCharacter: makeCharacter(id: 2, name: "Morty"))
        
        XCTAssertEqual(calledPages, [1, 2])
        XCTAssertEqual(sut.characters.map(\.id), [1, 2, 3])
        XCTAssertFalse(sut.isLoadingNextPage)
        XCTAssertNil(sut.paginationErrorMessage)
    }
    
    func testLoadNextPage_whenFailure_keepsExistingCharactersAndSetsPaginationError() async {
        let repository = CharactersRepository { page, query in
            XCTAssertTrue(query.isEmpty)
            
            switch page {
            case 1:
                return CharactersPage(
                    characters: [self.makeCharacter(id: 1, name: "Rick")],
                    nextPage: 2
                )
            case 2:
                throw URLError(.timedOut)
            default:
                XCTFail("Unexpected page request: \(page)")
                return CharactersPage(characters: [], nextPage: nil)
            }
        }
        
        let sut = CharactersViewModel(repository: repository)
        
        await sut.load()
        await sut.loadNextPage()
        
        XCTAssertEqual(sut.characters.map(\.id), [1])
        XCTAssertNotNil(sut.paginationErrorMessage)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoadingNextPage)
    }
    
    func testQueryChange_debouncesAndSendsCombinedFilters() async {
        var calls: [(Int, CharactersQuery)] = []
        
        let repository = CharactersRepository { page, query in
            calls.append((page, query))
            return CharactersPage(characters: [], nextPage: nil)
        }
        
        let sut = CharactersViewModel(
            repository: repository,
            debounceNanoseconds: 120_000_000
        )
        
        sut.updateSearchText("rick")
        sut.updateStatusFilter(.alive)
        sut.updateGenderFilter(.male)
        sut.updateSpeciesFilter("Human")
        sut.updateTypeFilter("Scientist")
        
        try? await Task.sleep(nanoseconds: 350_000_000)
        
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].0, 1)
        XCTAssertEqual(
            calls[0].1,
            CharactersQuery(
                name: "rick",
                status: .alive,
                gender: .male,
                species: "Human",
                type: "Scientist"
            )
        )
    }
    
    func testClearSearchAndFilters_resetsSpeciesAndTypeAndReloadsDefaultQuery() async {
        var calls: [(Int, CharactersQuery)] = []
        
        let repository = CharactersRepository { page, query in
            calls.append((page, query))
            return CharactersPage(characters: [], nextPage: nil)
        }
        
        let sut = CharactersViewModel(repository: repository, debounceNanoseconds: 0)
        
        sut.updateSearchText("rick")
        sut.updateStatusFilter(.alive)
        sut.updateGenderFilter(.male)
        sut.updateSpeciesFilter("Human")
        sut.updateTypeFilter("Scientist")
        
        for _ in 0..<100 where calls.count < 1 {
            await Task.yield()
        }
        
        XCTAssertTrue(sut.hasActiveQuery)
        
        sut.clearSearchAndFilters()
        
        for _ in 0..<100 where calls.count < 2 {
            await Task.yield()
        }
        
        XCTAssertEqual(sut.searchText, "")
        XCTAssertEqual(sut.statusFilter, .any)
        XCTAssertEqual(sut.genderFilter, .any)
        XCTAssertEqual(sut.speciesFilter, "")
        XCTAssertEqual(sut.typeFilter, "")
        XCTAssertFalse(sut.hasActiveQuery)
        XCTAssertEqual(calls.map(\.0), [1, 1])
        XCTAssertEqual(calls.last?.1, CharactersQuery())
    }
    
    func testQueryChange_resetsPaginationToFirstPage() async {
        var calls: [(Int, CharactersQuery)] = []
        
        let repository = CharactersRepository { page, query in
            calls.append((page, query))
            
            if query.trimmedName.isEmpty {
                switch page {
                case 1:
                    return CharactersPage(
                        characters: [self.makeCharacter(id: 1, name: "Rick")],
                        nextPage: 2
                    )
                case 2:
                    return CharactersPage(
                        characters: [self.makeCharacter(id: 2, name: "Morty")],
                        nextPage: nil
                    )
                default:
                    XCTFail("Unexpected page request for default query: \(page)")
                    return CharactersPage(characters: [], nextPage: nil)
                }
            }
            
            if query.trimmedName == "rick" {
                XCTAssertEqual(page, 1)
                return CharactersPage(
                    characters: [self.makeCharacter(id: 10, name: "Filtered Rick")],
                    nextPage: nil
                )
            }
            
            XCTFail("Unexpected query: \(query)")
            return CharactersPage(characters: [], nextPage: nil)
        }
        
        let sut = CharactersViewModel(repository: repository, debounceNanoseconds: 0)
        
        await sut.load()
        await sut.loadNextPage()
        XCTAssertEqual(sut.characters.map(\.id), [1, 2])
        
        sut.updateSearchText("rick")
        
        for _ in 0..<100 where calls.count < 3 {
            await Task.yield()
        }
        for _ in 0..<100 where sut.isLoading {
            await Task.yield()
        }
        
        XCTAssertEqual(calls.map(\.0), [1, 2, 1])
        XCTAssertEqual(calls[2].1.trimmedName, "rick")
        XCTAssertEqual(sut.characters.map(\.id), [10])
        XCTAssertTrue(sut.hasActiveQuery)
    }
    
    func testQueryWithNoMatches_resultsInEmptyStateWithoutError() async {
        let repository = CharactersRepository { page, query in
            if query.trimmedName.isEmpty {
                return CharactersPage(
                    characters: [self.makeCharacter(id: 1, name: "Rick")],
                    nextPage: nil
                )
            }
            
            XCTAssertEqual(page, 1)
            XCTAssertEqual(query.trimmedName, "not-found")
            return CharactersPage(characters: [], nextPage: nil)
        }
        
        let sut = CharactersViewModel(repository: repository, debounceNanoseconds: 0)
        
        await sut.load()
        XCTAssertEqual(sut.characters.map(\.id), [1])
        
        sut.updateSearchText("not-found")
        
        for _ in 0..<100 where sut.isLoading {
            await Task.yield()
        }
        
        XCTAssertTrue(sut.characters.isEmpty)
        XCTAssertNil(sut.errorMessage)
    }
    
    private func makeCharacter(id: Int, name: String) -> Characters {
        Characters(id: id, name: name, image: nil)
    }
}

@MainActor
final class CharacterDetailViewModelTests: XCTestCase {
    
    func testLoad_success_fetchesDetailAndEpisodesInRequestedOrder() async {
        let detail = makeDetail(id: 1, episodeIDs: [1, 2, 3])
        var requestedEpisodeIDs: [Int] = []
        
        let repository = CharacterDetailRepository(
            fetchDetail: { id in
                XCTAssertEqual(id, 1)
                return detail
            },
            fetchEpisodes: { ids in
                requestedEpisodeIDs = ids
                return [
                    self.makeEpisode(id: 3, code: "S01E03", name: "Anatomy Park"),
                    self.makeEpisode(id: 1, code: "S01E01", name: "Pilot"),
                    self.makeEpisode(id: 2, code: "S01E02", name: "Lawnmower Dog")
                ]
            }
        )
        
        let sut = CharacterDetailViewModel(characterID: 1, repository: repository)
        await sut.load()
        
        XCTAssertEqual(requestedEpisodeIDs, [1, 2, 3])
        XCTAssertEqual(sut.detail?.id, 1)
        XCTAssertEqual(sut.episodes.map(\.id), [1, 2, 3])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testLoad_whenDetailHasNoEpisodes_skipsEpisodeFetch() async {
        var fetchEpisodesCalled = false
        let detail = makeDetail(id: 2, episodeIDs: [])
        
        let repository = CharacterDetailRepository(
            fetchDetail: { _ in detail },
            fetchEpisodes: { _ in
                fetchEpisodesCalled = true
                return []
            }
        )
        
        let sut = CharacterDetailViewModel(characterID: 2, repository: repository)
        await sut.load()
        
        XCTAssertFalse(fetchEpisodesCalled)
        XCTAssertEqual(sut.detail?.id, 2)
        XCTAssertTrue(sut.episodes.isEmpty)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testLoad_whenDetailRequestFails_setsError() async {
        struct StubError: Error {}
        
        let repository = CharacterDetailRepository(
            fetchDetail: { _ in throw StubError() },
            fetchEpisodes: { _ in [] }
        )
        
        let sut = CharacterDetailViewModel(characterID: 99, repository: repository)
        await sut.load()
        
        XCTAssertNil(sut.detail)
        XCTAssertTrue(sut.episodes.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testLoad_whenEpisodeRequestFails_keepsDetailAndReturnsEmptyEpisodes() async {
        struct StubError: Error {}
        let detail = makeDetail(id: 4, episodeIDs: [1, 2])
        
        let repository = CharacterDetailRepository(
            fetchDetail: { _ in detail },
            fetchEpisodes: { _ in throw StubError() }
        )
        
        let sut = CharacterDetailViewModel(characterID: 4, repository: repository)
        await sut.load()
        
        XCTAssertEqual(sut.detail?.id, 4)
        XCTAssertTrue(sut.episodes.isEmpty)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNotNil(sut.episodeWarningMessage)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testLoad_whenEpisodeRequestFailsThenSucceeds_clearsEpisodeWarning() async {
        struct StubError: Error {}
        let detail = makeDetail(id: 5, episodeIDs: [1, 2])
        var fetchEpisodesCallCount = 0
        
        let repository = CharacterDetailRepository(
            fetchDetail: { _ in detail },
            fetchEpisodes: { _ in
                fetchEpisodesCallCount += 1
                if fetchEpisodesCallCount == 1 {
                    throw StubError()
                }
                return [
                    self.makeEpisode(id: 1, code: "S01E01", name: "Pilot"),
                    self.makeEpisode(id: 2, code: "S01E02", name: "Lawnmower Dog")
                ]
            }
        )
        
        let sut = CharacterDetailViewModel(characterID: 5, repository: repository)
        
        await sut.load()
        XCTAssertNotNil(sut.episodeWarningMessage)
        XCTAssertTrue(sut.episodes.isEmpty)
        
        await sut.load()
        XCTAssertNil(sut.episodeWarningMessage)
        XCTAssertEqual(sut.episodes.map(\.id), [1, 2])
    }
    
    private func makeDetail(id: Int, episodeIDs: [Int]) -> CharacterDetail {
        let episodeURLs = episodeIDs.compactMap { URL(string: "https://rickandmortyapi.com/api/episode/\($0)") }
        return CharacterDetail(
            id: id,
            name: "Character \(id)",
            status: "Alive",
            species: "Human",
            type: "",
            gender: "Male",
            origin: RMNamedResource(name: "Earth", url: "https://rickandmortyapi.com/api/location/1"),
            location: RMNamedResource(name: "Citadel", url: "https://rickandmortyapi.com/api/location/3"),
            image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(id).jpeg"),
            episode: episodeURLs
        )
    }
    
    private func makeEpisode(id: Int, code: String, name: String) -> Episode {
        Episode(
            id: id,
            name: name,
            airDate: "2013-12-\(String(format: "%02d", id))",
            episode: code
        )
    }
}

final class CharacterDetailEpisodesSectionStateTests: XCTestCase {
    
    func testCollapsedState_showsFirstEightEpisodesWithSummary() {
        let state = CharacterDetailEpisodesSectionState(
            episodes: makeEpisodes(count: 12),
            showsAllEpisodes: false
        )
        
        XCTAssertEqual(state.displayedEpisodes.count, 8)
        XCTAssertEqual(state.displayedEpisodes.map(\.id), Array(1...8))
        XCTAssertTrue(state.canToggleExpansion)
        XCTAssertEqual(state.expansionButtonTitle, "Show All Episodes")
        XCTAssertEqual(state.collapsedSummaryText, "Showing 8 of 12.")
    }
    
    func testExpandedState_showsAllEpisodesWithoutSummary() {
        let state = CharacterDetailEpisodesSectionState(
            episodes: makeEpisodes(count: 12),
            showsAllEpisodes: true
        )
        
        XCTAssertEqual(state.displayedEpisodes.count, 12)
        XCTAssertTrue(state.canToggleExpansion)
        XCTAssertEqual(state.expansionButtonTitle, "Show Less")
        XCTAssertNil(state.collapsedSummaryText)
    }
    
    private func makeEpisodes(count: Int) -> [Episode] {
        (1...count).map { id in
            Episode(
                id: id,
                name: "Episode \(id)",
                airDate: "December \(id), 2013",
                episode: String(format: "S01E%02d", id)
            )
        }
    }
}

final class CharactersRepositoryTests: XCTestCase {
    
    func testFetch_returnsProvidedCharactersPage() async throws {
        let expected = CharactersPage(
            characters: [Characters(id: 42, name: "Beth", image: nil)],
            nextPage: 2
        )
        
        let repository = CharactersRepository { page, query in
            XCTAssertEqual(page, 1)
            XCTAssertTrue(query.isEmpty)
            return expected
        }
        
        let result = try await repository.fetch(1, .init())
        
        XCTAssertEqual(result, expected)
    }
    
    func testFetch_propagatesThrownError() async {
        struct StubError: Error {}
        let repository = CharactersRepository { _, _ in
            throw StubError()
        }
        
        do {
            _ = try await repository.fetch(1, .init())
            XCTFail("Expected fetch(page:query:) to throw")
        } catch is StubError {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testMock_returnsPreviewCharactersOnPage1() async throws {
        let repository = CharactersRepository.mock()
        
        let result = try await repository.fetch(1, .init())
        
        XCTAssertFalse(result.characters.isEmpty)
        XCTAssertNil(result.nextPage)
    }
    
    func testMock_returnsEmptyDataAfterPage1() async throws {
        let repository = CharactersRepository.mock()
        
        let result = try await repository.fetch(2, .init())
        
        XCTAssertTrue(result.characters.isEmpty)
        XCTAssertNil(result.nextPage)
    }
    
    func testCached_whenSamePageAndQueryWithinMaxAge_returnsCachedPageWithoutSecondNetworkCall() async throws {
        var now = Date(timeIntervalSince1970: 10_000)
        var remoteCallCount = 0
        
        let repository = CharactersRepository.cached(
            maxAge: 300,
            now: { now },
            fetchRemote: { page, query in
                remoteCallCount += 1
                XCTAssertEqual(page, 1)
                XCTAssertEqual(query.trimmedName, "rick")
                XCTAssertEqual(query.status, .alive)
                XCTAssertEqual(query.gender, .male)
                
                return CharactersPage(
                    characters: [Characters(id: remoteCallCount, name: "Character \(remoteCallCount)", image: nil)],
                    nextPage: nil
                )
            }
        )
        
        let query = CharactersQuery(name: "rick", status: .alive, gender: .male)
        let first = try await repository.fetch(1, query)
        now.addTimeInterval(15)
        let second = try await repository.fetch(1, query)
        
        XCTAssertEqual(remoteCallCount, 1)
        XCTAssertEqual(first.characters.map(\.id), [1])
        XCTAssertEqual(second.characters.map(\.id), [1])
    }
    
    func testCached_whenCacheExpiredAndNetworkFails_returnsStaleCachedPage() async throws {
        var now = Date(timeIntervalSince1970: 20_000)
        var remoteCallCount = 0
        var shouldFail = false
        
        let repository = CharactersRepository.cached(
            maxAge: 60,
            now: { now },
            fetchRemote: { page, query in
                remoteCallCount += 1
                XCTAssertEqual(page, 1)
                XCTAssertEqual(query.trimmedName, "morty")
                
                if shouldFail {
                    throw URLError(.timedOut)
                }
                
                return CharactersPage(
                    characters: [Characters(id: 99, name: "Cached Morty", image: nil)],
                    nextPage: nil
                )
            }
        )
        
        let query = CharactersQuery(name: "morty")
        let initial = try await repository.fetch(1, query)
        XCTAssertEqual(initial.characters.map(\.id), [99])
        
        now.addTimeInterval(61)
        shouldFail = true
        let fallback = try await repository.fetch(1, query)
        
        XCTAssertEqual(remoteCallCount, 2)
        XCTAssertEqual(fallback.characters.map(\.id), [99])
    }
    
    func testCached_whenQueriesDiffer_usesSeparateCacheEntries() async throws {
        var remoteCallCount = 0
        let now = Date(timeIntervalSince1970: 21_000)
        
        let repository = CharactersRepository.cached(
            maxAge: 300,
            now: { now },
            fetchRemote: { _, query in
                remoteCallCount += 1
                return CharactersPage(
                    characters: [
                        Characters(
                            id: remoteCallCount,
                            name: "\(query.trimmedName)-\(query.status.rawValue)",
                            image: nil
                        )
                    ],
                    nextPage: nil
                )
            }
        )
        
        let aliveQuery = CharactersQuery(name: "rick", status: .alive, gender: .male)
        let deadQuery = CharactersQuery(name: "rick", status: .dead, gender: .male)
        
        let firstAlive = try await repository.fetch(1, aliveQuery)
        let firstDead = try await repository.fetch(1, deadQuery)
        let secondAlive = try await repository.fetch(1, aliveQuery)
        
        XCTAssertEqual(remoteCallCount, 2)
        XCTAssertEqual(firstAlive.characters.map(\.id), [1])
        XCTAssertEqual(firstDead.characters.map(\.id), [2])
        XCTAssertEqual(secondAlive.characters.map(\.id), [1])
    }
    
    func testCached_whenAgeEqualsMaxAge_usesCachedPage() async throws {
        var now = Date(timeIntervalSince1970: 22_000)
        var remoteCallCount = 0
        
        let repository = CharactersRepository.cached(
            maxAge: 60,
            now: { now },
            fetchRemote: { _, _ in
                remoteCallCount += 1
                return CharactersPage(
                    characters: [Characters(id: remoteCallCount, name: "Boundary", image: nil)],
                    nextPage: nil
                )
            }
        )
        
        let query = CharactersQuery(name: "boundary")
        _ = try await repository.fetch(1, query)
        now.addTimeInterval(60)
        let second = try await repository.fetch(1, query)
        
        XCTAssertEqual(remoteCallCount, 1)
        XCTAssertEqual(second.characters.map(\.id), [1])
    }
    
    func testCached_whenMaxAgeIsZero_refreshesAfterTimeAdvances() async throws {
        var now = Date(timeIntervalSince1970: 23_000)
        var remoteCallCount = 0
        
        let repository = CharactersRepository.cached(
            maxAge: 0,
            now: { now },
            fetchRemote: { _, _ in
                remoteCallCount += 1
                return CharactersPage(
                    characters: [Characters(id: remoteCallCount, name: "Zero TTL", image: nil)],
                    nextPage: nil
                )
            }
        )
        
        let query = CharactersQuery(name: "zero")
        let first = try await repository.fetch(1, query)
        now.addTimeInterval(0.001)
        let second = try await repository.fetch(1, query)
        
        XCTAssertEqual(remoteCallCount, 2)
        XCTAssertEqual(first.characters.map(\.id), [1])
        XCTAssertEqual(second.characters.map(\.id), [2])
    }
}

final class CharacterDetailRepositoryTests: XCTestCase {
    
    func testCachedFetchDetail_whenSameIDWithinMaxAge_returnsCachedValueWithoutSecondNetworkCall() async throws {
        var now = Date(timeIntervalSince1970: 30_000)
        var detailCallCount = 0
        
        let repository = CharacterDetailRepository.cached(
            maxAge: 300,
            now: { now },
            fetchDetailRemote: { id in
                detailCallCount += 1
                return self.makeDetail(id: id, episodeIDs: [1, 2], name: "Detail \(detailCallCount)")
            },
            fetchEpisodesRemote: { _ in [] }
        )
        
        let first = try await repository.fetchDetail(7)
        now.addTimeInterval(20)
        let second = try await repository.fetchDetail(7)
        
        XCTAssertEqual(detailCallCount, 1)
        XCTAssertEqual(first.name, "Detail 1")
        XCTAssertEqual(second.name, "Detail 1")
    }
    
    func testCachedFetchEpisodes_whenCacheExpiredAndNetworkFails_returnsStaleEpisodes() async throws {
        var now = Date(timeIntervalSince1970: 40_000)
        var episodesCallCount = 0
        var shouldFail = false
        
        let repository = CharacterDetailRepository.cached(
            maxAge: 60,
            now: { now },
            fetchDetailRemote: { id in self.makeDetail(id: id, episodeIDs: [1, 2]) },
            fetchEpisodesRemote: { ids in
                episodesCallCount += 1
                
                if shouldFail {
                    throw URLError(.networkConnectionLost)
                }
                
                return ids.map { id in
                    Episode(
                        id: id,
                        name: "Episode \(id)",
                        airDate: "December \(id), 2013",
                        episode: String(format: "S01E%02d", id)
                    )
                }
            }
        )
        
        let initial = try await repository.fetchEpisodes([1, 2])
        XCTAssertEqual(initial.map(\.id), [1, 2])
        
        now.addTimeInterval(61)
        shouldFail = true
        let fallback = try await repository.fetchEpisodes([1, 2])
        
        XCTAssertEqual(episodesCallCount, 2)
        XCTAssertEqual(fallback.map(\.id), [1, 2])
    }
    
    func testCachedFetchDetail_whenCacheExpiredAndNetworkFails_returnsStaleDetail() async throws {
        var now = Date(timeIntervalSince1970: 41_000)
        var detailCallCount = 0
        var shouldFail = false
        
        let repository = CharacterDetailRepository.cached(
            maxAge: 60,
            now: { now },
            fetchDetailRemote: { id in
                detailCallCount += 1
                
                if shouldFail {
                    throw URLError(.cannotFindHost)
                }
                
                return self.makeDetail(id: id, episodeIDs: [1, 2], name: "Detail \(detailCallCount)")
            },
            fetchEpisodesRemote: { _ in [] }
        )
        
        let initial = try await repository.fetchDetail(7)
        now.addTimeInterval(61)
        shouldFail = true
        let fallback = try await repository.fetchDetail(7)
        
        XCTAssertEqual(detailCallCount, 2)
        XCTAssertEqual(initial.name, "Detail 1")
        XCTAssertEqual(fallback.name, "Detail 1")
    }
    
    private func makeDetail(id: Int, episodeIDs: [Int], name: String = "Character") -> CharacterDetail {
        let episodeURLs = episodeIDs.compactMap { URL(string: "https://rickandmortyapi.com/api/episode/\($0)") }
        return CharacterDetail(
            id: id,
            name: name,
            status: "Alive",
            species: "Human",
            type: "",
            gender: "Male",
            origin: RMNamedResource(name: "Earth", url: "https://rickandmortyapi.com/api/location/1"),
            location: RMNamedResource(name: "Citadel", url: "https://rickandmortyapi.com/api/location/3"),
            image: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(id).jpeg"),
            episode: episodeURLs
        )
    }
}

final class CharacterLookupRepositoryTests: XCTestCase {

    func testMockFetchByIDs_returnsCharactersInRequestedOrder() async throws {
        let characterOne = Characters(id: 1, name: "Rick Sanchez", image: nil)
        let characterTwo = Characters(id: 2, name: "Morty Smith", image: nil)
        let repository = CharacterLookupRepository.mock(
            charactersByID: [
                1: characterOne,
                2: characterTwo
            ]
        )

        let result = try await repository.fetchByIDs([2, 1, 2, 0, -3])

        XCTAssertEqual(result.map(\.id), [2, 1])
    }

    func testMockFetchByIDs_whenNoValidIDs_returnsEmptyWithoutErrors() async throws {
        let repository = CharacterLookupRepository.mock(
            charactersByID: [1: Characters(id: 1, name: "Rick Sanchez", image: nil)]
        )

        let result = try await repository.fetchByIDs([0, -1, 0])

        XCTAssertTrue(result.isEmpty)
    }
}

@MainActor
final class LocationSearchViewModelTests: XCTestCase {

    func testQueryChange_debouncesAndSendsCombinedFilters() async {
        var calls: [(Int, LocationQuery)] = []

        let repository = LocationRepository(
            fetch: { page, query in
                calls.append((page, query))
                return LocationsPage(locations: [], nextPage: nil)
            },
            fetchByID: { _ in
                XCTFail("fetchByID should not be called in this test")
                return self.makeLocation(id: 0, name: "unused")
            }
        )

        let sut = LocationSearchViewModel(
            repository: repository,
            debounceNanoseconds: 120_000_000
        )

        sut.updateNameFilter("citadel")
        sut.updateTypeFilter("space station")
        sut.updateDimensionFilter("unknown")

        try? await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].0, 1)
        XCTAssertEqual(
            calls[0].1,
            LocationQuery(name: "citadel", type: "space station", dimension: "unknown")
        )
        XCTAssertTrue(sut.hasActiveQuery)
    }

    func testLoadNextPage_appendsUniqueLocations() async {
        let repository = LocationRepository(
            fetch: { page, _ in
                switch page {
                case 1:
                    return LocationsPage(
                        locations: [
                            self.makeLocation(id: 1, name: "Earth"),
                            self.makeLocation(id: 2, name: "Citadel")
                        ],
                        nextPage: 2
                    )
                case 2:
                    return LocationsPage(
                        locations: [
                            self.makeLocation(id: 2, name: "Citadel"),
                            self.makeLocation(id: 3, name: "Gazorpazorp")
                        ],
                        nextPage: nil
                    )
                default:
                    XCTFail("Unexpected page request: \(page)")
                    return LocationsPage(locations: [], nextPage: nil)
                }
            },
            fetchByID: { _ in
                XCTFail("fetchByID should not be called in this test")
                return self.makeLocation(id: 0, name: "unused")
            }
        )

        let sut = LocationSearchViewModel(repository: repository, debounceNanoseconds: 0)

        await sut.load()
        await sut.loadNextPage()

        XCTAssertEqual(sut.locations.map(\.id), [1, 2, 3])
        XCTAssertFalse(sut.isLoadingNextPage)
        XCTAssertNil(sut.paginationErrorMessage)
    }

    private func makeLocation(id: Int, name: String) -> Location {
        Location(
            id: id,
            name: name,
            type: "Space station",
            dimension: "unknown",
            residents: [],
            url: URL(string: "https://rickandmortyapi.com/api/location/\(id)")
        )
    }
}

@MainActor
final class EpisodeCatalogViewModelTests: XCTestCase {

    func testQueryChange_debouncesAndSendsCombinedFilters() async {
        var calls: [(Int, EpisodeListQuery)] = []

        let repository = EpisodeCatalogRepository(
            fetch: { page, query in
                calls.append((page, query))
                return EpisodesPage(episodes: [], nextPage: nil)
            }
        )

        let sut = EpisodeCatalogViewModel(
            repository: repository,
            debounceNanoseconds: 120_000_000
        )

        sut.updateNameFilter("pilot")
        sut.updateEpisodeFilter("S01")

        try? await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].0, 1)
        XCTAssertEqual(calls[0].1, EpisodeListQuery(name: "pilot", episode: "S01"))
        XCTAssertTrue(sut.hasActiveQuery)
    }

    func testLoadNextPage_appendsUniqueEpisodes() async {
        let repository = EpisodeCatalogRepository(
            fetch: { page, _ in
                switch page {
                case 1:
                    return EpisodesPage(
                        episodes: [
                            self.makeEpisode(id: 1, name: "Pilot"),
                            self.makeEpisode(id: 2, name: "Lawnmower Dog")
                        ],
                        nextPage: 2
                    )
                case 2:
                    return EpisodesPage(
                        episodes: [
                            self.makeEpisode(id: 2, name: "Lawnmower Dog"),
                            self.makeEpisode(id: 3, name: "Anatomy Park")
                        ],
                        nextPage: nil
                    )
                default:
                    XCTFail("Unexpected page request: \(page)")
                    return EpisodesPage(episodes: [], nextPage: nil)
                }
            }
        )

        let sut = EpisodeCatalogViewModel(repository: repository, debounceNanoseconds: 0)

        await sut.load()
        await sut.loadNextPage()

        XCTAssertEqual(sut.episodes.map(\.id), [1, 2, 3])
        XCTAssertFalse(sut.isLoadingNextPage)
        XCTAssertNil(sut.paginationErrorMessage)
    }

    private func makeEpisode(id: Int, name: String) -> Episode {
        Episode(
            id: id,
            name: name,
            airDate: "December \(id), 2013",
            episode: String(format: "S01E%02d", id)
        )
    }
}

final class LocationRepositoryTests: XCTestCase {

    func testMock_returnsConfiguredPageAndLocationByID() async throws {
        let expectedLocation = Location(
            id: 3,
            name: "Citadel of Ricks",
            type: "Space station",
            dimension: "unknown",
            residents: [],
            url: URL(string: "https://rickandmortyapi.com/api/location/3")
        )

        let repository = LocationRepository.mock(
            pages: [
                1: LocationsPage(locations: [expectedLocation], nextPage: nil)
            ],
            locationsByID: [
                3: expectedLocation
            ]
        )

        let page = try await repository.fetch(1, .init())
        let location = try await repository.fetchByID(3)

        XCTAssertEqual(page.locations.map(\.id), [3])
        XCTAssertEqual(location.id, 3)
        XCTAssertEqual(location.name, "Citadel of Ricks")
    }

    func testMock_whenLocationMissing_throws404Status() async {
        let repository = LocationRepository.mock()

        do {
            _ = try await repository.fetchByID(999)
            XCTFail("Expected fetchByID(_:) to throw")
        } catch let error as RMServiceError {
            guard case .httpStatus(let code) = error else {
                XCTFail("Unexpected RMServiceError: \(error)")
                return
            }
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

final class LocationLookupRepositoryTests: XCTestCase {

    func testMockFetchByIDs_returnsLocationsInRequestedOrder() async throws {
        let locationOne = makeLocation(id: 1, name: "Earth (C-137)")
        let locationThree = makeLocation(id: 3, name: "Citadel of Ricks")
        let repository = LocationLookupRepository.mock(
            locationsByID: [
                1: locationOne,
                3: locationThree
            ]
        )

        let result = try await repository.fetchByIDs([3, 1, 3, 0, -2])

        XCTAssertEqual(result.map(\.id), [3, 1])
    }

    func testMockFetchByIDs_whenNoValidIDs_returnsEmptyWithoutErrors() async throws {
        let repository = LocationLookupRepository.mock(
            locationsByID: [1: makeLocation(id: 1, name: "Earth (C-137)")]
        )

        let result = try await repository.fetchByIDs([0, -1, 0])

        XCTAssertTrue(result.isEmpty)
    }

    private func makeLocation(id: Int, name: String) -> Location {
        Location(
            id: id,
            name: name,
            type: "Space station",
            dimension: "unknown",
            residents: [],
            url: URL(string: "https://rickandmortyapi.com/api/location/\(id)")
        )
    }
}

final class EpisodeCatalogRepositoryTests: XCTestCase {

    func testMock_returnsConfiguredPage() async throws {
        let expected = EpisodesPage(
            episodes: [
                Episode(id: 1, name: "Pilot", airDate: "December 2, 2013", episode: "S01E01")
            ],
            nextPage: nil
        )
        let repository = EpisodeCatalogRepository.mock(pages: [1: expected])

        let page = try await repository.fetch(1, .init())

        XCTAssertEqual(page.episodes.map(\.id), [1])
        XCTAssertNil(page.nextPage)
    }
}
