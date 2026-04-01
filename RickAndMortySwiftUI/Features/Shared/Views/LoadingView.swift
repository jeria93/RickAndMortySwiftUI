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
                .tint(AppTheme.portalGreen)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .rmCardStyle(cornerRadius: 14)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rmScreenBackground()
    }
}

#if DEBUG
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView(message: "Loading...")
    }
}
#endif
