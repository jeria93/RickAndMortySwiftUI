//
//  Characters.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

enum CharacterStatusFilter: String, CaseIterable, Equatable {
    case any
    case alive
    case dead
    case unknown

    var title: String {
        switch self {
        case .any:
            "Any"
        case .alive:
            "Alive"
        case .dead:
            "Dead"
        case .unknown:
            "Unknown"
        }
    }

    var apiValue: String? {
        switch self {
        case .any:
            nil
        default:
            rawValue
        }
    }
}

enum CharacterGenderFilter: String, CaseIterable, Equatable {
    case any
    case female
    case male
    case genderless
    case unknown

    var title: String {
        switch self {
        case .any:
            "Any"
        case .female:
            "Female"
        case .male:
            "Male"
        case .genderless:
            "Genderless"
        case .unknown:
            "Unknown"
        }
    }

    var apiValue: String? {
        switch self {
        case .any:
            nil
        default:
            rawValue
        }
    }
}

struct CharactersQuery: Equatable {
    var name: String = ""
    var status: CharacterStatusFilter = .any
    var gender: CharacterGenderFilter = .any

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        trimmedName.isEmpty && status == .any && gender == .any
    }
}

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
