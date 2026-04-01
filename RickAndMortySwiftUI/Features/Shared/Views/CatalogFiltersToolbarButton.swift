//
//  CatalogFiltersToolbarButton.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct CatalogFiltersToolbarButton: View {
    let hasActiveQuery: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Label(
                "Filters",
                systemImage: hasActiveQuery
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle"
            )
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(hasActiveQuery ? AppTheme.portalGreen : .primary)
        }
    }
}
