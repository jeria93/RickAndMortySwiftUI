//
//  ErrorStateView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-27.
//

import SwiftUI

struct ErrorStateView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    let title: String
    let message: String
    let close: () -> Void
    let retry: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = horizontalPadding(for: geometry.size.width)
            let verticalPadding = verticalPadding(for: geometry.size.height)
            let contentMaxWidth = max(280, min(460, geometry.size.width - (horizontalPadding * 2)))
            
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.portalCyan)
                        
                        Text(title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    buttonGroup
                        .frame(maxWidth: 360)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .rmCardStyle(cornerRadius: 18)
                .frame(maxWidth: contentMaxWidth, minHeight: geometry.size.height)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .rmScreenBackground()
    }
    
    @ViewBuilder
    private var buttonGroup: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                retryButton
                closeButton
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    closeButton
                    retryButton
                }
                
                VStack(spacing: 12) {
                    retryButton
                    closeButton
                }
            }
        }
    }
    
    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width < 360 ? 16 : 24
    }
    
    private func verticalPadding(for height: CGFloat) -> CGFloat {
        height < 700 ? 20 : 32
    }
    
    private var closeButton: some View {
        Button("Close", action: close)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
    }
    
    private var retryButton: some View {
        Button("Retry", action: retry)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct ErrorStateView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorStateView(
            title: "Something went wrong",
            message: "We couldn't load the data. Please try again.",
            close: {},
            retry: {}
        )
    }
}
#endif
