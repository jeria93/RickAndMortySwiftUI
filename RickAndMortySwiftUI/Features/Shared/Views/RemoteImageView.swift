//
//  RemoteImageView.swift
//  RickAndMortySwiftUI
//
//  Created by Nicholas Samuelsson Jeria on 2026-04-01.
//

import SwiftUI
import UIKit
import CryptoKit
import Combine

enum RemoteImagePhase {
    case empty
    case loading
    case success(Image)
    case failure
}

private enum RemoteImageLoaderError: Error {
    case rateLimited(retryAfter: TimeInterval?)
}

struct RemoteImageView<Content: View>: View {
    let url: URL?
    private let maxRetryCount: Int
    private let content: (RemoteImagePhase) -> Content
    
    @StateObject private var loader: RemoteImageLoader
    
    init(
        url: URL?,
        maxRetryCount: Int = 1,
        @ViewBuilder content: @escaping (RemoteImagePhase) -> Content
    ) {
        self.url = url
        self.maxRetryCount = max(0, maxRetryCount)
        self.content = content
        _loader = StateObject(wrappedValue: RemoteImageLoader())
    }
    
    var body: some View {
        content(loader.phase)
            .task(id: url) {
                await loader.load(from: url, maxRetryCount: maxRetryCount)
            }
    }
}

private enum RemoteImageSessionProvider {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.urlCache = URLCache(
            memoryCapacity: 16 * 1_024 * 1_024,
            diskCapacity: 64 * 1_024 * 1_024,
            diskPath: "RMRemoteImageURLCache"
        )
        return URLSession(configuration: configuration)
    }()
}

@MainActor
private final class RemoteImageLoader: ObservableObject {
    @Published private(set) var phase: RemoteImagePhase = .empty
    
    private let session: URLSession
    private let cache: ImageMemoryCache
    private let diskCache: ImageDiskCache
    
    init(
        session: URLSession? = nil,
        cache: ImageMemoryCache? = nil,
        diskCache: ImageDiskCache? = nil
    ) {
        self.session = session ?? RemoteImageSessionProvider.shared
        self.cache = cache ?? .shared
        self.diskCache = diskCache ?? .shared
    }
    
    func load(from url: URL?, maxRetryCount: Int) async {
        guard !ProcessInfo.processInfo.isPreview else {
            phase = .failure
            return
        }
        
        guard let url else {
            phase = .failure
            return
        }
        
        if let cachedImage = cache.image(for: url) {
            phase = .success(Image(uiImage: cachedImage))
            return
        }
        
        if let diskData = await diskCache.imageData(for: url),
           let diskImage = UIImage(data: diskData) {
            cache.insert(diskImage, for: url)
            phase = .success(Image(uiImage: diskImage))
            return
        }
        
        phase = .loading
        
        var attempt = 0
        while !Task.isCancelled {
            do {
                let payload = try await fetchImage(from: url)
                let image = payload.image
                cache.insert(image, for: url)
                await diskCache.insert(payload.data, for: url)
                phase = .success(Image(uiImage: image))
                return
            } catch is CancellationError {
                return
            } catch let error as RemoteImageLoaderError {
                guard attempt < maxRetryCount else {
                    phase = .failure
                    return
                }
                
                attempt += 1
                let delay = imageRetryDelay(for: error, attempt: attempt)
                try? await Task.sleep(nanoseconds: delay)
            } catch {
                guard attempt < maxRetryCount else {
                    phase = .failure
                    return
                }
                
                attempt += 1
                let delay = UInt64(250_000_000 * attempt)
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }
    
    private func fetchImage(from url: URL) async throws -> (data: Data, image: UIImage) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if http.statusCode == 429 {
            throw RemoteImageLoaderError.rateLimited(
                retryAfter: retryAfterInterval(from: http)
            )
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        return (data: data, image: image)
    }
    
    private func imageRetryDelay(for error: RemoteImageLoaderError, attempt: Int) -> UInt64 {
        switch error {
        case .rateLimited(let retryAfter):
            let fallback = min(Double(max(1, attempt)), 4)
            let delay = min(max(retryAfter ?? fallback, 0), 8)
            return UInt64((delay * 1_000_000_000).rounded())
        }
    }
    
    private func retryAfterInterval(from response: HTTPURLResponse, now: Date = Date()) -> TimeInterval? {
        guard let header = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = TimeInterval(trimmed) {
            return max(0, seconds)
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        
        guard let date = formatter.date(from: trimmed) else {
            return nil
        }
        
        return max(0, date.timeIntervalSince(now))
    }
}

@MainActor
private final class ImageMemoryCache {
    static let shared = ImageMemoryCache()
    
    private let storage = NSCache<NSURL, UIImage>()
    
    private init() {
        storage.countLimit = 300
        storage.totalCostLimit = 64 * 1_024 * 1_024
    }
    
    func image(for url: URL) -> UIImage? {
        storage.object(forKey: url as NSURL)
    }
    
    func insert(_ image: UIImage, for url: URL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 1
        storage.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

private actor ImageDiskCache {
    static let shared = ImageDiskCache()
    
    private let fileManager = FileManager.default
    private let directoryURL: URL?
    private let maxAge: TimeInterval
    private let cleanupInterval: TimeInterval
    private var lastCleanupDate: Date?
    
    init(
        maxAge: TimeInterval = 60 * 60 * 24 * 7,
        cleanupInterval: TimeInterval = 60 * 10
    ) {
        self.maxAge = max(60, maxAge)
        self.cleanupInterval = max(60, cleanupInterval)
        
        let cachesDirectory = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first
        let directory = cachesDirectory?.appendingPathComponent(
            "RMImageDiskCache",
            isDirectory: true
        )
        
        if let directory {
            try? fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        
        self.directoryURL = directory
        self.lastCleanupDate = nil
    }
    
    func imageData(for url: URL, now: Date = Date()) -> Data? {
        guard let fileURL = fileURL(for: url) else { return nil }
        
        guard isFresh(fileURL: fileURL, now: now) else {
            remove(fileURL)
            cleanupIfNeeded(now: now)
            return nil
        }
        
        let data = try? Data(contentsOf: fileURL)
        cleanupIfNeeded(now: now)
        return data
    }
    
    func insert(_ data: Data, for url: URL, now: Date = Date()) {
        guard let fileURL = fileURL(for: url) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? fileManager.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: fileURL.path
        )
        cleanupIfNeeded(now: now)
    }
    
    private func fileURL(for url: URL) -> URL? {
        guard let directoryURL else { return nil }
        return directoryURL.appendingPathComponent(cacheKey(for: url))
    }
    
    private func isFresh(fileURL: URL, now: Date) -> Bool {
        guard
            let values = try? fileURL.resourceValues(
                forKeys: [.contentModificationDateKey, .isRegularFileKey]
            ),
            values.isRegularFile == true,
            let modifiedAt = values.contentModificationDate
        else {
            return false
        }
        
        return now.timeIntervalSince(modifiedAt) <= maxAge
    }
    
    private func cleanupIfNeeded(now: Date) {
        if let lastCleanupDate,
           now.timeIntervalSince(lastCleanupDate) < cleanupInterval {
            return
        }
        
        removeExpiredEntries(now: now)
        lastCleanupDate = now
    }
    
    private func removeExpiredEntries(now: Date) {
        guard let directoryURL else { return }
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        for fileURL in fileURLs where !isFresh(fileURL: fileURL, now: now) {
            remove(fileURL)
        }
    }
    
    private func remove(_ fileURL: URL) {
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".img"
    }
}
