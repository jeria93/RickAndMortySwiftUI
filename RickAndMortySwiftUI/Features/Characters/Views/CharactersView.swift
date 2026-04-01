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
    @State private var isSpeciesTypeSheetPresented: Bool = false
    @State private var speciesFilterDraft: String = ""
    @State private var typeFilterDraft: String = ""

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
                case .locations:
                    LocationCatalogView(viewModel: .live())
                case .episodes:
                    EpisodeCatalogView(viewModel: .live())
                }
            }
            .searchable(text: searchTextBinding, prompt: "Search characters")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CharactersExploreMenu(
                        onLocations: { router.push(.locations) },
                        onEpisodes: { router.push(.episodes) }
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CharactersFiltersMenu(
                        statusFilter: characterViewModel.statusFilter,
                        genderFilter: characterViewModel.genderFilter,
                        hasActiveQuery: characterViewModel.hasActiveQuery,
                        hasSpeciesOrTypeFilter: hasSpeciesOrTypeFilter,
                        onStatusChange: { characterViewModel.updateStatusFilter($0) },
                        onGenderChange: { characterViewModel.updateGenderFilter($0) },
                        onEditSpeciesType: { presentSpeciesTypeFilterSheet() },
                        onClearSpeciesType: { clearSpeciesAndTypeFilters() },
                        onClearAll: { characterViewModel.clearSearchAndFilters() }
                    )
                }
            }
        }
        .task {
            guard !ProcessInfo.processInfo.isPreview else { return }
            await characterViewModel.load()
        }
        .sheet(isPresented: $isSpeciesTypeSheetPresented) {
            CharactersSpeciesTypeFilterSheet(
                speciesDraft: $speciesFilterDraft,
                typeDraft: $typeFilterDraft,
                onCancel: { isSpeciesTypeSheetPresented = false },
                onApply: { applySpeciesAndTypeFilters() }
            )
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
                        emptyStateTitle,
                        systemImage: "person.3",
                        description: Text(emptyStateMessage)
                    )

                    if characterViewModel.hasActiveQuery {
                        clearFiltersButton
                    } else {
                        retryButton
                    }
                }
                .frame(maxWidth: 460, minHeight: size.height)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding(for: size.height))
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            List {
                ForEach(characterViewModel.characters) { character in
                    Button {
                        router.push(.characterDetail(character))
                    } label: {
                        CharacterRowView(name: character.name, imageURL: character.image)
                    }
                    .buttonStyle(PressableRowButtonStyle())
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
                    CatalogPaginationFooter(
                        isLoadingNextPage: characterViewModel.isLoadingNextPage,
                        paginationErrorMessage: characterViewModel.paginationErrorMessage,
                        canLoadMore: false,
                        loadMoreTitle: nil,
                        onRetry: { Task { await characterViewModel.loadNextPage() } },
                        onLoadMore: {}
                    )
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable { await characterViewModel.load() }
        }
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { characterViewModel.searchText },
            set: { characterViewModel.updateSearchText($0) }
        )
    }

    private var emptyStateTitle: String {
        characterViewModel.hasActiveQuery ? "No matching characters" : "No characters found"
    }

    private var emptyStateMessage: String {
        characterViewModel.hasActiveQuery
        ? "Try adjusting your search or filters."
        : "Try again to load characters."
    }

    private var retryButton: some View {
        Button("Retry") {
            Task { await characterViewModel.load() }
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
    }

    private var clearFiltersButton: some View {
        Button("Clear Search & Filters") {
            characterViewModel.clearSearchAndFilters()
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
    }

    private var hasSpeciesOrTypeFilter: Bool {
        !speciesFilterDraftValue(characterViewModel.speciesFilter).isEmpty ||
        !speciesFilterDraftValue(characterViewModel.typeFilter).isEmpty
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

    private func presentSpeciesTypeFilterSheet() {
        speciesFilterDraft = characterViewModel.speciesFilter
        typeFilterDraft = characterViewModel.typeFilter
        isSpeciesTypeSheetPresented = true
    }

    private func applySpeciesAndTypeFilters() {
        characterViewModel.updateSpeciesFilter(speciesFilterDraftValue(speciesFilterDraft))
        characterViewModel.updateTypeFilter(speciesFilterDraftValue(typeFilterDraft))
        isSpeciesTypeSheetPresented = false
    }

    private func clearSpeciesAndTypeFilters() {
        characterViewModel.updateSpeciesFilter("")
        characterViewModel.updateTypeFilter("")
    }

    private func speciesFilterDraftValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
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

private struct PressableRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.primary.opacity(configuration.isPressed ? 0.08 : 0))
            }
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
