//
//  PreviewFactory + Characters.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-25.
//

import Foundation

/// Builds ready-to-use view models for **SwiftUI previews only**.
///
/// Notes:
/// - Uses the **mock** repository (no network).
/// - Calls `PreviewID.reset()` so IDs are stable every time the preview runs.
/// - Fills the VM via `._previewInject(...)`, keeping production code clean.
@MainActor
enum PreviewFactory {

    /// ViewModel with a small list of mock characters.
    ///
    /// - Returns: `CharactersViewModel` preloaded with items.
    static func characterList() -> CharactersViewModel {
        PreviewID.reset()
        return CharactersViewModel(repository: .mock())
            ._previewInject(characters: CharactersPreviewData.some())
    }

    /// ViewModel in a loading state (spinner visible).
    ///
    /// - Returns: `CharactersViewModel` with `isLoading = true`.
    static func charactersLoading() -> CharactersViewModel {
        PreviewID.reset()
        return CharactersViewModel(repository: .mock())
            ._previewInject(characters: [], isLoading: true)
    }

    /// ViewModel showing an error message.
    ///
    /// - Returns: `CharactersViewModel` with a user-visible error.
    static func charactersError() -> CharactersViewModel {
        PreviewID.reset()
        return CharactersViewModel(repository: .mock())
            ._previewInject(characters: [], errorMessage: "Network unreachable")
    }
}
