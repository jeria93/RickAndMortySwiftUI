//
//  CatalogPaginationFooter.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct CatalogPaginationFooter: View {
    let isLoadingNextPage: Bool
    let paginationErrorMessage: String?
    let canLoadMore: Bool
    let loadMoreTitle: String?
    let onRetry: () -> Void
    let onLoadMore: () -> Void

    init(
        isLoadingNextPage: Bool,
        paginationErrorMessage: String?,
        canLoadMore: Bool,
        loadMoreTitle: String? = "Load More",
        onRetry: @escaping () -> Void,
        onLoadMore: @escaping () -> Void
    ) {
        self.isLoadingNextPage = isLoadingNextPage
        self.paginationErrorMessage = paginationErrorMessage
        self.canLoadMore = canLoadMore
        self.loadMoreTitle = loadMoreTitle
        self.onRetry = onRetry
        self.onLoadMore = onLoadMore
    }

    @ViewBuilder
    var body: some View {
        if isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 12)
        } else if let error = paginationErrorMessage {
            VStack(spacing: 8) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again", action: onRetry)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else if canLoadMore, let loadMoreTitle {
            HStack {
                Spacer()
                Button(loadMoreTitle, action: onLoadMore)
                    .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}
