//
//  ErrorStateView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-27.
//

import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    let close: () -> Void
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Close", action: close)
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
    }
}

#Preview {
    ErrorStateView(
        title: "Something went wrong",
        message: "We couldn't load the data. Please try again.",
        close: {},
        retry: {}
    )
}
