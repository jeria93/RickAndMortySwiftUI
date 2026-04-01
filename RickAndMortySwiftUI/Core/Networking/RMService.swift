//
//  RMService.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2025-10-24.
//

import Foundation

enum RMServiceError: LocalizedError {
    case badBaseURL
    case transport(URLError)
    case invalidResponse
    case httpStatus(Int)
    case decoding(DecodingError)
    case unexpected(Error)
    
    var errorDescription: String? {
        switch self {
        case .badBaseURL:
            "Invalid API base URL."
        case .transport(let error):
            error.localizedDescription
        case .invalidResponse:
            "Invalid server response."
        case .httpStatus(let statusCode):
            "Server returned HTTP \(statusCode)."
        case .decoding:
            "Failed to decode server response."
        case .unexpected(let error):
            error.localizedDescription
        }
    }
}

/// Minimal client for the Rick & Morty API.
/// Implements the endpoints used by this app's flows:
/// `GET /api/character`, `GET /api/location`, and `GET /api/episode`.
struct RMService {
    private static let defaultBaseURL = URL(string: "https://rickandmortyapi.com/api")
    private static let liveSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 128 * 1_024 * 1_024,
            diskPath: "RMServiceURLCache"
        )
        return URLSession(configuration: configuration)
    }()
    
    /// Base URL for all requests. Optional so we can validate it at runtime.
    private let base: URL?
    private let session: URLSession
    private let decoder: JSONDecoder
    
    static func live(base: URL? = defaultBaseURL) -> Self {
        .init(base: base, session: liveSession)
    }
    
    init(
        base: URL? = RMService.defaultBaseURL,
        session: URLSession = RMService.liveSession,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.base = base
        self.session = session
        self.decoder = decoder
    }
    
    /// Fetches a page of characters.
    ///
    /// - Parameter page: Page index (1-based).
    /// - Parameter query: Characters query for search/filter.
    /// - Returns: Characters plus pagination cursor for the next page.
    /// - Throws: `RMServiceError` for URL, transport, response and decoding failures.
    func fetchCharacters(
        page: Int,
        query: CharactersQuery? = nil
    ) async throws -> CharactersPage {
        let base = try baseURL()
        
        // Build endpoint: /api/character?page=n
        var components = URLComponents(
            url: base.appending(path: "character"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = makeQueryItems(page: page, query: query)
        let url = components?.url ?? base.appending(path: "character")
        
        let (data, http) = try await requestData(from: url)
        
        // For filtered searches, 404 means "no matches", not a hard error.
        if http.statusCode == 404, query?.isEmpty == false {
            return CharactersPage(characters: [], nextPage: nil)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw RMServiceError.httpStatus(http.statusCode)
        }
        
        // Decode only the `results` array
        do {
            let decoded = try decoder.decode(CharactersResponse.self, from: data)
            let nextPage = nextPageNumber(from: decoded.info?.next)
            return CharactersPage(characters: decoded.results, nextPage: nextPage)
        } catch let error as DecodingError {
            throw RMServiceError.decoding(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
    }
    
    /// Backward-compatible helper for callers that only need first-page results.
    func fetchCharacters() async throws -> [Characters] {
        let page = try await fetchCharacters(page: 1, query: nil)
        return page.characters
    }

    func fetchCharacters(ids: [Int]) async throws -> [Characters] {
        let uniqueIDs = uniquePositiveIDs(ids)
        guard !uniqueIDs.isEmpty else { return [] }

        let base = try baseURL()
        let joined = uniqueIDs.map(String.init).joined(separator: ",")
        let url = base.appending(path: "character/\(joined)")
        let (data, http) = try await requestData(from: url)

        guard (200...299).contains(http.statusCode) else {
            throw RMServiceError.httpStatus(http.statusCode)
        }

        do {
            let decoded = try decoder.decode(RMSingleOrMany<Characters>.self, from: data)
            let characters = decoded.array
            return sortCharacters(characters, by: uniqueIDs)
        } catch let error as DecodingError {
            throw RMServiceError.decoding(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
    }
    
    func fetchCharacterDetail(id: Int) async throws -> CharacterDetail {
        let base = try baseURL()
        let url = base.appending(path: "character/\(id)")
        let (data, http) = try await requestData(from: url)
        
        guard (200...299).contains(http.statusCode) else {
            throw RMServiceError.httpStatus(http.statusCode)
        }
        
        do {
            return try decoder.decode(CharacterDetail.self, from: data)
        } catch let error as DecodingError {
            throw RMServiceError.decoding(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
    }
    
    func fetchLocation(id: Int) async throws -> Location {
        let base = try baseURL()
        let url = base.appending(path: "location/\(id)")
        let (data, http) = try await requestData(from: url)
        
        guard (200...299).contains(http.statusCode) else {
            throw RMServiceError.httpStatus(http.statusCode)
        }
        
        do {
            return try decoder.decode(Location.self, from: data)
        } catch let error as DecodingError {
            throw RMServiceError.decoding(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
    }
    
    func fetchLocations(
        page: Int,
        query: LocationQuery? = nil
    ) async throws -> LocationsPage {
        let base = try baseURL()
        
        var components = URLComponents(
            url: base.appending(path: "location"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = makeLocationQueryItems(page: page, query: query)
        let url = components?.url ?? base.appending(path: "location")
        
        let (data, http) = try await requestData(from: url)
        
        if http.statusCode == 404, query?.isEmpty == false {
            return LocationsPage(locations: [], nextPage: nil)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw RMServiceError.httpStatus(http.statusCode)
        }
        
        do {
            let decoded = try decoder.decode(LocationsResponse.self, from: data)
            let nextPage = nextPageNumber(from: decoded.info?.next)
            return LocationsPage(locations: decoded.results, nextPage: nextPage)
        } catch let error as DecodingError {
            throw RMServiceError.decoding(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
    }
    
    func fetchEpisodes(
        page: Int,
        query: EpisodeListQuery? = nil
    ) async throws -> EpisodesPage {
        let base = try baseURL()
        
        var components = URLComponents(
            url: base.appending(path: "episode"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = makeEpisodeListQueryItems(page: page, query: query)
        let url = components?.url ?? base.appending(path: "episode")
        
        let (data, http) = try await requestData(from: url)
        
        if http.statusCode == 404, query?.isEmpty == false {
            return EpisodesPage(episodes: [], nextPage: nil)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw RMServiceError.httpStatus(http.statusCode)
        }
        
        do {
            let decoded = try decoder.decode(EpisodesResponse.self, from: data)
            let nextPage = nextPageNumber(from: decoded.info?.next)
            return EpisodesPage(episodes: decoded.results, nextPage: nextPage)
        } catch let error as DecodingError {
            throw RMServiceError.decoding(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
    }
    
    func fetchEpisodes(ids: [Int]) async throws -> [Episode] {
        let uniqueIDs = uniquePositiveIDs(ids)
        guard !uniqueIDs.isEmpty else { return [] }
        
        let base = try baseURL()
        let joined = uniqueIDs.map(String.init).joined(separator: ",")
        let url = base.appending(path: "episode/\(joined)")
        let (data, http) = try await requestData(from: url)
        
        guard (200...299).contains(http.statusCode) else {
            throw RMServiceError.httpStatus(http.statusCode)
        }
        
        do {
            let decoded = try decoder.decode(RMSingleOrMany<Episode>.self, from: data)
            let episodes = decoded.array
            return sortEpisodes(episodes, by: uniqueIDs)
        } catch let error as DecodingError {
            throw RMServiceError.decoding(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
    }
    
    private func makeQueryItems(page: Int, query: CharactersQuery?) -> [URLQueryItem] {
        var queryItems = [URLQueryItem(name: "page", value: String(max(page, 1)))]
        guard let query else { return queryItems }
        
        if !query.trimmedName.isEmpty {
            queryItems.append(URLQueryItem(name: "name", value: query.trimmedName))
        }
        
        if !query.trimmedSpecies.isEmpty {
            queryItems.append(URLQueryItem(name: "species", value: query.trimmedSpecies))
        }
        
        if !query.trimmedType.isEmpty {
            queryItems.append(URLQueryItem(name: "type", value: query.trimmedType))
        }
        
        if let status = query.status.apiValue {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        
        if let gender = query.gender.apiValue {
            queryItems.append(URLQueryItem(name: "gender", value: gender))
        }
        
        return queryItems
    }
    
    private func makeLocationQueryItems(page: Int, query: LocationQuery?) -> [URLQueryItem] {
        var queryItems = [URLQueryItem(name: "page", value: String(max(page, 1)))]
        guard let query else { return queryItems }
        
        if !query.trimmedName.isEmpty {
            queryItems.append(URLQueryItem(name: "name", value: query.trimmedName))
        }
        
        if !query.trimmedType.isEmpty {
            queryItems.append(URLQueryItem(name: "type", value: query.trimmedType))
        }
        
        if !query.trimmedDimension.isEmpty {
            queryItems.append(URLQueryItem(name: "dimension", value: query.trimmedDimension))
        }
        
        return queryItems
    }
    
    private func makeEpisodeListQueryItems(page: Int, query: EpisodeListQuery?) -> [URLQueryItem] {
        var queryItems = [URLQueryItem(name: "page", value: String(max(page, 1)))]
        guard let query else { return queryItems }
        
        if !query.trimmedName.isEmpty {
            queryItems.append(URLQueryItem(name: "name", value: query.trimmedName))
        }
        
        if !query.trimmedEpisode.isEmpty {
            queryItems.append(URLQueryItem(name: "episode", value: query.trimmedEpisode))
        }
        
        return queryItems
    }
    
    private func nextPageNumber(from nextURLString: String?) -> Int? {
        guard
            let nextURLString,
            let url = URL(string: nextURLString),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let value = components.queryItems?.first(where: { $0.name == "page" })?.value,
            let page = Int(value),
            page > 0
        else {
            return nil
        }
        
        return page
    }
    
    private func uniquePositiveIDs(_ ids: [Int]) -> [Int] {
        var seen = Set<Int>()
        var unique: [Int] = []
        
        for id in ids where id > 0 {
            if seen.insert(id).inserted {
                unique.append(id)
            }
        }
        
        return unique
    }
    
    private func sortEpisodes(_ episodes: [Episode], by orderedIDs: [Int]) -> [Episode] {
        sortByRequestedIDs(episodes, orderedIDs: orderedIDs, id: \.id)
    }

    private func sortCharacters(_ characters: [Characters], by orderedIDs: [Int]) -> [Characters] {
        sortByRequestedIDs(characters, orderedIDs: orderedIDs, id: \.id)
    }

    private func sortByRequestedIDs<T>(
        _ values: [T],
        orderedIDs: [Int],
        id: KeyPath<T, Int>
    ) -> [T] {
        let rank = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, $0) })
        return values.sorted { lhs, rhs in
            let leftRank = rank[lhs[keyPath: id]] ?? Int.max
            let rightRank = rank[rhs[keyPath: id]] ?? Int.max
            return leftRank < rightRank
        }
    }
    
    private func requestData(from url: URL) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError {
            throw RMServiceError.transport(error)
        } catch {
            throw RMServiceError.unexpected(error)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw RMServiceError.invalidResponse
        }
        
        return (data, http)
    }
    
    private func baseURL() throws -> URL {
        guard let base else {
            throw RMServiceError.badBaseURL
        }
        
        return base
    }
}

private enum RMSingleOrMany<T: Decodable>: Decodable {
    case single(T)
    case many([T])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let many = try? container.decode([T].self) {
            self = .many(many)
        } else {
            self = .single(try container.decode(T.self))
        }
    }
    
    var array: [T] {
        switch self {
        case .single(let value):
            [value]
        case .many(let values):
            values
        }
    }
}
