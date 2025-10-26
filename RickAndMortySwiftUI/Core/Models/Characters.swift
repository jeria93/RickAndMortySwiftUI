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
struct Characters: Identifiable, Codable {
    /// Stable numeric ID from the API.
    let id: Int
    /// Display name of the character.
    let name: String
    /// Full image URL (e.g. `https://.../avatar/1.jpeg`), if available.
    let image: URL?
}

/// Top-level response for `GET /api/character`.
/// We only care about the `results` array in this demo.
struct CharactersResponse: Decodable {
    /// Characters contained on the current page.
    let results: [Characters]
}
