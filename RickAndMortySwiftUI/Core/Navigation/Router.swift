//
//  Router.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-27.
//

import Foundation
import Combine

@MainActor
final class Router: ObservableObject {
    @Published var path: [Route] = []

    func push(_ route: Route) { path.append(route) }
    func pop() { _ = path.popLast() }
    func popToRoot() { path.removeAll() }
}
