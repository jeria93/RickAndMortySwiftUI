//
//  Characters.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

/// A Rick & Morty character as used by the UI.
///
/// - Note: `image` is optional to stay safe in previews and in case
///         the API responds with a missing/invalid URL.
struct Characters: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let image: URL?
}

/// Page payload used by the app's characters flow.
struct CharactersPage: Equatable {
    let characters: [Characters]
    let nextPage: Int?
}

/// Pagination metadata returned by list endpoints.
struct RMPageInfo: Decodable {
    let next: String?
}

/// Top-level response for `GET /api/character`.
/// We only care about the `results` array in this demo.
struct CharactersResponse: Decodable {
    let info: RMPageInfo?
    /// Characters contained on the current page.
    let results: [Characters]
}
