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
    @Published private(set) var isLoadingNextPage: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var paginationErrorMessage: String?
    
    private let repository: CharactersRepository
    private var latestLoadID: UInt64 = 0
    private var nextPage: Int? = 1
    
    init(repository: CharactersRepository) {
        self.repository = repository
    }
    
    static func mock() -> Self { .init(repository: .mock()) }
    static func live() -> Self { .init(repository: .live()) }
    
    func load() async {
        latestLoadID += 1
        let loadID = latestLoadID
        isLoading = true
        isLoadingNextPage = false
        errorMessage = nil
        paginationErrorMessage = nil
        nextPage = 1
        
        do {
            let firstPage = try await repository.fetch(1)
            finishInitialLoad(loadID, page: firstPage)
        } catch is CancellationError {
            finishInitialLoad(loadID)
        } catch {
            finishInitialLoad(loadID, errorMessage: error.localizedDescription)
        }
    }
    
    func loadNextPageIfNeeded(currentCharacter: Characters) async {
        guard shouldLoadNextPage(for: currentCharacter) else { return }
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading, !isLoadingNextPage else { return }
        guard let pageToLoad = nextPage else { return }

        let loadID = latestLoadID
        isLoadingNextPage = true
        paginationErrorMessage = nil

        do {
            let page = try await repository.fetch(pageToLoad)
            finishNextPageLoad(loadID, page: page)
        } catch is CancellationError {
            finishNextPageLoad(loadID)
        } catch {
            finishNextPageLoad(
                loadID,
                paginationErrorMessage: error.localizedDescription
            )
        }
    }

    private func shouldLoadNextPage(for currentCharacter: Characters) -> Bool {
        guard !isLoading, !isLoadingNextPage else { return false }
        guard paginationErrorMessage == nil else { return false }
        guard nextPage != nil else { return false }
        guard let currentIndex = characters.firstIndex(where: { $0.id == currentCharacter.id }) else {
            return false
        }

        let thresholdIndex = max(characters.count - 5, 0)
        return currentIndex >= thresholdIndex
    }

    private func finishInitialLoad(
        _ loadID: UInt64,
        page: CharactersPage? = nil,
        errorMessage: String? = nil
    ) {
        guard loadID == latestLoadID else { return }

        if let page {
            characters = page.characters
            nextPage = page.nextPage
        }

        self.errorMessage = errorMessage
        isLoading = false
        isLoadingNextPage = false
    }

    private func finishNextPageLoad(
        _ loadID: UInt64,
        page: CharactersPage? = nil,
        paginationErrorMessage: String? = nil
    ) {
        guard loadID == latestLoadID else { return }

        if let page {
            appendUniqueCharacters(page.characters)
            nextPage = page.nextPage
        }

        self.paginationErrorMessage = paginationErrorMessage
        isLoadingNextPage = false
    }

    private func appendUniqueCharacters(_ newCharacters: [Characters]) {
        var ids = Set(characters.map(\.id))
        let unique = newCharacters.filter { ids.insert($0.id).inserted }
        characters.append(contentsOf: unique)
    }
    
    func dismissError() { errorMessage = nil }
    func dismissPaginationError() { paginationErrorMessage = nil }
}

extension CharactersViewModel {
    /// Preview-only helper to inject controlled state snapshots.
    @discardableResult
    func _previewInject(
        characters: [Characters] = [],
        isLoading: Bool = false,
        isLoadingNextPage: Bool = false,
        errorMessage: String? = nil,
        paginationErrorMessage: String? = nil,
        nextPage: Int? = nil
    ) -> Self {
        self.characters = characters
        self.isLoading = isLoading
        self.isLoadingNextPage = isLoadingNextPage
        self.errorMessage = errorMessage
        self.paginationErrorMessage = paginationErrorMessage
        self.nextPage = nextPage
        return self
    }
}
