//
//  CharactersView+Previews.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-25.
//

import SwiftUI

/// Preview helpers for `CharactersView`.
/// These return *ready-to-use* snapshots that do **not** hit the network.
/// Data and states come from `PreviewFactory`.
@MainActor
extension CharactersView {

    /// Preview showing a populated list of characters.
    static var previewList: some View {
        CharactersView(viewModel: PreviewFactory.characterList())
    }

    /// Preview showing a loading spinner state.
    static var previewLoading: some View {
        CharactersView(viewModel: PreviewFactory.charactersLoading())
    }

    /// Preview showing an error message with retry/close actions.
    static var previewError: some View {
        CharactersView(viewModel: PreviewFactory.charactersError())
    }
}
