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
                    exploreMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filtersMenu
                }
            }
        }
        .task {
            guard !ProcessInfo.processInfo.isPreview else { return }
            await characterViewModel.load()
        }
        .sheet(isPresented: $isSpeciesTypeSheetPresented) {
            speciesTypeFilterSheet
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
            
            Divider()
            Button {
                presentSpeciesTypeFilterSheet()
            } label: {
                selectionLabel(
                    title: "Species & Type",
                    isSelected: hasSpeciesOrTypeFilter
                )
            }
            
            if hasSpeciesOrTypeFilter {
                Button("Clear Species & Type") {
                    clearSpeciesAndTypeFilters()
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
    
    private var exploreMenu: some View {
        Menu {
            Button("Locations") {
                router.push(.locations)
            }
            Button("Episodes") {
                router.push(.episodes)
            }
        } label: {
            Label("Explore", systemImage: "safari")
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
    
    private var hasSpeciesOrTypeFilter: Bool {
        !speciesFilterDraftValue(characterViewModel.speciesFilter).isEmpty ||
        !speciesFilterDraftValue(characterViewModel.typeFilter).isEmpty
    }
    
    private var speciesTypeFilterSheet: some View {
        NavigationStack {
            Form {
                Section("Text Filters") {
                    TextField("Species (e.g. Human)", text: $speciesFilterDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Type (e.g. Parasite)", text: $typeFilterDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Species & Type")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isSpeciesTypeSheetPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applySpeciesAndTypeFilters()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

struct LocationCatalogView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: LocationSearchViewModel
    @State private var isFilterSheetPresented: Bool = false
    @State private var typeFilterDraft: String = ""
    @State private var dimensionFilterDraft: String = ""
    
    init(viewModel: LocationSearchViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? .live())
    }
    
    var body: some View {
        content
            .navigationTitle("Locations")
            .searchable(text: nameFilterBinding, prompt: "Search locations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentFilterSheet()
                    } label: {
                        Label(
                            "Filters",
                            systemImage: viewModel.hasActiveQuery
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
            }
            .task {
                guard !ProcessInfo.processInfo.isPreview else { return }
                await viewModel.load()
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                filterSheet
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            LoadingView(message: "Loading locations...")
        } else if let error = viewModel.errorMessage {
            ErrorStateView(
                title: "Failed to load locations",
                message: error,
                close: { viewModel.dismissError() },
                retry: { Task { await viewModel.load() } }
            )
            .padding(.horizontal, 24)
        } else if viewModel.locations.isEmpty {
            ScrollView {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        viewModel.hasActiveQuery ? "No matching locations" : "No locations found",
                        systemImage: "globe",
                        description: Text(
                            viewModel.hasActiveQuery
                            ? "Try adjusting your filters."
                            : "Try again to load locations."
                        )
                    )
                    
                    if viewModel.hasActiveQuery {
                        Button("Clear Filters") {
                            viewModel.clearFilters()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
                    } else {
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        } else {
            List {
                ForEach(viewModel.locations) { location in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(location.name)
                            .font(.headline)
                        Text(location.type.isEmpty ? "Unknown type" : location.type)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(location.dimension.isEmpty ? "Unknown dimension" : location.dimension)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                paginationFooter
            }
            .listStyle(.plain)
            .refreshable { await viewModel.load() }
        }
    }
    
    @ViewBuilder
    private var paginationFooter: some View {
        if viewModel.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 12)
        } else if let error = viewModel.paginationErrorMessage {
            VStack(spacing: 8) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await viewModel.loadNextPage() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else if viewModel.canLoadMore {
            HStack {
                Spacer()
                Button("Load More") {
                    Task { await viewModel.loadNextPage() }
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private var nameFilterBinding: Binding<String> {
        Binding(
            get: { viewModel.nameFilter },
            set: { viewModel.updateNameFilter($0) }
        )
    }
    
    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Filters") {
                    TextField("Type (e.g. Space station)", text: $typeFilterDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Dimension (e.g. C-137)", text: $dimensionFilterDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Location Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isFilterSheetPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.updateTypeFilter(trimmed(typeFilterDraft))
                        viewModel.updateDimensionFilter(trimmed(dimensionFilterDraft))
                        isFilterSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func presentFilterSheet() {
        typeFilterDraft = viewModel.typeFilter
        dimensionFilterDraft = viewModel.dimensionFilter
        isFilterSheetPresented = true
    }
    
    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct EpisodeCatalogView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: EpisodeCatalogViewModel
    @State private var isFilterSheetPresented: Bool = false
    @State private var episodeCodeDraft: String = ""
    
    init(viewModel: EpisodeCatalogViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? .live())
    }
    
    var body: some View {
        content
            .navigationTitle("Episodes")
            .searchable(text: nameFilterBinding, prompt: "Search episodes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentFilterSheet()
                    } label: {
                        Label(
                            "Filters",
                            systemImage: viewModel.hasActiveQuery
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
            }
            .task {
                guard !ProcessInfo.processInfo.isPreview else { return }
                await viewModel.load()
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                filterSheet
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            LoadingView(message: "Loading episodes...")
        } else if let error = viewModel.errorMessage {
            ErrorStateView(
                title: "Failed to load episodes",
                message: error,
                close: { viewModel.dismissError() },
                retry: { Task { await viewModel.load() } }
            )
            .padding(.horizontal, 24)
        } else if viewModel.episodes.isEmpty {
            ScrollView {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        viewModel.hasActiveQuery ? "No matching episodes" : "No episodes found",
                        systemImage: "tv",
                        description: Text(
                            viewModel.hasActiveQuery
                            ? "Try adjusting your filters."
                            : "Try again to load episodes."
                        )
                    )
                    
                    if viewModel.hasActiveQuery {
                        Button("Clear Filters") {
                            viewModel.clearFilters()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
                    } else {
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        } else {
            List {
                ForEach(viewModel.episodes) { episode in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(episode.name)
                            .font(.headline)
                        Text(episode.episode)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(episode.airDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                paginationFooter
            }
            .listStyle(.plain)
            .refreshable { await viewModel.load() }
        }
    }
    
    @ViewBuilder
    private var paginationFooter: some View {
        if viewModel.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 12)
        } else if let error = viewModel.paginationErrorMessage {
            VStack(spacing: 8) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await viewModel.loadNextPage() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else if viewModel.canLoadMore {
            HStack {
                Spacer()
                Button("Load More") {
                    Task { await viewModel.loadNextPage() }
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private var nameFilterBinding: Binding<String> {
        Binding(
            get: { viewModel.nameFilter },
            set: { viewModel.updateNameFilter($0) }
        )
    }
    
    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Filters") {
                    TextField("Episode code (e.g. S01)", text: $episodeCodeDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Episode Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isFilterSheetPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.updateEpisodeFilter(trimmed(episodeCodeDraft))
                        isFilterSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func presentFilterSheet() {
        episodeCodeDraft = viewModel.episodeFilter
        isFilterSheetPresented = true
    }
    
    private func trimmed(_ value: String) -> String {
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
