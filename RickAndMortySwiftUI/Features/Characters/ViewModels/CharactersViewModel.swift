//
//  CharactersViewModel.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation
import Combine

@MainActor
final class CharactersViewModel: ObservableObject {
    @Published private(set) var characters: [Characters] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    
    private let repository: CharactersRepository
    private var latestLoadID: UInt64 = 0
    
    init(repository: CharactersRepository) {
        self.repository = repository
    }
    
    static func mock() -> Self { .init(repository: .mock()) }
    static func live() -> Self { .init(repository: .live()) }
    
    func load() async {
        latestLoadID += 1
        let loadID = latestLoadID
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await repository.fetch()
            finishLoad(loadID, characters: fetched)
        } catch is CancellationError {
            finishLoad(loadID)
        } catch {
            finishLoad(loadID, errorMessage: error.localizedDescription)
        }
    }
    
    private func finishLoad(
        _ loadID: UInt64,
        characters: [Characters]? = nil,
        errorMessage: String? = nil
    ) {
        guard loadID == latestLoadID else { return }
        if let characters {
            self.characters = characters
        }
        self.errorMessage = errorMessage
        isLoading = false
    }
    
    func dismissError() { errorMessage = nil }
}

extension CharactersViewModel {
    /// Preview-only helper to inject controlled state snapshots.
    @discardableResult
    func _previewInject(
        characters: [Characters] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) -> Self {
        self.characters = characters
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        return self
    }
}
