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
/// - Important: `fetch` is an async closure that returns characters
///   or throws on failure. The ViewModel calls this.
struct CharactersRepository {
    /// The fetch function used by the ViewModel.
    let fetch: () async throws -> [Characters]

    /// Production repository. Uses the real network service.
    static func live() -> CharactersRepository {
        .init(fetch: { try await RMService().fetchCharacters() })
    }

    /// Preview/testing repository. Returns stable mock data.
    static func mock() -> CharactersRepository {
        .init(fetch: { CharactersPreviewData.some() })
    }
}
