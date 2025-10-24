//
//  Characters.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

struct Characters: Identifiable, Codable {
    let id: Int
    let name: String
    let image: URL?
}

struct CharactersResponse: Decodable {
    let results: [Characters]
}
