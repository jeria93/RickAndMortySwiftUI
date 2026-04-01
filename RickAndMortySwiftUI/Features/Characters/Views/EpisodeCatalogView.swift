//
//  EpisodeCatalogView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

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

                CatalogPaginationFooter(
                    isLoadingNextPage: viewModel.isLoadingNextPage,
                    paginationErrorMessage: viewModel.paginationErrorMessage,
                    canLoadMore: viewModel.canLoadMore,
                    onRetry: { Task { await viewModel.loadNextPage() } },
                    onLoadMore: { Task { await viewModel.loadNextPage() } }
                )
            }
            .listStyle(.plain)
            .refreshable { await viewModel.load() }
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
