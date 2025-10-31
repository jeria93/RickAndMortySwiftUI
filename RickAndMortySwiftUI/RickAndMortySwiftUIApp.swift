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
            CharactersView()                // Use mock VM by default
                .environmentObject(router)

            // To run the real API instead, pass a live ViewModel:
            // CharactersView(viewModel: .live())
            //     .environmentObject(router)
        }
    }
}
