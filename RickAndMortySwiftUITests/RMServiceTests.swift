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
            gender: .male,
            species: "Human",
            type: "Scientist"
        )

        _ = try await sut.fetchCharacters(page: 2, query: query)

        let requestURL = try XCTUnwrap(URLProtocolStub.lastRequestURL)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []

        XCTAssertTrue(items.contains(URLQueryItem(name: "page", value: "2")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "name", value: "rick")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "species", value: "Human")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "type", value: "Scientist")))
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

    func testFetchCharactersByIDs_whenMultipleIDs_decodesArrayAndPreservesRequestedOrder() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character/2,1")
        let payload = """
        [
          {
            "id": 1,
            "name": "Rick Sanchez",
            "image": "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
          },
          {
            "id": 2,
            "name": "Morty Smith",
            "image": "https://rickandmortyapi.com/api/character/avatar/2.jpeg"
          }
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

        let characters = try await sut.fetchCharacters(ids: [2, 1, 2, 0, -3])

        XCTAssertEqual(characters.map(\.id), [2, 1])
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.path, "/api/character/2,1")
    }

    func testFetchCharactersByIDs_whenSingleID_decodesSingleObject() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "character/7")
        let payload = """
        {
          "id": 7,
          "name": "Abradolf Lincler",
          "image": "https://rickandmortyapi.com/api/character/avatar/7.jpeg"
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

        let characters = try await sut.fetchCharacters(ids: [7])

        XCTAssertEqual(characters.map(\.id), [7])
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.path, "/api/character/7")
    }

    func testFetchCharactersByIDs_whenAllIDsInvalid_returnsEmptyWithoutNetworkCall() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        let characters = try await sut.fetchCharacters(ids: [0, -4, 0])

        XCTAssertTrue(characters.isEmpty)
        XCTAssertNil(URLProtocolStub.lastRequestURL)
    }

    func testFetchCharactersByIDs_whenHTTP404_mapsHTTPStatusError() async {
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
            _ = try await sut.fetchCharacters(ids: [404])
            XCTFail("Expected fetchCharacters(ids:) to throw")
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

    func testFetchLocation_successDecodesResponse() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "location/3")
        let payload = """
        {
          "id": 3,
          "name": "Citadel of Ricks",
          "type": "Space station",
          "dimension": "unknown",
          "residents": [
            "https://rickandmortyapi.com/api/character/8"
          ],
          "url": "https://rickandmortyapi.com/api/location/3"
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

        let location = try await sut.fetchLocation(id: 3)

        XCTAssertEqual(location.id, 3)
        XCTAssertEqual(location.name, "Citadel of Ricks")
        XCTAssertEqual(location.type, "Space station")
        XCTAssertEqual(location.residents.count, 1)
        XCTAssertEqual(URLProtocolStub.lastRequestURL?.path, "/api/location/3")
    }

    func testFetchLocations_whenQueryHasFilters_encodesAllFilterParameters() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "location")
        let payload = """
        {
          "info": {
            "next": "https://rickandmortyapi.com/api/location?page=2"
          },
          "results": [
            {
              "id": 3,
              "name": "Citadel of Ricks",
              "type": "Space station",
              "dimension": "unknown",
              "residents": [],
              "url": "https://rickandmortyapi.com/api/location/3"
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
        let query = LocationQuery(name: "citadel", type: "space station", dimension: "unknown")

        let page = try await sut.fetchLocations(page: 1, query: query)
        let requestURL = try XCTUnwrap(URLProtocolStub.lastRequestURL)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []

        XCTAssertEqual(page.locations.count, 1)
        XCTAssertEqual(page.nextPage, 2)
        XCTAssertEqual(requestURL.path, "/api/location")
        XCTAssertTrue(items.contains(URLQueryItem(name: "page", value: "1")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "name", value: "citadel")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "type", value: "space station")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "dimension", value: "unknown")))
    }

    func testFetchLocations_whenFilteredQueryReturns404_mapsToEmptyPage() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "location")
        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(
            data: #"{"error":"There is nothing here"}"#.data(using: .utf8)!,
            response: response,
            error: nil
        )
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        let page = try await sut.fetchLocations(page: 1, query: LocationQuery(name: "missing"))

        XCTAssertTrue(page.locations.isEmpty)
        XCTAssertNil(page.nextPage)
    }

    func testFetchEpisodesList_whenQueryHasFilters_encodesAllFilterParameters() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "episode")
        let payload = """
        {
          "info": {
            "next": null
          },
          "results": [
            { "id": 1, "name": "Pilot", "air_date": "Dec 2, 2013", "episode": "S01E01" }
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
        let query = EpisodeListQuery(name: "pilot", episode: "S01")

        let page = try await sut.fetchEpisodes(page: 4, query: query)
        let requestURL = try XCTUnwrap(URLProtocolStub.lastRequestURL)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []

        XCTAssertEqual(page.episodes.count, 1)
        XCTAssertNil(page.nextPage)
        XCTAssertEqual(requestURL.path, "/api/episode")
        XCTAssertTrue(items.contains(URLQueryItem(name: "page", value: "4")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "name", value: "pilot")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "episode", value: "S01")))
    }

    func testFetchEpisodesList_whenFilteredQueryReturns404_mapsToEmptyPage() async throws {
        let baseURL = URL(string: "https://rickandmortyapi.com/api")!
        let endpointURL = baseURL.appending(path: "episode")
        let response = HTTPURLResponse(
            url: endpointURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!

        URLProtocolStub.setStub(
            data: #"{"error":"There is nothing here"}"#.data(using: .utf8)!,
            response: response,
            error: nil
        )
        let sut = RMService(base: baseURL, session: makeStubbedSession())

        let page = try await sut.fetchEpisodes(page: 1, query: EpisodeListQuery(name: "missing"))

        XCTAssertTrue(page.episodes.isEmpty)
        XCTAssertNil(page.nextPage)
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
