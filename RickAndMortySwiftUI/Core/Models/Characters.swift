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

struct RMNamedResource: Decodable, Hashable {
    let name: String
    let url: String
}

struct CharacterDetail: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let status: String
    let species: String
    let type: String
    let gender: String
    let origin: RMNamedResource
    let location: RMNamedResource
    let image: URL?
    let episode: [URL]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case species
        case type
        case gender
        case origin
        case location
        case image
        case episode
    }
    
    init(
        id: Int,
        name: String,
        status: String,
        species: String,
        type: String,
        gender: String,
        origin: RMNamedResource,
        location: RMNamedResource,
        image: URL?,
        episode: [URL]
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.species = species
        self.type = type
        self.gender = gender
        self.origin = origin
        self.location = location
        self.image = image
        self.episode = episode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(String.self, forKey: .status)
        species = try container.decode(String.self, forKey: .species)
        type = try container.decode(String.self, forKey: .type)
        gender = try container.decode(String.self, forKey: .gender)
        origin = try container.decode(RMNamedResource.self, forKey: .origin)
        location = try container.decode(RMNamedResource.self, forKey: .location)
        image = try container.decodeIfPresent(URL.self, forKey: .image)
        let episodeStrings = try container.decode([String].self, forKey: .episode)
        episode = episodeStrings.compactMap(URL.init(string:))
    }
}

struct Episode: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let airDate: String
    let episode: String
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case airDate = "air_date"
        case episode
    }
}

extension CharacterDetail {
    static func preview() -> CharacterDetail {
        CharacterDetail(
            id: 1,
            name: "Rick Sanchez",
            status: "Alive",
            species: "Human",
            type: "",
            gender: "Male",
            origin: RMNamedResource(
                name: "Earth (C-137)",
                url: "https://rickandmortyapi.com/api/location/1"
            ),
            location: RMNamedResource(
                name: "Citadel of Ricks",
                url: "https://rickandmortyapi.com/api/location/3"
            ),
            image: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"),
            episode: [
                URL(string: "https://rickandmortyapi.com/api/episode/1"),
                URL(string: "https://rickandmortyapi.com/api/episode/2"),
                URL(string: "https://rickandmortyapi.com/api/episode/3")
            ].compactMap { $0 }
        )
    }
}

extension Episode {
    static func previewList() -> [Episode] {
        [
            Episode(id: 1, name: "Pilot", airDate: "December 2, 2013", episode: "S01E01"),
            Episode(id: 2, name: "Lawnmower Dog", airDate: "December 9, 2013", episode: "S01E02"),
            Episode(id: 3, name: "Anatomy Park", airDate: "December 16, 2013", episode: "S01E03")
        ]
    }
}

extension URL {
    var resourceID: Int? {
        Int(lastPathComponent)
    }
}
