//
//  PreviewCharactersPreviewData.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

/// Raw, dependency-free mock data for SwiftUI previews.
///
/// - Uses `PreviewID.next()` to guarantee **unique** IDs across previews.
/// - No network or repositories are needed here.
/// - Keep this file tiny and focused on data only.
enum CharactersPreviewData {

    /// A small, safe default list for previews.
    ///
    /// - Returns: An array of `Characters` with stable unique IDs.
    static func some() -> [Characters] {
        [
            .init(
                id: PreviewID.next(),
                name: "Rick Sanchez",
                image: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")
            ),
            .init(
                id: PreviewID.next(),
                name: "Morty Smith",
                image: URL(string: "https://rickandmortyapi.com/api/character/avatar/2.jpeg")
            )
        ]
    }
}
