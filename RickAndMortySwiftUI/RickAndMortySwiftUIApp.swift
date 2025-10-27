//
//  RickAndMortySwiftUIApp.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-20.
//

import SwiftUI

@main
struct RickAndMortySwiftUIApp: App {

    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            CharactersView()
                .environmentObject(router)
//              Run the actual API
//            CharactersView(viewModel: .live())
        }
    }
}
