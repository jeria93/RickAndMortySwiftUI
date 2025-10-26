//
//  RMService.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

/// Minimal client for the Rick & Morty API.
/// Only implements a single endpoint for this demo:
/// `GET /api/character` (first page).
struct RMService {
    /// Base URL for all requests. Optional so we can validate it at runtime.
    private let base = URL(string: "https://rickandmortyapi.com/api")

    /// Fetches the first page of characters.
    ///
    /// - Returns: An array of `Characters` decoded from the API.
    /// - Throws: `URLError` if the URL is bad or the server response is not 2xx,
    ///           or a decoding error if the payload does not match `CharactersResponse`.
    func fetchCharacters() async throws -> [Characters] {
        // Make sure base URL exists
        guard let base else {
            throw URLError(.badURL)
        }

        // Build endpoint: /api/character
        let url = base.appending(path: "character")

        // Perform request
        let (data, response) = try await URLSession.shared.data(from: url)

        // Validate HTTP status 2xx
        guard
            let http = response as? HTTPURLResponse,
            (200...299).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        // Decode only the `results` array
        let decoded = try JSONDecoder().decode(CharactersResponse.self, from: data)
        return decoded.results
    }
}
