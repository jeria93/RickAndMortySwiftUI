//
//  CharactersView+Previews.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-25.
//

import SwiftUI

@MainActor
extension CharactersView {
    static var previewList: some View {
        CharactersView(viewModel: PreviewFactory.characterList())
    }

    static var previewLoading: some View {
        CharactersView(viewModel: PreviewFactory.charactersLoading())
    }
    static var previewError: some View {
        CharactersView(viewModel: PreviewFactory.charactersError())
    }
}
