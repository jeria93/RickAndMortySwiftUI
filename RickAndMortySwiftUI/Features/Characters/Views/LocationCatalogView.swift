//
//  LocationCatalogView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

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
