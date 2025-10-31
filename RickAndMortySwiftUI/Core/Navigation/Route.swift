//
//  Route.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-27.
//

import Foundation

/// All app navigation destinations.
///
/// Use with `Router.path` inside `NavigationStack`.
enum Route: Hashable {
    /// Detail page for a specific character.
    /// - Parameter Characters: The selected character to show.
    case characterDetail(Characters)
}
