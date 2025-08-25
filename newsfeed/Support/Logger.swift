//
//  Logger.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 20.08.2025.
//

import Foundation

enum LogLevel {
    case debug, release
}

var currentLevel: LogLevel = .debug

func Logger(_ message: String) {
    guard currentLevel == .debug else { return }
    print("[DEBUG] \(message)")
}
