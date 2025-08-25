//
//  ImageLoading.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 24.08.2025.
//

import UIKit

protocol ImageLoading: AnyObject {
    
    /// Загрузка в последовательности память / диск / сеть
    func image(for url: URL) async throws -> UIImage

    /// Ресайз изображений
    func image(for url: URL, targetSize: CGSize?, scale: CGFloat) async throws -> UIImage

    /// Предзагрузка
    func prefetch(urls: [URL])

    /// Отмена предзагрузки
    func cancelPrefetch(urls: [URL])
}
