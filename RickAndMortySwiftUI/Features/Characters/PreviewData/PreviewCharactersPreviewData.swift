//
//  PreviewCharactersPreviewData.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

enum CharactersPreviewData {
    static func some() -> [Characters] {
        
        [
            .init(
                id: 1,
                name: "Rick Sanchez",
                image: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")
            ),
            .init(
                id: 2,
                name: "Morty Smith",
                image: URL(string: "https://rickandmortyapi.com/api/character/avatar/2.jpeg")
            )
        ]
    }
}
