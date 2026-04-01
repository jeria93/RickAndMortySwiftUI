//
//  CatalogEmptyStateView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct CatalogEmptyStateView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let hasActiveQuery: Bool
    let matchingTitle: String
    let emptyTitle: String
    let systemImage: String
    let matchingMessage: String
    let emptyMessage: String
    let clearButtonTitle: String
    let retryButtonTitle: String
    let onClearFilters: () -> Void
    let onRetry: () -> Void

    init(
        hasActiveQuery: Bool,
        matchingTitle: String,
        emptyTitle: String,
        systemImage: String,
        matchingMessage: String,
        emptyMessage: String,
        clearButtonTitle: String = "Clear Filters",
        retryButtonTitle: String = "Retry",
        onClearFilters: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.hasActiveQuery = hasActiveQuery
        self.matchingTitle = matchingTitle
        self.emptyTitle = emptyTitle
        self.systemImage = systemImage
        self.matchingMessage = matchingMessage
        self.emptyMessage = emptyMessage
        self.clearButtonTitle = clearButtonTitle
        self.retryButtonTitle = retryButtonTitle
        self.onClearFilters = onClearFilters
        self.onRetry = onRetry
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ContentUnavailableView(
                    hasActiveQuery ? matchingTitle : emptyTitle,
                    systemImage: systemImage,
                    description: Text(hasActiveQuery ? matchingMessage : emptyMessage)
                )
                .foregroundStyle(AppTheme.portalCyan)

                if hasActiveQuery {
                    Button(clearButtonTitle, action: onClearFilters)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
                } else {
                    Button(retryButtonTitle, action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .rmCardStyle(cornerRadius: 18)
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .rmScreenBackground()
    }
}
