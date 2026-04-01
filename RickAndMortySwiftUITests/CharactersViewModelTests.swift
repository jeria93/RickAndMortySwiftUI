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

        try? await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].0, 1)
        XCTAssertEqual(calls[0].1, CharactersQuery(name: "rick", status: .alive, gender: .male))
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
}
