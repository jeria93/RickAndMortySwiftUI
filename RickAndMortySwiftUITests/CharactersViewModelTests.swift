import XCTest
@testable import RickAndMortySwiftUI

@MainActor
final class CharactersViewModelTests: XCTestCase {

    func testLoad_whenRequestsOverlap_lastRequestWins() async {
        var continuations: [CheckedContinuation<[Characters], Error>] = []

        let repository = CharactersRepository {
            try await withCheckedThrowingContinuation { continuation in
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

        continuations[0].resume(returning: [makeCharacter(id: 1, name: "First")])
        await Task.yield()

        XCTAssertTrue(sut.isLoading)
        XCTAssertTrue(sut.characters.isEmpty)

        continuations[1].resume(returning: [makeCharacter(id: 2, name: "Second")])

        await firstTask.value
        await secondTask.value

        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.characters.map(\.id), [2])
    }

    func testLoad_whenCancelled_doesNotSetErrorMessage() async {
        let repository = CharactersRepository {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return [self.makeCharacter(id: 1, name: "Rick")]
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

        let repository = CharactersRepository {
            callCount += 1
            if callCount == 1 {
                throw URLError(.timedOut)
            }
            return [self.makeCharacter(id: 7, name: "Summer")]
        }

        let sut = CharactersViewModel(repository: repository)

        await sut.load()
        XCTAssertNotNil(sut.errorMessage)

        await sut.load()

        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.characters.map(\.id), [7])
    }

    private func makeCharacter(id: Int, name: String) -> Characters {
        Characters(id: id, name: name, image: nil)
    }
}

final class CharactersRepositoryTests: XCTestCase {

    func testFetch_returnsProvidedCharacters() async throws {
        let expected = [Characters(id: 42, name: "Beth", image: nil)]
        let repository = CharactersRepository { expected }

        let result = try await repository.fetch()

        XCTAssertEqual(result, expected)
    }

    func testFetch_propagatesThrownError() async {
        struct StubError: Error {}
        let repository = CharactersRepository {
            throw StubError()
        }

        do {
            _ = try await repository.fetch()
            XCTFail("Expected fetch() to throw")
        } catch is StubError {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMock_returnsPreviewCharacters() async throws {
        let repository = CharactersRepository.mock()

        let result = try await repository.fetch()

        XCTAssertFalse(result.isEmpty)
    }
}
