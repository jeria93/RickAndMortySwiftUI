//
//  PreviewID.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-26.
//

import Foundation

/// Generates unique, deterministic IDs **only for SwiftUI previews**.
///
/// Why this exists:
/// - Lists/ForEach need **unique** IDs. Reusing mock data across multiple
///   previews can create duplicate IDs and weird UI glitches.
/// - `PreviewID` gives you unique IDs and lets you **reset** them so each
///   preview render is stable and repeatable.
///
/// Usage:
/// ```swift
/// PreviewID.reset()                // do this once per preview "scenario"
/// let id1 = PreviewID.next()       // 100_000
/// let id2 = PreviewID.next()       // 100_001
/// ```
enum PreviewID {
    /// Internal counter used to generate unique IDs.
    private static var current: Int = 100_000

    /// Returns the next unique ID.
    ///
    /// - Returns: A unique `Int` starting at `100_000`.
    /// - Note: Uses `defer` to increment *after* returning the current value.
    static func next() -> Int {
        defer { current += 1 }
        return current
    }

    /// Resets the ID counter back to its start value.
    ///
    /// Call this in your preview factory before creating mock data so
    /// preview snapshots are deterministic.
    static func reset() {
        current = 100_000
    }
}
