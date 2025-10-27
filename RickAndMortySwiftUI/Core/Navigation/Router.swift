//
//  Router.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-27.
//

import Foundation
import Combine

/// Simple enum-based navigator for `NavigationStack`.
///
/// Keep this object alive (e.g., `@StateObject`) and pass it with
/// `.environmentObject(router)` to views that need navigation.
@MainActor
final class Router: ObservableObject {

    /// Current navigation path (stack of routes).
    ///
    /// Bind this to `NavigationStack(path:)`.
    @Published var path: [Route] = []

    /// Push a new destination onto the path.
    /// - Parameter route: The route to navigate to.
    func push(_ route: Route) { path.append(route) }

    /// Pop the last destination if any.
    func pop() { _ = path.popLast() }

    /// Clear the path and return to the root screen.
    func popToRoot() { path.removeAll() }
}
