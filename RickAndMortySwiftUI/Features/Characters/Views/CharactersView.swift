//
//  CharactersView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-20.
//

import SwiftUI

struct CharactersView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var characterViewModel: CharactersViewModel

    init(viewModel: CharactersViewModel? = nil) {
        _characterViewModel = StateObject(wrappedValue: viewModel ?? .mock())
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                if characterViewModel.isLoading {
                    LoadingView(message: "Loading...")
                } else if let error = characterViewModel.errorMessage {
                    ErrorStateView(
                        title: "Something went wrong",
                        message: error,
                        close: { characterViewModel.dismissError() },
                        retry: { Task { await characterViewModel.load() } }
                    )

                } else {
                    List(characterViewModel.characters) { character in
                        CharacterRowView(name: character.name, imageURL: character.image)
                            .onTapGesture { router.push(.characterDetail(character)) }
                    }
                    .listStyle(.plain)
                    .refreshable { await characterViewModel.load() }
                }
            }
            .navigationTitle("Characters")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .characterDetail(let character):
                    CharacterDetailView(character: character)
                }
            }
        }
        .task { await characterViewModel.load() }
    }
}

#Preview("List") {
    CharactersView.previewList
}

#Preview("Loading") {
    CharactersView.previewLoading
}

#Preview("Error") {
    CharactersView.previewError
}
