//
//  RMService.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

struct RMService {
    private let base = URL(string: "https://rickandmortyapi.com/api")

    func fetchCharacters() async throws -> [Characters] {
        guard let base else {
            throw URLError(.badURL)
        }

        let url = base.appending(path: "character")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(CharactersResponse.self, from: data)
        return decoded.results
    }
}
