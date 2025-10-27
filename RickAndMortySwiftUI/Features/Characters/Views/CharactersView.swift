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
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = characterViewModel.errorMessage {
                    VStack(spacing: 10) {
                        Text("Something went wrong").font(.headline)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Close") { characterViewModel.dismissError() }
                            Button("Retry") { Task { await characterViewModel.load() } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(characterViewModel.characters) { character in
                        HStack(spacing: 12) {
                            AsyncImage(url: character.image) { phase in
                                switch phase {
                                case .empty: ProgressView()
                                case .success(let image): image.resizable().scaledToFill()
                                case .failure: Image(systemName: "person.crop.square").resizable().scaledToFit()
                                @unknown default: EmptyView()
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(character.name).font(.headline)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.push(.characterDetail(character))
                        }
                        .padding(.vertical, 4)
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
