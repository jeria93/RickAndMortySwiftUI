//
//  LocationCatalogView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct LocationCatalogView: View {
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
                LocationCatalogFilterSheet(
                    typeDraft: $typeFilterDraft,
                    dimensionDraft: $dimensionFilterDraft,
                    onCancel: { isFilterSheetPresented = false },
                    onApply: { applyFilterDrafts() }
                )
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
            CatalogEmptyStateView(
                hasActiveQuery: viewModel.hasActiveQuery,
                matchingTitle: "No matching locations",
                emptyTitle: "No locations found",
                systemImage: "globe",
                matchingMessage: "Try adjusting your filters.",
                emptyMessage: "Try again to load locations.",
                onClearFilters: { viewModel.clearFilters() },
                onRetry: { Task { await viewModel.load() } }
            )
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
        typeFilterDraft = viewModel.typeFilter
        dimensionFilterDraft = viewModel.dimensionFilter
        isFilterSheetPresented = true
    }

    private func applyFilterDrafts() {
        viewModel.updateTypeFilter(trimmed(typeFilterDraft))
        viewModel.updateDimensionFilter(trimmed(dimensionFilterDraft))
        isFilterSheetPresented = false
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
