//
//  DiskCache.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 20.08.2025.
//

import CryptoKit
import Foundation

/// Дисковый кэш
final class DiskCache {
    static let shared = DiskCache()

    private let fm = FileManager.default
    private let directory: URL

    private init(folderName: String = "Images") {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.directory = dir
    }

    private func key(for url: URL) -> String {
        let normalizedString = url.absoluteString.lowercased().trimmingCharacters(in: .whitespaces)
        let hash = SHA256.hash(data: Data(normalizedString.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func path(for url: URL) -> URL {
        let name = key(for: url)
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
        return directory.appendingPathComponent("\(name).\(ext)")
    }

    func read(_ url: URL) -> Data? {
        let fileURL = path(for: url)
        return try? Data(contentsOf: fileURL)
    }

    func write(_ data: Data, for url: URL) {
        let fileURL = path(for: url)
        try? data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? fm.removeItem(at: directory)
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    func cleanupExpiredFiles(expirationInterval: TimeInterval = 60 * 60 * 24 * 7) {
        do {
            let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modificationDate = attributes.contentModificationDate,
                   Date().timeIntervalSince(modificationDate) > expirationInterval {
                    try? fm.removeItem(at: file)
                }
            }
        } catch {
            Logger("Disk cache cleanup failed: \(error)")
        }
    }
}
