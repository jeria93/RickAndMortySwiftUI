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
