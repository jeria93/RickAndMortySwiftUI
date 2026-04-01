//
//  RMService.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

enum RMServiceError: LocalizedError {
    case badBaseURL
    case transport(URLError)
    case invalidResponse
    case httpStatus(Int)
    case decoding(DecodingError)
    case unexpected(Error)

    var errorDescription: String? {
        switch self {
        case .badBaseURL:
            "Invalid API base URL."
        case .transport(let error):
            error.localizedDescription
        case .invalidResponse:
            "Invalid server response."
        case .httpStatus(let statusCode):
            "Server returned HTTP \(statusCode)."
        case .decoding:
            "Failed to decode server response."
        case .unexpected(let error):
            error.localizedDescription
        }
    }
}

/// Minimal client for the Rick & Morty API.
/// Only implements a single endpoint for this demo:
/// `GET /api/character`.
struct RMService {
    /// Base URL for all requests. Optional so we can validate it at runtime.
    private let base: URL?
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        base: URL? = URL(string: "https://rickandmortyapi.com/api"),
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.base = base
        self.session = session
        self.decoder = decoder
    }

    /// Fetches a page of characters.
    ///
    /// - Parameter page: Page index (1-based).
    /// - Returns: Characters plus pagination cursor for the next page.
    /// - Throws: `RMServiceError` for URL, transport, response and decoding failures.
    func fetchCharacters(page: Int) async throws -> CharactersPage {
        // Make sure base URL exists
        guard let base else {
            throw RMServiceError.badBaseURL
        }

        // Build endpoint: /api/character?page=n
        var components = URLComponents(
            url: base.appending(path: "character"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "page", value: String(max(page, 1)))]
        let url = components?.url ?? base.appending(path: "character")

        // Perform request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError {
            throw RMServiceError.transport(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }

        // Validate HTTP status 2xx
        guard let http = response as? HTTPURLResponse else {
            throw RMServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw RMServiceError.httpStatus(http.statusCode)
        }

        // Decode only the `results` array
        do {
            let decoded = try decoder.decode(CharactersResponse.self, from: data)
            let nextPage = nextPageNumber(from: decoded.info?.next)
            return CharactersPage(characters: decoded.results, nextPage: nextPage)
        } catch let error as DecodingError {
            throw RMServiceError.decoding(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
    }

    /// Backward-compatible helper for callers that only need first-page results.
    func fetchCharacters() async throws -> [Characters] {
        let page = try await fetchCharacters(page: 1)
        return page.characters
    }

    private func nextPageNumber(from nextURLString: String?) -> Int? {
        guard
            let nextURLString,
            let url = URL(string: nextURLString),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let value = components.queryItems?.first(where: { $0.name == "page" })?.value,
            let page = Int(value),
            page > 0
        else {
            return nil
        }

        return page
    }
}
