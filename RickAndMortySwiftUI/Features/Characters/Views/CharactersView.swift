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
            .searchable(text: searchTextBinding, prompt: "Search characters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filtersMenu
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
    
    private var searchTextBinding: Binding<String> {
        Binding(
            get: { characterViewModel.searchText },
            set: { characterViewModel.updateSearchText($0) }
        )
    }
    
    private var filtersMenu: some View {
        Menu {
            Menu("Status") {
                ForEach(CharacterStatusFilter.allCases, id: \.self) { status in
                    Button {
                        characterViewModel.updateStatusFilter(status)
                    } label: {
                        selectionLabel(
                            title: status.title,
                            isSelected: characterViewModel.statusFilter == status
                        )
                    }
                }
            }
            
            Menu("Gender") {
                ForEach(CharacterGenderFilter.allCases, id: \.self) { gender in
                    Button {
                        characterViewModel.updateGenderFilter(gender)
                    } label: {
                        selectionLabel(
                            title: gender.title,
                            isSelected: characterViewModel.genderFilter == gender
                        )
                    }
                }
            }
            
            if characterViewModel.hasActiveQuery {
                Divider()
                Button("Clear Search & Filters") {
                    characterViewModel.clearSearchAndFilters()
                }
            }
        } label: {
            Label(
                "Filters",
                systemImage: characterViewModel.hasActiveQuery
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle"
            )
        }
    }
    
    @ViewBuilder
    private func selectionLabel(title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
    
    private var emptyStateTitle: String {
        characterViewModel.hasActiveQuery ? "No matching characters" : "No characters found"
    }
    
    private var emptyStateMessage: String {
        characterViewModel.hasActiveQuery
        ? "Try adjusting your search or filters."
        : "Try again to load characters."
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
    
    private var clearFiltersButton: some View {
        Button("Clear Search & Filters") {
            characterViewModel.clearSearchAndFilters()
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
