//
//  RickAndMortySwiftUIApp.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-20.
//

import SwiftUI

/// App entry point.
///
/// Holds a single `Router` instance and injects it into the environment so
/// any view can navigate using enum-based routes.
@main
struct RickAndMortySwiftUIApp: App {
    
    /// Global router for the app lifetime.
    @StateObject private var router = Router()
    
    var body: some Scene {
        WindowGroup {
            CharactersView(viewModel: .live())
                .environmentObject(router)
                .tint(AppTheme.portalGreen)
        }
    }
}

enum AppTheme {
    static let portalGreen = Color(red: 0.56, green: 0.95, blue: 0.57)
    static let portalCyan = Color(red: 0.42, green: 0.86, blue: 0.98)
    static let cardFill = Color(uiColor: .secondarySystemBackground)
    static let cardStroke = portalGreen.opacity(0.25)
    static let pressedFill = portalGreen.opacity(0.14)

    static let screenGradient = LinearGradient(
        colors: [
            Color(uiColor: .systemBackground),
            portalCyan.opacity(0.05),
            portalGreen.opacity(0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    func rmScreenBackground() -> some View {
        background(AppTheme.screenGradient.ignoresSafeArea())
    }

    func rmCardStyle(cornerRadius: CGFloat = 14) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
    }
}
