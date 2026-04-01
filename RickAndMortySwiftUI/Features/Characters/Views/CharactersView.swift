//
//  CharactersView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-20.
//

import SwiftUI

struct CharactersView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var router: Router
    @StateObject private var characterViewModel: CharactersViewModel

    init(viewModel: CharactersViewModel? = nil) {
        _characterViewModel = StateObject(wrappedValue: viewModel ?? .mock())
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            GeometryReader { geometry in
                content(for: geometry.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Characters")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .characterDetail(let character):
                    CharacterDetailView(character: character)
                }
            }
        }
        .task {
            guard !ProcessInfo.processInfo.isPreview else { return }
            await characterViewModel.load()
        }
    }

    @ViewBuilder
    private func content(for size: CGSize) -> some View {
        let horizontalPadding = horizontalPadding(for: size.width)
        let rowInsets = listRowInsets(for: size.width)

        if characterViewModel.isLoading {
            LoadingView(message: "Loading...")
                .padding(.horizontal, horizontalPadding)
        } else if let error = characterViewModel.errorMessage {
            ErrorStateView(
                title: "Something went wrong",
                message: error,
                close: { characterViewModel.dismissError() },
                retry: { Task { await characterViewModel.load() } }
            )
            .padding(.horizontal, horizontalPadding)
        } else if characterViewModel.characters.isEmpty {
            ScrollView {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No characters found",
                        systemImage: "person.3",
                        description: Text("Try again to load characters.")
                    )

                    retryButton
                }
                .frame(maxWidth: 460, minHeight: size.height)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding(for: size.height))
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            List {
                ForEach(characterViewModel.characters) { character in
                    CharacterRowView(name: character.name, imageURL: character.image)
                        .onTapGesture { router.push(.characterDetail(character)) }
                        .onAppear {
                            Task {
                                await characterViewModel.loadNextPageIfNeeded(
                                    currentCharacter: character
                                )
                            }
                        }
                        .listRowInsets(rowInsets)
                }

                if characterViewModel.isLoadingNextPage ||
                    characterViewModel.paginationErrorMessage != nil {
                    paginationFooter
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable { await characterViewModel.load() }
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if characterViewModel.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 12)
        } else if let paginationError = characterViewModel.paginationErrorMessage {
            VStack(spacing: 8) {
                Text(paginationError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    Task { await characterViewModel.loadNextPage() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private var retryButton: some View {
        Button("Retry") {
            Task { await characterViewModel.load() }
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        if width < 360 { return 16 }
        if width > 430 { return 28 }
        return 24
    }

    private func verticalPadding(for height: CGFloat) -> CGFloat {
        height < 700 ? 20 : 32
    }

    private func listRowInsets(for width: CGFloat) -> EdgeInsets {
        let horizontalInset: CGFloat = width < 360 ? 12 : 16
        return EdgeInsets(top: 6, leading: horizontalInset, bottom: 6, trailing: horizontalInset)
    }
}

#if DEBUG
struct CharactersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CharactersView.previewList
                .previewDisplayName("List")
            CharactersView.previewLoading
                .previewDisplayName("Loading")
            CharactersView.previewError
                .previewDisplayName("Error")
        }
    }
}
#endif
