//
//  PreviewHelper.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-25.
//

import Foundation

/// Small runtime helper to detect **SwiftUI Previews**.
///
/// - Returns `true` only when code runs inside Xcode’s Preview canvas
///   (checks the `XCODE_RUNNING_FOR_PREVIEWS` environment variable).
/// - Useful to **skip side effects** in previews, e.g. network calls,
///   timers, analytics, or heavy animations.
/// - No build flags needed (`#if DEBUG` not required).
///
/// **Example**
/// ```swift
/// .task {
///   guard !ProcessInfo.processInfo.isPreview else { return }
///   await viewModel.load()
/// }
/// ```
extension ProcessInfo {
    var isPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
