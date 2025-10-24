//
//  CharacterRepository.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

struct CharactersRepository {
    let fetch: () async throws -> [Characters]

    static func live() -> CharactersRepository {
        .init(fetch: { try await RMService().fetchCharacters() })
    }

    static func mock() -> CharactersRepository {
        .init(fetch: { CharactersPreviewData.some() })
    }
}
