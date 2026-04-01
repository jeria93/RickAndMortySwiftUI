//
//  EpisodeCatalogView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct EpisodeCatalogView: View {
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
                    CatalogFiltersToolbarButton(
                        hasActiveQuery: viewModel.hasActiveQuery,
                        onTap: { presentFilterSheet() }
                    )
                }
            }
            .task {
                guard !ProcessInfo.processInfo.isPreview else { return }
                await viewModel.load()
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                EpisodeCatalogFilterSheet(
                    episodeCodeDraft: $episodeCodeDraft,
                    onCancel: { isFilterSheetPresented = false },
                    onApply: { applyFilterDraft() }
                )
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
            CatalogEmptyStateView(
                hasActiveQuery: viewModel.hasActiveQuery,
                matchingTitle: "No matching episodes",
                emptyTitle: "No episodes found",
                systemImage: "tv",
                matchingMessage: "Try adjusting your filters.",
                emptyMessage: "Try again to load episodes.",
                onClearFilters: { viewModel.clearFilters() },
                onRetry: { Task { await viewModel.load() } }
            )
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
    
    private func presentFilterSheet() {
        episodeCodeDraft = viewModel.episodeFilter
        isFilterSheetPresented = true
    }
    
    private func applyFilterDraft() {
        viewModel.updateEpisodeFilter(trimmed(episodeCodeDraft))
        isFilterSheetPresented = false
    }
    
    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
