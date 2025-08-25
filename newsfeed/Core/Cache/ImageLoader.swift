//
//  ImageLoader.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 24.08.2025.
//

import ImageIO
import UIKit

private actor InflightStore {
    private var tasks: [URL: Task<UIImage, Error>] = [:]
    func get(_ url: URL) -> Task<UIImage, Error>? { tasks[url] }
    func set(_ url: URL, task: Task<UIImage, Error>) { tasks[url] = task }
    func remove(_ url: URL) { tasks[url] = nil }
}

/// Загрузка: память / диск / сеть
final class ImageLoader: ImageLoading {
    static let shared = ImageLoader()

    private let memory = NSCache<NSURL, UIImage>()
    private let disk = DiskCache.shared
    private let inflight = InflightStore()
    private let session: URLSession
    private let screenScale: CGFloat

    private var prefetchTasks: [URL: Task<Void, Never>] = [:]
    private let prefetchSemaphore = DispatchSemaphore(value: 4)

    private init(session: URLSession = .shared) {
        self.session = session
        self.screenScale = UIScreen.main.scale
        memory.totalCostLimit = 128 * 1024 * 1024
        memory.countLimit = 2000

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Периодическая очистка устаревших файлов
        cleanupExpiredFilesPeriodically()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func didReceiveMemoryWarning() {
        Logger("Memory warning received. Clearing image cache...")
        memory.removeAllObjects()
    }
    
    private func cleanupExpiredFilesPeriodically() {
        Task.detached(priority: .utility) { [weak self] in
            // Очистка каждые 24 часа
            while true {
                try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)
                self?.disk.cleanupExpiredFiles()
            }
        }
    }

    // MARK: - Public
    
    func image(for url: URL) async throws -> UIImage {
        try await image(for: url, targetSize: nil, scale: screenScale)
    }

    func image(for url: URL, targetSize: CGSize?, scale: CGFloat) async throws -> UIImage {
        // Проверка валидности URL
        guard url.isFileURL || (url.scheme != nil && url.host != nil) else {
            throw URLError(.badURL)
        }

        if let existing = await inflight.get(url) {
            return try await existing.value
        }

        let task = Task.detached(priority: .userInitiated) { [weak self] () -> UIImage in
            guard let self else { throw CancellationError() }
            defer { Task { await self.inflight.remove(url) } }

            // Поиск в памяти
            if let img = self.memory.object(forKey: url as NSURL) {
                Logger("Cached ram: \(url.lastPathComponent)")
                return img
            }

            // Поиск на диске
            if let data = self.disk.read(url), let img = Self.makeImage(from: data, targetSize: targetSize, scale: scale) {
                Logger("Cached disk: \(url.lastPathComponent)")
                self.memory.setObject(img, forKey: url as NSURL, cost: img.cacheCost)
                return img
            }

            // Загрузка из сети
            let (data, response) = try await self.session.data(from: url)
            
            // Проверка HTTP статуса
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
            
            guard let img = Self.makeImage(from: data, targetSize: targetSize, scale: scale) else {
                throw URLError(.cannotDecodeContentData)
            }
            
            Logger("Network download: \(url.lastPathComponent)")
            self.disk.write(data, for: url)
            self.memory.setObject(img, forKey: url as NSURL, cost: img.cacheCost)
            return img
        }
        
        await inflight.set(url, task: task)
        return try await task.value
    }
    
    func prefetch(urls: [URL]) {
        // Фильтруем уже загруженные или загружаемые
        let urlsToPrefetch = urls.filter { url in
            prefetchTasks[url] == nil &&
            memory.object(forKey: url as NSURL) == nil &&
            disk.read(url) == nil
        }
        
        for url in urlsToPrefetch {
            guard prefetchTasks[url] == nil else { continue }
            
            let task = Task.detached(priority: .utility) { [weak self] in
                guard let self else { return }
                Logger("Prefetching start: \(url.lastPathComponent)")
                self.prefetchSemaphore.wait()
                defer { self.prefetchSemaphore.signal() }
                
                do {
                    _ = try await self.image(for: url, targetSize: nil, scale: 1.0)
                    Logger("Prefetching success: \(url.lastPathComponent)")
                } catch {
                    Logger("Prefetch failed: \(url.lastPathComponent): \(error.localizedDescription)")
                }
                
                await MainActor.run {
                    self.prefetchTasks[url] = nil
                }
            }
            
            prefetchTasks[url] = task
        }
    }

    func cancelPrefetch(urls: [URL]) {
        for url in urls {
            prefetchTasks[url]?.cancel()
            prefetchTasks[url] = nil
        }
    }
}

// MARK: - Helpers
extension ImageLoader {

    fileprivate static func makeImage(from data: Data, targetSize: CGSize?, scale: CGFloat) -> UIImage? {
        guard let targetSize, targetSize.width > 0, targetSize.height > 0 else {
            return UIImage(data: data, scale: scale)
        }
        
        // Если исходное изображение меньше целевого
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
           let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            
            let originalSize = CGSize(width: width, height: height)
            if originalSize.width <= targetSize.width && originalSize.height <= targetSize.height {
                return UIImage(data: data, scale: scale)
            }
        }
        
        let srcOpts: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts as CFDictionary) else {
            return UIImage(data: data, scale: scale)
        }
        
        let maxDim = max(targetSize.width, targetSize.height) * max(scale, 1.0)
        let downsampleOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxDim)),
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, downsampleOpts as CFDictionary) {
            return UIImage(cgImage: cg, scale: scale, orientation: .up)
        }
        
        return UIImage(data: data, scale: scale)
    }
}

extension UIImage {

    fileprivate var cacheCost: Int {
        guard let cg = cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
    }
}
