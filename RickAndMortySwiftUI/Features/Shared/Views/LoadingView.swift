//
//  LoadingView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-27.
//

import SwiftUI

struct LoadingView: View {
    let message: String?

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()

            if let message, !message.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview { LoadingView(message: "Loading...") }
