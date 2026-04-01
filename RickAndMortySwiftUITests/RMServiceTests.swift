import XCTest
@testable import RickAndMortySwiftUI

final class RMServiceTests: XCTestCase {

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testFetchCharacters_successDecodesResponse() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character")

        let payload = """
        {
          "results": [
            {
              "id": 1,
              "name": "Rick Sanchez",
              "image": "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: payload, response: response, error: nil)

        let sut = RMService(base: baseURL, session: makeStubbedSession())
        let characters = try await sut.fetchCharacters()

        XCTAssertEqual(characters.count, 1)
        XCTAssertEqual(characters.first?.id, 1)
        XCTAssertEqual(characters.first?.name, "Rick Sanchez")
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.path, "/api/character")
    }

    func testFetchCharacters_whenFetchingPage_mapsNextPageAndAddsPageQuery() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character")

        let payload = """
        {
          "info": {
            "next": "https://rickandmortyapi.com/api/character?page=3"
          },
          "results": [
            {
              "id": 20,
              "name": "Ants in my Eyes Johnson",
              "image": "https://rickandmortyapi.com/api/character/avatar/20.jpeg"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: payload, response: response, error: nil)

        let sut = RMService(base: baseURL, session: makeStubbedSession())
        let page = try await sut.fetchCharacters(page: 2)

        XCTAssertEqual(page.characters.count, 1)
        XCTAssertEqual(page.nextPage, 3)
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.path, "/api/character")
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.query, "page=2")
    }

    func testFetchCharacters_whenQueryHasFilters_encodesAllFilterParameters() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character")
        let payload = """
        {
          "info": {
            "next": null
          },
          "results": []
        }
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: payload, response: response, error: nil)
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        let query = CharactersQuery(
            name: "rick",
            status: .alive,
            gender: .male
        )

        _ = try await sut.fetchCharacters(page: 2, query: query)

        let requestURL = try XCTUnwrap(URLProtocolStub.lastRequestURL)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []

        XCTAssertTrue(items.contains(URLQueryItem(name: "page", value: "2")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "name", value: "rick")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "status", value: "alive")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "gender", value: "male")))
    }

    func testFetchCharacters_whenFilteredQueryReturns404_mapsToEmptyPage() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character")
        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!

        let payload = #"{"error":"There is nothing here"}"#.data(using: .utf8)!
        URLProtocolStub.setStub(data: payload, response: response, error: nil)

        let sut = RMService(base: baseURL, session: makeStubbedSession())
        let query = CharactersQuery(name: "not-found", status: .any, gender: .any)

        let page = try await sut.fetchCharacters(page: 1, query: query)

        XCTAssertTrue(page.characters.isEmpty)
        XCTAssertNil(page.nextPage)
    }

    func testFetchCharacters_whenUnfilteredQueryReturns404_keepsHTTPStatusError() async {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character")
        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: Data(), response: response, error: nil)
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        do {
            _ = try await sut.fetchCharacters(page: 1, query: .init())
            XCTFail("Expected fetchCharacters(page:query:) to throw")
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

    func testFetchCharacters_whenHTTPIsNon2xx_mapsHTTPStatusError() async {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character")

        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: Data(), response: response, error: nil)

        let sut = RMService(base: baseURL, session: makeStubbedSession())

        do {
            _ = try await sut.fetchCharacters()
            XCTFail("Expected fetchCharacters() to throw")
        } catch let error as RMServiceError {
            guard case .httpStatus(let code) = error else {
                XCTFail("Unexpected RMServiceError: \(error)")
                return
            }
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchCharacters_whenPayloadIsInvalid_throwsDecodingError() async {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character")

        let invalidPayload = "{ \"results\": [ { \"unexpected\": true } ] }".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: invalidPayload, response: response, error: nil)

        let sut = RMService(base: baseURL, session: makeStubbedSession())

        do {
            _ = try await sut.fetchCharacters()
            XCTFail("Expected fetchCharacters() to throw")
        } catch let error as RMServiceError {
            guard case .decoding = error else {
                XCTFail("Unexpected RMServiceError: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchCharacters_whenBaseURLIsNil_mapsBadBaseURLError() async {
        let sut = RMService(base: nil, session: makeStubbedSession())

        do {
            _ = try await sut.fetchCharacters()
            XCTFail("Expected fetchCharacters() to throw")
        } catch let error as RMServiceError {
            guard case .badBaseURL = error else {
                XCTFail("Unexpected RMServiceError: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchCharacters_whenTransportFails_mapsTransportError() async {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let transportError = URLError(.notConnectedToInternet)

        URLProtocolStub.setStub(data: nil, response: nil, error: transportError)
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        do {
            _ = try await sut.fetchCharacters()
            XCTFail("Expected fetchCharacters() to throw")
        } catch let error as RMServiceError {
            guard case .transport(let urlError) = error else {
                XCTFail("Unexpected RMServiceError: \(error)")
                return
            }
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchCharacters_whenResponseIsNotHTTP_mapsInvalidResponse() async {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character")
        let response = URLResponse(
            url: endpointURL,
            mimeType: "application/json",
            expectedContentLength: 0,
            textEncodingName: nil
        )

        URLProtocolStub.setStub(data: Data(), response: response, error: nil)
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        do {
            _ = try await sut.fetchCharacters()
            XCTFail("Expected fetchCharacters() to throw")
        } catch let error as RMServiceError {
            guard case .invalidResponse = error else {
                XCTFail("Unexpected RMServiceError: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchCharacterDetail_successDecodesResponse() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character/1")
        let payload = """
        {
          "id": 1,
          "name": "Rick Sanchez",
          "status": "Alive",
          "species": "Human",
          "type": "",
          "gender": "Male",
          "origin": {
            "name": "Earth (C-137)",
            "url": "https://rickandmortyapi.com/api/location/1"
          },
          "location": {
            "name": "Citadel of Ricks",
            "url": "https://rickandmortyapi.com/api/location/3"
          },
          "image": "https://rickandmortyapi.com/api/character/avatar/1.jpeg",
          "episode": [
            "https://rickandmortyapi.com/api/episode/1",
            "https://rickandmortyapi.com/api/episode/2"
          ]
        }
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: payload, response: response, error: nil)
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        let detail = try await sut.fetchCharacterDetail(id: 1)

        XCTAssertEqual(detail.id, 1)
        XCTAssertEqual(detail.name, "Rick Sanchez")
        XCTAssertEqual(detail.origin.name, "Earth (C-137)")
        XCTAssertEqual(detail.location.name, "Citadel of Ricks")
        XCTAssertEqual(detail.episode.count, 2)
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.path, "/api/character/1")
    }

    func testFetchCharacterDetail_whenHTTP404_mapsHTTPStatusError() async {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character/404")
        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: Data(), response: response, error: nil)
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        do {
            _ = try await sut.fetchCharacterDetail(id: 404)
            XCTFail("Expected fetchCharacterDetail(id:) to throw")
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

    func testFetchEpisodes_whenMultipleIDs_decodesArrayAndPreservesOrder() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "episode/1,2,3")
        let payload = """
        [
          { "id": 3, "name": "Anatomy Park", "air_date": "Dec 16, 2013", "episode": "S01E03" },
          { "id": 1, "name": "Pilot", "air_date": "Dec 2, 2013", "episode": "S01E01" },
          { "id": 2, "name": "Lawnmower Dog", "air_date": "Dec 9, 2013", "episode": "S01E02" }
        ]
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: payload, response: response, error: nil)
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        let episodes = try await sut.fetchEpisodes(ids: [1, 2, 3])

        XCTAssertEqual(episodes.map(\.id), [1, 2, 3])
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.path, "/api/episode/1,2,3")
    }

    func testFetchEpisodes_whenSingleID_decodesSingleObject() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "episode/1")
        let payload = """
        { "id": 1, "name": "Pilot", "air_date": "Dec 2, 2013", "episode": "S01E01" }
        """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(data: payload, response: response, error: nil)
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        let episodes = try await sut.fetchEpisodes(ids: [1])

        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes.first?.id, 1)
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.path, "/api/episode/1")
    }

    private func makeStubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private final class URLProtocolStub: URLProtocol {
    private struct Stub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    private static let lock = NSLock()
    private static var stub: Stub?
    private(set) static var lastRequestURL: URL?

    static func setStub(data: Data?, response: URLResponse?, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        stub = Stub(data: data, response: response, error: error)
        lastRequestURL = nil
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        stub = nil
        lastRequestURL = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        URLProtocolStub.lock.lock()
        let currentStub = URLProtocolStub.stub
        URLProtocolStub.lastRequestURL = request.url
        URLProtocolStub.lock.unlock()

        if let error = currentStub?.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if let response = currentStub?.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = currentStub?.data {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
