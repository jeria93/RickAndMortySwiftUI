//
//  CharactersExploreMenu.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI

struct CharactersExploreMenu: View {
    let onLocations: () -> Void
    let onEpisodes: () -> Void
    
    var body: some View {
        Menu {
            Button("Locations", action: onLocations)
            Button("Episodes", action: onEpisodes)
        } label: {
            Label("Explore", systemImage: "safari")
        }
    }
}
