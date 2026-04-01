//
//  CharacterDetailView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-27.
//

import SwiftUI

struct CharacterDetailView: View {
    let character: Characters
    @StateObject private var viewModel: CharacterDetailViewModel

    init(
        character: Characters,
        viewModel: CharacterDetailViewModel? = nil
    ) {
        self.character = character
        _viewModel = StateObject(
            wrappedValue: viewModel ?? .live(characterID: character.id)
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                LoadingView(message: "Loading details...")
            } else if let error = viewModel.errorMessage, viewModel.detail == nil {
                ErrorStateView(
                    title: "Couldn't load character",
                    message: error,
                    close: { viewModel.dismissError() },
                    retry: { Task { await viewModel.load() } }
                )
            } else {
                detailContent
            }
        }
        .navigationTitle(viewModel.detail?.name ?? character.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !ProcessInfo.processInfo.isPreview else { return }
            await viewModel.load()
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                infoSection
                episodesSection
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var headerCard: some View {
        let imageURL = viewModel.detail?.image ?? character.image

        return HStack(alignment: .center, spacing: 16) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.quaternary)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.quaternary)
                        Image(systemName: "person.crop.square")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    Color.clear
                }
            }
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.detail?.name ?? character.name)
                    .font(.title2.weight(.semibold))

                if let detail = viewModel.detail {
                    Text(detail.species)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !detail.type.isEmpty {
                        Text(detail.type)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
        )
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            if let detail = viewModel.detail {
                DetailRow(label: "Status", value: detail.status)
                DetailRow(label: "Species", value: detail.species)
                DetailRow(label: "Gender", value: detail.gender)
                DetailRow(label: "Origin", value: detail.origin.name)
                DetailRow(label: "Location", value: detail.location.name)
            } else {
                DetailRow(label: "Status", value: "-")
                DetailRow(label: "Species", value: "-")
                DetailRow(label: "Gender", value: "-")
                DetailRow(label: "Origin", value: "-")
                DetailRow(label: "Location", value: "-")
            }
        }
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Episodes")
                .font(.headline)

            if viewModel.episodes.isEmpty {
                Text("No episodes available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.episodes) { episode in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(episode.episode)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(episode.name)
                                .font(.body)
                            Text(episode.airDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value.isEmpty ? "-" : value)
                .font(.subheadline)

            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
struct CharacterDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CharacterDetailView(
                character: CharactersPreviewData.some().first ?? Characters(
                    id: 1,
                    name: "Rick Sanchez",
                    image: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")
                ),
                viewModel: CharacterDetailViewModel.preview()
            )
        }
    }
}
#endif
