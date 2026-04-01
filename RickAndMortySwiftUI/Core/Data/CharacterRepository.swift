//
//  CharacterRepository.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

/// Tiny repository wrapper so the ViewModel can stay unaware of
/// *how* data is loaded. Swap `.live()` and `.mock()` freely.
///
/// - Important: `fetch` is an async closure that returns a specific
///   page of characters or throws on failure.
struct CharactersRepository {
    /// The fetch function used by the ViewModel.
    let fetch: (_ page: Int, _ query: CharactersQuery) async throws -> CharactersPage

    /// Production repository. Uses the real network service.
    static func live() -> CharactersRepository {
        .init(fetch: { page, query in
            try await RMService().fetchCharacters(page: page, query: query)
        })
    }

    /// Preview/testing repository. Returns stable mock data.
    static func mock() -> CharactersRepository {
        .init(fetch: { page, _ in
            guard page == 1 else {
                return CharactersPage(characters: [], nextPage: nil)
            }

            return CharactersPage(
                characters: CharactersPreviewData.some(),
                nextPage: nil
            )
        })
    }
}
