//
//  PreviewFactory + Characters.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-25.
//

import Foundation

@MainActor
enum PreviewFactory {
    static func characterList() -> CharactersViewModel {
        CharactersViewModel(repository: .mock())
            ._previewInject(characters: CharactersPreviewData.some())
    }

    static func charactersLoading() -> CharactersViewModel {
        CharactersViewModel(repository: .mock())
            ._previewInject(characters: [], isLoading: true)
    }

    static func charactersError() -> CharactersViewModel {
        CharactersViewModel(repository: .mock())
            ._previewInject(characters: [], errorMessage: "Network unreachable")
    }

}
