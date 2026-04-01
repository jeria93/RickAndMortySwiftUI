//
//  CharactersView+Previews.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-25.
//

import SwiftUI

/// Preview helpers for `CharactersView`.
/// These return ready-to-use snapshots that **do not** hit the network.
/// Data and states are provided by `PreviewFactory`.
@MainActor
extension CharactersView {
    
    /// Preview showing a populated list of characters.
    /// - Returns: A `CharactersView` wrapped with a fresh `Router`.
    static var previewList: some View {
        CharactersView(viewModel: PreviewFactory.characterList())
            .environmentObject(Router())
    }
    
    /// Preview showing a loading spinner state.
    /// - Returns: A `CharactersView` in loading mode.
    static var previewLoading: some View {
        CharactersView(viewModel: PreviewFactory.charactersLoading())
            .environmentObject(Router())
    }
    
    /// Preview showing an error message with retry/close actions.
    /// - Returns: A `CharactersView` in error mode.
    static var previewError: some View {
        CharactersView(viewModel: PreviewFactory.charactersError())
            .environmentObject(Router())
    }
}
