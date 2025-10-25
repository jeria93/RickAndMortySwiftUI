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
    @Published private(set) var errorMessage : String?

    private let repository: CharactersRepository

    init(repository: CharactersRepository) {
        self.repository = repository
    }

//    Self == shorter `here` and rename "safe", both fulfills same functionality
    static func mock() -> Self { .init(repository: .mock()) }
    static func live() -> Self { .init(repository: .live()) }
// Its same thing but a little bit longer.
//    static func mock() -> CharactersViewModel { .init(repository: .mock()) }
//    static func live() -> CharactersViewModel { .init(repository: .live()) }

//    Load characters / no pagination yet
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            characters = try await repository.fetch()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() { errorMessage = nil }
}

extension CharactersViewModel {

//    Preview bypass (same file -> allowed to set 'private(set)')
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
